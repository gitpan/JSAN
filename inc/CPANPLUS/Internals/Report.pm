#line 1 "inc/CPANPLUS/Internals/Report.pm - /Library/Perl/5.8.6/CPANPLUS/Internals/Report.pm"
package CPANPLUS::Internals::Report;

use strict;
use CPANPLUS::inc;
use CPANPLUS::Error;
use CPANPLUS::Internals::Constants;
use CPANPLUS::Internals::Constants::Report;

use Data::Dumper;

use Params::Check               qw[check];
use Locale::Maketext::Simple    Class => 'CPANPLUS', Style => 'gettext';
use Module::Load::Conditional   qw[can_load];

$Params::Check::VERBOSE = 1;

### for the version ###
require CPANPLUS::Internals;

#line 33
{   my $query_list = {
        LWP              => '0.0',
        'LWP::UserAgent' => '0.0',
        'HTTP::Request'  => '0.0',
        URI              => '0.0',
        YAML             => '0.0',
    };

    my $send_list = {
        %$query_list,
        'Test::Reporter' => 1.27,
    };

    sub _have_query_report_modules {
        my $self = shift;
        my $conf = $self->configure_object;
        my %hash = @_;

        my $tmpl = {
            verbose => { default => $conf->get_conf('verbose') },
        };

        my $args = check( $tmpl, \%hash ) or return;

        return can_load( modules => $query_list, verbose => $args->{verbose} )
                ? 1
                : 0;
    }

    sub _have_send_report_modules {
        my $self = shift;
        my $conf = $self->configure_object;
        my %hash = @_;

        my $tmpl = {
            verbose => { default => $conf->get_conf('verbose') },
        };

        my $args = check( $tmpl, \%hash ) or return;

        return can_load( modules => $send_list, verbose => $args->{verbose} )
                ? 1
                : 0;
    }
}

#line 119

sub _query_report {
    my $self = shift;
    my $conf = $self->configure_object;
    my %hash = @_;

    my($mod, $verbose, $all);
    my $tmpl = {
        module          => { required => 1, allow => IS_MODOBJ,
                                store => \$mod },
        verbose         => { default => $conf->get_conf('verbose'),
                                store => \$verbose },
        all_versions    => { default => 0, store => \$all },
    };

    check( $tmpl, \%hash ) or return;

    ### check if we have the modules we need for querying
    return unless $self->_have_query_report_modules( verbose => 1 );

    ### new user agent ###
    my $ua = LWP::UserAgent->new;
    $ua->agent( CPANPLUS_UA->() );

    ### set proxies if we have them ###
    $ua->env_proxy();

    my $url = TESTERS_URL->($mod->package_name);
    my $req = HTTP::Request->new( GET => $url);

    msg( loc("Fetching: '%1'", $url), $verbose );

    my $res = $ua->request( $req );

    unless( $res->is_success ) {
        error( loc( "Fetching report for '%1' failed: %2",
                    $url, $res->message ) );
        return;
    }

    my $aref = YAML::Load( $res->content );

    my $dist = $mod->package_name .'-'. $mod->package_version;

    my @rv;
    for my $href ( @$aref ) {
        next unless $all or defined $href->{'distversion'} && 
                            $href->{'distversion'} eq $dist;

        push @rv, { platform    => $href->{'platform'},
                    grade       => $href->{'action'},
                    dist        => $href->{'distversion'},
                    ( $href->{'action'} eq 'FAIL'
                        ? (details => TESTERS_DETAILS_URL->($mod->package_name))
                        : ()
                    ) };
    }

    return @rv if @rv;
    return;
}

#line 247

sub _send_report {
    my $self = shift;
    my $conf = $self->configure_object;
    my %hash = @_;

    ### do you even /have/ test::reporter? ###
    unless( $self->_have_send_report_modules(verbose => 1) ) {
        error( loc( "You don't have '%1' (or modules required by '%2') ".
                    "installed, you cannot report test results.",
                    'Test::Reporter', 'Test::Reporter' ) );
        return;
    }

    ### check arguments ###
    my ($buffer, $failed, $mod, $verbose, $force, $address, $save, $dontcc);
    my $tmpl = {
            module  => { required => 1, store => \$mod, allow => IS_MODOBJ },
            buffer  => { required => 1, store => \$buffer },
            failed  => { required => 1, store => \$failed },
            address => { default  => CPAN_TESTERS_EMAIL, store => \$address },
            save    => { default  => 0, store => \$save },
            dontcc  => { default  => 0, store => \$dontcc },
            verbose => { default  => $conf->get_conf('verbose'),
                            store => \$verbose },
            force   => { default  => $conf->get_conf('force'),
                            store => \$force },
    };

    check( $tmpl, \%hash ) or return;

    ### get the data to fill the email with ###
    my $name    = $mod->module;
    my $dist    = $mod->package_name . '-' . $mod->package_version;
    my $author  = $mod->author->author;
    my $email   = $mod->author->email || CPAN_MAIL_ACCOUNT->( $author );
    my $cp_conf = $conf->get_conf('cpantest') || '';
    my $int_ver = $CPANPLUS::Internals::VERSION;


    ### determine the grade now ###

    my $grade;
    ### check if this is a platform specific module ###
    unless( RELEVANT_TEST_RESULT->($mod) ) {
        msg(loc("'%1' is a platform specific module, and the test results on".
                " your platform are not relevant --sending N/A grade.",
                $name), $verbose);

        $grade = GRADE_NA;

    ### you dont have a high enough perl version?    
    } elsif ( PERL_VERSION_TOO_LOW->( $buffer ) ) {
        msg(loc("'%1' requires a higher version of perl than your current ".
                "version -- sending N/A grade.", $name), $verbose);

        $grade = GRADE_NA;                

    ### see if the thing even had tests ###
    } elsif ( NO_TESTS_DEFINED->( $buffer ) ) {
        $grade = GRADE_UNKNOWN;

    ### see if it was a pass or fail ###
    } else {
        $grade = $failed ? GRADE_FAIL : GRADE_PASS;
    }

    ### so an error occurred, let's see what stage it went wrong in ###
    my $message;
    if( $grade eq GRADE_FAIL or $grade eq GRADE_UNKNOWN) {

        ### return if one or more missing external libraries
        if( my @missing = MISSING_EXTLIBS_LIST->($buffer) ) {
            msg(loc("Not sending test report - external libraries not pre-installed"));
            return 1;
        }

        ### will be 'fetch', 'make', 'test', 'install', etc ###
        my $stage   = TEST_FAIL_STAGE->($buffer);

        ### return if we're only supposed to report make_test failures ###
        return 1 if $cp_conf =~  /\bmaketest_only\b/i
                    and ($stage !~ /\btest\b/);

        ### the header
        $message =  REPORT_MESSAGE_HEADER->( $int_ver, $author );

        ### the bit where we inform what went wrong
        $message .= REPORT_MESSAGE_FAIL_HEADER->( $stage, $buffer );

        ### was it missing prereqs? ###
        if( my @missing = MISSING_PREREQS_LIST->($buffer) ) {
            if(!$self->_verify_missing_prereqs(
								module  => $mod,
								missing => \@missing
						)) {
                msg(loc("Not sending test report - bogus missing prerequisites report"));
                return 1;
            }
            $message .= REPORT_MISSING_PREREQS->($author,$email,@missing);
        }

        ### was it missing test files? ###
        if( NO_TESTS_DEFINED->($buffer) ) {
            $message .= REPORT_MISSING_TESTS->();
        }

        ### add a list of what modules have been loaded of your prereqs list
        $message .= REPORT_LOADED_PREREQS->($mod);

        ### the footer
        $message .=  REPORT_MESSAGE_FOOTER->();
    }

    ### if it failed, and that already got reported, we're not cc'ing the
    ### author. Also, 'dont_cc' might be in the config, so check this;
    my $dont_cc_author = $dontcc;

    unless( $dont_cc_author ) {
        if( $cp_conf =~ /\bdont_cc\b/i ) {
            $dont_cc_author++;

        } elsif ( $grade eq GRADE_PASS ) {
            $dont_cc_author++

        } elsif( $grade eq GRADE_FAIL ) {
            my @already_sent =
                $self->_query_report( module => $mod, verbose => $verbose );

            ### if we can't fetch it, we'll just assume no one
            ### mailed him yet
            my $count = 0;
            if( @already_sent ) {
                for my $href (@already_sent) {
                    $count++ if uc $href->{'grade'} eq uc GRADE_FAIL;
                }
            }

            if( $count > MAX_REPORT_SEND and !$force) {
                msg(loc("'%1' already reported for '%2', ".
                        "not cc-ing the author",
                        GRADE_FAIL, $dist ), $verbose );
                $dont_cc_author++;
            }
        }
    }

    ### reporter object ###
    my $reporter = Test::Reporter->new(
                        grade           => $grade,
                        distribution    => $dist,
                        via             => "CPANPLUS $int_ver",
                    );

    ### set the from address ###
    $reporter->from( $conf->get_conf('email') )
        if $conf->get_conf('email') !~ /\@example\.\w+$/i;

    ### give the user a chance to programattically alter the message
    $message = $self->_callbacks->munge_test_report->( $mod, $message );

    ### add the body if we have any ###
    $reporter->comments( $message ) if defined $message && length $message;

    ### do a callback to ask if we should send the report
    unless ($self->_callbacks->send_test_report->($mod, $grade)) {
        msg(loc("Ok, not sending test report"));
        return 1;
    }

    ### do a callback to ask if we should edit the report
    if ($self->_callbacks->edit_test_report->($mod, $grade)) {
        ### test::reporter 1.20 and lower don't have a way to set
        ### the preferred editor with a method call, but it does
        ### respect your env variable, so let's set that.
        local $ENV{VISUAL} = $conf->get_program('editor')
                                if $conf->get_program('editor');

        $reporter->edit_comments;
    }

    ### people to mail ###
    my @inform;
    #push @inform, $email unless $dont_cc_author;

    ### allow to be overridden, but default to the normal address ###
    $reporter->address( $address );

    ### should we save it locally? ###
    if( $save ) {
        if( my $file = $reporter->write() ) {
            msg(loc("Successfully wrote report for '%1' to '%2'",
                    $dist, $file), $verbose);
            return $file;

        } else {
            error(loc("Failed to write report for '%1'", $dist));
            return;
        }

    ### should we send it to a bunch of people? ###
    ### XXX should we do an 'already sent' check? ###
    } elsif( $reporter->send( @inform ) ) {
        msg(loc("Successfully sent '%1' report for '%2'", $grade, $dist),
            $verbose);
        return 1;

    ### something broke :( ###
    } else {
        error(loc("Could not send '%1' report for '%2': %3",
                $grade, $dist, $reporter->errstr));
        return;
    }
}

sub _verify_missing_prereqs {
    my $self = shift;
    my %hash = @_;

    ### check arguments ###
    my ($mod, $missing);
    my $tmpl = {
            module  => { required => 1, store => \$mod },
            missing => { required => 1, store => \$missing },
    };

    check( $tmpl, \%hash ) or return;

	
    my %missing = map {$_ => 1} @$missing;
    my $conf = $self->configure_object;

    ### Read pre-requisites from Makefile.PL or Build.PL (if there is one),
    ### of the form:
    ###     'PREREQ_PM' => {
    ###                      'Compress::Zlib'        => '1.20',
    ###                      'Test::More'            => 0,
    ###                    },
    ###  Build.PL uses 'requires' instead of 'PREREQ_PM'.


    for my $file (  MAKEFILE_PL->( $mod->status->extract ),
                    BUILD_PL->( $mod->status->extract ),
    ) {
        if(-e $file and -r $file) {
            my $slurp = $self->_get_file_contents(file => $file);
            my ($prereq) = 
                ($slurp =~ /'?(?:PREREQ_PM|requires)'?\s*=>\s*{(.*?)}/s);
            my @prereq = 
                ($prereq =~ /'?([\w\:]+)'?\s*=>\s*'?\d[\d\.\-\_]*'?/sg);
            delete $missing{$_} for(@prereq);
        }
    }

    return 1    if(keys %missing);  # There ARE missing prerequisites
    return;                         # All prerequisites accounted for
}

1;


# Local variables:
# c-indentation-style: bsd
# c-basic-offset: 4
# indent-tabs-mode: nil
# End:
# vim: expandtab shiftwidth=4:

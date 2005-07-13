#line 1 "inc/CPANPLUS/Internals/Fetch.pm - /Library/Perl/5.8.6/CPANPLUS/Internals/Fetch.pm"
package CPANPLUS::Internals::Fetch;

use strict;
use CPANPLUS::inc;
use CPANPLUS::Error;
use CPANPLUS::Internals::Constants;

use File::Fetch;
use File::Spec;
use Cwd                         qw[cwd];
use IPC::Cmd                    qw[run];
use Params::Check               qw[check];
use Module::Load::Conditional   qw[can_load];
use Locale::Maketext::Simple    Class => 'CPANPLUS', Style => 'gettext';

$Params::Check::VERBOSE = 1;

#line 51

#line 82

sub _fetch {
    my $self = shift;
    my $conf = $self->configure_object;
    my %hash = @_;

    local $Params::Check::NO_DUPLICATES = 0;

    my ($modobj, $verbose, $force);
    my $tmpl = {
        module      => { required => 1, allow => IS_MODOBJ, store => \$modobj },
        fetchdir    => { default => $conf->get_conf('fetchdir') },
        force       => { default => $conf->get_conf('force'),
                            store => \$force },
        verbose     => { default => $conf->get_conf('verbose'),
                            store => \$verbose },
        prefer_bin  => { default => $conf->get_conf('prefer_bin') },
    };


    my $args = check( $tmpl, \%hash ) or return;

    ### check if we already downloaded the thing ###
    if( (my $where = $modobj->status->fetch()) && !$force ) {
        msg(loc("Already fetched '%1' to '%2', " .
                "won't fetch again without force",
                $modobj->module, $where ), $verbose );
        return $where;
    }

    my ($remote_file, $local_file, $local_path);

    ### build the remote path to download from ###
    {   $remote_file = File::Spec::Unix->catfile(
                                    $modobj->path,
                                    $modobj->package,
                                );
        unless( $remote_file ) {
            error( loc('No remote file given for download') );
            return;
        }
    }

    ### build the local path to downlaod to ###
    {
        $local_path =   $args->{fetchdir} ||
                        File::Spec->catdir(
                            $conf->get_conf('base'),
                            $modobj->path,
                        );

        ### create the path if it doesn't exist ###
        unless( -d $local_path ) {
            unless( $self->_mkdir( dir => $local_path ) ) {
                msg( loc("Could not create path '%1'", $local_path), $verbose);
                return;
            }
        }

        $local_file = File::Spec->rel2abs(
                        File::Spec->catfile(
                                    $local_path,
                                    $modobj->package,
                        )
                    );
    }


    ### do we already have the file? ###
    if( -e $local_file ) {

        if( $args->{force} ) {

            ### some fetches will fail if the files exist already, so let's
            ### delete them first
            unlink $local_file
                or msg( loc("Could not delete %1, some methods may " .
                            "fail to force a download", $local_file), $verbose);
         } else {

            ### store where we fetched it ###
            $modobj->status->fetch( $local_file );

            return $local_file;
        }
    }

    ### see if we even have a host or a method to use to download with ###
    my $found_host;
    my @maybe_bad_host;

    HOST: {
        ### F*CKING PIECE OF F*CKING p4 SHIT makes '$File :: Fetch::SOME_VAR'
        ### into a meta variable and starts substituting the file name...
        ### GRAAAAAAAAAAAAAAAAAAAAAAH!
        ### use ' to combat it!

        ### set up some flags for File::Fetch ###
        local $File'Fetch::BLACKLIST    = $conf->_get_fetch('blacklist');
        local $File'Fetch::TIMEOUT      = $conf->get_conf('timeout');
        local $File'Fetch::DEBUG        = $conf->get_conf('debug');
        local $File'Fetch::FTP_PASSIVE  = $conf->get_conf('passive');
        local $File'Fetch::FROM_EMAIL   = $conf->get_conf('email');
        local $File'Fetch::PREFER_BIN   = $conf->get_conf('prefer_bin');
        local $File'Fetch::WARN         = $verbose;


        ### loop over all hosts we have ###
        for my $host ( @{$conf->get_conf('hosts')} ) {
            $found_host++;

            my $mirror_path = File::Spec::Unix->catfile(
                                    $host->{'path'}, $remote_file
                                );

            ### build pretty print uri ###
            my $where;
            if( $host->{'scheme'} eq 'file' ) {
                $where = CREATE_FILE_URI->(
                            File::Spec::Unix->rel2abs(
                                File::Spec::Unix->catdir(
                                    grep { defined $_ && length $_ }
                                    $host->{'host'},
                                    $mirror_path
                                 )
                            )
                        );
            } else {
                $where = "$host->{scheme}://" .
                         File::Spec::Unix->catdir(
                            ($host->{'host'} ? $host->{'host'} : 'localhost'),
                            $mirror_path
                         );
            }

            msg(loc("Trying to get '%1'", $where ), $verbose );

            ### build the object ###
            my $ff = File::Fetch->new( uri => $where );

            ### sanity check ###
            error(loc("Bad uri '%1'",$where)),next unless $ff;

            if( my $file = $ff->fetch( to => $local_path ) ) {
                unless( -e $file && -s _ ) {
                    msg(loc("'%1' said it fetched '%2', but it was not created",
                            'File::Fetch', $file), $verbose);

                } else {
                    my $abs = File::Spec->rel2abs( $file );

                    ### store where we fetched it ###
                    $modobj->status->fetch( $abs );

                    ### this host is good, the previous ones are apparently
                    ### not, so mark them as such.
                    $self->_add_fail_host( host => $_ ) for @maybe_bad_host;

                    return $abs;
                }

            } else {
                error(loc("Fetching of '%1' failed: %2", $where, $ff->error));
            }

            ### so we tried to get the file but didn't actually fetch it --
            ### there's a chance this host is bad. mark it as such and actually
            ### flag it back if we manage to get the file somewhere else
            push @maybe_bad_host, $host;
        }
    }

    $found_host
        ? error(loc("Fetch failed: host list exhausted " .
                    "-- are you connected today?"))
        : error(loc("No hosts found to download from -- check your config"));

    return;
}

#line 277

{   ### caching functions ###

    sub _add_fail_host {
        my $self = shift;
        my %hash = @_;

        my $host;
        my $tmpl = {
            host => { required      => 1, default   => {},
                      strict_type   => 1, store     => \$host },
        };

        check( $tmpl, \%hash ) or return;

        return $self->_hosts->{$host} = 1;
    }

    sub _host_ok {
        my $self = shift;
        my %hash = @_;

        my $host;
        my $tmpl = {
            host => { required => 1, store => \$host },
        };

        check( $tmpl, \%hash ) or return;

        return $self->_hosts->{$host} ? 0 : 1;
    }
}


1;

# Local variables:
# c-indentation-style: bsd
# c-basic-offset: 4
# indent-tabs-mode: nil
# End:
# vim: expandtab shiftwidth=4:

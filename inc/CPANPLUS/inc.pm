#line 1 "inc/CPANPLUS/inc.pm - /Library/Perl/5.8.6/CPANPLUS/inc.pm"
package CPANPLUS::inc;

use strict;
use vars        qw[$DEBUG $VERSION $ENABLE_INC_HOOK %LIMIT];
use File::Spec  ();
use Config      ();

### 5.6.1. nags about require + bareword otherwise ###
use lib ();

$DEBUG              = 0;
%LIMIT              = ();

#line 67

{   my $ext     = '.pm';
    my $file    = (join '/', split '::', __PACKAGE__) . $ext;

    ### os specific file path, if you're not on unix
    my $osfile  = File::Spec->catfile( split('::', __PACKAGE__) ) . $ext;

    ### this returns a unixy path, compensate if you're on non-unix
    my $path    = File::Spec->rel2abs(
                        File::Spec->catfile( split '/', $INC{$file} )
                    );

    ### don't forget to quotemeta; win32 paths are special
    my $qm_osfile = quotemeta $osfile;
    my $path_to_me          = $path; $path_to_me    =~ s/$qm_osfile$//i;
    my $path_to_inc         = $path; $path_to_inc   =~ s/$ext$//i;
    my $path_to_installers  = File::Spec->catdir( $path_to_inc, 'installers' );

    sub inc_path        { return $path_to_inc  }
    sub my_path         { return $path_to_me   }
    sub installer_path  { return $path_to_installers }
}

#line 113

{   my $org_opt = $ENV{PERL5OPT};
    my $org_lib = $ENV{PERL5LIB};
    my @org_inc = @INC;

    sub original_perl5opt   { $org_opt || ''};
    sub original_perl5lib   { $org_lib || ''};
    sub original_inc        { @org_inc };

    sub limited_perl5opt    {
        my $pkg = shift;
        my $lim = join ',', @_ or return;

        ### -Icp::inc -Mcp::inc=mod1,mod2,mod3
        my $opt =   '-I' . __PACKAGE__->my_path . ' ' .
                    '-M' . __PACKAGE__ . "=$lim";

        $opt .=     $Config::Config{'path_sep'} .
                    CPANPLUS::inc->original_perl5opt
                if  CPANPLUS::inc->original_perl5opt;

        return $opt;
    }
}

#line 151

{
    my $map = {
        'File::Fetch'               => '0.07',
        #'File::Spec'                => '0.82', # can't, need it ourselves...
        'IPC::Run'                  => '0.80',
        'IPC::Cmd'                  => '0.24',
        'Locale::Maketext::Simple'  => 0,
        'Log::Message'              => 0,
        'Module::Load'              => '0.10',
        'Module::Load::Conditional' => '0.07',
        'Module::Build'             => '0.26081',
        'Params::Check'             => '0.22',
        'Term::UI'                  => '0.05',
        'Archive::Extract'          => '0.07',
        'Archive::Tar'              => '1.23',
        'IO::Zlib'                  => '1.04',
        'Object::Accessor'          => '0.03',
        'Module::CoreList'          => '1.97',
        'Module::Pluggable'         => '2.4',
        #'Config::Auto'             => 0,   # not yet, not using it yet
    };

    sub interesting_modules { return $map; }
}


#line 216

{   my $Loaded;
    my %Cache;


    ### returns the path to a certain module we found
    sub path_to {
        my $self    = shift;
        my $mod     = shift or return;

        ### find the directory
        my $path    = $Cache{$mod}->[0][2] or return;

        ### probe them explicitly for a special file, because the
        ### dir we found the file in vs our own paths may point to the
        ### same location, but might not pass an 'eq' test.

        ### it's our inc-path
        return __PACKAGE__->inc_path
                if -e File::Spec->catfile( $path, '.inc' );

        ### it's our installer path
        return __PACKAGE__->installer_path
                if -e File::Spec->catfile( $path, '.installers' );

        ### it's just some dir...
        return $path;
    }

    ### just a debug method
    sub _show_cache { return \%Cache };

    sub import {
        my $pkg = shift;

        ### filter DEBUG, and toggle the global
        map { $LIMIT{$_} = 1 }  grep { /DEBUG/ ? ++$DEBUG && 0 : 1 } @_;

        ### only load once ###
        return 1 if $Loaded++;

        ### first, add our own private dir to the end of @INC:
        {
            push @INC,  __PACKAGE__->my_path, __PACKAGE__->inc_path,
                        __PACKAGE__->installer_path;

            ### XXX stop doing this, there's no need for it anymore;
            ### none of the shell outs need to have this set anymore
#             ### add the path to this module to PERL5OPT in case
#             ### we spawn off some programs...
#             ### then add this module to be loaded in PERL5OPT...
#             {   local $^W;
#                 $ENV{'PERL5LIB'} .= $Config::Config{'path_sep'}
#                                  . __PACKAGE__->my_path
#                                  . $Config::Config{'path_sep'}
#                                  . __PACKAGE__->inc_path;
#
#                 $ENV{'PERL5OPT'} = '-M'. __PACKAGE__ . ' '
#                                  . ($ENV{'PERL5OPT'} || '');
#             }
        }

        ### next, find the highest version of a module that
        ### we care about. very basic check, but will
        ### have to do for now.
        lib->import( sub {
            my $path    = pop();                    # path to the pm
            my $module  = $path or return;          # copy of the path, to munge
            my @parts   = split qr!\\|/!, $path;    # dirs + file name; could be
                                                    # win32 paths =/
            my $file    = pop @parts;               # just the file name
            my $map     = __PACKAGE__->interesting_modules;

            ### translate file name to module name 
            ### could contain win32 paths delimiters
            $module =~ s!/|\\!::!g; $module =~ s/\.pm//i;

            my $check_version; my $try;
            ### does it look like a module we care about?
            my ($interesting) = grep { $module =~ /^$_/ } keys %$map;
            ++$try if $interesting;

            ### do we need to check the version too?
            ++$check_version if exists $map->{$module};

            ### we don't care ###
            unless( $try ) {
                warn __PACKAGE__ .": Not interested in '$module'\n" if $DEBUG;
                return;

            ### we're not allowed
            } elsif ( $try and keys %LIMIT ) {
                unless( grep { $module =~ /^$_/ } keys %LIMIT  ) {
                    warn __PACKAGE__ .": Limits active, '$module' not allowed ".
                                        "to be loaded" if $DEBUG;
                    return;
                }
            }

            ### found filehandles + versions ###
            my @found;
            DIR: for my $dir (@INC) {
                next DIR unless -d $dir;

                ### get the full path to the module ###
                my $pm = File::Spec->catfile( $dir, @parts, $file );

                ### open the file if it exists ###
                if( -e $pm ) {
                    my $fh;
                    unless( open $fh, "$pm" ) {
                        warn __PACKAGE__ .": Could not open '$pm': $!\n"
                            if $DEBUG;
                        next DIR;
                    }

                    my $found;
                    ### XXX stolen from module::load::conditional ###
                    while (local $_ = <$fh> ) {

                        ### the following regexp comes from the
                        ### ExtUtils::MakeMaker documentation.
                        if ( /([\$*])(([\w\:\']*)\bVERSION)\b.*\=/ ) {

                            ### this will eval the version in to $VERSION if it
                            ### was declared as $VERSION in the module.
                            ### else the result will be in $res.
                            ### this is a fix on skud's Module::InstalledVersion

                            local $VERSION;
                            my $res = eval $_;

                            ### default to '0.0' if there REALLY is no version
                            ### all to satisfy warnings
                            $found = $VERSION || $res || '0.0';

                            ### found what we came for
                            last if $found;
                        }
                    }

                    ### no version defined at all? ###
                    $found ||= '0.0';

                    warn __PACKAGE__ .": Found match for '$module' in '$dir' "
                                     ."with version '$found'\n" if $DEBUG;

                    ### reset the position of the filehandle ###
                    seek $fh, 0, 0;

                    ### store the found version + filehandle it came from ###
                    push @found, [ $found, $fh, $dir, $pm ];
                }

            } # done looping over all the dirs

            ### nothing found? ###
            unless (@found) {
                warn __PACKAGE__ .": Unable to find any module named "
                                    . "'$module'\n" if $DEBUG;
                return;
            }

            ### find highest version
            ### or the one in the same dir as a base module already loaded
            ### or otherwise, the one not bundled
            ### or otherwise the newest
            my @sorted = sort {
                            ($b->[0] <=> $a->[0])                   ||
                            ($Cache{$interesting}
                                ?($b->[2] eq $Cache{$interesting}->[0][2]) <=>
                                 ($a->[2] eq $Cache{$interesting}->[0][2])
                                : 0 )                               ||
                            (($a->[2] eq __PACKAGE__->inc_path) <=>
                             ($b->[2] eq __PACKAGE__->inc_path))    ||
                            (-M $a->[3] <=> -M $b->[3])
                          } @found;

            warn __PACKAGE__ .": Best match for '$module' is found in "
                             ."'$sorted[0][2]' with version '$sorted[0][0]'\n"
                    if $DEBUG;

            if( $check_version and not ($sorted[0][0] >= $map->{$module}) ) {
                warn __PACKAGE__ .": Cannot find high enough version for "
                                 ."'$module' -- need '$map->{$module}' but "
                                 ."only found '$sorted[0][0]'. Returning "
                                 ."highest found version but this may cause "
                                 ."problems\n";
            };

            ### right, so that damn )#$(*@#)(*@#@ Module::Build makes
            ### assumptions about the environment (especially its own tests)
            ### and blows up badly if it's loaded via CP::inc :(
            ### so, if we find a newer version on disk (which would happen when
            ### upgrading or having upgraded, just pretend we didn't find it,
            ### let it be loaded via the 'normal' way.
            ### can't even load the *proper* one via our CP::inc, as it will
            ### get upset just over the fact it's loaded via a non-standard way
            if( $module =~ /^Module::Build/ and
                $sorted[0][2] ne __PACKAGE__->inc_path and
                $sorted[0][2] ne __PACKAGE__->installer_path
            ) {
                warn __PACKAGE__ .": Found newer version of 'Module::Build::*' "
                                 ."elsewhere in your path. Pretending to not "
                                 ."have found it\n" if $DEBUG;
                return;
            }

            ### store what we found for this module
            $Cache{$module} = \@sorted;

            ### best matching filehandle ###
            return $sorted[0][1];
        } );
    }
}

#line 478

1;

# Local variables:
# c-indentation-style: bsd
# c-basic-offset: 4
# indent-tabs-mode: nil
# End:
# vim: expandtab shiftwidth=4:


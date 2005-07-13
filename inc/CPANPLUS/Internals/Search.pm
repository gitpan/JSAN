#line 1 "inc/CPANPLUS/Internals/Search.pm - /Library/Perl/5.8.6/CPANPLUS/Internals/Search.pm"
package CPANPLUS::Internals::Search;

use strict;
use CPANPLUS::inc;
use CPANPLUS::Error;
use CPANPLUS::Internals::Constants;
use CPANPLUS::Module;
use CPANPLUS::Module::Author;

use File::Find;
use File::Spec;

use Params::Check               qw[check allow];
use Locale::Maketext::Simple    Class => 'CPANPLUS', Style => 'gettext';

$Params::Check::VERBOSE = 1;

#line 80

# Although the Params::Check solution is more graceful, it is WAY too slow.
#
# This sample script:
#
#     use CPANPLUS::Backend;
#     my $cb = new CPANPLUS::Backend;
#     $cb->module_tree;
#     my @list = $cb->search( type => 'module', allow => [qr/^Acme/] );
#     print $_->module, $/ for @list;
#
# Produced the following output using Dprof WITH params::check code
#
#     Total Elapsed Time = 3.670024 Seconds
#       User+System Time = 3.390373 Seconds
#     Exclusive Times
#     %Time ExclSec CumulS #Calls sec/call Csec/c  Name
#      88.7   3.008  4.463  20610   0.0001 0.0002  Params::Check::check
#      47.4   1.610  1.610      1   1.6100 1.6100  Storable::net_pstore
#      25.6   0.869  0.737  20491   0.0000 0.0000  Locale::Maketext::Simple::_default
#                                                  _gettext
#      23.2   0.789  0.524  40976   0.0000 0.0000  Params::Check::_who_was_it
#      23.2   0.789  0.677  20610   0.0000 0.0000  Params::Check::_sanity_check
#      19.7   0.670  0.670      1   0.6700 0.6700  Storable::pretrieve
#      14.1   0.480  0.211  41350   0.0000 0.0000  Params::Check::_convert_case
#      11.5   0.390  0.256  20610   0.0000 0.0000  Params::Check::_hashdefs
#      11.5   0.390  0.255  20697   0.0000 0.0000  Params::Check::_listreqs
#      11.4   0.389  0.177  20653   0.0000 0.0000  Params::Check::_canon_key
#      10.9   0.370  0.356  20697   0.0000 0.0000  Params::Check::_hasreq
#      8.02   0.272  4.750      1   0.2723 4.7501  CPANPLUS::Internals::Search::_sear
#                                                  ch_module_tree
#      6.49   0.220  0.086  20653   0.0000 0.0000  Params::Check::_iskey
#      6.19   0.210  0.077  20488   0.0000 0.0000  Params::Check::_store_error
#      5.01   0.170  0.036  20680   0.0000 0.0000  CPANPLUS::Module::__ANON__
#
# and this output /without/
#
#     Total Elapsed Time = 2.803426 Seconds
#       User+System Time = 2.493426 Seconds
#     Exclusive Times
#     %Time ExclSec CumulS #Calls sec/call Csec/c  Name
#      56.9   1.420  1.420      1   1.4200 1.4200  Storable::net_pstore
#      25.6   0.640  0.640      1   0.6400 0.6400  Storable::pretrieve
#      9.22   0.230  0.096  20680   0.0000 0.0000  CPANPLUS::Module::__ANON__
#      7.06   0.176  0.272      1   0.1762 0.2719  CPANPLUS::Internals::Search::_sear
#                                                  ch_module_tree
#      3.21   0.080  0.098     10   0.0080 0.0098  IPC::Cmd::BEGIN
#      1.60   0.040  0.205     13   0.0031 0.0158  CPANPLUS::Internals::BEGIN
#      1.20   0.030  0.030     29   0.0010 0.0010  vars::BEGIN
#      1.20   0.030  0.117     10   0.0030 0.0117  Log::Message::BEGIN
#      1.20   0.030  0.029      9   0.0033 0.0033  CPANPLUS::Internals::Search::BEGIN
#      0.80   0.020  0.020      5   0.0040 0.0040  DynaLoader::dl_load_file
#      0.80   0.020  0.127     10   0.0020 0.0127  CPANPLUS::Module::BEGIN
#      0.80   0.020  0.389      2   0.0099 0.1944  main::BEGIN
#      0.80   0.020  0.359     12   0.0017 0.0299  CPANPLUS::Backend::BEGIN
#      0.40   0.010  0.010     30   0.0003 0.0003  Config::FETCH
#      0.40   0.010  0.010     18   0.0006 0.0005  Locale::Maketext::Simple::load_loc
#

sub _search_module_tree {
    my $self = shift;
    my $conf = $self->configure_object;
    my %hash = @_;

    my($mods,$list,$verbose,$type);
    my $tmpl = {
        data    => { default    => [values %{$self->module_tree}],
                     strict_type=> 1, store     => \$mods },
        allow   => { required   => 1, default   => [ ], strict_type => 1,
                     store      => \$list },
        verbose => { default    => $conf->get_conf('verbose'),
                     store      => \$verbose },
        type    => { required   => 1, allow => [CPANPLUS::Module->accessors()],
                     store      => \$type },
    };

    my $args = check( $tmpl, \%hash ) or return;

    {   local $Params::Check::VERBOSE = 0;

        my @rv;
        for my $mod (@$mods) {
            #push @rv, $mod if check(
            #                        { $type => { allow => $list } },
            #                        { $type => $mod->$type() }
            #                    );
            push @rv, $mod if allow( $mod->$type() => $list );

        }
        return \@rv;
    }
}

#line 209

sub _search_author_tree {
    my $self = shift;
    my $conf = $self->configure_object;
    my %hash = @_;

    my($authors,$list,$verbose,$type);
    my $tmpl = {
        data    => { default    => [values %{$self->author_tree}],
                     strict_type=> 1, store     => \$authors },
        allow   => { required   => 1, default   => [ ], strict_type => 1,
                     store      => \$list },
        verbose => { default    => $conf->get_conf('verbose'),
                     store      => \$verbose },
        type    => { required   => 1, allow => [CPANPLUS::Module::Author->accessors()],
                     store      => \$type },
    };

    my $args = check( $tmpl, \%hash ) or return;

    {   local $Params::Check::VERBOSE = 0;

        my @rv;
        for my $auth (@$authors) {
            #push @rv, $auth if check(
            #                        { $type => { allow => $list } },
            #                        { $type => $auth->$type }
            #                    );
            push @rv, $auth if allow( $auth->$type() => $list );
        }
        return \@rv;
    }


}

#line 253

sub _all_installed {
    my $self = shift;
    my $conf = $self->configure_object;
    my %hash = @_;

    my %seen; my @rv;


    ### File::Find uses lstat, which quietly becomes stat on win32
    ### it then uses -l _ which is not allowed by the statbuffer because
    ### you did a stat, not an lstat (duh!). so don't tell win32 to
    ### follow symlinks, as that will break badly
    my %find_args = ();
    $find_args{'follow_fast'} = 1 unless $^O eq 'MSWin32';

    ### never use the @INC hooks to find installed versions of
    ### modules -- they're just there in case they're not on the
    ### perl install, but the user shouldn't trust them for *other*
    ### modules!
    local @INC = CPANPLUS::inc->original_inc;

    for my $dir (@INC ) {
        next if $dir eq '.';

        ### not a directory after all ###
        next unless -d $dir;


        File::Find::find(
            {   %find_args,
                wanted      => sub {

                    return unless /\.pm$/i;
                    my $mod = $File::Find::name;

                    $mod = substr($mod, length($dir) + 1, -3);
                    $mod = join '::', File::Spec->splitdir($mod);

                    return if $seen{$mod}++;
                    my $modobj = $self->module_tree($mod) or return;

                    push @rv, $modobj;
                },
            }, $dir
        );
    }

    return \@rv;
}

1;

# Local variables:
# c-indentation-style: bsd
# c-basic-offset: 4
# indent-tabs-mode: nil
# End:
# vim: expandtab shiftwidth=4:

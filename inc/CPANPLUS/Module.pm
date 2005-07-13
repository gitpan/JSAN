#line 1 "inc/CPANPLUS/Module.pm - /Library/Perl/5.8.6/CPANPLUS/Module.pm"
package CPANPLUS::Module;

use strict;
use vars qw[@ISA];

use CPANPLUS::inc;
use CPANPLUS::Dist;
use CPANPLUS::Error;
use CPANPLUS::Module::Signature;
use CPANPLUS::Module::Checksums;
use CPANPLUS::Internals::Constants;

use FileHandle;

use Locale::Maketext::Simple    Class => 'CPANPLUS', Style => 'gettext';
use IPC::Cmd                    qw[can_run run];
use File::Find                  qw[find];
use Params::Check               qw[check];
use Module::Load::Conditional   qw[can_load check_install];

$Params::Check::VERBOSE = 1;

@ISA = qw[ CPANPLUS::Module::Signature CPANPLUS::Module::Checksums];

#line 57

my $tmpl = {
    module      => { default => '', required => 1 },    # full module name
    version     => { default => '0.0' },                # version number
    path        => { default => '', required => 1 },    # extended path on the
                                                        # cpan mirror, like
                                                        # /author/id/K/KA/KANE
    comment     => { default => ''},                    # comment on module
    package     => { default => '', required => 1 },    # package name, like
                                                        # 'bar-baz-1.03.tgz'
    description => { default => '' },                   # description of the
                                                        # module
    dslip       => { default => '    ' },               # dslip information
    _id         => { required => 1 },                   # id of the Internals
                                                        # parent object
    status      => { no_override => 1 },                # stores status object
    author      => { default => '', required => 1,
                     allow => IS_AUTHOBJ },             # module author
};

### autogenerate accessors ###
for my $key ( keys %$tmpl ) {
    no strict 'refs';
    *{__PACKAGE__."::$key"} = sub {
        $_[0]->{$key} = $_[1] if @_ > 1;
        return $_[0]->{$key};
    }
}

#line 95

sub accessors { return keys %$tmpl };

#line 153

### Alias ->name to ->module, for human beings.
*name = *module;

sub parent {
    my $self = shift;
    my $obj  = CPANPLUS::Internals->_retrieve_id( $self->_id );

    return $obj;
}

#line 275


sub new {
    my($class, %hash) = @_;

    ### don't check the template for sanity
    ### -- we know it's good and saves a lot of performance
    local $Params::Check::SANITY_CHECK_TEMPLATE = 0;

    my $object  = check( $tmpl, \%hash ) or return;

    bless $object, $class;

    my $acc = Object::Accessor->new;
    $acc->mk_accessors( qw[ installer_type dist_cpan dist prereqs
                            signature extract fetch readme uninstall
                            created installed prepared checksums 
                            checksum_ok checksum_value ] );

    $object->status( $acc );

    return $object;
}


### flush the cache of this object ###
sub _flush {
    my $self = shift;
    $self->status->mk_flush;
    return 1;
}

#line 340

{
    my $regex = qr/^(.+)-(.+)\.((?:tar\.gz|zip|tgz))/i;

    ### fetches the test reports for a certain module ###
    sub package_name {
        return $1 if shift->package() =~ $regex;
    }

    sub package_version {
        return $2 if shift->package() =~ $regex;
    }

    sub package_extension {
        return $3 if shift->package() =~ $regex;
    }

    sub package_is_perl_core {
        my $self = shift;

        ### check if the package looks like a perl core package
        return 1 if $self->package_name eq PERL_CORE;

        my $core = $self->module_is_supplied_with_perl_core;
        ### ok, so it's found in the core, BUT it could be dual-lifed
        if ($core) {
            ### if the package is newer than installed, then it's dual-lifed
            return if $self->version > $self->installed_version;

            ### if the package is newer than corelist, then it's dual-lifed
            return if $self->version > $core;

            ### otherwise, it's older than corelist, thus unsuitable.
            return 1;
        }

        ### not in corelist, not a perl core package.
        return;
    }

    sub module_is_supplied_with_perl_core {
        my $self = shift;
        my $ver  = shift || $];

        ### check Module::CoreList to see if it's a core package
        require Module::CoreList;
        my $core = $Module::CoreList::version{ $ver }->{ $self->module };

        return $core;
    }

    sub is_bundle {
        return shift->module =~ /^bundle::/i ? 1 : 0;
    }
}

#line 405

sub clone {
    my $self = shift;

    ### clone the object ###
    my %data;
    for my $acc ( grep !/status/, __PACKAGE__->accessors() ) {
        $data{$acc} = $self->$acc();
    }

    my $obj = CPANPLUS::Module::Fake->new( %data );

    return $obj;
}

#line 429

sub fetch {
    my $self = shift;
    my $cb   = $self->parent;

    my $where = $cb->_fetch( @_, module => $self ) or return;

    ### do an md5 check ###
    if( $cb->configure_object->get_conf('md5') and
        $self->package ne CHECKSUMS
    ) {
        unless( $self->_validate_checksum ) {
            error( loc( "Checksum error for '%1' -- will not trust package",
                        $self->package) );
            return;
        }
    }

    return $where;
}

#line 459

sub extract {
    my $self = shift;
    my $cb   = $self->parent;

    unless( $self->status->fetch ) {
        error( loc( "You have not fetched '%1' yet -- cannot extract",
                    $self->module) );
        return;
    }

    return $cb->_extract( @_, module => $self );
}

#line 484

sub get_installer_type {
    my $self = shift;
    my $cb   = $self->parent;
    my $conf = $cb->configure_object;
    my %hash = @_;

    my $prefer_makefile;
    my $tmpl = {
        prefer_makefile => { default => $conf->get_conf('prefer_makefile'),
                             store => \$prefer_makefile, allow => BOOLEANS },
    };

    check( $tmpl, \%hash ) or return;

    my $extract = $self->status->extract();
    unless( $extract ) {
        error(loc("Cannot determine installer type of unextracted module '%1'",
                  $self->module));
        return;
    }


    ### check if it's a makemaker or a module::build type dist ###
    my $found_build     = -e BUILD_PL->( $extract );
    my $found_makefile  = -e MAKEFILE_PL->( $extract );

    my $type;
    $type = INSTALLER_BUILD if !$prefer_makefile &&  $found_build;
    $type = INSTALLER_BUILD if  $found_build     && !$found_makefile;
    $type = INSTALLER_MM    if  $prefer_makefile &&  $found_makefile;
    $type = INSTALLER_MM    if  $found_makefile  && !$found_build;

    ### ok, so it's a 'build' installer, but you don't /have/ module build
    if( $type eq INSTALLER_BUILD and 
        !check_install( module => 'Module::Build' ) 
    ) {
        error( loc( "This module requires '%1' to be installed, ".
                    "but you don't have it! Will fall back to ".
                    "'%2', but might not be able to install!",
                     'Module::Build', INSTALLER_MM ) );
        $type = INSTALLER_MM;

    ### ok, actually we found neither ###
    } elsif ( !$type ) {
        error( loc( "Unable to find '%1' or '%2' for '%3'; ".
                    "Will default to '%4' but might be unable ".
                    "to install!", BUILD_PL->(), MAKEFILE_PL->(),
                    $self->module, INSTALLER_MM ) );
        $type = INSTALLER_MM;
    }

    return $self->status->installer_type( $type ) if $type;
    return;
}

#line 555

sub dist {
    my $self = shift;
    my $cb   = $self->parent;
    my $conf = $cb->configure_object;
    my %hash = @_;

    my($type,$args,$target);
    my $tmpl = {
        format  => { default => $conf->get_conf('dist_type') ||
                                $self->status->installer_type,
                     store   => \$type },
        target  => { default => TARGET_CREATE, store => \$target },                     
        args    => { default => {}, store => \$args },
    };

    check( $tmpl, \%hash ) or return;

    my $dist = CPANPLUS::Dist->new( format => $type,
                                    module => $self
                            ) or return;

    DIST: {
        ### first prepare the dist
        $dist->prepare( %$args ) or return;
        $self->status->prepared(1);

        ### you just wanted us to prepare?
        last DIST if $target eq TARGET_PREPARE;

        $dist->create( %$args ) or return;
        $self->status->created(1);
    }

    return $dist;
}

#line 603

sub prepare { 
    my $self = shift;
    return $self->install( @_, target => TARGET_PREPARE );
}

#line 618

sub create { 
    my $self = shift;
    return $self->install( @_, target => TARGET_CREATE );
}

#line 634

sub test {
    my $self = shift;
    return $self->install( @_, target => TARGET_CREATE, skiptest => 0 );
}

#line 657

sub install {
    my $self = shift;
    my $cb   = $self->parent;
    my $conf = $cb->configure_object;
    my %hash = @_;

    my $args; my $target; my $format;
    {   ### so we can use the rest of the args to the create calls etc ###
        local $Params::Check::NO_DUPLICATES = 1;
        local $Params::Check::ALLOW_UNKNOWN = 1;

        ### targets 'dist' and 'test' are now completely ignored ###
        my $tmpl = {
                        ### match this allow list with Dist->_resolve_prereqs
            target     => { default => TARGET_INSTALL, store => \$target,
                            allow   => [TARGET_PREPARE, TARGET_CREATE,
                                        TARGET_INSTALL] },
            force      => { default => $conf->get_conf('force'), },
            verbose    => { default => $conf->get_conf('verbose'), },
            format     => { default => $conf->get_conf('dist_type'),
                                store => \$format },
        };

        $args = check( $tmpl, \%hash ) or return;
    }

    ### if this target isn't 'install', we will need to at least 'create' 
    ### every prereq, so it can build
    ### XXX prereq_target of 'prepare' will do weird things here, and is
    ### not supported.
    $args->{'prereq_target'} ||= TARGET_CREATE if $target ne TARGET_INSTALL;

    ### check if it's already upto date ###
    if( $target eq TARGET_INSTALL and !$args->{'force'} and
        !$self->package_is_perl_core() and         # separate rules apply
        ( $self->status->installed() or $self->is_uptodate ) and
        !INSTALL_VIA_PACKAGE_MANAGER->($format)
    ) {
        msg(loc("Module '%1' already up to date, won't install without force",
                $self->module), $args->{'verbose'} );
        return $self->status->installed(1);
    }

    # if it's a non-installable core package, abort the install.
    if( $self->package_is_perl_core() ) {
        # if the installed is newer, say so.
        if( $self->installed_version > $self->version ) {
            error(loc("The core Perl %1 module '%2' (%3) is more ".
                      "recent than the latest release on CPAN (%4). ".
                      "Aborting install.",
                      $], $self->module, $self->installed_version,
                      $self->version ) );
        # if the installed matches, say so.
        } elsif( $self->installed_version == $self->version ) {
            error(loc("The core Perl %1 module '%2' (%3) can only ".
                      "be installed by Perl itself. ".
                      "Aborting install.",
                      $], $self->module, $self->installed_version ) );
        # otherwise, the installed is older; say so.
        } else {
            error(loc("The core Perl %1 module '%2' can only be ".
                      "upgraded from %3 to %4 by Perl itself (%5). ".
                      "Aborting install.",
                      $], $self->module, $self->installed_version,
                      $self->version, $self->package ) );
        }
        return;
    }

    ### fetch it if need be ###
    unless( $self->status->fetch ) {
        my $params;
        for (qw[prefer_bin fetchdir]) {
            $params->{$_} = $args->{$_} if exists $args->{$_};
        }
        for (qw[force verbose]) {
            $params->{$_} = $args->{$_} if defined $args->{$_};
        }
        $self->fetch( %$params ) or return;
    }

    ### extract it if need be ###
    unless( $self->status->extract ) {
        my $params;
        for (qw[prefer_bin extractdir]) {
            $params->{$_} = $args->{$_} if exists $args->{$_};
        }
        for (qw[force verbose]) {
            $params->{$_} = $args->{$_} if defined $args->{$_};
        }
        $self->extract( %$params ) or return;
    }

    $format ||= $self->status->installer_type;

    unless( $format ) {
        error( loc( "Don't know what installer to use; " .
                    "Couldn't find either '%1' or '%2' in the extraction " .
                    "directory '%3' -- will be unable to install",
                    BUILD_PL->(), MAKEFILE_PL->(), $self->status->extract ) );

        $self->status->installed(0);
        return;
    }


    ### do SIGNATURE checks? ###
    if( $conf->get_conf('signature') ) {
        unless( $self->check_signature( verbose => $args->{verbose} ) ) {
            error( loc( "Signature check failed for module '%1' ".
                        "-- Not trusting this module, aborting install",
                        $self->module ) );
            $self->status->signature(0);
            return;

        } else {
            ### signature OK ###
            $self->status->signature(1);
        }
    }

    ### a target of 'create' basically means not to run make test ###
    ### eh, no it /doesn't/.. skiptest => 1 means skiptest => 1.
    #$args->{'skiptest'} = 1 if $target eq 'create';

    ### bundle rules apply ###
    if( $self->is_bundle ) {
        ### check what we need to install ###
        my @prereqs = $self->bundle_modules();
        unless( @prereqs ) {
            error( loc( "Bundle '%1' does not specify any modules to install",
                        $self->module ) );

            ### XXX mark an error here? ###
        }
    }

    my $dist = $self->dist( format  => $format, 
                            target  => $target, 
                            args    => $args );
    unless( $dist ) {
        error( loc( "Unable to create a new distribution object for '%1' " .
                    "-- cannot continue", $self->module ) );
        return;
    }

    return 1 if $target ne TARGET_INSTALL;

    my $ok = $dist->install( %$args ) ? 1 : 0;

    $self->status->installed($ok);

    return 1 if $ok;
    return;
}

#line 824

sub bundle_modules {
    my $self = shift;
    my $cb   = $self->parent;

    unless( $self->is_bundle ) {
        error( loc("'%1' is not a bundle", $self->module ) );
        return;
    }

    my $dir;
    unless( $dir = $self->status->extract ) {
        error( loc("Don't know where '%1' was extracted to", $self->module ) );
        return;
    }

    my @files;
    find( {
        wanted      => sub { push @files, File::Spec->rel2abs($_) if /\.pm/i; },
        no_chdir    => 1,
    }, $dir );

    my $prereqs = {}; my @list; my $seen = {};
    for my $file ( @files ) {
        my $fh = FileHandle->new($file)
                    or( error(loc("Could not open '%1' for reading: %2",
                        $file,$!)), next );

        my $flag;
        while(<$fh>) {
            ### quick hack to read past the header of the file ###
            last if $flag && m|^=head|i;

            ### from perldoc cpan:
            ### =head1 CONTENTS
            ### In this pod section each line obeys the format
            ### Module_Name [Version_String] [- optional text]
            $flag = 1 if m|^=head1 CONTENTS|i;

            if ($flag && /^(?!=)(\S+)\s*(\S+)?/) {
                my $module  = $1;
                my $version = $2 || '0';

                my $obj = $cb->module_tree($module);

                unless( $obj ) {
                    error(loc("Cannot find bundled module '%1'", $module),
                          loc("-- it does not seem to exist") );
                    next;
                }

                ### make sure we list no duplicates ###
                unless( $seen->{ $obj->module }++ ) {
                    push @list, $obj;
                    $prereqs->{ $module } =
                        $cb->_version_to_number( version => $version );
                }
            }
        }
    }

    ### store the prereqs we just found ###
    $self->status->prereqs( $prereqs );

    return @list;
}

#line 900

sub readme {
    my $self = shift;

    ### did we already dl the readme once? ###
    return $self->status->readme() if $self->status->readme();

    ### this should be core ###
    return unless can_load( modules     => { FileHandle => '0.0' },
                            verbose     => 1,
                        );

    ### get a clone of the current object, with a fresh status ###
    my $obj  = $self->clone or return;

    ### munge the package name
    my $pkg = README->( $obj );
    $obj->package($pkg);

    my $file = $obj->fetch or return;

    ### read the file into a scalar, to store in the original object ###
    my $fh = new FileHandle;
    unless( $fh->open($file) ) {
        error( loc( "Could not open file '%1': %2", $file, $! ) );
        return;
    }

    my $in;
    { local $/; $in = <$fh> };
    $fh->close;

    return $self->status->readme( $in );
}

#line 951

### uptodate/installed functions
{   my $map = {             # hashkey,      alternate rv
        installed_version   => ['version',  0 ],
        installed_file      => ['file',     ''],
        is_uptodate         => ['uptodate', 0 ],
    };

    while( my($method, $aref) = each %$map ) {
        my($key,$alt_rv) = @$aref;

        no strict 'refs';
        *$method = sub {
            ### never use the @INC hooks to find installed versions of
            ### modules -- they're just there in case they're not on the
            ### perl install, but the user shouldn't trust them for *other*
            ### modules!
            local @INC = CPANPLUS::inc->original_inc;

            my $self = shift;
            my $href = check_install(
                            module  => $self->module,
                            version => $self->version,
                            @_,
                        );

            return $href->{$key} || $alt_rv;
        }
    }
}



#line 1003

sub details {
    my $self = shift;
    my $conf = $self->parent->configure_object();
    my $cb   = $self->parent;
    my %hash = @_;

    my $res = {
        Author              => loc("%1 (%2)",   $self->author->author(),
                                                $self->author->email() ),
        Package             => $self->package,
        Description         => $self->description     || loc('None given'),
        'Version on CPAN'   => $self->version,
    };

    ### check if we have the module installed
    ### if so, add version have and version on cpan
    $res->{'Version Installed'} = $self->installed_version
                                    if $self->installed_version;

    my $i = 0;
    for my $item( split '', $self->dslip ) {
        $res->{ $cb->_dslip_defs->[$i]->[0] } =
                $cb->_dslip_defs->[$i]->[1]->{$item} || loc('Unknown');
        $i++;
    }

    return $res;
}

#line 1045

sub contains {
    my $self = shift;
    my $cb   = $self->parent;
    my $pkg  = $self->package;
    
    my @mods = $cb->search( type => 'package', allow => [qr/^$pkg$/] );
    
    return @mods;
}

#line 1068

sub fetch_report {
    my $self    = shift;
    my $cb      = $self->parent;

    return $cb->_query_report( @_, module => $self );
}

#line 1093

sub uninstall {
    my $self = shift;
    my $conf = $self->parent->configure_object();
    my %hash = @_;

    my ($type,$verbose);
    my $tmpl = {
        type    => { default => 'all', allow => [qw|man prog all|],
                        store => \$type },
        verbose => { default => $conf->get_conf('verbose'),
                        store => \$verbose },
        force   => { default => $conf->get_conf('force') },
    };

    ### XXX add a warning here if your default install dist isn't
    ### makefile or build -- that means you are using a package manager
    ### and this will not do what you think!

    my $args = check( $tmpl, \%hash ) or return;

    if( $conf->get_conf('dist_type') and (
        ($conf->get_conf('dist_type') ne INSTALLER_BUILD) or
        ($conf->get_conf('dist_type') ne INSTALLER_MM))
    ) {
        msg(loc("You have a default installer type set (%1) ".
                "-- you should probably use that package manager to " .
                "uninstall modules", $conf->get_conf('dist_type')), $verbose);
    }

    ### check if we even have the module installed -- no point in continuing
    ### otherwise
    unless( $self->installed_version ) {
        error( loc( "Module '%1' is not installed, so cannot uninstall",
                    $self->module ) );
        return;
    }

                                                ### nothing to uninstall ###
    my $files   = $self->files( type => $type )             or return;
    my $dirs    = $self->directory_tree( type => $type )    or return;
    my $sudo    = $conf->get_program('sudo');

    ### just in case there's no file; M::B doensn't provide .packlists yet ###
    my $pack    = $self->packlist;
    $pack       = $pack->[0]->packlist_file() if $pack;

    ### first remove the files, then the dirs if they are empty ###
    my $flag = 0;
    for my $file( @$files, $pack ) {
        next unless defined $file && -f $file;

        msg(loc("Unlinking '%1'", $file), $verbose);

        my $buffer;
        unless ( run(   command => [$sudo, $^X, "-eunlink+q[$file]"],
                        verbose => $verbose,
                        buffer  => \$buffer )
        ) {
            error(loc("Failed to unlink '%1': '%2'",$file, $buffer));
            $flag++;
        }
    }

    for my $dir ( sort @$dirs ) {
        local *DIR;
        open DIR, $dir or next;
        my @count = readdir(DIR);
        close DIR;

        next unless @count == 2;    # . and ..

        msg(loc("Removing '%1'", $dir), $verbose);

        ### this fails on my win2k machines.. it indeed leaves the
        ### dir, but it's not a critical error, since the files have
        ### been removed. --kane
        #unless( rmdir $dir ) {
        #    error( loc( "Could not remove '%1': %2", $dir, $! ) )
        #        unless $^O eq 'MSWin32';
        #}
        my $buffer;
        unless ( run(   command => [$sudo, $^X, "-ermdir+q[$dir]"],
                        verbose => $verbose,
                        buffer  => \$buffer )
        ) {
            error(loc("Failed to rmdir '%1': %2",$dir,$buffer));
            $flag++;
        }
    }

    $self->status->uninstall(!$flag);
    $self->status->installed( $flag ? 1 : undef);

    return !$flag;
}

#line 1198

sub distributions {
    my $self = shift;
    my %hash = @_;

    my @list = $self->author->distributions( %hash, module => $self ) or return;

    ### it's another release then by the same author ###
    return grep { $_->package_name eq $self->package_name } @list;
}

#line 1216

sub files {
    return shift->_extutils_installed( @_, method => 'files' );
}

#line 1228

sub directory_tree {
    return shift->_extutils_installed( @_, method => 'directory_tree' );
}

#line 1240

sub packlist {
    return shift->_extutils_installed( @_, method => 'packlist' );
}

#line 1253

sub validate {
    return shift->_extutils_installed( method => 'validate' );
}

### generic method to call an ExtUtils::Installed method ###
sub _extutils_installed {
    my $self = shift;
    my $conf = $self->parent->configure_object();
    my %hash = @_;

    my ($verbose,$type,$method);
    my $tmpl = {
        verbose => {    default     => $conf->get_conf('verbose'),
                        store       => \$verbose, },
        type    => {    default     => 'all',
                        allow       => [qw|prog man all|],
                        store       => \$type, },
        method  => {    required    => 1,
                        store       => \$method,
                        allow       => [qw|files directory_tree packlist
                                        validate|],
                    },
    };

    my $args = check( $tmpl, \%hash ) or return;

    ### old versions of cygwin + perl < 5.8 are buggy here. bail out if we
    ### find we're being used by them
    {   my $err = ON_OLD_CYGWIN;
        if($err) { error($err); return };
    }

    return unless can_load(
                        modules     => { 'ExtUtils::Installed' => '0.0' },
                        verbose     => $verbose,
                    );

    my $inst;
    unless( $inst = ExtUtils::Installed->new() ) {
        error( loc("Could not create an '%1' object", 'ExtUtils::Installed' ) );

        ### in case it's being used directly... ###
        return;
    }


    {   ### EU::Installed can die =/
        my @files;
        eval { @files = $inst->$method( $self->module, $type ) };

        if( $@ ) {
            chomp $@;
            error( loc("Could not get '%1' for '%2': %3",
                        $method, $self->module, $@ ) );
            return;
        }

        return wantarray ? @files : \@files;
    }
}

#line 1329

### make sure we're always running 'perl Build.PL' and friends
### against the highest version of module::build available
sub best_path_to_module_build {
    my $self = shift;

    ### Since M::B will actually shell out and run the Build.PL, we must
    ### make sure it refinds the proper version of M::B in the path.
    ### that may be either in our cp::inc or in site_perl, or even a
    ### new M::B being installed.
    ### don't add anything else here, as that might screw up prereq checks

    ### XXX this might be needed for Dist::MM too, if a makefile.pl is
    ###	masquerading as a Build.PL

    ### did we find the most recent module::build in our installer path?

    ### XXX can't do changes to @INC, they're being ignored by
    ### new_from_context when writing a Build script. see ticket:
    ### #8826 Module::Build ignores changes to @INC when writing Build
    ### from new_from_context
    ### XXX applied schwern's patches (as seen on CPANPLUS::Devel 10/12/04)
    ### and upped the version to 0.26061 of the bundled version, and things
    ### work again

    require Module::Build;
    if( CPANPLUS::inc->path_to('Module::Build') and (
        CPANPLUS::inc->path_to('Module::Build') eq
        CPANPLUS::inc->installer_path )
    ) {

        ### if the module being installed is *not* Module::Build
        ### itself -- as that would undoubtedly be newer -- add
        ### the path to the installers to @INC
        ### if it IS module::build itself, add 'lib' to its path,
        ### as the Build.PL would do as well, but the API doesn't.
        ### this makes self updates possible
        return $self->module eq 'Module::Build'
                        ? 'lib'
                        : CPANPLUS::inc->installer_path;
    }

    ### otherwise, the path was found through a 'normal' way of
    ### scanning @INC.
    return;
}


# Local variables:
# c-indentation-style: bsd
# c-basic-offset: 4
# indent-tabs-mode: nil
# End:
# vim: expandtab shiftwidth=4:

1;

__END__

todo:
reports();

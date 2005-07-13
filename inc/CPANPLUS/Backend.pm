#line 1 "inc/CPANPLUS/Backend.pm - /Library/Perl/5.8.6/CPANPLUS/Backend.pm"
package CPANPLUS::Backend;

use strict;

use CPANPLUS::inc;
use CPANPLUS::Error;
use CPANPLUS::Configure;
use CPANPLUS::Internals;
use CPANPLUS::Internals::Constants;
use CPANPLUS::Module;
use CPANPLUS::Module::Author;
use CPANPLUS::Backend::RV;

use FileHandle;
use File::Spec                  ();
use File::Spec::Unix            ();
use Params::Check               qw[check];
use Locale::Maketext::Simple    Class => 'CPANPLUS', Style => 'gettext';

$Params::Check::VERBOSE = 1;

use vars qw[@ISA $VERSION];

@ISA     = qw[CPANPLUS::Internals];
$VERSION = $CPANPLUS::Internals::VERSION;

### mark that we're running under CPANPLUS to spawned processes
$ENV{'PERL5_CPANPLUS_IS_RUNNING'} = $$;

#line 95

sub new {
    my $class   = shift;
    my $conf;

    if( $_[0] && IS_CONFOBJ->( conf => $_[0] ) ) {
        $conf = shift;
    } else {
        $conf = CPANPLUS::Configure->new( @_ ) or return;
    }

    my $self = $class->SUPER::_init( _conf => $conf );

    return $self;
}

#line 125

sub module_tree {
    my $self    = shift;
    my $modtree = $self->_module_tree;

    if( @_ ) {
        my @rv;
        for my $name (@_) {
            push @rv, $modtree->{$name} || '';
        }
        return @rv == 1 ? $rv[0] : @rv;
    } else {
        return $modtree;
    }
}

#line 155

sub author_tree {
    my $self        = shift;
    my $authtree    = $self->_author_tree;

    if( @_ ) {
        my @rv;
        for my $name (@_) {
            push @rv, $authtree->{$name} || '';
        }
        return @rv == 1 ? $rv[0] : @rv;
    } else {
        return $authtree;
    }
}

#line 181

sub configure_object { return shift->_conf() };

#line 214

sub search {
    my $self = shift;
    my $conf = $self->configure_object;
    my %hash = @_;

    local $Params::Check::ALLOW_UNKNOWN = 1;

    my ($data,$type);
    my $tmpl = {
        type    => { required => 1, allow => [CPANPLUS::Module->accessors(),
                        CPANPLUS::Module::Author->accessors()], store => \$type },
        allow   => { required => 1, default => [ ], strict_type => 1 },
    };

    my $args = check( $tmpl, \%hash ) or return;

    ### figure out whether it was an author or a module search
    ### when ambiguous, it'll be an author search.
    my $aref;
    if( grep { $type eq $_ } CPANPLUS::Module::Author->accessors() ) {
        $aref = $self->_search_author_tree( %$args );
    } else {
        $aref = $self->_search_module_tree( %$args );
    }

    return @$aref if $aref;
    return;
}

#line 326

### XXX add direcotry_tree, packlist etc? or maybe remove files? ###
for my $func (qw[fetch extract install readme files distributions]) {
    no strict 'refs';

    *$func = sub {
        my $self = shift;
        my $conf = $self->configure_object;
        my %hash = @_;

        local $Params::Check::NO_DUPLICATES = 1;
        local $Params::Check::ALLOW_UNKNOWN = 1;

        my ($mods);
        my $tmpl = {
            modules     => { default  => [],    strict_type => 1,
                             required => 1,     store => \$mods },
        };

        my $args = check( $tmpl, \%hash ) or return;

        ### make them all into module objects ###
        my %mods = map {$_ => $self->parse_module(module => $_) || ''} @$mods;

        my $flag; my $href;
        while( my($name,$obj) = each %mods ) {
            $href->{$name} = IS_MODOBJ->( mod => $obj )
                                ? $obj->$func( %$args )
                                : undef;

            $flag++ unless $href->{$name};
        }

        return CPANPLUS::Backend::RV->new(
                    function    => $func,
                    ok          => !$flag,
                    rv          => $href,
                    args        => \%hash,
                );
    }
}

#line 411

sub parse_module {
    my $self = shift;
    my $conf = $self->configure_object;
    my %hash = @_;

    my $mod;
    my $tmpl = {
        module  => { required => 1, store => \$mod },
    };

    my $args = check( $tmpl, \%hash ) or return;

    return $mod if IS_MODOBJ->( module => $mod );

    ### ok, so it's not a module object, but a ref nonetheless?
    ### what are you smoking?
    return if ref $mod;

    ### check only for allowed characters in a module name
    unless( $mod =~ /[^\w:]/ ) {
        my $maybe = $self->module_tree($mod);
        return $maybe if IS_MODOBJ->( module => $maybe );
    }


    ### ok, so it looks like a distribution then?
    my @parts   = split '/', $mod;
    my $dist    = pop @parts;

    unless( $dist ) {
        error( loc("%1 is not a proper distribution name!", $mod) );
        return;
    }
    
    ### there's wonky uris out there, like this:
    ### E/EY/EYCK/Net/Lite/Net-Lite-FTP-0.091
    ### compensate for that
    my $author;
    ### you probably have an A/AB/ABC/....../Dist.tgz type uri
    if( (defined $parts[0] and length $parts[0] == 1) and 
        (defined $parts[1] and length $parts[1] == 2) and
        $parts[2] =~ /^$parts[0]/i and $parts[2] =~ /^$parts[1]/i
    ) {   
        splice @parts, 0, 2;    # remove the first 2 entries from the list
        $author = shift @parts; # this is the actual author name then    

    ### we''ll assume a ABC/..../Dist.tgz
    } else {
        $author = shift @parts || '';
    }

    ### translate a distribution into a module name ###
    my $guess   = $dist;
    $guess      =~ s/-(\d[.\w]*?)(?:\.[A-Za-z.]*)?$//; 
                                    # versions must begin with a digit,
                                    # but may contain letters (wtf?? silly
                                    # cpan authors).
                                    # strip version plus .tgz & co
    my $version = $1 || '';
    
    $guess      =~ s/-$//;                      # strip trailing -
    my $pkg     = $guess;
    $guess      =~ s/-/::/g;

    my $maybe = $self->module_tree( $guess );
    if( IS_MODOBJ->( module => $maybe ) ) {

        ### maybe you asked for a package instead
        if ( $maybe->package eq $mod ) {
            return $maybe;

        ### perhaps an outdated version instead?
        } elsif (   ($maybe->package_name eq $pkg)
                    and $version
        ) {
            my $auth_obj; my $path;

            ### did you give us an author part? ###
            if( $author ) {
                $auth_obj   = CPANPLUS::Module::Author::Fake->new(
                                    _id     => $maybe->_id,
                                    cpanid  => uc $author,
                                    author  => uc $author,
                                );
                $path       = File::Spec::Unix->catdir(
                                    $conf->_get_mirror('base'),
                                    substr(uc $author, 0, 1),
                                    substr(uc $author, 0, 2),
                                    uc $author,
                                    @parts,     #possible sub dirs
                                );
            } else {
                $auth_obj   = $maybe->author;
                $path       = $maybe->path;
            }

            my $modobj = CPANPLUS::Module::Fake->new(
                module  => $maybe->module,
                version => $version,
                package => $pkg . '-' . $version . '.' .
                                $maybe->package_extension,
                path    => $path,
                author  => $auth_obj,
                _id     => $maybe->_id
            );
            return $modobj;

        ### you didn't care about a version, so just return the object then
        } elsif ( !$version ) {
            return $maybe;
        }

    ### ok, so we can't find it, and it's not an outdated dist either
    ### perhaps we can fake one based on the author name and so on
    } elsif ( $author and $version ) {

        ### be extra friendly and pad the .tar.gz suffix where needed
        ### it's just a guess of course, but most dists are .tar.gz
        $dist .= '.tar.gz' unless $dist =~ /\.[A-Za-z]+$/;

        my $modobj = CPANPLUS::Module::Fake->new(
            module  => $guess,
            version => $version,
            package => $dist,
            author  => CPANPLUS::Module::Author::Fake->new(
                            author  => uc $author,
                            cpanid  => uc $author,
                            _id     => $self->_id,
                        ),
            path    => File::Spec::Unix->catdir(
                            $conf->_get_mirror('base'),
                            substr(uc $author, 0, 1),
                            substr(uc $author, 0, 2),
                            uc $author,
                            @parts,         #possible subdirs
                        ),
            _id     => $self->_id,
        );

        return $modobj;

    ### face it, we have /no/ idea what he or she wants...
    ### let's start putting the blame somewhere
    } else {

        unless( $author ) {
            error( loc( "'%1' does not contain an author part", $mod ) );
        }

        error( loc( "Cannot find '%1' in the module tree", $mod ) );
    }

    return;
}

#line 585

sub reload_indices {
    my $self    = shift;
    my %hash    = @_;
    my $conf    = $self->configure_object;

    my $tmpl = {
        update_source   => { default    => 0, allow => [qr/^\d$/] },
        verbose         => { default    => $conf->get_conf('verbose') },
    };

    my $args = check( $tmpl, \%hash ) or return;

    ### make a call to the internal _module_tree, so it triggers cache
    ### file age
    my $uptodate = $self->_check_trees( %$args );


    return 1 if $self->_build_trees(
                                uptodate    => $uptodate,
                                use_stored  => 0,
                                verbose     => $conf->get_conf('verbose'),
                            );

    error( loc( "Error rebuilding source trees!" ) );

    return;
}

#line 658

sub flush {
    my $self = shift;
    my $type = shift or return;

    my $cache = {
        methods => [ qw( methods load ) ],
        hosts   => [ qw( hosts ) ],
        modules => [ qw( modules lib) ],
        lib     => [ qw( lib ) ],
        load    => [ qw( load ) ],
        all     => [ qw( hosts lib modules methods load ) ],
    };

    my $aref = $cache->{$type}
                    or (
                        error( loc("No such cache '%1'", $type) ),
                        return
                    );

    return $self->_flush( list => $aref );
}

#line 692

sub installed {
    my $self = shift;
    my $aref = $self->_all_installed;

    return @$aref if $aref;
    return;
}

#line 741

sub local_mirror {
    my $self = shift;
    my $conf = $self->configure_object;
    my %hash = @_;

    my($path, $index, $force, $verbose);
    my $tmpl = {
        path        => { default => $conf->get_conf('base'),
                            store => \$path },
        index_files => { default => 1, store => \$index },
        force       => { default => $conf->get_conf('force'),
                            store => \$force },
        verbose     => { default => $conf->get_conf('verbose'),
                            store => \$verbose },
    };

    check( $tmpl, \%hash ) or return;

    unless( -d $path ) {
        $self->_mkdir( dir => $path )
                or( error( loc( "Could not create '%1', giving up", $path ) ),
                    return
                );
    } elsif ( ! -w _ ) {
        error( loc( "Could not write to '%1', giving up", $path ) );
        return;
    }

    my $flag;
    AUTHOR: {
    for my $auth (  sort { $a->cpanid cmp $b->cpanid }
                    values %{$self->author_tree}
    ) {

        MODULE: {
        my $i;
        for my $mod ( $auth->modules ) {
            my $fetchdir = File::Spec->catdir( $path, $mod->path );

            my %opts = (
                verbose     => $verbose,
                force       => $force,
                fetchdir    => $fetchdir,
            );

            ### only do this the for the first module ###
            unless( $i++ ) {
                $mod->_get_checksums_file(
                            %opts
                        ) or (
                            error( loc( "Could not fetch %1 file, " .
                                        "skipping author '%2'",
                                        CHECKSUMS, $auth->cpanid ) ),
                            $flag++, next AUTHOR
                        );
            }

            $mod->fetch( %opts )
                    or( error( loc( "Could not fetch '%1'", $mod->module ) ),
                        $flag++, next MODULE
                    );
        } }
    } }

    if( $index ) {
        for my $name (qw[auth dslip mod]) {
            $self->_update_source(
                        name    => $name,
                        verbose => $verbose,
                        path    => $path,
                    ) or ( $flag++, next );
        }
    }

    return !$flag;
}

#line 835

sub autobundle {
    my $self = shift;
    my $conf = $self->configure_object;
    my %hash = @_;

    my($path,$force,$verbose);
    my $tmpl = {
        force   => { default => $conf->get_conf('force'), store => \$force },
        verbose => { default => $conf->get_conf('verbose'), store => \$verbose },
        path    => { default => File::Spec->catdir(
                                        $conf->get_conf('base'),
                                        $self->_perl_version( perl => $^X ),
                                        $conf->_get_build('distdir'),
                                        $conf->_get_build('autobundle') ),
                    store => \$path },
    };

    check($tmpl, \%hash) or return;

    unless( -d $path ) {
        $self->_mkdir( dir => $path )
                or( error(loc("Could not create directory '%1'", $path ) ),
                    return
                );
    }

    my $name; my $file;
    {   ### default filename for the bundle ###
        my($year,$month,$day) = (localtime)[5,4,3];
        $year += 1900; $month++;

        my $ext = 0;

        my $prefix  = $conf->_get_build('autobundle_prefix');
        my $format  = "${prefix}_%04d_%02d_%02d_%02d";

        BLOCK: {
            $name = sprintf( $format, $year, $month, $day, $ext);

            $file = File::Spec->catfile( $path, $name . '.pm' );

            -f $file ? ++$ext && redo BLOCK : last BLOCK;
        }
    }
    my $fh;
    unless( $fh = FileHandle->new( ">$file" ) ) {
        error( loc( "Could not open '%1' for writing: %2", $file, $! ) );
        return;
    }

    my $string = join "\n\n",
                    map {
                        join ' ',
                            $_->module,
                            ($_->installed_version(verbose => 0) || 'undef')
                    } sort {
                        $a->module cmp $b->module
                    }  $self->installed;

    my $now     = scalar localtime;
    my $head    = '=head1';
    my $pkg     = __PACKAGE__;
    my $version = $self->VERSION;
    my $perl_v  = join '', `$^X -V`;

    print $fh <<EOF;
package $name

\$VERSION = '0.01';

1;

__END__

$head NAME

$name - Snapshot of your installation at $now

$head SYNOPSIS

perl -MCPANPLUS -e "install $name"

$head CONTENTS

$string

$head CONFIGURATION

$perl_v

$head AUTHOR

This bundle has been generated autotomatically by
    $pkg $version

EOF

    close $fh;

    return $file;
}

1;

#line 962

# Local variables:
# c-indentation-style: bsd
# c-basic-offset: 4
# indent-tabs-mode: nil
# End:
# vim: expandtab shiftwidth=4:

__END__

todo:
sub dist {          # not sure about this one -- probably already done
                      enough in Module.pm
sub reports {       # in Module.pm, wrapper here



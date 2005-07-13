#line 1 "inc/CPANPLUS/Module/Author.pm - /Library/Perl/5.8.6/CPANPLUS/Module/Author.pm"
package CPANPLUS::Module::Author;

use strict;
use CPANPLUS::inc;
use CPANPLUS::Error;
use Params::Check               qw[check];
use Locale::Maketext::Simple    Class => 'CPANPLUS', Style => 'gettext';

local $Params::Check::VERBOSE = 1;

#line 67

my $tmpl = {
    author      => { required => 1 },   # full name of the author
    cpanid      => { required => 1 },   # cpan id
    email       => { default => '' },   # email address of the author
    _id         => { required => 1 },   # id of the Internals object that spawned us
};

### autogenerate accessors ###
for my $key ( keys %$tmpl ) {
    no strict 'refs';
    *{__PACKAGE__."::$key"} = sub {
        my $self = shift;
        $self->{$key} = $_[0] if @_;
        return $self->{$key};
    }
}

sub parent {
    my $self = shift;
    my $obj  = CPANPLUS::Internals->_retrieve_id( $self->_id );

    return $obj;
}

#line 104

sub new {
    my $class   = shift;
    my %hash    = @_;

    ### don't check the template for sanity
    ### -- we know it's good and saves a lot of performance
    local $Params::Check::SANITY_CHECK_TEMPLATE = 0;

    my $object = check( $tmpl, \%hash ) or return;

    return bless $object, $class;
}

#line 125

sub modules {
    my $self    = shift;
    my $cb      = $self->parent;

    my $aref = $cb->_search_module_tree(
                    type    => 'author',
                    allow   => [$self],
                );
    return @$aref if $aref;
    return;
}

#line 146

sub distributions {
    my $self = shift;
    my %hash = @_;

    local $Params::Check::ALLOW_UNKNOWN = 1;
    local $Params::Check::NO_DUPLICATES = 1;

    my $mod;
    my $tmpl = {
        module  => { default => '', store => \$mod },
    };

    my $args = check( $tmpl, \%hash ) or return;

    ### if we didn't get a module object passed, we'll find one ourselves ###
    unless( $mod ) {
        my @list = $self->modules;
        if( @list ) {
            $mod = $list[0];
        } else {
            error( loc( "This author has released no modules" ) );
            return;
        }
    }

    my $file = $mod->checksums( %hash );
    my $href = $mod->_parse_checksums_file( file => $file ) or return;

    my @rv;
    for my $dist ( keys %$href ) {
        my $clone = $mod->clone;

        $clone->package( $dist );
        $clone->module( $clone->package_name );
        $clone->version( $clone->package_version );
        push @rv, $clone;
    }

    return @rv;
}


#line 198

sub accessors { return keys %$tmpl };

1;

# Local variables:
# c-indentation-style: bsd
# c-basic-offset: 4
# indent-tabs-mode: nil
# End:
# vim: expandtab shiftwidth=4:

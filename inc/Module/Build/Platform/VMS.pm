#line 1 "inc/Module/Build/Platform/VMS.pm - /Library/Perl/5.8.6/Module/Build/Platform/VMS.pm"
package Module::Build::Platform::VMS;

use strict;
use Module::Build::Base;

use vars qw(@ISA);
@ISA = qw(Module::Build::Base);

sub need_prelink_c { 1 }


#line 31

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->{properties}{build_script} = 'Build.com';

    return $self;
}


#line 48

sub cull_args {
    my $self = shift;
    my($action, $args) = $self->SUPER::cull_args(@_);
    my @possible_actions = grep { lc $_ eq lc $action } $self->known_actions;

    die "Ambiguous action '$action'.  Could be one of @possible_actions"
        if @possible_actions > 1;

    return ($possible_actions[0], $args);
}


#line 68

sub manpage_separator {
    return '__';
}


#line 83

1;
__END__

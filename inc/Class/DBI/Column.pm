#line 1 "inc/Class/DBI/Column.pm - /Library/Perl/5.8.6/Class/DBI/Column.pm"
package Class::DBI::Column;

#line 27

use strict;
use base 'Class::Accessor';

__PACKAGE__->mk_accessors(
	qw/name accessor mutator placeholder
		is_constrained/
);

use overload
	'""'     => sub { shift->name_lc },
	fallback => 1;

#line 47

sub new {
	my ($class, $name) = @_;
	return $class->SUPER::new(
		{
			name        => $name,
			_groups     => {},
			placeholder => '?'
		}
	);
}

sub name_lc { lc shift->name }

sub add_group {
	my ($self, $group) = @_;
	$self->{_groups}->{$group} = 1;
}

sub groups {
	my $self   = shift;
	my %groups = %{ $self->{_groups} };
	delete $groups{All} if keys %groups > 1;
	return keys %groups;
}

sub in_database {
	return !scalar grep $_ eq "TEMP", shift->groups;
}

1;

#line 1 "inc/Class/DBI/ColumnGrouper.pm - /Library/Perl/5.8.6/Class/DBI/ColumnGrouper.pm"
package Class::DBI::ColumnGrouper;

#line 27

use strict;

use Carp;
use Storable 'dclone';
use Class::DBI::Column;

sub _unique {
	my %seen;
	map { $seen{$_}++ ? () : $_ } @_;
}

sub _uniq {
	my %tmp;
	return grep !$tmp{$_}++, @_;
}

#line 57

sub new {
	my $class = shift;
	bless {
		_groups => {},
		_cols   => {},
	}, $class;
}

sub clone {
	my ($class, $prev) = @_;
	return dclone $prev;
}

#line 79

sub add_column {
	my ($self, $name) = @_;
	return $name if ref $name;
	$self->{_allcol}->{ lc $name } ||= Class::DBI::Column->new($name);
}

sub find_column {
	my ($self, $name) = @_;
	return $name if ref $name;
	return unless $self->{_allcol}->{ lc $name };
}

#line 99

sub add_group {
	my ($self, $group, @names) = @_;
	$self->add_group(Primary => $names[0])
		if ($group eq "All" or $group eq "Essential")
		and not $self->group_cols('Primary');
	$self->add_group(Essential => @names)
		if $group eq "All"
		and !$self->essential;
	@names = _unique($self->primary, @names) if $group eq "Essential";

	my @cols = map $self->add_column($_), @names;
	$_->add_group($group) foreach @cols;
	$self->{_groups}->{$group} = \@cols;
	return $self;
}

#line 125

sub group_cols {
	my ($self, $group) = @_;
	return $self->all_columns if $group eq "All";
	@{ $self->{_groups}->{$group} || [] };
}

sub groups_for {
	my ($self, @cols) = @_;
	return _uniq(map $_->groups, @cols);
}

#line 144

sub columns_in {
	my ($self, @groups) = @_;
	return _uniq(map $self->group_cols($_), @groups);
}

#line 169

sub all_columns {
	my $self = shift;
	return grep $_->in_database, values %{ $self->{_allcol} };
}

sub primary {
	my @cols = shift->group_cols('Primary');
	if (!wantarray && @cols > 1) {
		local ($Carp::CarpLevel) = 1;
		confess(
			"Multiple columns in Primary group (@cols) but primary called in scalar context"
		);
		return $cols[0];
	}
	return @cols;
}

sub essential {
	my $self = shift;
	my @cols = $self->group_cols('Essential');
	@cols = $self->primary unless @cols;
	return @cols;
}

1;

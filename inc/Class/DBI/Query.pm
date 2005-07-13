#line 1 "inc/Class/DBI/Query.pm - /Library/Perl/5.8.6/Class/DBI/Query.pm"
package Class::DBI::Query::Base;

use strict;

use base 'Class::Accessor';
use Storable 'dclone';

sub new {
	my ($class, $fields) = @_;
	my $self = $class->SUPER::new();
	foreach my $key (keys %{ $fields || {} }) {
		$self->set($key => $fields->{$key});
	}
	$self;
}

sub get {
	my ($self, $key) = @_;
	my @vals = @{ $self->{$key} || [] };
	return wantarray ? @vals : $vals[0];
}

sub set {
	my ($self, $key, @args) = @_;
	@args = map { ref $_ eq "ARRAY" ? @$_ : $_ } @args;
	$self->{$key} = [@args];
}

sub clone { dclone shift }

package Class::DBI::Query;

use base 'Class::DBI::Query::Base';

__PACKAGE__->mk_accessors(
	qw/
		owner essential sqlname where_clause restrictions order_by kings
		/
);

#line 67

#line 109

sub new {
	my ($class, $self) = @_;
	require Carp;
	Carp::carp "Class::DBI::Query deprecated";
	$self->{owner}     ||= caller;
	$self->{kings}     ||= $self->{owner};
	$self->{essential} ||= [ $self->{owner}->_essential ];
	$self->{sqlname}   ||= 'SearchSQL';
	return $class->SUPER::new($self);
}

sub _essential_string {
	my $self  = shift;
	my $table = $self->owner->table_alias;
	join ", ", map "$table.$_", $self->essential;
}

sub where {
	my ($self, $type, @cols) = @_;
	my @where = $self->where_clause;
	my $last = pop @where || "";
	$last .= join " AND ", $self->restrictions;
	$last .= " ORDER BY " . $self->order_by if $self->order_by;
	push @where, $last;
	return @where;
}

sub add_restriction {
	my ($self, $sql) = @_;
	$self->restrictions($self->restrictions, $sql);
}

sub tables {
	my $self = shift;
	join ", ", map { join " ", $_->table, $_->table_alias } $self->kings;
}

# my $sth = $query->run(@vals);
# Runs the SQL set up in $sqlname, e.g.
#
# SELECT %s (Essential)
# FROM   %s (Table)
# WHERE  %s = ? (SelectCol = @vals)
#
# substituting the relevant values via sprintf, and then executing with $select_val.

sub run {
	my $self = shift;
	my $owner = $self->owner or Class::DBI->_croak("Query has no owner");
	$owner = ref $owner || $owner;
	$owner->can('db_Main') or $owner->_croak("No database connection defined");
	my $sql_name = $self->sqlname or $owner->_croak("Query has no SQL");

	my @sel_vals = @_
		? ref $_[0] eq "ARRAY" ? @{ $_[0] } : (@_)
		: ();
	my $sql_method = "sql_$sql_name";

	my $sth;
	eval {
		$sth =
			$owner->$sql_method($self->_essential_string, $self->tables,
			$self->where);
		$sth->execute(@sel_vals);
	};
	if ($@) {
		$owner->_croak(
			"Can't select for $owner using '$sth->{Statement}' ($sql_name): $@",
			err => $@);
		return;
	}
	return $sth;
}

1;

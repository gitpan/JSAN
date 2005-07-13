#line 1 "inc/Ima/DBI.pm - /Library/Perl/5.8.6/Ima/DBI.pm"
package Ima::DBI;

$VERSION = '0.33';

use strict;
use base 'Class::Data::Inheritable';
use DBI;

# Some class data to store a per-class list of handles.
Ima::DBI->mk_classdata('__Database_Names');
Ima::DBI->mk_classdata('__Statement_Names');

#line 265

sub _croak { my $self = shift; require Carp; Carp::croak(@_) }

sub set_db {
	my $class = shift;
	my $db_name = shift or $class->_croak("Need a db name");
	$db_name =~ s/\s/_/g;

	my $data_source = shift or $class->_croak("Need a data source");
	my $user     = shift || "";
	my $password = shift || "";
	my $attr     = shift || {};
	ref $attr eq 'HASH' or $class->_croak("$attr must be a hash reference");
	$attr = $class->_add_default_attributes($attr);

	$class->_remember_handle($db_name);
	no strict 'refs';
	*{ $class . "::db_$db_name" } =
		$class->_mk_db_closure($data_source, $user, $password, $attr);

	return 1;
}

sub _add_default_attributes {
	my ($class, $user_attr) = @_;
	my %attr = $class->_default_attributes;
	@attr{ keys %$user_attr } = values %$user_attr;
	return \%attr;
}

sub _default_attributes {
	(
		RaiseError => 1,
		AutoCommit => 0,
		PrintError => 0,
		Taint      => 1,
		RootClass  => "DBIx::ContextualFetch"
	);
}

sub _remember_handle {
	my ($class, $db) = @_;
	my $handles = $class->__Database_Names || [];
	push @$handles, $db;
	$class->__Database_Names($handles);
}

sub _mk_db_closure {
	my ($class, @connection) = @_;
	my $dbh;
	return sub {
		unless ($dbh && $dbh->FETCH('Active') && $dbh->ping) {
			$dbh = DBI->connect_cached(@connection);
		}
		return $dbh;
	};
}

#line 356

sub set_sql {
	my ($class, $sql_name, $statement, $db_name, $cache) = @_;
	$cache = 1 unless defined $cache;

	# ------------------------- sql_* closure ----------------------- #
	my $db_meth = $db_name;
	$db_meth =~ s/\s/_/g;
	$db_meth = "db_$db_meth";

	(my $sql_meth = $sql_name) =~ s/\s/_/g;
	$sql_meth = "sql_$sql_meth";

	# Remember the name of this handle for the class.
	my $handles = $class->__Statement_Names || [];
	push @$handles, $sql_name;
	$class->__Statement_Names($handles);

	no strict 'refs';
	*{ $class . "::$sql_meth" } =
		$class->_mk_sql_closure($sql_name, $statement, $db_meth, $cache);

	return 1;
}

sub _mk_sql_closure {
	my ($class, $sql_name, $statement, $db_meth, $cache) = @_;

	return sub {
		my $class = shift;
		my $dbh   = $class->$db_meth();

		# Everything must pass through sprintf, even if @_ is empty.
		# This is to do proper '%%' translation.
		my $sql = $class->transform_sql($statement => @_);
		return $cache
			? $dbh->prepare_cached($sql)
			: $dbh->prepare($sql);
	};
}

sub transform_sql {
	my ($class, $sql, @args) = @_;
	return sprintf $sql, @args;
}

#line 432

sub db_names { @{ $_[0]->__Database_Names || [] } }

sub db_handles {
	my ($self, @db_names) = @_;
	@db_names = $self->db_names unless @db_names;
	return map $self->$_(), map "db_$_", @db_names;
}

#line 452

sub sql_names { @{ $_[0]->__Statement_Names || [] } }

#line 527

sub DBIwarn {
	my ($self, $thing, $doing) = @_;
	my $errstr = "Failure while doing '$doing' with '$thing'\n";
	$errstr .= $@ if $@;

	require Carp;
	Carp::carp $errstr;

	return 1;
}

#line 566

sub commit {
	my ($self, @db_names) = @_;
	return grep(!$_, map $_->commit, $self->db_handles(@db_names)) ? 0 : 1;
}

#line 587

sub rollback {
	my ($self, @db_names) = @_;
	return grep(!$_, map $_->rollback, $self->db_handles(@db_names)) ? 0 : 1;
}

#line 708

return 1001001;

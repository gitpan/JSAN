#line 1 "inc/Class/DBI/SQLite.pm - /Library/Perl/5.8.6/Class/DBI/SQLite.pm"
package Class::DBI::SQLite;

use strict;
use vars qw($VERSION);
$VERSION = "0.09";

require Class::DBI;
use base qw(Class::DBI);

sub _auto_increment_value {
    my $self = shift;
    return $self->db_Main->func("last_insert_rowid");
}

sub set_up_table {
    my($class, $table) = @_;

    # find all columns.
    my $sth = $class->db_Main->prepare("PRAGMA table_info('$table')");
    $sth->execute();
    my @columns;
    while (my $row = $sth->fetchrow_hashref) {
	push @columns, $row->{name};
    }
    $sth->finish;

    # find primary key. so complex ;-(
    $sth = $class->db_Main->prepare(<<'SQL');
SELECT sql FROM sqlite_master WHERE tbl_name = ?
SQL
    $sth->execute($table);
    my($sql) = $sth->fetchrow_array;
    $sth->finish;
    my ($primary) = $sql =~ m/
    (?:\(|\,) # either a ( to start the definition or a , for next
    \s*       # maybe some whitespace
    (\w+)     # the col name
    [^,]*     # anything but the end or a ',' for next column
    PRIMARY\sKEY/sxi;
    my @pks;
    if ($primary) {
        @pks = ($primary);
    } else {
        my ($pks)= $sql =~ m/PRIMARY\s+KEY\s*\(\s*([^)]+)\s*\)/;
        @pks = split m/\s*\,\s*/, $pks;
    }
    $class->table($table);
    $class->columns(Primary => @pks);
    $class->columns(All => @columns);
}

1;

__END__

#line 96

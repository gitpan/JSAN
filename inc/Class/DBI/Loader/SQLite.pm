#line 1 "inc/Class/DBI/Loader/SQLite.pm - /Library/Perl/5.8.6/Class/DBI/Loader/SQLite.pm"
package Class::DBI::Loader::SQLite;

use strict;
use base 'Class::DBI::Loader::Generic';
use vars '$VERSION';
use Text::Balanced qw( extract_bracketed );
use DBI;
use Carp;
require Class::DBI::SQLite;
require Class::DBI::Loader::Generic;

$VERSION = '0.22';

#line 38

sub _db_class { return 'Class::DBI::SQLite' }

sub _relationships {
    my $self = shift;
    foreach my $table ( $self->tables ) {

        my $dbh = $self->find_class($table)->db_Main;
        my $sth = $dbh->prepare(<<"");
SELECT sql FROM sqlite_master WHERE tbl_name = ?

        $sth->execute($table);
        my ($sql) = $sth->fetchrow_array;
        $sth->finish;

        # Cut "CREATE TABLE ( )" blabla...
        $sql =~ /^[\w\s]+\((.*)\)$/si;
        my $cols = $1;
        # strip single-line comments
        $cols =~ s/\-\-.*\n/\n/g;

        # temporarily replace any commas inside parens,
        # so we don't incorrectly split on them below
        my $cols_no_bracketed_commas = $cols;
        while ( my $extracted = (extract_bracketed($cols,"()","[^(]*"))[0] ) {
            my $replacement = $extracted;
            $replacement =~ s/,/--comma--/g;
            $replacement =~ s/^\(//;
            $replacement =~ s/\)$//;
            $cols_no_bracketed_commas =~ s/$extracted/$replacement/m;
        }

        # Split column definitions
        for my $col ( split /,/, $cols_no_bracketed_commas ) {
            # put the paren-bracketed commas back, to help
            # find multi-col fks below
            $col =~ s/\-\-comma\-\-/,/g;
            # CDBI doesn't have built-in support multi-col fks, so ignore them
            next if $col =~ s/^\s*FOREIGN\s+KEY\s*//i && $col =~ /^\([^,)]+,/;
            $col =~ s/^\s+//gs;

            # Grab reference
            if ( $col =~ /^(\w+).*REFERENCES\s+(\w+)/i ) {
                warn qq/Found foreign key definition "$col"/ if $self->debug;
                eval { $self->_has_a_many( $table, $1, $2 ) };
                warn qq/has_a_many failed "$@"/ if $@ && $self->debug;
            }
        }
    }
}

sub _tables {
    my $self = shift;
    my $dbh  = DBI->connect( @{ $self->{_datasource} } ) or croak($DBI::errstr);
    my $sth  = $dbh->prepare("SELECT * FROM sqlite_master");
    $sth->execute;
    my @tables;
    while ( my $row = $sth->fetchrow_hashref ) {
        next unless lc( $row->{type} ) eq 'table';
        push @tables, $row->{tbl_name};
    }
    return @tables;
}

#line 107

1;

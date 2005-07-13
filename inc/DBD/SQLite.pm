#line 1 "inc/DBD/SQLite.pm - /Library/Perl/5.8.6/darwin-thread-multi-2level/DBD/SQLite.pm"
# $Id: SQLite.pm,v 1.47 2005/06/20 13:53:01 matt Exp $

package DBD::SQLite;
use strict;

use DBI;
use vars qw($err $errstr $state $drh $VERSION @ISA);
$VERSION = '1.09';

use DynaLoader();
@ISA = ('DynaLoader');

__PACKAGE__->bootstrap($VERSION);

$drh = undef;

sub driver {
    return $drh if $drh;
    my ($class, $attr) = @_;

    $class .= "::dr";

    $drh = DBI::_new_drh($class, {
        Name        => 'SQLite',
        Version     => $VERSION,
        Attribution => 'DBD::SQLite by Matt Sergeant',
    });

    return $drh;
}

sub CLONE {
    undef $drh;
}

package DBD::SQLite::dr;

sub connect {
    my ($drh, $dbname, $user, $auth, $attr) = @_;

    my $dbh = DBI::_new_dbh($drh, {
        Name => $dbname,
        });

    my $real_dbname = $dbname;
    if ($dbname =~ /=/) {
        foreach my $attrib (split(/;/, $dbname)) {
            my ($k, $v) = split(/=/, $attrib, 2);
            if ($k eq 'dbname') {
                $real_dbname = $v;
            }
            else {
                # TODO: add to attribs
            }
        }
    }
    DBD::SQLite::db::_login($dbh, $real_dbname, $user, $auth)
        or return undef;

    return $dbh;
}

package DBD::SQLite::db;

sub prepare {
    my ($dbh, $statement, @attribs) = @_;

    my $sth = DBI::_new_sth($dbh, {
        Statement => $statement,
    });

    DBD::SQLite::st::_prepare($sth, $statement, @attribs)
        or return undef;

    return $sth;
}

sub _get_version {
    my ($dbh) = @_;
    return (DBD::SQLite::db::FETCH($dbh, 'sqlite_version'));
}

my %info = (
    17 => 'SQLite',         # SQL_DBMS_NAME
    18 => \&_get_version,   # SQL_DBMS_VER
    29 => '"',              # SQL_IDENTIFIER_QUOTE_CHAR
);
	
sub get_info {
    my($dbh, $info_type) = @_;
    my $v = $info{int($info_type)};
    $v = $v->($dbh) if ref $v eq 'CODE';
    return $v;
}

sub table_info {
    my ($dbh, $CatVal, $SchVal, $TblVal, $TypVal) = @_;
    # SQL/CLI (ISO/IEC JTC 1/SC 32 N 0595), 6.63 Tables
    # Based on DBD::Oracle's
    # See also http://www.ch-werner.de/sqliteodbc/html/sqliteodbc_8c.html#a117

    my @Where = ();
    my $Sql;
    if (   defined($CatVal) && $CatVal eq '%'
       && defined($SchVal) && $SchVal eq '' 
       && defined($TblVal) && $TblVal eq '')  { # Rule 19a
            $Sql = <<'SQL';
SELECT NULL TABLE_CAT
     , NULL TABLE_SCHEM
     , NULL TABLE_NAME
     , NULL TABLE_TYPE
     , NULL REMARKS
SQL
    }
    elsif (   defined($SchVal) && $SchVal eq '%' 
          && defined($CatVal) && $CatVal eq '' 
          && defined($TblVal) && $TblVal eq '') { # Rule 19b
            $Sql = <<'SQL';
SELECT NULL      TABLE_CAT
     , NULL      TABLE_SCHEM
     , NULL      TABLE_NAME
     , NULL      TABLE_TYPE
     , NULL      REMARKS
SQL
    }
    elsif (    defined($TypVal) && $TypVal eq '%' 
           && defined($CatVal) && $CatVal eq '' 
           && defined($SchVal) && $SchVal eq '' 
           && defined($TblVal) && $TblVal eq '') { # Rule 19c
            $Sql = <<'SQL';
SELECT NULL TABLE_CAT
     , NULL TABLE_SCHEM
     , NULL TABLE_NAME
     , t.tt TABLE_TYPE
     , NULL REMARKS
FROM (
     SELECT 'TABLE' tt                  UNION
     SELECT 'VIEW' tt                   UNION
     SELECT 'LOCAL TEMPORARY' tt
) t
ORDER BY TABLE_TYPE
SQL
    }
    else {
            $Sql = <<'SQL';
SELECT *
FROM
(
SELECT NULL         TABLE_CAT
     , NULL         TABLE_SCHEM
     , tbl_name     TABLE_NAME
     ,              TABLE_TYPE
     , NULL         REMARKS
     , sql          sqlite_sql
FROM (
    SELECT tbl_name, upper(type) TABLE_TYPE, sql
    FROM sqlite_master
    WHERE type IN ( 'table','view')
UNION ALL
    SELECT tbl_name, 'LOCAL TEMPORARY' TABLE_TYPE, sql
    FROM sqlite_temp_master
    WHERE type IN ( 'table','view')
UNION ALL
    SELECT 'sqlite_master'      tbl_name, 'SYSTEM TABLE' TABLE_TYPE, NULL sql
UNION ALL
    SELECT 'sqlite_temp_master' tbl_name, 'SYSTEM TABLE' TABLE_TYPE, NULL sql
)
)
SQL
            if ( defined $TblVal ) {
                    push @Where, "TABLE_NAME  LIKE '$TblVal'";
            }
            if ( defined $TypVal ) {
                    my $table_type_list;
                    $TypVal =~ s/^\s+//;
                    $TypVal =~ s/\s+$//;
                    my @ttype_list = split (/\s*,\s*/, $TypVal);
                    foreach my $table_type (@ttype_list) {
                            if ($table_type !~ /^'.*'$/) {
                                    $table_type = "'" . $table_type . "'";
                            }
                            $table_type_list = join(", ", @ttype_list);
                    }
                    push @Where, "TABLE_TYPE IN (\U$table_type_list)"
			if $table_type_list;
            }
            $Sql .= ' WHERE ' . join("\n   AND ", @Where ) . "\n" if @Where;
            $Sql .= " ORDER BY TABLE_TYPE, TABLE_SCHEM, TABLE_NAME\n";
    }
    my $sth = $dbh->prepare($Sql) or return undef;
    $sth->execute or return undef;
    $sth;
}


sub primary_key_info {
    my($dbh, $catalog, $schema, $table) = @_;

    my @pk_info;

    my $sth_tables = $dbh->table_info($catalog, $schema, $table, '');

    # this is a hack but much simpler than using pragma index_list etc
    # also the pragma doesn't list 'INTEGER PRIMARK KEY' autoinc PKs!
    while ( my $row = $sth_tables->fetchrow_hashref ) {
        my $sql = $row->{sqlite_sql} or next;
	next unless $sql =~ /(.*?)\s*PRIMARY\s+KEY\s*(?:\(\s*(.*?)\s*\))?/si;
	my @pk = split /\s*,\s*/, $2 || '';
	unless (@pk) {
	    my $prefix = $1;
	    $prefix =~ s/.*create\s+table\s+.*?\(\s*//i;
	    $prefix = (split /\s*,\s*/, $prefix)[-1];
	    @pk = (split /\s+/, $prefix)[0]; # take first word as name
	}
	#warn "GOT PK $row->{TABLE_NAME} (@pk)\n";
	my $key_seq = 0;
	for my $pk_field (@pk) {
	    push @pk_info, {
		TABLE_SCHEM => $row->{TABLE_SCHEM},
		TABLE_NAME  => $row->{TABLE_NAME},
		COLUMN_NAME => $pk_field,
		KEY_SEQ => ++$key_seq,
		PK_NAME => 'PRIMARY KEY',
	    };
	}
    }

    my $sponge = DBI->connect("DBI:Sponge:", '','')
        or return $dbh->DBI::set_err($DBI::err, "DBI::Sponge: $DBI::errstr");
    my @names = qw(TABLE_CAT TABLE_SCHEM TABLE_NAME COLUMN_NAME KEY_SEQ PK_NAME);
    my $sth = $sponge->prepare("column_info $table", {
        rows => [ map { [ @{$_}{@names} ] } @pk_info ],
        NUM_OF_FIELDS => scalar @names,
        NAME => \@names,
    }) or return $dbh->DBI::set_err($sponge->err(), $sponge->errstr());
    return $sth;
}

sub type_info_all {
    my ($dbh) = @_;
return; # XXX code just copied from DBD::Oracle, not yet thought about
    my $names = {
	TYPE_NAME	=> 0,
	DATA_TYPE	=> 1,
	COLUMN_SIZE	=> 2,
	LITERAL_PREFIX	=> 3,
	LITERAL_SUFFIX	=> 4,
	CREATE_PARAMS	=> 5,
	NULLABLE	=> 6,
	CASE_SENSITIVE	=> 7,
	SEARCHABLE	=> 8,
	UNSIGNED_ATTRIBUTE	=> 9,
	FIXED_PREC_SCALE	=>10,
	AUTO_UNIQUE_VALUE	=>11,
	LOCAL_TYPE_NAME	=>12,
	MINIMUM_SCALE	=>13,
	MAXIMUM_SCALE	=>14,
	SQL_DATA_TYPE	=>15,
	SQL_DATETIME_SUB=>16,
	NUM_PREC_RADIX	=>17,
    };
    my $ti = [
      $names,
      [ 'CHAR', 1, 255, '\'', '\'', 'max length', 1, 1, 3,
	undef, '0', '0', undef, undef, undef, 1, undef, undef
      ],
      [ 'NUMBER', 3, 38, undef, undef, 'precision,scale', 1, '0', 3,
	'0', '0', '0', undef, '0', 38, 3, undef, 10
      ],
      [ 'DOUBLE', 8, 15, undef, undef, undef, 1, '0', 3,
	'0', '0', '0', undef, undef, undef, 8, undef, 10
      ],
      [ 'DATE', 9, 19, '\'', '\'', undef, 1, '0', 3,
	undef, '0', '0', undef, '0', '0', 11, undef, undef
      ],
      [ 'VARCHAR', 12, 1024*1024, '\'', '\'', 'max length', 1, 1, 3,
	undef, '0', '0', undef, undef, undef, 12, undef, undef
      ]
    ];
    return $ti;
}


1;
__END__

#line 556

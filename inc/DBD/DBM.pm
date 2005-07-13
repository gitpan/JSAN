#line 1 "inc/DBD/DBM.pm - /Library/Perl/5.8.6/darwin-thread-multi-2level/DBD/DBM.pm"
#######################################################################
#
#  DBD::DBM - a DBI driver for DBM files
#
#  Copyright (c) 2004 by Jeff Zucker < jzucker AT cpan.org >
#
#  All rights reserved.
#
#  You may freely distribute and/or modify this  module under the terms
#  of either the GNU  General Public License (GPL) or the Artistic License,
#  as specified in the Perl README file.
#
#  USERS - see the pod at the bottom of this file
#
#  DBD AUTHORS - see the comments in the code
#
#######################################################################
require 5.005_03;
use strict;

#################
package DBD::DBM;
#################
use base qw( DBD::File );
use vars qw($VERSION $ATTRIBUTION $drh $methods_already_installed);
$VERSION     = '0.02';
$ATTRIBUTION = 'DBD::DBM by Jeff Zucker';

# no need to have driver() unless you need private methods
#
sub driver ($;$) {
    my($class, $attr) = @_;
    return $drh if $drh;

    # do the real work in DBD::File
    #
    $attr->{Attribution} = 'DBD::DBM by Jeff Zucker';
    my $this = $class->SUPER::driver($attr);

    # install private methods
    #
    # this requires that dbm_ (or foo_) be a registered prefix
    # but you can write private methods before official registration
    # by hacking the $dbd_prefix_registry in a private copy of DBI.pm
    #
    if ( $DBI::VERSION >= 1.37 and !$methods_already_installed++ ) {
        DBD::DBM::db->install_method('dbm_versions');
        DBD::DBM::st->install_method('dbm_schema');
    }

    $this;
}

sub CLONE {
    undef $drh;
}

#####################
package DBD::DBM::dr;
#####################
$DBD::DBM::dr::imp_data_size = 0;
@DBD::DBM::dr::ISA = qw(DBD::File::dr);

# you can get by without connect() if you don't have to check private
# attributes, DBD::File will gather the connection string arguements for you
#
sub connect ($$;$$$) {
    my($drh, $dbname, $user, $auth, $attr)= @_;

    # create a 'blank' dbh
    my $this = DBI::_new_dbh($drh, {
	Name => $dbname,
    });

    # parse the connection string for name=value pairs
    if ($this) {

        # define valid private attributes
        #
        # attempts to set non-valid attrs in connect() or
        # with $dbh->{attr} will throw errors
        #
        # the attrs here *must* start with dbm_ or foo_
        #
        # see the STORE methods below for how to check these attrs
        #
        $this->{dbm_valid_attrs} = {
            dbm_tables            => 1  # per-table information
          , dbm_type              => 1  # the global DBM type e.g. SDBM_File
          , dbm_mldbm             => 1  # the global MLDBM serializer
          , dbm_cols              => 1  # the global column names
          , dbm_version           => 1  # verbose DBD::DBM version
          , dbm_ext               => 1  # file extension
          , dbm_lockfile          => 1  # lockfile extension
          , dbm_store_metadata    => 1  # column names, etc.
          , dbm_berkeley_flags    => 1  # for BerkeleyDB
        };

	my($var, $val);
	$this->{f_dir} = $DBD::File::haveFileSpec ? File::Spec->curdir() : '.';
	while (length($dbname)) {
	    if ($dbname =~ s/^((?:[^\\;]|\\.)*?);//s) {
		$var = $1;
	    } else {
		$var = $dbname;
		$dbname = '';
	    }
	    if ($var =~ /^(.+?)=(.*)/s) {
		$var = $1;
		($val = $2) =~ s/\\(.)/$1/g;

                # in the connect string the attr names
                # can either have dbm_ (or foo_) prepended or not
                # this will add the prefix if it's missing
                #
                $var = 'dbm_' . $var unless $var =~ /^dbm_/
                                     or     $var eq 'f_dir';
		# XXX should pass back to DBI via $attr for connect() to STORE
		$this->{$var} = $val;
	    }
	}
	$this->{f_version} = $DBD::File::VERSION;
        $this->{dbm_version} = $DBD::DBM::VERSION;
        for (qw( nano_version statement_version)) {
            $this->{'sql_'.$_} = $DBI::SQL::Nano::versions->{$_}||'';
        }
        $this->{sql_handler} = ($this->{sql_statement_version})
                             ? 'SQL::Statement'
   	                     : 'DBI::SQL::Nano';
    }
    $this->STORE('Active',1);
    return $this;
}

# you could put some :dr private methods here

# you may need to over-ride some DBD::File::dr methods here
# but you can probably get away with just letting it do the work
# in most cases

#####################
package DBD::DBM::db;
#####################
$DBD::DBM::db::imp_data_size = 0;
@DBD::DBM::db::ISA = qw(DBD::File::db);

# the ::db::STORE method is what gets called when you set
# a lower-cased database handle attribute such as $dbh->{somekey}=$someval;
#
# STORE should check to make sure that "somekey" is a valid attribute name
# but only if it is really one of our attributes (starts with dbm_ or foo_)
# You can also check for valid values for the attributes if needed
# and/or perform other operations
#
sub STORE ($$$) {
    my ($dbh, $attrib, $value) = @_;

    # use DBD::File's STORE unless its one of our own attributes
    #
    return $dbh->SUPER::STORE($attrib,$value) unless $attrib =~ /^dbm_/;

    # throw an error if it has our prefix but isn't a valid attr name
    #
    if ( $attrib ne 'dbm_valid_attrs'          # gotta start somewhere :-)
     and !$dbh->{dbm_valid_attrs}->{$attrib} ) {
        return $dbh->set_err( 1,"Invalid attribute '$attrib'!");
    }
    else {

        # check here if you need to validate values
        # or conceivably do other things as well
        #
	$dbh->{$attrib} = $value;
        return 1;
    }
}

# and FETCH is done similar to STORE
#
sub FETCH ($$) {
    my ($dbh, $attrib) = @_;

    return $dbh->SUPER::FETCH($attrib) unless $attrib =~ /^dbm_/;

    # throw an error if it has our prefix but isn't a valid attr name
    #
    if ( $attrib ne 'dbm_valid_attrs'          # gotta start somewhere :-)
     and !$dbh->{dbm_valid_attrs}->{$attrib} ) {
        return $dbh->set_err( 1,"Invalid attribute '$attrib'");
    }
    else {

        # check here if you need to validate values
        # or conceivably do other things as well
        #
	return $dbh->{$attrib};
    }
}


# this is an example of a private method
# these used to be done with $dbh->func(...)
# see above in the driver() sub for how to install the method
#
sub dbm_versions {
    my $dbh   = shift;
    my $table = shift || '';
    my $dtype = $dbh->{dbm_tables}->{$table}->{type}
             || $dbh->{dbm_type}
             || 'SDBM_File';
    my $mldbm = $dbh->{dbm_tables}->{$table}->{mldbm}
             || $dbh->{dbm_mldbm}
             || '';
    $dtype   .= ' + MLDBM + ' . $mldbm if $mldbm;

    my %version = ( DBI => $DBI::VERSION );
    $version{"DBI::PurePerl"} = $DBI::PurePerl::VERSION	if $DBI::PurePerl;
    $version{OS}   = "$^O ($Config::Config{osvers})";
    $version{Perl} = "$] ($Config::Config{archname})";
    my $str = sprintf "%-16s %s\n%-16s %s\n%-16s %s\n",
      'DBD::DBM'         , $dbh->{Driver}->{Version} . " using $dtype"
    , '  DBD::File'      , $dbh->{f_version}
    , '  DBI::SQL::Nano' , $dbh->{sql_nano_version}
    ;
    $str .= sprintf "%-16s %s\n",
    , '  SQL::Statement' , $dbh->{sql_statement_version}
      if $dbh->{sql_handler} eq 'SQL::Statement';
    for (sort keys %version) {
        $str .= sprintf "%-16s %s\n", $_, $version{$_};
    }
    return "$str\n";
}

# you may need to over-ride some DBD::File::db methods here
# but you can probably get away with just letting it do the work
# in most cases

#####################
package DBD::DBM::st;
#####################
$DBD::DBM::st::imp_data_size = 0;
@DBD::DBM::st::ISA = qw(DBD::File::st);

sub dbm_schema {
    my($sth,$tname)=@_;
    return $sth->set_err(1,'No table name supplied!') unless $tname;
    return $sth->set_err(1,"Unknown table '$tname'!")
       unless $sth->{Database}->{dbm_tables}
          and $sth->{Database}->{dbm_tables}->{$tname};
    return $sth->{Database}->{dbm_tables}->{$tname}->{schema};
}
# you could put some :st private methods here

# you may need to over-ride some DBD::File::st methods here
# but you can probably get away with just letting it do the work
# in most cases

############################
package DBD::DBM::Statement;
############################
use base qw( DBD::File::Statement );
use IO::File;  # for locking only
use Fcntl;

my $HAS_FLOCK = eval { flock STDOUT, 0; 1 };

# you must define open_table;
# it is done at the start of all executes;
# it doesn't necessarily have to "open" anything;
# you must define the $tbl and at least the col_names and col_nums;
# anything else you put in depends on what you need in your
# ::Table methods below; you must bless the $tbl into the
# appropriate class as shown
#
# see also the comments inside open_table() showing the difference
# between global, per-table, and default settings
#
sub open_table ($$$$$) {
    my($self, $data, $table, $createMode, $lockMode) = @_;
    my $dbh = $data->{Database};

    my $tname = $table || $self->{tables}->[0]->{name};
    my $file;
    ($table,$file) = $self->get_file_name($data,$tname);

    # note the use of three levels of attribute settings below
    # first it looks for a per-table setting
    # if none is found, it looks for a global setting
    # if none is found, it sets a default
    #
    # your DBD may not need this, gloabls and defaults may be enough
    #
    my $dbm_type = $dbh->{dbm_tables}->{$tname}->{type}
                || $dbh->{dbm_type}
                || 'SDBM_File';
    $dbh->{dbm_tables}->{$tname}->{type} = $dbm_type;

    my $serializer = $dbh->{dbm_tables}->{$tname}->{mldbm}
                  || $dbh->{dbm_mldbm}
                  || '';
    $dbh->{dbm_tables}->{$tname}->{mldbm} = $serializer if $serializer;

    my $ext =  '' if $dbm_type eq 'GDBM_File'
                  or $dbm_type eq 'DB_File'
                  or $dbm_type eq 'BerkeleyDB';
    # XXX NDBM_File on FreeBSD (and elsewhere?) may actually be Berkeley
    # behind the scenes and so create a single .db file.
    $ext = '.pag' if $dbm_type eq 'NDBM_File'
                  or $dbm_type eq 'SDBM_File'
                  or $dbm_type eq 'ODBM_File';
    $ext = $dbh->{dbm_ext} if defined $dbh->{dbm_ext};
    $ext = $dbh->{dbm_tables}->{$tname}->{ext}
        if defined $dbh->{dbm_tables}->{$tname}->{ext};
    $ext = '' unless defined $ext;

    my $open_mode = O_RDONLY;
       $open_mode = O_RDWR                 if $lockMode;
       $open_mode = O_RDWR|O_CREAT|O_TRUNC if $createMode;

    my($tie_type);

    if ( $serializer ) {
       require 'MLDBM.pm';
       $MLDBM::UseDB      = $dbm_type;
       $MLDBM::UseDB      = 'BerkeleyDB::Hash' if $dbm_type eq 'BerkeleyDB';
       $MLDBM::Serializer = $serializer;
       $tie_type = 'MLDBM';
    }
    else {
       require "$dbm_type.pm";
       $tie_type = $dbm_type;
    }

    # Second-guessing the file extension isn't great here (or in general)
    # could replace this by trying to open the file in non-create mode
    # first and dieing if that succeeds.
    # Currently this test doesn't work where NDBM is actually Berkeley (.db)
    die "Cannot CREATE '$file$ext' because it already exists"
        if $createMode and (-e "$file$ext");

    # LOCKING
    #
    my($nolock,$lockext,$lock_table);
    $lockext = $dbh->{dbm_tables}->{$tname}->{lockfile};
    $lockext = $dbh->{dbm_lockfile} if !defined $lockext;
    if ( (defined $lockext and $lockext == 0) or !$HAS_FLOCK
    ) {
        undef $lockext;
        $nolock = 1;
    }
    else {
        $lockext ||= '.lck';
    }
    # open and flock the lockfile, creating it if necessary
    #
    if (!$nolock) {
        $lock_table = $self->SUPER::open_table(
            $data, "$table$lockext", $createMode, $lockMode
        );
    }

    # TIEING
    #
    # allow users to pass in a pre-created tied object
    #
    my @tie_args;
    if ($dbm_type eq 'BerkeleyDB') {
       my $DB_CREATE = 1;  # but import constants if supplied
       my $DB_RDONLY = 16; #
       my %flags;
       if (my $f = $dbh->{dbm_berkeley_flags}) {
           $DB_CREATE  = $f->{DB_CREATE} if $f->{DB_CREATE};
           $DB_RDONLY  = $f->{DB_RDONLY} if $f->{DB_RDONLY};
           delete $f->{DB_CREATE};
           delete $f->{DB_RDONLY};
           %flags = %$f;
       }
       $flags{'-Flags'} = $DB_RDONLY;
       $flags{'-Flags'} = $DB_CREATE if $lockMode or $createMode;
        my $t = 'BerkeleyDB::Hash';
           $t = 'MLDBM' if $serializer;
	@tie_args = ($t, -Filename=>$file, %flags);
    }
    else {
        @tie_args = ($tie_type, $file, $open_mode, 0666);
    }
    my %h;
    if ( $self->{command} ne 'DROP') {
	my $tie_class = shift @tie_args;
	eval { tie %h, $tie_class, @tie_args };
	die "Cannot tie(%h $tie_class @tie_args): $@" if $@;
    }


    # COLUMN NAMES
    #
    my $store = $dbh->{dbm_tables}->{$tname}->{store_metadata};
       $store = $dbh->{dbm_store_metadata} unless defined $store;
       $store = 1 unless defined $store;
    $dbh->{dbm_tables}->{$tname}->{store_metadata} = $store;

    my($meta_data,$schema,$col_names);
    $meta_data = $col_names = $h{"_metadata \0"} if $store;
    if ($meta_data and $meta_data =~ m~<dbd_metadata>(.+)</dbd_metadata>~is) {
        $schema  = $col_names = $1;
        $schema  =~ s~.*<schema>(.+)</schema>.*~$1~is;
        $col_names =~ s~.*<col_names>(.+)</col_names>.*~$1~is;
    }
    $col_names ||= $dbh->{dbm_tables}->{$tname}->{c_cols}
               || $dbh->{dbm_tables}->{$tname}->{cols}
               || $dbh->{dbm_cols}
               || ['k','v'];
    $col_names = [split /,/,$col_names] if (ref $col_names ne 'ARRAY');
    $dbh->{dbm_tables}->{$tname}->{cols}   = $col_names;
    $dbh->{dbm_tables}->{$tname}->{schema} = $schema;

    my $i;
    my %col_nums  = map { $_ => $i++ } @$col_names;

    my $tbl = {
	table_name     => $tname,
	file           => $file,
	ext            => $ext,
        hash           => \%h,
        dbm_type       => $dbm_type,
        store_metadata => $store,
        mldbm          => $serializer,
        lock_fh        => $lock_table->{fh},
        lock_ext       => $lockext,
        nolock         => $nolock,
	col_nums       => \%col_nums,
	col_names      => $col_names
    };

    my $class = ref($self);
    $class =~ s/::Statement/::Table/;
    bless($tbl, $class);
    $tbl;
}

# DELETE is only needed for backward compat with old SQL::Statement
# it can be removed when the next SQL::Statement is released
#
# It is an example though of how you can subclass SQL::Statement/Nano
# in your DBD ... if you needed to, you could over-ride CREATE
# SELECT, etc.
#
# Note also the use of $dbh->{sql_handler} to differentiate
# between SQL::Statement and DBI::SQL::Nano
#
# Your driver may support only one of those two SQL engines, but
# your users will have more options if you support both
#
# Generally, you don't need to do anything to support both, but
# if you subclass them like this DELETE function does, you may
# need some minor changes to support both (similar to the first
# if statement in DELETE, everything else is the same)
#
sub DELETE ($$$) {
    my($self, $data, $params) = @_;
    my $dbh   = $data->{Database};
    my($table,$tname,@where_args);
    if ($dbh->{sql_handler} eq 'SQL::Statement') {
       my($eval,$all_cols) = $self->open_tables($data, 0, 1);
       return undef unless $eval;
       $eval->params($params);
       $self->verify_columns($eval, $all_cols);
       $table = $eval->table($self->tables(0)->name());
       @where_args = ($eval,$self->tables(0)->name());
    }
    else {
        $table = $self->open_tables($data, 0, 1);
        $self->verify_columns($table);
        @where_args = ($table);
    }
    my($affected) = 0;
    my(@rows, $array);
    if ( $table->can('delete_one_row') ) {
        while (my $array = $table->fetch_row($data)) {
            if ($self->eval_where(@where_args,$array)) {
                ++$affected;
                $array = $self->{fetched_value} if $self->{fetched_from_key};
                $table->delete_one_row($data,$array);
                return ($affected, 0) if $self->{fetched_from_key};
            }
        }
        return ($affected, 0);
    }
    while ($array = $table->fetch_row($data)) {
        if ($self->eval_where($table,$array)) {
            ++$affected;
        } else {
            push(@rows, $array);
        }
    }
    $table->seek($data, 0, 0);
    foreach $array (@rows) {
        $table->push_row($data, $array);
    }
    $table->truncate($data);
    return ($affected, 0);
}

########################
package DBD::DBM::Table;
########################
use base qw( DBD::File::Table );

# you must define drop
# it is called from execute of a SQL DROP statement
#
sub drop ($$) {
    my($self,$data) = @_;
    untie %{$self->{hash}} if $self->{hash};
    my $ext = $self->{ext};
    unlink $self->{file}.$ext if -f $self->{file}.$ext;
    unlink $self->{file}.'.dir' if -f $self->{file}.'.dir'
                               and $ext eq '.pag';
    if (!$self->{nolock}) {
        $self->{lock_fh}->close if $self->{lock_fh};
        unlink $self->{file}.$self->{lock_ext}
            if -f $self->{file}.$self->{lock_ext};
    }
    return 1;
}

# you must define fetch_row, it is called on all fetches;
# it MUST return undef when no rows are left to fetch;
# checking for $ary[0] is specific to hashes so you'll
# probably need some other kind of check for nothing-left.
# as Janis might say: "undef's just another word for
# nothing left to fetch" :-)
#
sub fetch_row ($$$) {
    my($self, $data, $row) = @_;
    # fetch with %each
    #
    my @ary = each %{$self->{hash}};
    @ary = each %{$self->{hash}} if $self->{store_metadata}
                                 and $ary[0]
                                 and $ary[0] eq "_metadata \0";

    return undef unless defined $ary[0];
    if (ref $ary[1] eq 'ARRAY') {
       @ary = ( $ary[0], @{$ary[1]} );
    }
    return (@ary) if wantarray;
    return \@ary;

    # fetch without %each
    #
    # $self->{keys} = [sort keys %{$self->{hash}}] unless $self->{keys};
    # my $key = shift @{$self->{keys}};
    # $key = shift @{$self->{keys}} if $self->{store_metadata}
    #                             and $key
    #                             and $key eq "_metadata \0";
    # return undef unless defined $key;
    # my @ary;
    # $row = $self->{hash}->{$key};
    # if (ref $row eq 'ARRAY') {
    #   @ary = ( $key, @{$row} );
    # }
    # else {
    #    @ary = ($key,$row);
    # }
    # return (@ary) if wantarray;
    # return \@ary;
}

# you must define push_row
# it is called on inserts and updates
#
sub push_row ($$$) {
    my($self, $data, $row_aryref) = @_;
    my $key = shift @$row_aryref;
    if ( $self->{mldbm} ) {
        $self->{hash}->{$key}= $row_aryref;
    }
    else {
        $self->{hash}->{$key}=$row_aryref->[0];
    }
    1;
}

# this is where you grab the column names from a CREATE statement
# if you don't need to do that, it must be defined but can be empty
#
sub push_names ($$$) {
    my($self, $data, $row_aryref) = @_;
    $data->{Database}->{dbm_tables}->{$self->{table_name}}->{c_cols}
       = $row_aryref;
    next unless $self->{store_metadata};
    my $stmt = $data->{f_stmt};
    my $col_names = join ',', @{$row_aryref};
    my $schema = $data->{Database}->{Statement};
       $schema =~ s/^[^\(]+\((.+)\)$/$1/s;
       $schema = $stmt->schema_str if $stmt->can('schema_str');
    $self->{hash}->{"_metadata \0"} = "<dbd_metadata>"
                                    . "<schema>$schema</schema>"
                                    . "<col_names>$col_names</col_names>"
                                    . "</dbd_metadata>"
                                    ;
}

# fetch_one_row, delete_one_row, update_one_row
# are optimized for hash-style lookup without looping;
# if you don't need them, omit them, they're optional
# but, in that case you may need to define
# truncate() and seek(), see below
#
sub fetch_one_row ($$;$) {
    my($self,$key_only,$value) = @_;
    return $self->{col_names}->[0] if $key_only;
    return [$value, $self->{hash}->{$value}];
}
sub delete_one_row ($$$) {
    my($self,$data,$aryref) = @_;
    delete $self->{hash}->{$aryref->[0]};
}
sub update_one_row ($$$) {
    my($self,$data,$aryref) = @_;
    my $key = shift @$aryref;
    return undef unless defined $key;
    if( ref $aryref->[0] eq 'ARRAY'){
        return  $self->{hash}->{$key}=$aryref;
    }
    $self->{hash}->{$key}=$aryref->[0];
}

# you may not need to explicitly DESTROY the ::Table
# put cleanup code to run when the execute is done
#
sub DESTROY ($) {
    my $self=shift;
    untie %{$self->{hash}} if $self->{hash};
    # release the flock on the lock file
    $self->{lock_fh}->close if !$self->{nolock} and $self->{lock_fh};
}

# truncate() and seek() must be defined to satisfy DBI::SQL::Nano
# *IF* you define the *_one_row methods above, truncate() and
# seek() can be empty or you can use them without actually
# truncating or seeking anything but if you don't define the
# *_one_row methods, you may need to define these

# if you need to do something after a series of
# deletes or updates, you can put it in truncate()
# which is called at the end of executing
#
sub truncate ($$) {
    my($self,$data) = @_;
    1;
}

# seek() is only needed if you use IO::File
# though it could be used for other non-file operations
# that you need to do before "writes" or truncate()
#
sub seek ($$$$) {
    my($self, $data, $pos, $whence) = @_;
}

# Th, th, th, that's all folks!  See DBD::File and DBD::CSV for other
# examples of creating pure perl DBDs.  I hope this helped.
# Now it's time to go forth and create your own DBD!
# Remember to check in with dbi-dev@perl.org before you get too far.
# We may be able to make suggestions or point you to other related
# projects.

1;
__END__

#line 1031


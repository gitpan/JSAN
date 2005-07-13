#line 1 "inc/Class/DBI/Loader/Generic.pm - /Library/Perl/5.8.6/Class/DBI/Loader/Generic.pm"
package Class::DBI::Loader::Generic;

use strict;
use vars qw($VERSION);
use Carp;
use Lingua::EN::Inflect;

$VERSION = '0.22';

#line 77

sub new {
    my ( $class, %args ) = @_;
    if ( $args{debug} ) {
        no strict 'refs';
        *{"$class\::debug"} = sub { 1 };
    }
    my $additional = $args{additional_classes} || [];
    $additional = [$additional] unless ref $additional eq 'ARRAY';
    my $additional_base = $args{additional_base_classes} || [];
    $additional_base = [$additional_base]
      unless ref $additional_base eq 'ARRAY';
    my $left_base = $args{left_base_classes} || [];
    $left_base = [$left_base] unless ref $left_base eq 'ARRAY';
    my $self = bless {
        _datasource =>
          [ $args{dsn}, $args{user}, $args{password}, $args{options} ],
        _namespace       => $args{namespace},
        _additional      => $additional,
        _additional_base => $additional_base,
        _left_base       => $left_base,
        _constraint      => $args{constraint} || '.*',
        _exclude         => $args{exclude},
        _relationships   => $args{relationships},
        _inflect         => $args{inflect},
        CLASSES          => {},
    }, $class;
    $self->_load_classes;
    $self->_relationships if $self->{_relationships};
    $self;
}

#line 116

sub find_class {
    my ( $self, $table ) = @_;
    return $self->{CLASSES}->{$table};
}

#line 129

sub classes {
    my $self = shift;
    return sort values %{ $self->{CLASSES} };
}

#line 140

sub debug { 0 }

#line 150

sub tables {
    my $self = shift;
    return sort keys %{ $self->{CLASSES} };
}

# Overload in your driver class
sub _db_class { croak "ABSTRACT METHOD" }

# Setup has_a and has_many relationships
sub _has_a_many {
    my ( $self, $table, $column, $other ) = @_;
    my $table_class = $self->find_class($table);
    my $other_class = $self->find_class($other);
    warn qq/Has_a relationship "$table_class", "$column" -> "$other_class"/
      if $self->debug;
    $table_class->has_a( $column => $other_class );
    my ($table_class_base) = $table_class =~ /.*::(.+)/;
    my $plural = Lingua::EN::Inflect::PL( lc $table_class_base );
    $plural = $self->{_inflect}->{lc $table_class_base}
      if $self->{_inflect} and exists $self->{_inflect}->{lc $table_class_base};
    warn qq/Has_many relationship "$other_class", "$plural" -> "$table_class"/
      if $self->debug;
    $other_class->has_many( $plural => $table_class );
}

# Load and setup classes
sub _load_classes {
    my $self            = shift;
    my @tables          = $self->_tables();
    my $db_class        = $self->_db_class();
    my $additional      = join '', map "use $_;", @{ $self->{_additional} };
    my $additional_base = join '', map "use base '$_';",
      @{ $self->{_additional_base} };
    my $left_base       = join '', map "use $_;", @{ $self->{_left_base} };
    my $constraint = $self->{_constraint};
    my $exclude = $self->{_exclude};
    foreach my $table (@tables) {
        next unless $table =~ /$constraint/;
        next if (defined $exclude && $table =~ /$exclude/);
        warn qq/Found table "$table"/ if $self->debug;
        my $class = $self->_table2class($table);
        warn qq/Initializing "$class"/ if $self->debug;
        no strict 'refs';
        @{"$class\::ISA"} = $db_class;
        $class->set_db( Main => @{ $self->{_datasource} } );
        $class->set_up_table($table);
        $self->{CLASSES}->{$table} = $class;
        my $code = "package $class;$additional_base$additional$left_base";
        warn qq/Additional classes are "$code"/ if $self->debug;
        eval $code;
        croak qq/Couldn't load additional classes "$@"/ if $@;
        unshift @{"$class\::ISA"}, $_ foreach (@{ $self->{_left_base} });
    }
}

# Find and setup relationships
sub _relationships {
    my $self = shift;
    foreach my $table ( $self->tables ) {
        my $dbh = $self->find_class($table)->db_Main;
        if ( my $sth = $dbh->foreign_key_info( '', '', '', '', '', $table ) ) {
            for my $res ( @{ $sth->fetchall_arrayref( {} ) } ) {
                my $column = $res->{FK_COLUMN_NAME};
                my $other  = $res->{UK_TABLE_NAME};
                eval { $self->_has_a_many( $table, $column, $other ) };
                warn qq/has_a_many failed "$@"/ if $@ && $self->debug;
            }
        }
    }
}

# Make a class from a table
sub _table2class {
    my ( $self, $table ) = @_;
    my $namespace = $self->{_namespace} || "";
    $namespace =~ s/(.*)::$/$1/;
    my $subclass = join '', map ucfirst, split /[\W_]+/, $table;
    my $class = $namespace ? "$namespace\::" . $subclass : $subclass;
}

# Overload in driver class
sub _tables { croak "ABSTRACT METHOD" }

#line 240

1;

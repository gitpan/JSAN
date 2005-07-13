#line 1 "inc/SQL/Translator/Schema.pm - /Library/Perl/5.8.6/SQL/Translator/Schema.pm"
package SQL::Translator::Schema;

# vim: sw=4: ts=4:

# ----------------------------------------------------------------------
# $Id: Schema.pm,v 1.23 2005/06/08 15:31:06 mwz444 Exp $
# ----------------------------------------------------------------------
# Copyright (C) 2002-4 SQLFairy Authors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; version 2.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
# 02111-1307  USA
# -------------------------------------------------------------------

#line 50

use strict;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Schema::Procedure;
use SQL::Translator::Schema::Table;
use SQL::Translator::Schema::Trigger;
use SQL::Translator::Schema::View;
use SQL::Translator::Schema::Graph;
use SQL::Translator::Utils 'parse_list_arg';

use base 'SQL::Translator::Schema::Object';
use vars qw[ $VERSION $TABLE_ORDER $VIEW_ORDER $TRIGGER_ORDER $PROC_ORDER ];

$VERSION = sprintf "%d.%02d", q$Revision: 1.23 $ =~ /(\d+)\.(\d+)/;

__PACKAGE__->_attributes(qw/name database translator/);

# ----------------------------------------------------------------------
sub as_graph {

#line 77

    my $self = shift;
    return SQL::Translator::Schema::Graph->new(
        translator => $self->translator );
}

# ----------------------------------------------------------------------
sub add_table {

#line 100

    my $self        = shift;
    my $table_class = 'SQL::Translator::Schema::Table';
    my $table;

    if ( UNIVERSAL::isa( $_[0], $table_class ) ) {
        $table = shift;
        $table->schema($self);
    }
    else {
        my %args = @_;
        $args{'schema'} = $self;
        $table = $table_class->new( \%args )
          or return $self->error( $table_class->error );
    }

    $table->order( ++$TABLE_ORDER );

    # We know we have a name as the Table->new above errors if none given.
    my $table_name = $table->name;

    if ( defined $self->{'tables'}{$table_name} ) {
        return $self->error(qq[Can't create table: "$table_name" exists]);
    }
    else {
        $self->{'tables'}{$table_name} = $table;
    }

    return $table;
}

# ----------------------------------------------------------------------
sub drop_table {

#line 147

    my $self        = shift;
    my $table_class = 'SQL::Translator::Schema::Table';
    my $table_name;

    if ( UNIVERSAL::isa( $_[0], $table_class ) ) {
        $table_name = shift->name;
    }
    else {
        $table_name = shift;
    }
    my %args    = @_;
    my $cascade = $args{'cascade'};

    if ( !exists $self->{'tables'}{$table_name} ) {
        return $self->error(qq[Can't drop table: $table_name" doesn't exist]);
    }

    my $table = delete $self->{'tables'}{$table_name};

    if ($cascade) {

        # Drop all triggers on this table
        $self->drop_trigger()
          for ( grep { $_->on_table eq $table_name } @{ $self->{'triggers'} } );
    }
    return $table;
}

# ----------------------------------------------------------------------
sub add_procedure {

#line 193

    my $self            = shift;
    my $procedure_class = 'SQL::Translator::Schema::Procedure';
    my $procedure;

    if ( UNIVERSAL::isa( $_[0], $procedure_class ) ) {
        $procedure = shift;
        $procedure->schema($self);
    }
    else {
        my %args = @_;
        $args{'schema'} = $self;
        return $self->error('No procedure name') unless $args{'name'};
        $procedure = $procedure_class->new( \%args )
          or return $self->error( $procedure_class->error );
    }

    $procedure->order( ++$PROC_ORDER );
    my $procedure_name = $procedure->name
      or return $self->error('No procedure name');

    if ( defined $self->{'procedures'}{$procedure_name} ) {
        return $self->error(
            qq[Can't create procedure: "$procedure_name" exists] );
    }
    else {
        $self->{'procedures'}{$procedure_name} = $procedure;
    }

    return $procedure;
}

# ----------------------------------------------------------------------
sub drop_procedure {

#line 240

    my $self       = shift;
    my $proc_class = 'SQL::Translator::Schema::Procedure';
    my $proc_name;

    if ( UNIVERSAL::isa( $_[0], $proc_class ) ) {
        $proc_name = shift->name;
    }
    else {
        $proc_name = shift;
    }

    if ( !exists $self->{'procedures'}{$proc_name} ) {
        return $self->error(
            qq[Can't drop procedure: $proc_name" doesn't exist]);
    }

    my $proc = delete $self->{'procedures'}{$proc_name};

    return $proc;
}

# ----------------------------------------------------------------------
sub add_trigger {

#line 279

    my $self          = shift;
    my $trigger_class = 'SQL::Translator::Schema::Trigger';
    my $trigger;

    if ( UNIVERSAL::isa( $_[0], $trigger_class ) ) {
        $trigger = shift;
        $trigger->schema($self);
    }
    else {
        my %args = @_;
        $args{'schema'} = $self;
        return $self->error('No trigger name') unless $args{'name'};
        $trigger = $trigger_class->new( \%args )
          or return $self->error( $trigger_class->error );
    }

    $trigger->order( ++$TRIGGER_ORDER );
    my $trigger_name = $trigger->name or return $self->error('No trigger name');

    if ( defined $self->{'triggers'}{$trigger_name} ) {
        return $self->error(qq[Can't create trigger: "$trigger_name" exists]);
    }
    else {
        $self->{'triggers'}{$trigger_name} = $trigger;
    }

    return $trigger;
}

# ----------------------------------------------------------------------
sub drop_trigger {

#line 323

    my $self          = shift;
    my $trigger_class = 'SQL::Translator::Schema::Trigger';
    my $trigger_name;

    if ( UNIVERSAL::isa( $_[0], $trigger_class ) ) {
        $trigger_name = shift->name;
    }
    else {
        $trigger_name = shift;
    }

    if ( !exists $self->{'triggers'}{$trigger_name} ) {
        return $self->error(
            qq[Can't drop trigger: $trigger_name" doesn't exist]);
    }

    my $trigger = delete $self->{'triggers'}{$trigger_name};

    return $trigger;
}

# ----------------------------------------------------------------------
sub add_view {

#line 362

    my $self       = shift;
    my $view_class = 'SQL::Translator::Schema::View';
    my $view;

    if ( UNIVERSAL::isa( $_[0], $view_class ) ) {
        $view = shift;
        $view->schema($self);
    }
    else {
        my %args = @_;
        $args{'schema'} = $self;
        return $self->error('No view name') unless $args{'name'};
        $view = $view_class->new( \%args ) or return $view_class->error;
    }

    $view->order( ++$VIEW_ORDER );
    my $view_name = $view->name or return $self->error('No view name');

    if ( defined $self->{'views'}{$view_name} ) {
        return $self->error(qq[Can't create view: "$view_name" exists]);
    }
    else {
        $self->{'views'}{$view_name} = $view;
    }

    return $view;
}

# ----------------------------------------------------------------------
sub drop_view {

#line 405

    my $self       = shift;
    my $view_class = 'SQL::Translator::Schema::View';
    my $view_name;

    if ( UNIVERSAL::isa( $_[0], $view_class ) ) {
        $view_name = shift->name;
    }
    else {
        $view_name = shift;
    }

    if ( !exists $self->{'views'}{$view_name} ) {
        return $self->error(qq[Can't drop view: $view_name" doesn't exist]);
    }

    my $view = delete $self->{'views'}{$view_name};

    return $view;
}

# ----------------------------------------------------------------------
sub database {

#line 438

    my $self = shift;
    $self->{'database'} = shift if @_;
    return $self->{'database'} || '';
}

# ----------------------------------------------------------------------
sub is_valid {

#line 456

    my $self = shift;

    return $self->error('No tables') unless $self->get_tables;

    for my $object ( $self->get_tables, $self->get_views ) {
        return $object->error unless $object->is_valid;
    }

    return 1;
}

# ----------------------------------------------------------------------
sub get_procedure {

#line 480

    my $self = shift;
    my $procedure_name = shift or return $self->error('No procedure name');
    return $self->error(qq[Table "$procedure_name" does not exist])
      unless exists $self->{'procedures'}{$procedure_name};
    return $self->{'procedures'}{$procedure_name};
}

# ----------------------------------------------------------------------
sub get_procedures {

#line 500

    my $self       = shift;
    my @procedures =
      map  { $_->[1] }
      sort { $a->[0] <=> $b->[0] }
      map  { [ $_->order, $_ ] } values %{ $self->{'procedures'} };

    if (@procedures) {
        return wantarray ? @procedures : \@procedures;
    }
    else {
        $self->error('No procedures');
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------
sub get_table {

#line 528

    my $self = shift;
    my $table_name = shift or return $self->error('No table name');
    return $self->error(qq[Table "$table_name" does not exist])
      unless exists $self->{'tables'}{$table_name};
    return $self->{'tables'}{$table_name};
}

# ----------------------------------------------------------------------
sub get_tables {

#line 548

    my $self   = shift;
    my @tables =
      map  { $_->[1] }
      sort { $a->[0] <=> $b->[0] }
      map  { [ $_->order, $_ ] } values %{ $self->{'tables'} };

    if (@tables) {
        return wantarray ? @tables : \@tables;
    }
    else {
        $self->error('No tables');
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------
sub get_trigger {

#line 576

    my $self = shift;
    my $trigger_name = shift or return $self->error('No trigger name');
    return $self->error(qq[Table "$trigger_name" does not exist])
      unless exists $self->{'triggers'}{$trigger_name};
    return $self->{'triggers'}{$trigger_name};
}

# ----------------------------------------------------------------------
sub get_triggers {

#line 596

    my $self     = shift;
    my @triggers =
      map  { $_->[1] }
      sort { $a->[0] <=> $b->[0] }
      map  { [ $_->order, $_ ] } values %{ $self->{'triggers'} };

    if (@triggers) {
        return wantarray ? @triggers : \@triggers;
    }
    else {
        $self->error('No triggers');
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------
sub get_view {

#line 624

    my $self = shift;
    my $view_name = shift or return $self->error('No view name');
    return $self->error('View "$view_name" does not exist')
      unless exists $self->{'views'}{$view_name};
    return $self->{'views'}{$view_name};
}

# ----------------------------------------------------------------------
sub get_views {

#line 644

    my $self  = shift;
    my @views =
      map  { $_->[1] }
      sort { $a->[0] <=> $b->[0] }
      map  { [ $_->order, $_ ] } values %{ $self->{'views'} };

    if (@views) {
        return wantarray ? @views : \@views;
    }
    else {
        $self->error('No views');
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------
sub make_natural_joins {

#line 689

    my $self         = shift;
    my %args         = @_;
    my $join_pk_only = $args{'join_pk_only'} || 0;
    my %skip_fields  =
      map { s/^\s+|\s+$//g; $_, 1 } @{ parse_list_arg( $args{'skip_fields'} ) };

    my ( %common_keys, %pk );
    for my $table ( $self->get_tables ) {
        for my $field ( $table->get_fields ) {
            my $field_name = $field->name or next;
            next if $skip_fields{$field_name};
            $pk{$field_name} = 1 if $field->is_primary_key;
            push @{ $common_keys{$field_name} }, $table->name;
        }
    }

    for my $field ( keys %common_keys ) {
        next if $join_pk_only and !defined $pk{$field};

        my @table_names = @{ $common_keys{$field} };
        next unless scalar @table_names > 1;

        for my $i ( 0 .. $#table_names ) {
            my $table1 = $self->get_table( $table_names[$i] ) or next;

            for my $j ( 1 .. $#table_names ) {
                my $table2 = $self->get_table( $table_names[$j] ) or next;
                next if $table1->name eq $table2->name;

                $table1->add_constraint(
                    type             => FOREIGN_KEY,
                    fields           => $field,
                    reference_table  => $table2->name,
                    reference_fields => $field,
                );
            }
        }
    }

    return 1;
}

# ----------------------------------------------------------------------
sub name {

#line 744

    my $self = shift;
    $self->{'name'} = shift if @_;
    return $self->{'name'} || '';
}

# ----------------------------------------------------------------------
sub translator {

#line 760

    my $self = shift;
    $self->{'translator'} = shift if @_;
    return $self->{'translator'};
}

# ----------------------------------------------------------------------
sub DESTROY {
    my $self = shift;
    undef $_ for values %{ $self->{'tables'} };
    undef $_ for values %{ $self->{'views'} };
}

1;

# ----------------------------------------------------------------------

#line 784


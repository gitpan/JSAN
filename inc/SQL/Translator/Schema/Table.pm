#line 1 "inc/SQL/Translator/Schema/Table.pm - /Library/Perl/5.8.6/SQL/Translator/Schema/Table.pm"
package SQL::Translator::Schema::Table;

# ----------------------------------------------------------------------
# $Id: Table.pm,v 1.30 2004/11/27 16:32:46 schiffbruechige Exp $
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

#line 41

use strict;
use SQL::Translator::Utils 'parse_list_arg';
use SQL::Translator::Schema::Constants;
use SQL::Translator::Schema::Constraint;
use SQL::Translator::Schema::Field;
use SQL::Translator::Schema::Index;
use Data::Dumper;

use base 'SQL::Translator::Schema::Object';

use vars qw( $VERSION $FIELD_ORDER );

$VERSION = sprintf "%d.%02d", q$Revision: 1.30 $ =~ /(\d+)\.(\d+)/;


# Stringify to our name, being careful not to pass any args through so we don't
# accidentally set it to undef. We also have to tweak bool so the object is
# still true when it doesn't have a name (which shouldn't happen!).
use overload
    '""'     => sub { shift->name },
    'bool'   => sub { $_[0]->name || $_[0] },
    fallback => 1,
;

# ----------------------------------------------------------------------

__PACKAGE__->_attributes( qw/schema name comments options order/ );

#line 82

# ----------------------------------------------------------------------
sub add_constraint {

#line 103

    my $self             = shift;
    my $constraint_class = 'SQL::Translator::Schema::Constraint';
    my $constraint;

    if ( UNIVERSAL::isa( $_[0], $constraint_class ) ) {
        $constraint = shift;
        $constraint->table( $self );
    }
    else {
        my %args = @_;
        $args{'table'} = $self;
        $constraint = $constraint_class->new( \%args ) or 
           return $self->error( $constraint_class->error );
    }

    #
    # If we're trying to add a PK when one is already defined,
    # then just add the fields to the existing definition.
    #
    my $ok = 1;
    my $pk = $self->primary_key;
    if ( $pk && $constraint->type eq PRIMARY_KEY ) {
        $self->primary_key( $constraint->fields );
        $pk->name($constraint->name) if $constraint->name;
        my %extra = $constraint->extra; 
        $pk->extra(%extra) if keys %extra;
        $constraint = $pk;
        $ok         = 0;
    }
    elsif ( $constraint->type eq PRIMARY_KEY ) {
        for my $fname ( $constraint->fields ) {
            if ( my $f = $self->get_field( $fname ) ) {
                $f->is_primary_key( 1 );
            }
        }
    }
    #
    # See if another constraint of the same type 
    # covers the same fields.  -- This doesn't work!  ky
    #
#    elsif ( $constraint->type ne CHECK_C ) {
#        my @field_names = $constraint->fields;
#        for my $c ( 
#            grep { $_->type eq $constraint->type } 
#            $self->get_constraints 
#        ) {
#            my %fields = map { $_, 1 } $c->fields;
#            for my $field_name ( @field_names ) {
#                if ( $fields{ $field_name } ) {
#                    $constraint = $c;
#                    $ok = 0; 
#                    last;
#                }
#            }
#            last unless $ok;
#        }
#    }

    if ( $ok ) {
        push @{ $self->{'constraints'} }, $constraint;
    }

    return $constraint;
}

# ----------------------------------------------------------------------
sub drop_constraint {

#line 183

    my $self             = shift;
    my $constraint_class = 'SQL::Translator::Schema::Constraint';
    my $constraint_name;

    if ( UNIVERSAL::isa( $_[0], $constraint_class ) ) {
        $constraint_name = shift->name;
    }
    else {
        $constraint_name = shift;
    }

    if ( ! grep { $_->name eq $constraint_name } @ { $self->{'constraints'} } ) { 
        return $self->error(qq[Can't drop constraint: "$constraint_name" doesn't exist]);
    }

    my @cs = @{ $self->{'constraints'} };
    my ($constraint_id) = grep { $cs[$_]->name eq  $constraint_name } (0..$#cs);
    my $constraint = splice(@{$self->{'constraints'}}, $constraint_id, 1);

    return $constraint;
}

# ----------------------------------------------------------------------
sub add_index {

#line 226

    my $self        = shift;
    my $index_class = 'SQL::Translator::Schema::Index';
    my $index;

    if ( UNIVERSAL::isa( $_[0], $index_class ) ) {
        $index = shift;
        $index->table( $self );
    }
    else {
        my %args = @_;
        $args{'table'} = $self;
        $index = $index_class->new( \%args ) or return 
            $self->error( $index_class->error );
    }

    push @{ $self->{'indices'} }, $index;
    return $index;
}

# ----------------------------------------------------------------------
sub drop_index {

#line 260

    my $self        = shift;
    my $index_class = 'SQL::Translator::Schema::Index';
    my $index_name;

    if ( UNIVERSAL::isa( $_[0], $index_class ) ) {
        $index_name = shift->name;
    }
    else {
        $index_name = shift;
    }

    if ( ! grep { $_->name eq  $index_name } @{ $self->{'indices'} }) { 
        return $self->error(qq[Can't drop index: "$index_name" doesn't exist]);
    }

    my @is = @{ $self->{'indices'} };
    my ($index_id) = grep { $is[$_]->name eq  $index_name } (0..$#is);
    my $index = splice(@{$self->{'indices'}}, $index_id, 1);

    return $index;
}

# ----------------------------------------------------------------------
sub add_field {

#line 308

    my $self        = shift;
    my $field_class = 'SQL::Translator::Schema::Field';
    my $field;

    if ( UNIVERSAL::isa( $_[0], $field_class ) ) {
        $field = shift;
        $field->table( $self );
    }
    else {
        my %args = @_;
        $args{'table'} = $self;
        $field = $field_class->new( \%args ) or return 
            $self->error( $field_class->error );
    }

    $field->order( ++$FIELD_ORDER );
    # We know we have a name as the Field->new above errors if none given.
    my $field_name = $field->name;

    if ( exists $self->{'fields'}{ $field_name } ) { 
        return $self->error(qq[Can't create field: "$field_name" exists]);
    }
    else {
        $self->{'fields'}{ $field_name } = $field;
    }

    return $field;
}
# ----------------------------------------------------------------------
sub drop_field {

#line 351

    my $self        = shift;
    my $field_class = 'SQL::Translator::Schema::Field';
    my $field_name;

    if ( UNIVERSAL::isa( $_[0], $field_class ) ) {
        $field_name = shift->name;
    }
    else {
        $field_name = shift;
    }
    my %args = @_;
    my $cascade = $args{'cascade'};

    if ( ! exists $self->{'fields'}{ $field_name } ) {
        return $self->error(qq[Can't drop field: "$field_name" doesn't exists]);
    }

    my $field = delete $self->{'fields'}{ $field_name };

    if ( $cascade ) {
        # Remove this field from all indices using it
        foreach my $i ($self->get_indices()) {
            my @fs = $i->fields();
            @fs = grep { $_ ne $field->name } @fs;
            $i->fields(@fs);
        }

        # Remove this field from all constraints using it
        foreach my $c ($self->get_constraints()) {
            my @cs = $c->fields();
            @cs = grep { $_ ne $field->name } @cs;
            $c->fields(@cs);
        }
    }

    return $field;
}

# ----------------------------------------------------------------------
sub comments {

#line 407

    my $self     = shift;
    my @comments = ref $_[0] ? @{ $_[0] } : @_;

    for my $arg ( @comments ) {
        $arg = $arg->[0] if ref $arg;
        push @{ $self->{'comments'} }, $arg if defined $arg && $arg;
    }

    if ( @{ $self->{'comments'} || [] } ) {
        return wantarray 
            ? @{ $self->{'comments'} }
            : join( "\n", @{ $self->{'comments'} } )
        ;
    } 
    else {
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------
sub get_constraints {

#line 439

    my $self = shift;

    if ( ref $self->{'constraints'} ) {
        return wantarray 
            ? @{ $self->{'constraints'} } : $self->{'constraints'};
    }
    else {
        $self->error('No constraints');
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------
sub get_indices {

#line 464

    my $self = shift;

    if ( ref $self->{'indices'} ) {
        return wantarray 
            ? @{ $self->{'indices'} } 
            : $self->{'indices'};
    }
    else {
        $self->error('No indices');
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------
sub get_field {

#line 490

    my $self       = shift;
    my $field_name = shift or return $self->error('No field name');
    return $self->error( qq[Field "$field_name" does not exist] ) unless
        exists $self->{'fields'}{ $field_name };
    return $self->{'fields'}{ $field_name };
}

# ----------------------------------------------------------------------
sub get_fields {

#line 510

    my $self = shift;
    my @fields = 
        map  { $_->[1] }
        sort { $a->[0] <=> $b->[0] }
        map  { [ $_->order, $_ ] }
        values %{ $self->{'fields'} || {} };

    if ( @fields ) {
        return wantarray ? @fields : \@fields;
    }
    else {
        $self->error('No fields');
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------
sub is_valid {

#line 539

    my $self = shift;
    return $self->error('No name')   unless $self->name;
    return $self->error('No fields') unless $self->get_fields;

    for my $object ( 
        $self->get_fields, $self->get_indices, $self->get_constraints 
    ) {
        return $object->error unless $object->is_valid;
    }

    return 1;
}

# ----------------------------------------------------------------------
sub is_trivial_link {

#line 563

    my $self = shift;
    return 0 if $self->is_data;
    return $self->{'is_trivial_link'} if defined $self->{'is_trivial_link'};

    $self->{'is_trivial_link'} = 1;

    my %fk = ();

    foreach my $field ( $self->get_fields ) {
	  next unless $field->is_foreign_key;
	  $fk{$field->foreign_key_reference->reference_table}++;
	}

    foreach my $referenced (keys %fk){
	if($fk{$referenced} > 1){
	  $self->{'is_trivial_link'} = 0;
	  last;
	}
    }

    return $self->{'is_trivial_link'};

}

sub is_data {

#line 597

    my $self = shift;
    return $self->{'is_data'} if defined $self->{'is_data'};

    $self->{'is_data'} = 0;

    foreach my $field ( $self->get_fields ) {
        if ( !$field->is_primary_key and !$field->is_foreign_key ) {
            $self->{'is_data'} = 1;
            return $self->{'is_data'};
        }
    }

    return $self->{'is_data'};
}

# ----------------------------------------------------------------------
sub can_link {

#line 625

    my ( $self, $table1, $table2 ) = @_;

    return $self->{'can_link'}{ $table1->name }{ $table2->name }
      if defined $self->{'can_link'}{ $table1->name }{ $table2->name };

    if ( $self->is_data == 1 ) {
        $self->{'can_link'}{ $table1->name }{ $table2->name } = [0];
        $self->{'can_link'}{ $table2->name }{ $table1->name } = [0];
        return $self->{'can_link'}{ $table1->name }{ $table2->name };
    }

    my %fk = ();

    foreach my $field ( $self->get_fields ) {
        if ( $field->is_foreign_key ) {
            push @{ $fk{ $field->foreign_key_reference->reference_table } },
              $field->foreign_key_reference;
        }
    }

    if ( !defined( $fk{ $table1->name } ) or !defined( $fk{ $table2->name } ) )
    {
        $self->{'can_link'}{ $table1->name }{ $table2->name } = [0];
        $self->{'can_link'}{ $table2->name }{ $table1->name } = [0];
        return $self->{'can_link'}{ $table1->name }{ $table2->name };
    }

    # trivial traversal, only one way to link the two tables
    if (    scalar( @{ $fk{ $table1->name } } == 1 )
        and scalar( @{ $fk{ $table2->name } } == 1 ) )
    {
        $self->{'can_link'}{ $table1->name }{ $table2->name } =
          [ 'one2one', $fk{ $table1->name }, $fk{ $table2->name } ];
        $self->{'can_link'}{ $table1->name }{ $table2->name } =
          [ 'one2one', $fk{ $table2->name }, $fk{ $table1->name } ];

        # non-trivial traversal.  one way to link table2, 
        # many ways to link table1
    }
    elsif ( scalar( @{ $fk{ $table1->name } } > 1 )
        and scalar( @{ $fk{ $table2->name } } == 1 ) )
    {
        $self->{'can_link'}{ $table1->name }{ $table2->name } =
          [ 'many2one', $fk{ $table1->name }, $fk{ $table2->name } ];
        $self->{'can_link'}{ $table2->name }{ $table1->name } =
          [ 'one2many', $fk{ $table2->name }, $fk{ $table1->name } ];

        # non-trivial traversal.  one way to link table1, 
        # many ways to link table2
    }
    elsif ( scalar( @{ $fk{ $table1->name } } == 1 )
        and scalar( @{ $fk{ $table2->name } } > 1 ) )
    {
        $self->{'can_link'}{ $table1->name }{ $table2->name } =
          [ 'one2many', $fk{ $table1->name }, $fk{ $table2->name } ];
        $self->{'can_link'}{ $table2->name }{ $table1->name } =
          [ 'many2one', $fk{ $table2->name }, $fk{ $table1->name } ];

        # non-trivial traversal.  many ways to link table1 and table2
    }
    elsif ( scalar( @{ $fk{ $table1->name } } > 1 )
        and scalar( @{ $fk{ $table2->name } } > 1 ) )
    {
        $self->{'can_link'}{ $table1->name }{ $table2->name } =
          [ 'many2many', $fk{ $table1->name }, $fk{ $table2->name } ];
        $self->{'can_link'}{ $table2->name }{ $table1->name } =
          [ 'many2many', $fk{ $table2->name }, $fk{ $table1->name } ];

        # one of the tables didn't export a key 
        # to this table, no linking possible
    }
    else {
        $self->{'can_link'}{ $table1->name }{ $table2->name } = [0];
        $self->{'can_link'}{ $table2->name }{ $table1->name } = [0];
    }

    return $self->{'can_link'}{ $table1->name }{ $table2->name };
}

# ----------------------------------------------------------------------
sub name {

#line 723

    my $self = shift;

    if ( @_ ) {
        my $arg = shift || return $self->error( "No table name" );
        if ( my $schema = $self->schema ) {
            return $self->error( qq[Can't use table name "$arg": table exists] )
                if $schema->get_table( $arg );
        }
        $self->{'name'} = $arg;
    }

    return $self->{'name'} || '';
}

# ----------------------------------------------------------------------
sub schema {

#line 750

    my $self = shift;
    if ( my $arg = shift ) {
        return $self->error('Not a schema object') unless
            UNIVERSAL::isa( $arg, 'SQL::Translator::Schema' );
        $self->{'schema'} = $arg;
    }

    return $self->{'schema'};
}

# ----------------------------------------------------------------------
sub primary_key {

#line 787

    my $self   = shift;
    my $fields = parse_list_arg( @_ );

    my $constraint;
    if ( @$fields ) {
        for my $f ( @$fields ) {
            return $self->error(qq[Invalid field "$f"]) unless 
                $self->get_field($f);
        }

        my $has_pk;
        for my $c ( $self->get_constraints ) {
            if ( $c->type eq PRIMARY_KEY ) {
                $has_pk = 1;
                $c->fields( @{ $c->fields }, @$fields );
                $constraint = $c;
            } 
        }

        unless ( $has_pk ) {
            $constraint = $self->add_constraint(
                type   => PRIMARY_KEY,
                fields => $fields,
            ) or return;
        }
    }

    if ( $constraint ) {
        return $constraint;
    }
    else {
        for my $c ( $self->get_constraints ) {
            return $c if $c->type eq PRIMARY_KEY;
        }
    }

    return;
}

# ----------------------------------------------------------------------
sub options {

#line 840

    my $self    = shift;
    my $options = parse_list_arg( @_ );

    push @{ $self->{'options'} }, @$options;

    if ( ref $self->{'options'} ) {
        return wantarray ? @{ $self->{'options'} || [] } : $self->{'options'};
    }
    else {
        return wantarray ? () : [];
    }
}

# ----------------------------------------------------------------------
sub order {

#line 866

    my ( $self, $arg ) = @_;

    if ( defined $arg && $arg =~ /^\d+$/ ) {
        $self->{'order'} = $arg;
    }

    return $self->{'order'} || 0;
}

# ----------------------------------------------------------------------
sub field_names {

#line 888

    my $self = shift;
    my @fields = 
        map  { $_->name }
        sort { $a->order <=> $b->order }
        values %{ $self->{'fields'} || {} };

    if ( @fields ) {
        return wantarray ? @fields : \@fields;
    }
    else {
        $self->error('No fields');
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------

#line 946

sub pkey_fields {
    my $me = shift;
    my @fields = grep { $_->is_primary_key } $me->get_fields;
    return wantarray ? @fields : \@fields;
}

# ----------------------------------------------------------------------
sub fkey_fields {
    my $me = shift;
    my @fields;
    push @fields, $_->fields foreach $me->fkey_constraints;
    return wantarray ? @fields : \@fields;
}

# ----------------------------------------------------------------------
sub nonpkey_fields {
    my $me = shift;
    my @fields = grep { !$_->is_primary_key } $me->get_fields;
    return wantarray ? @fields : \@fields;
}

# ----------------------------------------------------------------------
sub data_fields {
    my $me = shift;
    my @fields =
        grep { !$_->is_foreign_key and !$_->is_primary_key } $me->get_fields;
    return wantarray ? @fields : \@fields;
}

# ----------------------------------------------------------------------
sub unique_fields {
    my $me = shift;
    my @fields;
    push @fields, $_->fields foreach $me->unique_constraints;
    return wantarray ? @fields : \@fields;
}

# ----------------------------------------------------------------------
sub unique_constraints {
    my $me = shift;
    my @cons = grep { $_->type eq UNIQUE } $me->get_constraints;
    return wantarray ? @cons : \@cons;
}

# ----------------------------------------------------------------------
sub fkey_constraints {
    my $me = shift;
    my @cons = grep { $_->type eq FOREIGN_KEY } $me->get_constraints;
    return wantarray ? @cons : \@cons;
}

# ----------------------------------------------------------------------
sub DESTROY {
    my $self = shift;
    undef $self->{'schema'}; # destroy cyclical reference
    undef $_ for @{ $self->{'constraints'} };
    undef $_ for @{ $self->{'indices'} };
    undef $_ for values %{ $self->{'fields'} };
}

1;

# ----------------------------------------------------------------------

#line 1019

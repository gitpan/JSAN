#line 1 "inc/SQL/Translator/Schema/Constraint.pm - /Library/Perl/5.8.6/SQL/Translator/Schema/Constraint.pm"
package SQL::Translator::Schema::Constraint;

# ----------------------------------------------------------------------
# $Id: Constraint.pm,v 1.15 2004/11/05 13:19:31 grommit Exp $
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

#line 45

use strict;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils 'parse_list_arg';

use base 'SQL::Translator::Schema::Object';

use vars qw($VERSION $TABLE_COUNT $VIEW_COUNT);

$VERSION = sprintf "%d.%02d", q$Revision: 1.15 $ =~ /(\d+)\.(\d+)/;

my %VALID_CONSTRAINT_TYPE = (
    PRIMARY_KEY, 1,
    UNIQUE,      1,
    CHECK_C,     1,
    FOREIGN_KEY, 1,
    NOT_NULL,    1,
);

# ----------------------------------------------------------------------

__PACKAGE__->_attributes( qw/
    table name type fields reference_fields reference_table 
    match_type on_delete on_update expression deferrable
/);

# Override to remove empty arrays from args.
# t/14postgres-parser breaks without this.
sub init {
    
#line 94

    my $self = shift;
    foreach ( values %{$_[0]} ) { $_ = undef if ref($_) eq "ARRAY" && ! @$_; }
    $self->SUPER::init(@_);
}

# ----------------------------------------------------------------------
sub deferrable {

#line 116

    my ( $self, $arg ) = @_;

    if ( defined $arg ) {
        $self->{'deferrable'} = $arg ? 1 : 0;
    }

    return defined $self->{'deferrable'} ? $self->{'deferrable'} : 1;
}

# ----------------------------------------------------------------------
sub expression {

#line 138

    my $self = shift;
    
    if ( my $arg = shift ) {
        # check arg here?
        $self->{'expression'} = $arg;
    }

    return $self->{'expression'} || '';
}

# ----------------------------------------------------------------------
sub is_valid {

#line 161

    my $self       = shift;
    my $type       = $self->type   or return $self->error('No type');
    my $table      = $self->table  or return $self->error('No table');
    my @fields     = $self->fields or return $self->error('No fields');
    my $table_name = $table->name  or return $self->error('No table name');

    for my $f ( @fields ) {
        next if $table->get_field( $f );
        return $self->error(
            "Constraint references non-existent field '$f' ",
            "in table '$table_name'"
        );
    }

    my $schema = $table->schema or return $self->error(
        'Table ', $table->name, ' has no schema object'
    );

    if ( $type eq FOREIGN_KEY ) {
        return $self->error('Only one field allowed for foreign key')
            if scalar @fields > 1;

        my $ref_table_name  = $self->reference_table or 
            return $self->error('No reference table');

        my $ref_table = $schema->get_table( $ref_table_name ) or
            return $self->error("No table named '$ref_table_name' in schema");

        my @ref_fields = $self->reference_fields or return;

        return $self->error('Only one field allowed for foreign key reference')
            if scalar @ref_fields > 1;

        for my $ref_field ( @ref_fields ) {
            next if $ref_table->get_field( $ref_field );
            return $self->error(
                "Constraint from field(s) ", 
                join(', ', map {qq['$table_name.$_']} @fields),
                " to non-existent field '$ref_table_name.$ref_field'"
            );
        }
    }
    elsif ( $type eq CHECK_C ) {
        return $self->error('No expression for CHECK') unless 
            $self->expression;
    }

    return 1;
}

# ----------------------------------------------------------------------
sub fields {

#line 238

    my $self   = shift;
    my $fields = parse_list_arg( @_ );

    if ( @$fields ) {
        my ( %unique, @unique );
        for my $f ( @$fields ) {
            next if $unique{ $f };
            $unique{ $f } = 1;
            push @unique, $f;
        }

        $self->{'fields'} = \@unique;
    }

    if ( @{ $self->{'fields'} || [] } ) {
        # We have to return fields that don't exist on the table as names in
        # case those fields havn't been created yet.
        my @ret = map {
            $self->table->get_field($_) || $_ } @{ $self->{'fields'} };
        return wantarray ? @ret : \@ret;
    }
    else {
        return wantarray ? () : undef;
    }
}

# ----------------------------------------------------------------------
sub field_names {

#line 277

    my $self = shift;
    return wantarray ? @{ $self->{'fields'} } : $self->{'fields'};
}

# ----------------------------------------------------------------------
sub match_type {

#line 295

    my $self = shift;
    
    if ( my $arg = lc shift ) {
        return $self->error("Invalid match type: $arg")
            unless $arg eq 'full' || $arg eq 'partial';
        $self->{'match_type'} = $arg;
    }

    return $self->{'match_type'} || '';
}

# ----------------------------------------------------------------------
sub name {

#line 319

    my $self = shift;
    my $arg  = shift || '';
    $self->{'name'} = $arg if $arg;
    return $self->{'name'} || '';
}

# ----------------------------------------------------------------------
sub options {

#line 340

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
sub on_delete {

#line 367

    my $self = shift;
    
    if ( my $arg = shift ) {
        # validate $arg?
        $self->{'on_delete'} = $arg;
    }

    return $self->{'on_delete'} || '';
}

# ----------------------------------------------------------------------
sub on_update {

#line 390

    my $self = shift;
    
    if ( my $arg = shift ) {
        # validate $arg?
        $self->{'on_update'} = $arg;
    }

    return $self->{'on_update'} || '';
}

# ----------------------------------------------------------------------
sub reference_fields {

#line 420

    my $self   = shift;
    my $fields = parse_list_arg( @_ );

    if ( @$fields ) {
        $self->{'reference_fields'} = $fields;
    }

    # Nothing set so try and derive it from the other constraint data
    unless ( ref $self->{'reference_fields'} ) {
        my $table   = $self->table   or return $self->error('No table');
        my $schema  = $table->schema or return $self->error('No schema');
        if ( my $ref_table_name = $self->reference_table ) { 
            my $ref_table  = $schema->get_table( $ref_table_name ) or
                return $self->error("Can't find table '$ref_table_name'");

            if ( my $constraint = $ref_table->primary_key ) { 
                $self->{'reference_fields'} = [ $constraint->fields ];
            }
            else {
                $self->error(
                 'No reference fields defined and cannot find primary key in ',
                 "reference table '$ref_table_name'"
                );
            }
        }
        # No ref table so we are not that sort of constraint, hence no ref
        # fields. So we let the return below return an empty list.
    }

    if ( ref $self->{'reference_fields'} ) {
        return wantarray 
            ?  @{ $self->{'reference_fields'} } 
            :     $self->{'reference_fields'};
    }
    else {
        return wantarray ? () : [];
    }
}

# ----------------------------------------------------------------------
sub reference_table {

#line 472

    my $self = shift;
    $self->{'reference_table'} = shift if @_;
    return $self->{'reference_table'} || '';
}

# ----------------------------------------------------------------------
sub table {

#line 490

    my $self = shift;
    if ( my $arg = shift ) {
        return $self->error('Not a table object') unless
            UNIVERSAL::isa( $arg, 'SQL::Translator::Schema::Table' );
        $self->{'table'} = $arg;
    }

    return $self->{'table'};
}

# ----------------------------------------------------------------------
sub type {

#line 513

    my $self = shift;

    if ( my $type = uc shift ) {
        $type =~ s/_/ /g;
        return $self->error("Invalid constraint type: $type") 
            unless $VALID_CONSTRAINT_TYPE{ $type };
        $self->{'type'} = $type;
    }

    return $self->{'type'} || '';
}
# ----------------------------------------------------------------------
sub DESTROY {
    my $self = shift;
    undef $self->{'table'}; # destroy cyclical reference
}

1;

# ----------------------------------------------------------------------

#line 542

#line 1 "inc/SQL/Translator/Schema/Field.pm - /Library/Perl/5.8.6/SQL/Translator/Schema/Field.pm"
package SQL::Translator::Schema::Field;

# ----------------------------------------------------------------------
# $Id: Field.pm,v 1.22 2004/11/05 15:03:10 grommit Exp $
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

#line 44

use strict;
use SQL::Translator::Schema::Constants;
use SQL::Translator::Utils 'parse_list_arg';

use base 'SQL::Translator::Schema::Object';

use vars qw($VERSION $TABLE_COUNT $VIEW_COUNT);

$VERSION = sprintf "%d.%02d", q$Revision: 1.22 $ =~ /(\d+)\.(\d+)/;

# Stringify to our name, being careful not to pass any args through so we don't
# accidentally set it to undef. We also have to tweak bool so the object is
# still true when it doesn't have a name (which shouldn't happen!).
use overload
    '""'     => sub { shift->name },
    'bool'   => sub { $_[0]->name || $_[0] },
    fallback => 1,
;

# ----------------------------------------------------------------------

__PACKAGE__->_attributes( qw/
    table name data_type size is_primary_key is_nullable
    is_auto_increment default_value comments is_foreign_key
    is_unique order
/);

#line 84

# ----------------------------------------------------------------------
sub comments {

#line 102

    my $self = shift;

    for my $arg ( @_ ) {
        $arg = $arg->[0] if ref $arg;
        push @{ $self->{'comments'} }, $arg if $arg;
    }

    if ( @{ $self->{'comments'} || [] } ) {
        return wantarray 
            ? @{ $self->{'comments'} || [] }
            : join( "\n", @{ $self->{'comments'} || [] } );
    }
    else {
        return wantarray ? () : '';
    }
}


# ----------------------------------------------------------------------
sub data_type {

#line 133

    my $self = shift;
    $self->{'data_type'} = shift if @_;
    return $self->{'data_type'} || '';
}

# ----------------------------------------------------------------------
sub default_value {

#line 153

    my ( $self, $arg ) = @_;
    $self->{'default_value'} = $arg if defined $arg;
    return $self->{'default_value'};
}

# ----------------------------------------------------------------------
#line 171


# ----------------------------------------------------------------------
sub foreign_key_reference {

#line 185

    my $self = shift;

    if ( my $arg = shift ) {
        my $class = 'SQL::Translator::Schema::Constraint';
        if ( UNIVERSAL::isa( $arg, $class ) ) {
            return $self->error(
                'Foreign key reference for ', $self->name, 'already defined'
            ) if $self->{'foreign_key_reference'};

            $self->{'foreign_key_reference'} = $arg;
        }
        else {
            return $self->error(
                "Argument to foreign_key_reference is not an $class object"
            );
        }
    }

    return $self->{'foreign_key_reference'};
}

# ----------------------------------------------------------------------
sub is_auto_increment {

#line 219

    my ( $self, $arg ) = @_;

    if ( defined $arg ) {
        $self->{'is_auto_increment'} = $arg ? 1 : 0;
    }

    unless ( defined $self->{'is_auto_increment'} ) {
        if ( my $table = $self->table ) {
            if ( my $schema = $table->schema ) {
                if ( 
                    $schema->database eq 'PostgreSQL' &&
                    $self->data_type eq 'serial'
                ) {
                    $self->{'is_auto_increment'} = 1;
                }
            }
        }
    }

    return $self->{'is_auto_increment'} || 0;
}

# ----------------------------------------------------------------------
sub is_foreign_key {

#line 254

    my ( $self, $arg ) = @_;

    unless ( defined $self->{'is_foreign_key'} ) {
        if ( my $table = $self->table ) {
            for my $c ( $table->get_constraints ) {
                if ( $c->type eq FOREIGN_KEY ) {
                    my %fields = map { $_, 1 } $c->fields;
                    if ( $fields{ $self->name } ) {
                        $self->{'is_foreign_key'} = 1;
                        $self->foreign_key_reference( $c );
                        last;
                    }
                }
            }
        }
    }

    return $self->{'is_foreign_key'} || 0;
}

# ----------------------------------------------------------------------
sub is_nullable {

#line 296

    my ( $self, $arg ) = @_;

    if ( defined $arg ) {
        $self->{'is_nullable'} = $arg ? 1 : 0;
    }

    if ( 
        defined $self->{'is_nullable'} && 
        $self->{'is_nullable'} == 1    &&
        $self->is_primary_key
    ) {
        $self->{'is_nullable'} = 0;
    }

    return defined $self->{'is_nullable'} ? $self->{'is_nullable'} : 1;
}

# ----------------------------------------------------------------------
sub is_primary_key {

#line 327

    my ( $self, $arg ) = @_;

    if ( defined $arg ) {
        $self->{'is_primary_key'} = $arg ? 1 : 0;
    }

    unless ( defined $self->{'is_primary_key'} ) {
        if ( my $table = $self->table ) {
            if ( my $pk = $table->primary_key ) {
                my %fields = map { $_, 1 } $pk->fields;
                $self->{'is_primary_key'} = $fields{ $self->name } || 0;
            }
            else {
                $self->{'is_primary_key'} = 0;
            }
        }
    }

    return $self->{'is_primary_key'} || 0;
}

# ----------------------------------------------------------------------
sub is_unique {

#line 361

    my $self = shift;
    
    unless ( defined $self->{'is_unique'} ) {
        if ( my $table = $self->table ) {
            for my $c ( $table->get_constraints ) {
                if ( $c->type eq UNIQUE ) {
                    my %fields = map { $_, 1 } $c->fields;
                    if ( $fields{ $self->name } ) {
                        $self->{'is_unique'} = 1;
                        last;
                    }
                }
            }
        }
    }

    return $self->{'is_unique'} || 0;
}

# ----------------------------------------------------------------------
sub is_valid {

#line 393

    my $self = shift;
    return $self->error('No name')         unless $self->name;
    return $self->error('No data type')    unless $self->data_type;
    return $self->error('No table object') unless $self->table;
    return 1;
}

# ----------------------------------------------------------------------
sub name {

#line 419

    my $self = shift;

    if ( @_ ) {
        my $arg = shift || return $self->error( "No field name" );
        if ( my $table = $self->table ) {
            return $self->error( qq[Can't use field name "$arg": field exists] )
                if $table->get_field( $arg );
        }

        $self->{'name'} = $arg;
    }

    return $self->{'name'} || '';
}

sub full_name {

#line 443

    my $self = shift;
    return $self->table.".".$self->name;
}

# ----------------------------------------------------------------------
sub order {

#line 460

    my ( $self, $arg ) = @_;

    if ( defined $arg && $arg =~ /^\d+$/ ) {
        $self->{'order'} = $arg;
    }

    return $self->{'order'} || 0;
}

# ----------------------------------------------------------------------
sub schema {

#line 481

    my $self = shift;
    if ( my $table = $self->table ) { return $table->schema || undef; }
    return undef;
}

# ----------------------------------------------------------------------
sub size {

#line 506

    my $self    = shift;
    my $numbers = parse_list_arg( @_ );

    if ( @$numbers ) {
        my @new;
        for my $num ( @$numbers ) {
            if ( defined $num && $num =~ m/^\d+(?:\.\d+)?$/ ) {
                push @new, $num;
            }
        }
        $self->{'size'} = \@new if @new; # only set if all OK
    }

    return wantarray 
        ? @{ $self->{'size'} || [0] }
        : join( ',', @{ $self->{'size'} || [0] } )
    ;
}

# ----------------------------------------------------------------------
sub table {

#line 540

    my $self = shift;
    if ( my $arg = shift ) {
        return $self->error('Not a table object') unless
            UNIVERSAL::isa( $arg, 'SQL::Translator::Schema::Table' );
        $self->{'table'} = $arg;
    }

    return $self->{'table'};
}

# ----------------------------------------------------------------------
sub DESTROY {
#
# Destroy cyclical references.
#
    my $self = shift;
    undef $self->{'table'};
    undef $self->{'foreign_key_reference'};
}

1;

# ----------------------------------------------------------------------

#line 572

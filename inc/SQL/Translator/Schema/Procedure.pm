#line 1 "inc/SQL/Translator/Schema/Procedure.pm - /Library/Perl/5.8.6/SQL/Translator/Schema/Procedure.pm"
package SQL::Translator::Schema::Procedure;

# ----------------------------------------------------------------------
# $Id: Procedure.pm,v 1.4 2004/11/05 13:19:31 grommit Exp $
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

#line 49

use strict;
use SQL::Translator::Utils 'parse_list_arg';

use base 'SQL::Translator::Schema::Object';

use vars qw($VERSION);

$VERSION = sprintf "%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/;

# ----------------------------------------------------------------------

__PACKAGE__->_attributes( qw/
    name sql parameters comments owner sql schema order
/);

#line 74

# ----------------------------------------------------------------------
sub parameters {

#line 93

    my $self   = shift;
    my $parameters = parse_list_arg( @_ );

    if ( @$parameters ) {
        my ( %unique, @unique );
        for my $p ( @$parameters ) {
            next if $unique{ $p };
            $unique{ $p } = 1;
            push @unique, $p;
        }

        $self->{'parameters'} = \@unique;
    }

    return wantarray ? @{ $self->{'parameters'} || [] } : $self->{'parameters'};
}

# ----------------------------------------------------------------------
sub name {

#line 124

    my $self        = shift;
    $self->{'name'} = shift if @_;
    return $self->{'name'} || '';
}

# ----------------------------------------------------------------------
sub sql {

#line 143

    my $self       = shift;
    $self->{'sql'} = shift if @_;
    return $self->{'sql'} || '';
}

# ----------------------------------------------------------------------
sub order {

#line 162

    my $self         = shift;
    $self->{'order'} = shift if @_;
    return $self->{'order'};
}

# ----------------------------------------------------------------------
sub owner {

#line 181

    my $self         = shift;
    $self->{'owner'} = shift if @_;
    return $self->{'owner'} || '';
}

# ----------------------------------------------------------------------
sub comments {

#line 201

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
sub schema {

#line 232

    my $self = shift;
    if ( my $arg = shift ) {
        return $self->error('Not a schema object') unless
            UNIVERSAL::isa( $arg, 'SQL::Translator::Schema' );
        $self->{'schema'} = $arg;
    }

    return $self->{'schema'};
}

# ----------------------------------------------------------------------
sub DESTROY {
    my $self = shift;
    undef $self->{'schema'}; # destroy cyclical reference
}

1;

# ----------------------------------------------------------------------

#line 261

#line 1 "inc/SQL/Translator/Schema/Trigger.pm - /Library/Perl/5.8.6/SQL/Translator/Schema/Trigger.pm"
package SQL::Translator::Schema::Trigger;

# ----------------------------------------------------------------------
# $Id: Trigger.pm,v 1.5 2004/11/05 13:19:31 grommit Exp $
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

use vars qw($VERSION $TABLE_COUNT $VIEW_COUNT);

$VERSION = sprintf "%d.%02d", q$Revision: 1.5 $ =~ /(\d+)\.(\d+)/;

# ----------------------------------------------------------------------

__PACKAGE__->_attributes( qw/
    name perform_action_when database_event fields on_table action schema
    order
/);

#line 75

# ----------------------------------------------------------------------
sub perform_action_when {

#line 89

    my $self = shift;
    
    if ( my $arg = shift ) {
        $arg =  lc $arg;
        $arg =~ s/\s+/ /g;
        if ( $arg =~ m/^(before|after)$/i ) {
            $self->{'perform_action_when'} = $arg;
        }
        else {
            return 
                $self->error("Invalid argument '$arg' to perform_action_when");
        }
    }

    return $self->{'perform_action_when'};
}

# ----------------------------------------------------------------------
sub database_event {

#line 119

    my $self = shift;

    if ( my $arg = shift ) {
        $arg =  lc $arg;
        $arg =~ s/\s+/ /g;
        if ( $arg =~ /^(insert|update|update_on|delete)$/ ) {
            $self->{'database_event'} = $arg;
        }
        else {
            return 
                $self->error("Invalid argument '$arg' to database_event");
        }
    }

    return $self->{'database_event'};
}

# ----------------------------------------------------------------------
sub fields {

#line 155

    my $self = shift;
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

    return wantarray ? @{ $self->{'fields'} || [] } : $self->{'fields'};
}

# ----------------------------------------------------------------------
sub on_table {

#line 185

    my $self = shift;
    my $arg  = shift || '';
    $self->{'on_table'} = $arg if $arg;
    return $self->{'on_table'};
}

# ----------------------------------------------------------------------
sub action {

#line 211

    my $self = shift;
    my $arg  = shift || '';
    $self->{'action'} = $arg if $arg;
    return $self->{'action'};
}

# ----------------------------------------------------------------------
sub is_valid {

#line 230

    my $self = shift;

    for my $attr ( 
        qw[ name perform_action_when database_event on_table action ] 
    ) {
        return $self->error("No $attr") unless $self->$attr();
    }
    
    return $self->error("Missing fields for UPDATE ON") if 
        $self->database_event eq 'update_on' && !$self->fields;

    return 1;
}

# ----------------------------------------------------------------------
sub name {

#line 257

    my $self        = shift;
    $self->{'name'} = shift if @_;
    return $self->{'name'} || '';
}

# ----------------------------------------------------------------------
sub order {

#line 275

    my ( $self, $arg ) = @_;

    if ( defined $arg && $arg =~ /^\d+$/ ) {
        $self->{'order'} = $arg;
    }

    return $self->{'order'} || 0;
}

# ----------------------------------------------------------------------
sub schema {

#line 298

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

#line 326

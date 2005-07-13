#line 1 "inc/SQL/Translator/Schema/Object.pm - /Library/Perl/5.8.6/SQL/Translator/Schema/Object.pm"
package SQL::Translator::Schema::Object;

# ----------------------------------------------------------------------
# $Id: Object.pm,v 1.4 2005/01/13 09:44:15 grommit Exp $
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

#line 37

use strict;
use Class::Base;
use base 'Class::Data::Inheritable';
use base 'Class::Base';

use vars qw[ $VERSION ];

$VERSION = sprintf "%d.%02d", q$Revision: 1.4 $ =~ /(\d+)\.(\d+)/;


#line 83


__PACKAGE__->mk_classdata("__attributes");

# Define any global attributes here
__PACKAGE__->__attributes([qw/extra/]); 

# Set the classes attribute names. Multiple calls are cumulative.
# We need to be careful to create a new ref so that all classes don't end up
# with the same ref and hence the same attributes!
sub _attributes {
    my $class = shift;
    if (@_) { $class->__attributes( [ @{$class->__attributes}, @_ ] ); }
    return @{$class->__attributes};
}

# Call accessors for any args in hashref passed
sub init {
    my ( $self, $config ) = @_;
    
    for my $arg ( $self->_attributes ) {
        next unless defined $config->{$arg};
        defined $self->$arg( $config->{$arg} ) or return; 
    }

    return $self;
}

# ----------------------------------------------------------------------
sub extra {

#line 137

    my $self = shift;
    @_ = %{$_[0]} if ref $_[0] eq "HASH";
    my $extra = $self->{'extra'} ||= {};

    if (@_==1) { 
        return exists($extra->{$_[0]}) ? $extra->{$_[0]} : undef ;
    }
    elsif (@_) {
        my %args = @_;
        while ( my ( $key, $value ) = each %args ) {
            $extra->{$key} = $value;
        }
    }
    
    return wantarray ? %$extra : $extra;
}

#=============================================================================

1;

#line 172

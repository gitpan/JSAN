#line 1 "inc/SQL/Translator/Utils.pm - /Library/Perl/5.8.6/SQL/Translator/Utils.pm"
package SQL::Translator::Utils;

# ----------------------------------------------------------------------
# $Id: Utils.pm,v 1.12 2004/02/09 23:04:26 kycl4rk Exp $
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

use strict;
use base qw(Exporter);
use vars qw($VERSION $DEFAULT_COMMENT @EXPORT_OK);

use Exporter;

$VERSION = sprintf "%d.%02d", q$Revision: 1.12 $ =~ /(\d+)\.(\d+)/;
$DEFAULT_COMMENT = '-- ';
@EXPORT_OK = qw(
    debug normalize_name header_comment parse_list_arg $DEFAULT_COMMENT
);

# ----------------------------------------------------------------------
# debug(@msg)
#
# Will send debugging messages to STDERR, if the caller's $DEBUG global
# is set.
#
# This debug() function has a neat feature: Occurances of the strings
# PKG, LINE, and SUB in each message will be replaced with elements
# from caller():
#
#   debug("PKG: Bad things happened on line LINE!");
#
# Will be warned as:
#
#   [SQL::Translator: Bad things happened on line 643]
#
# If called from Translator.pm, on line 643.
# ----------------------------------------------------------------------
sub debug {
    my ($pkg, $file, $line, $sub) = caller(0);
    {
        no strict qw(refs);
        return unless ${"$pkg\::DEBUG"};
    }

    $sub =~ s/^$pkg\:://;

    while (@_) {
        my $x = shift;
        chomp $x;
        $x =~ s/\bPKG\b/$pkg/g;
        $x =~ s/\bLINE\b/$line/g;
        $x =~ s/\bSUB\b/$sub/g;
        #warn '[' . $x . "]\n";
        print STDERR '[' . $x . "]\n";
    }
}

# ----------------------------------------------------------------------
sub normalize_name {
    my $name = shift or return '';

    # The name can only begin with a-zA-Z_; if there's anything
    # else, prefix with _
    $name =~ s/^([^a-zA-Z_])/_$1/;

    # anything other than a-zA-Z0-9_ in the non-first position
    # needs to be turned into _
    $name =~ tr/[a-zA-Z0-9_]/_/c;

    # All duplicated _ need to be squashed into one.
    $name =~ tr/_/_/s;

    # Trim a trailing _
    $name =~ s/_$//;

    return $name;
}

# ----------------------------------------------------------------------
sub header_comment {
    my $producer = shift || caller;
    my $comment_char = shift;
    my $now = scalar localtime;

    $comment_char = $DEFAULT_COMMENT
        unless defined $comment_char;

    my $header_comment =<<"HEADER_COMMENT";
${comment_char}
${comment_char}Created by $producer
${comment_char}Created on $now
${comment_char}
HEADER_COMMENT

    # Any additional stuff passed in
    for my $additional_comment (@_) {
        $header_comment .= "${comment_char}${additional_comment}\n";
    }

    return $header_comment;
}

# ----------------------------------------------------------------------
# parse_list_arg
#
# Meant to accept a list, an array reference, or a string of 
# comma-separated values.  Retuns an array reference of the 
# arguments.  Modified to also handle a list of references.
# ----------------------------------------------------------------------
sub parse_list_arg {
    my $list = UNIVERSAL::isa( $_[0], 'ARRAY' ) ? shift : [ @_ ];

    #
    # This protects stringification of references.
    #
    if ( @$list && ref $list->[0] ) {
        return $list;
    }
    #
    # This processes string-like arguments.
    #
    else {
        return [ 
            map { s/^\s+|\s+$//g; $_ }
            map { split /,/ }
            grep { defined && length } @$list
        ];
    }
}

1;

# ----------------------------------------------------------------------

#line 264

=cut

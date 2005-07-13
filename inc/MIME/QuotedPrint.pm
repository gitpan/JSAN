#line 1 "inc/MIME/QuotedPrint.pm - /System/Library/Perl/5.8.6/darwin-thread-multi-2level/MIME/QuotedPrint.pm"
package MIME::QuotedPrint;

# $Id: QuotedPrint.pm,v 3.4 2004/08/25 09:33:45 gisle Exp $

use strict;
use vars qw(@ISA @EXPORT $VERSION);

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(encode_qp decode_qp);

$VERSION = "3.03";

use MIME::Base64;  # will load XS version of {en,de}code_qp()

*encode = \&encode_qp;
*decode = \&decode_qp;

1;

__END__

#line 116

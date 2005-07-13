#line 1 "inc/URI/imap.pm - /Library/Perl/5.8.6/URI/imap.pm"
package URI::imap;
# $Id: imap.pm,v 1.1 2004/08/07 19:17:46 cwest Exp $
use strict;

use vars qw[$VERSION];
$VERSION = sprintf "%d.%02d", split m/\./, (qw$Revision: 1.1 $)[1];

use base qw[URI::_server];

sub default_port { 143 }

1;

__END__

#line 39

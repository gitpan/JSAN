#line 1 "inc/URI/imaps.pm - /Library/Perl/5.8.6/URI/imaps.pm"
package URI::imaps;
# $Id: imaps.pm,v 1.1 2004/08/07 19:21:51 cwest Exp $
use strict;

use vars qw[$VERSION];
$VERSION = sprintf "%d.%02d", split m/\./, (qw$Revision: 1.1 $)[1];

use base qw[URI::_server];

sub default_port { 993 }

1;

__END__

#line 39

#line 1 "inc/URI/https.pm - /System/Library/Perl/Extras/5.8.6/URI/https.pm"
package URI::https;
require URI::http;
@ISA=qw(URI::http);

sub default_port { 443 }

1;

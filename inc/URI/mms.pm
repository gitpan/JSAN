#line 1 "inc/URI/mms.pm - /System/Library/Perl/Extras/5.8.6/URI/mms.pm"
package URI::mms;

require URI::http;
@ISA=qw(URI::http);

sub default_port { 1755 }

1;

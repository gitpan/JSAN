#line 1 "inc/URI/rtsp.pm - /System/Library/Perl/Extras/5.8.6/URI/rtsp.pm"
package URI::rtsp;

require URI::http;
@ISA=qw(URI::http);

sub default_port { 554 }

1;

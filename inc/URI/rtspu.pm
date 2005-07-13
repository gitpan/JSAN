#line 1 "inc/URI/rtspu.pm - /System/Library/Perl/Extras/5.8.6/URI/rtspu.pm"
package URI::rtspu;

require URI::rtsp;
@ISA=qw(URI::rtsp);

sub default_port { 554 }

1;

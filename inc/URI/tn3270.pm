#line 1 "inc/URI/tn3270.pm - /System/Library/Perl/Extras/5.8.6/URI/tn3270.pm"
package URI::tn3270;
require URI::_login;
@ISA = qw(URI::_login);

sub default_port { 23 }

1;

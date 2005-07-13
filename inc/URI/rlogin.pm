#line 1 "inc/URI/rlogin.pm - /System/Library/Perl/Extras/5.8.6/URI/rlogin.pm"
package URI::rlogin;
require URI::_login;
@ISA = qw(URI::_login);

sub default_port { 513 }

1;

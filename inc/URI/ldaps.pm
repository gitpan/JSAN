#line 1 "inc/URI/ldaps.pm - /System/Library/Perl/Extras/5.8.6/URI/ldaps.pm"
package URI::ldaps;
require URI::ldap;
@ISA=qw(URI::ldap);

sub default_port { 636 }

1;

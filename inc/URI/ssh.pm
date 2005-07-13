#line 1 "inc/URI/ssh.pm - /System/Library/Perl/Extras/5.8.6/URI/ssh.pm"
package URI::ssh;
require URI::_login;
@ISA=qw(URI::_login);

# ssh://[USER@]HOST[:PORT]/SRC

sub default_port { 22 }

1;

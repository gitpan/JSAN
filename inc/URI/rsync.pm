#line 1 "inc/URI/rsync.pm - /System/Library/Perl/Extras/5.8.6/URI/rsync.pm"
package URI::rsync;  # http://rsync.samba.org/

# rsync://[USER@]HOST[:PORT]/SRC

require URI::_server;
require URI::_userpass;

@ISA=qw(URI::_server URI::_userpass);

sub default_port { 873 }

1;

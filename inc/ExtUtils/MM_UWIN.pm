#line 1 "inc/ExtUtils/MM_UWIN.pm - /System/Library/Perl/5.8.6/ExtUtils/MM_UWIN.pm"
package ExtUtils::MM_UWIN;

use strict;
use vars qw($VERSION @ISA);
$VERSION = 0.02;

require ExtUtils::MM_Unix;
@ISA = qw(ExtUtils::MM_Unix);


#line 36

sub os_flavor {
    return('Unix', 'U/WIN');
}


#line 45

sub replace_manpage_separator {
    my($self, $man) = @_;

    $man =~ s,/+,.,g;
    return $man;
}

#line 64

1;

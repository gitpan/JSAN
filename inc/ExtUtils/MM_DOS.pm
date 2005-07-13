#line 1 "inc/ExtUtils/MM_DOS.pm - /System/Library/Perl/5.8.6/ExtUtils/MM_DOS.pm"
package ExtUtils::MM_DOS;

use strict;
use vars qw($VERSION @ISA);

$VERSION = 0.02;

require ExtUtils::MM_Any;
require ExtUtils::MM_Unix;
@ISA = qw( ExtUtils::MM_Any ExtUtils::MM_Unix );


#line 36

sub os_flavor {
    return('DOS');
}

#line 46

sub replace_manpage_separator {
    my($self, $man) = @_;

    $man =~ s,/+,__,g;
    return $man;
}

#line 65

1;

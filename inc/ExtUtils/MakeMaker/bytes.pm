#line 1 "inc/ExtUtils/MakeMaker/bytes.pm - /System/Library/Perl/5.8.6/ExtUtils/MakeMaker/bytes.pm"
package ExtUtils::MakeMaker::bytes;

use vars qw($VERSION);
$VERSION = 0.01;

my $Have_Bytes = eval q{require bytes; 1;};

sub import {
    return unless $Have_Bytes;

    shift;
    unshift @_, 'bytes';

    goto &bytes::import;
}

1;


#line 40

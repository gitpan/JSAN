#line 1 "inc/Class/DBI/Loader.pm - /Library/Perl/5.8.6/Class/DBI/Loader.pm"
package Class::DBI::Loader;

use strict;
use vars '$VERSION';

$VERSION = '0.22';

#line 71

sub new {
    my ( $class, %args ) = @_;
    my $dsn = $args{dsn};
    my ($driver) = $dsn =~ m/^dbi:(\w*?)(?:\((.*?)\))?:/i;
    $driver = 'SQLite' if $driver eq 'SQLite2';
    my $impl = "Class::DBI::Loader::" . $driver;
    eval qq/use $impl/;
    die qq/Couldn't require loader class "$impl", "$@"/ if $@;
    return $impl->new(%args);
}

#line 108

1;

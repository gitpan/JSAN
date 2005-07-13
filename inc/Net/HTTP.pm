#line 1 "inc/Net/HTTP.pm - /Library/Perl/5.8.6/Net/HTTP.pm"
package Net::HTTP;

# $Id: HTTP.pm,v 1.45 2004/05/21 08:56:16 gisle Exp $

use strict;
use vars qw($VERSION @ISA);

$VERSION = "1.00";
eval { require IO::Socket::INET } || require IO::Socket;
require Net::HTTP::Methods;

@ISA=qw(IO::Socket::INET Net::HTTP::Methods);

sub configure {
    my($self, $cnf) = @_;
    $self->http_configure($cnf);
}

sub http_connect {
    my($self, $cnf) = @_;
    $self->SUPER::configure($cnf);
}

1;

__END__

#line 267

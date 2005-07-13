#line 1 "inc/URI/urn/oid.pm - /System/Library/Perl/Extras/5.8.6/URI/urn/oid.pm"
package URI::urn::oid;  # RFC 2061

require URI::urn;
@ISA=qw(URI::urn);

use strict;

sub oid {
    my $self = shift;
    my $old = $self->nss;
    if (@_) {
	$self->nss(join(".", @_));
    }
    return split(/\./, $old) if wantarray;
    return $old;
}

1;

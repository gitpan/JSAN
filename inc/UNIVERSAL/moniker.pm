#line 1 "inc/UNIVERSAL/moniker.pm - /Library/Perl/5.8.6/UNIVERSAL/moniker.pm"
package UNIVERSAL::moniker;
$UNIVERSAL::moniker::VERSION = '0.08';

#line 40

package UNIVERSAL;

sub moniker {
    (ref( $_[0] ) || $_[0]) =~ /([^:]+)$/;
    return lc $1;
}

sub plural_moniker {
    CORE::require Lingua::EN::Inflect;
	return Lingua::EN::Inflect::PL($_[0]->moniker);
}

#line 73


1;

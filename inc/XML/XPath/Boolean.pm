#line 1 "inc/XML/XPath/Boolean.pm - /Library/Perl/5.8.6/XML/XPath/Boolean.pm"
# $Id: Boolean.pm,v 1.7 2000/07/03 08:54:47 matt Exp $

package XML::XPath::Boolean;
use XML::XPath::Number;
use XML::XPath::Literal;
use strict;

use overload
		'""' => \&value,
		'<=>' => \&cmp;

sub True {
	my $class = shift;
	my $val = 1;
	bless \$val, $class;
}

sub False {
	my $class = shift;
	my $val = 0;
	bless \$val, $class;
}

sub value {
	my $self = shift;
	$$self;
}

sub cmp {
	my $self = shift;
	my ($other, $swap) = @_;
	if ($swap) {
		return $other <=> $$self;
	}
	return $$self <=> $other;
}

sub to_number { XML::XPath::Number->new($_[0]->value); }
sub to_boolean { $_[0]; }
sub to_literal { XML::XPath::Literal->new($_[0]->value ? "true" : "false"); }

sub string_value { return $_[0]->to_literal->value; }

1;
__END__

#line 74

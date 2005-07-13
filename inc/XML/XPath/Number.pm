#line 1 "inc/XML/XPath/Number.pm - /Library/Perl/5.8.6/XML/XPath/Number.pm"
# $Id: Number.pm,v 1.14 2002/12/26 17:57:09 matt Exp $

package XML::XPath::Number;
use XML::XPath::Boolean;
use XML::XPath::Literal;
use strict;

use overload
        '""' => \&value,
        '0+' => \&value,
        '<=>' => \&cmp;

sub new {
    my $class = shift;
    my $number = shift;
    if ($number !~ /^\s*[+-]?(\d+(\.\d*)?|\.\d+)\s*$/) {
        $number = undef;
    }
    else {
        $number =~ s/^\s*(.*)\s*$/$1/;
    }
    bless \$number, $class;
}

sub as_string {
    my $self = shift;
    defined $$self ? $$self : 'NaN';
}

sub as_xml {
    my $self = shift;
    return "<Number>" . (defined($$self) ? $$self : 'NaN') . "</Number>\n";
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

sub evaluate {
    my $self = shift;
    $self;
}

sub to_boolean {
    my $self = shift;
    return $$self ? XML::XPath::Boolean->True : XML::XPath::Boolean->False;
}

sub to_literal { XML::XPath::Literal->new($_[0]->as_string); }
sub to_number { $_[0]; }

sub string_value { return $_[0]->value }

1;
__END__

#line 88

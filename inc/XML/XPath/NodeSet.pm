#line 1 "inc/XML/XPath/NodeSet.pm - /Library/Perl/5.8.6/XML/XPath/NodeSet.pm"
# $Id: NodeSet.pm,v 1.17 2002/04/24 13:06:08 matt Exp $

package XML::XPath::NodeSet;
use strict;

use XML::XPath::Boolean;

use overload 
		'""' => \&to_literal,
                'bool' => \&to_boolean,
        ;

sub new {
	my $class = shift;
	bless [], $class;
}

sub sort {
    my $self = CORE::shift;
    @$self = CORE::sort { $a->get_global_pos <=> $b->get_global_pos } @$self;
    return $self;
}

sub pop {
	my $self = CORE::shift;
	CORE::pop @$self;
}

sub push {
	my $self = CORE::shift;
	my (@nodes) = @_;
	CORE::push @$self, @nodes;
}

sub append {
	my $self = CORE::shift;
	my ($nodeset) = @_;
	CORE::push @$self, $nodeset->get_nodelist;
}

sub shift {
	my $self = CORE::shift;
	CORE::shift @$self;
}

sub unshift {
	my $self = CORE::shift;
	my (@nodes) = @_;
	CORE::unshift @$self, @nodes;
}

sub prepend {
	my $self = CORE::shift;
	my ($nodeset) = @_;
	CORE::unshift @$self, $nodeset->get_nodelist;
}

sub size {
	my $self = CORE::shift;
	scalar @$self;
}

sub get_node { # uses array index starting at 1, not 0
	my $self = CORE::shift;
	my ($pos) = @_;
	$self->[$pos - 1];
}

sub getRootNode {
    my $self = CORE::shift;
    return $self->[0]->getRootNode;
}

sub get_nodelist {
	my $self = CORE::shift;
	@$self;
}

sub to_boolean {
	my $self = CORE::shift;
	return (@$self > 0) ? XML::XPath::Boolean->True : XML::XPath::Boolean->False;
}

sub string_value {
	my $self = CORE::shift;
	return '' unless @$self;
	return $self->[0]->string_value;
}

sub to_literal {
	my $self = CORE::shift;
	return XML::XPath::Literal->new(
			join('', map { $_->string_value } @$self)
			);
}

sub to_number {
	my $self = CORE::shift;
	return XML::XPath::Number->new(
			$self->to_literal
			);
}

1;
__END__

#line 185

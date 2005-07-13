#line 1 "inc/XML/XPath/Node/Namespace.pm - /Library/Perl/5.8.6/XML/XPath/Node/Namespace.pm"
# $Id: Namespace.pm,v 1.4 2000/08/24 16:23:02 matt Exp $

package XML::XPath::Node::Namespace;

use strict;
use vars qw/@ISA/;

@ISA = ('XML::XPath::Node');

package XML::XPath::Node::NamespaceImpl;

use vars qw/@ISA/;
@ISA = ('XML::XPath::NodeImpl', 'XML::XPath::Node::Namespace');
use XML::XPath::Node ':node_keys';

sub new {
	my $class = shift;
	my ($prefix, $expanded) = @_;
	
        my $pos = XML::XPath::Node->nextPos;
        
        my @vals;
        @vals[node_global_pos, node_prefix, node_expanded] =
                ($pos, $prefix, $expanded);
	my $self = \@vals;
        
	bless $self, $class;
}

sub getNodeType { NAMESPACE_NODE }

sub isNamespaceNode { 1; }

sub getPrefix {
	my $self = shift;
	$self->[node_prefix];
}

sub getExpanded {
	my $self = shift;
	$self->[node_expanded];
}

sub getValue {
	my $self = shift;
	$self->[node_expanded];
}

sub getData {
	my $self = shift;
	$self->[node_expanded];
}

sub string_value {
	my $self = shift;
	$self->[node_expanded];
}

sub toString {
	my $self = shift;
	my $string = '';
	return '' unless defined $self->[node_expanded];
	if ($self->[node_prefix] eq '#default') {
		$string .= ' xmlns="';
	}
	else {
		$string .= ' xmlns:' . $self->[node_prefix] . '="';
	}
	$string .= XML::XPath::Node::XMLescape($self->[node_expanded], '"&<');
	$string .= '"';
}

1;
__END__

#line 100

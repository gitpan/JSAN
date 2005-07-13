#line 1 "inc/XML/XPath/Node/Text.pm - /Library/Perl/5.8.6/XML/XPath/Node/Text.pm"
# $Id: Text.pm,v 1.5 2000/09/05 13:05:47 matt Exp $

package XML::XPath::Node::Text;

use strict;
use vars qw/@ISA/;

@ISA = ('XML::XPath::Node');

package XML::XPath::Node::TextImpl;

use vars qw/@ISA/;
@ISA = ('XML::XPath::NodeImpl', 'XML::XPath::Node::Text');
use XML::XPath::Node ':node_keys';

sub new {
    my $class = shift;
    my ($text) = @_;
    
        my $pos = XML::XPath::Node->nextPos;
        
        my @vals;
        @vals[node_global_pos, node_text] = ($pos, $text);
    my $self = \@vals;
        
    bless $self, $class;
}

sub getNodeType { TEXT_NODE }

sub isTextNode { 1; }

sub appendText {
    my $self = shift;
    my ($text) = @_;
    $self->[node_text] .= $text;
}

sub getNodeValue {
    my $self = shift;
    $self->[node_text];
}

sub getData {
    my $self = shift;
    $self->[node_text];
}

sub setNodeValue {
    my $self = shift;
    $self->[node_text] = shift;
}

sub _to_sax {
    my $self = shift;
    my ($doch, $dtdh, $enth) = @_;
    
    $doch->characters( { Data => $self->getValue } );
}

sub string_value {
    my $self = shift;
    $self->[node_text];
}

sub toString {
    my $self = shift;
    XML::XPath::Node::XMLescape($self->[node_text], "<&");
}

1;
__END__

#line 97

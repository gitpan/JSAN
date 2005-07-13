#line 1 "inc/XML/XPath.pm - /Library/Perl/5.8.6/XML/XPath.pm"
# $Id: XPath.pm,v 1.56 2003/01/26 19:33:17 matt Exp $

package XML::XPath;

use strict;
use vars qw($VERSION $AUTOLOAD $revision);

$VERSION = '1.13';

$XML::XPath::Namespaces = 1;
$XML::XPath::Debug = 0;

use XML::XPath::XMLParser;
use XML::XPath::Parser;
use IO::File;

# For testing
#use Data::Dumper;
#$Data::Dumper::Indent = 1;

# Parameters for new()
my @options = qw(
        filename
        parser
        xml
        ioref
        context
        );

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;

    my(%args);
    # Try to figure out what the user passed
    if ($#_ == 0) { # passed a scalar
        my $string = $_[0];
        if ($string =~ m{<.*?>}s) { # it's an XML string
            $args{'xml'} = $string;
        } elsif (ref($string)) {    # read XML from file handle
            $args{'ioref'} = $string;
        } elsif ($string eq '-') {  # read XML from stdin
            $args{'ioref'} = IO::File->new($string);
        } else {                    # read XML from a file
            $args{'filename'} = $string;
        }
    } else {        # passed a hash or hash reference
        # just pass the parameters on to the XPath constructor
        %args = ((ref($_[0]) eq "HASH") ? %{$_[0]} : @_);
    }

    if ($args{filename} && (!-e $args{filename} || !-r $args{filename})) {
        die "Cannot open file '$args{filename}'";
    }
    my %hash = map(( "_$_" => $args{$_} ), @options);
    $hash{path_parser} = XML::XPath::Parser->new();
    return bless \%hash, $class;
}

sub find {
    my $self = shift;
    my $path = shift;
    my $context = shift;
    die "No path to find" unless $path;
    
    if (!defined $context) {
        $context = $self->get_context;
    }
    if (!defined $context) {
        # Still no context? Need to parse...
        my $parser = XML::XPath::XMLParser->new(
                filename => $self->get_filename,
                xml => $self->get_xml,
                ioref => $self->get_ioref,
                parser => $self->get_parser,
                );
        $context = $parser->parse;
        $self->set_context($context);
#        warn "CONTEXT:\n", Data::Dumper->Dumpxs([$context], ['context']);
    }
    
    my $parsed_path = $self->{path_parser}->parse($path);
#    warn "\n\nPATH: ", $parsed_path->as_string, "\n\n";
    
#    warn "evaluating path\n";
    return $parsed_path->evaluate($context);
}

# sub memsize {
#     print STDERR @_, "\t";
#     open(FH, '/proc/self/status');
#     while(<FH>) {
#         print STDERR $_ if /^VmSize/;
#     }
#     close FH;
# }
# 
sub findnodes {
    my $self = shift;
    my ($path, $context) = @_;
    
    my $results = $self->find($path, $context);
    
    if ($results->isa('XML::XPath::NodeSet')) {
        return wantarray ? $results->get_nodelist : $results;
#        return $results->get_nodelist;
    }
    
#    warn("findnodes returned a ", ref($results), " object\n") if $XML::XPath::Debug;
    return wantarray ? () : XML::XPath::NodeSet->new();
}

sub matches {
    my $self = shift;
    my ($node, $path, $context) = @_;

    my @nodes = $self->findnodes($path, $context);

    if (grep { "$node" eq "$_" } @nodes) {
        return 1;
    }
    return;
}

sub findnodes_as_string {
    my $self = shift;
    my ($path, $context) = @_;
    
    my $results = $self->find($path, $context);
    
    if ($results->isa('XML::XPath::NodeSet')) {
        return join('', map { $_->toString } $results->get_nodelist);
    }
    elsif ($results->isa('XML::XPath::Node')) {
        return $results->toString;
    }
    else {
        return XML::XPath::Node::XMLescape($results->value);
    }
}

sub findvalue {
    my $self = shift;
    my ($path, $context) = @_;
    
    my $results = $self->find($path, $context);
    
    if ($results->isa('XML::XPath::NodeSet')) {
        return $results->to_literal;
    }
    
    return $results;
}

sub exists
{
    my $self = shift;
    my ($path, $context) = @_;
    $path = '/' if (!defined $path);
    my @nodeset = $self->findnodes($path, $context);
    return 1 if (scalar( @nodeset ));
    return 0;
}

sub getNodeAsXML {
  my $self = shift;
  my $node_path = shift;
  $node_path = '/' if (!defined $node_path);
  if (ref($node_path)) {
    return $node_path->as_string();
  } else {
    return $self->findnodes_as_string($node_path);
  }
}

sub getNodeText {
  my $self = shift;
  my $node_path = shift;
  if (ref($node_path)) {
    return $node_path->string_value();
  } else {
    return $self->findvalue($node_path);
  }
}

sub setNodeText {
  my $self = shift;
  my($node_path, $new_text) = @_;
  my $nodeset = $self->findnodes($node_path);
  return undef if (!defined $nodeset); # could not find node
  my @nodes = $nodeset->get_nodelist;
  if ($#nodes < 0) {
    if ($node_path =~ m|/@([^/]+)$|) {
      # attribute not found, so try to create it
      my $parent_path = $`;
      my $attr = $1;
      $nodeset = $self->findnodes($parent_path);
      return undef if (!defined $nodeset); # could not find node
      foreach my $node ($nodeset->get_nodelist) {
        my $newnode = XML::XPath::Node::Attribute->new($attr, $new_text);
        return undef if (!defined $newnode); # could not create new node
        $node->appendAttribute($newnode);
      }
    } else {
      return undef; # could not find node
    }
  }
  foreach my $node (@nodes) {
    if ($node->getNodeType == XML::XPath::Node::ATTRIBUTE_NODE) {
      $node->setNodeValue($new_text);
    } else {
      foreach my $delnode ($node->getChildNodes()) {
        $node->removeChild($delnode);
      }
      my $newnode = XML::XPath::Node::Text->new($new_text);
      return undef if (!defined $newnode); # could not create new node
      $node->appendChild($newnode);
    }
  }
  return 1;
}

sub createNode {
  my $self = shift;
  my($node_path) = @_;
  my $path_steps = $self->{path_parser}->parse($node_path);
  my @path_steps = ();
  foreach my $step (@{$path_steps->get_lhs()}) {
    my $string = $step->as_string();
    push(@path_steps, $string) if (defined $string && $string ne "");
  }
  my $prev_node = undef;
  my $nodeset = undef;
  my $nodes = undef;
  my $p = undef;
  my $test_path = "";
  # Start with the deepest node, working up the path (right to left),
  # trying to find a node that exists.
  for ($p = $#path_steps; $p >= 0; $p--) {
    my $path = $path_steps[$p];
    $test_path = "(/" . join("/", @path_steps[0..$p]) . ")";
    $nodeset = $self->findnodes($test_path);
    return undef if (!defined $nodeset); # error looking for node
    $nodes = $nodeset->size;
    return undef if ($nodes > 1); # too many paths - path not specific enough
    if ($nodes == 1) { # found a node -- need to create nodes below it
      $prev_node = $nodeset->get_node(1);
      last;
    }
  }
  if (!defined $prev_node) {
    my @root_nodes = $self->findnodes('/')->get_nodelist();
    $prev_node = $root_nodes[0];
  }
  # We found a node that exists, or we'll start at the root.
  # Create all lower nodes working left to right along the path.
  for ($p++ ; $p <= $#path_steps; $p++) {
    my $path = $path_steps[$p];
    my $newnode = undef;
    my($axis,$name) = ($path =~ /^(.*?)::(.*)$/);
    if ($axis =~ /^child$/i) {
      $newnode = XML::XPath::Node::Element->new($name);
      return undef if (!defined $newnode); # could not create new node
      $prev_node->appendChild($newnode);
    } elsif ($axis =~ /^attribute$/i) {
      $newnode = XML::XPath::Node::Attribute->new($name, "");
      return undef if (!defined $newnode); # could not create new node
      $prev_node->appendAttribute($newnode);
    }
    $prev_node = $newnode;
  }
  return $prev_node;
}

sub get_filename {
    my $self = shift;
    $self->{_filename};
}

sub set_filename {
    my $self = shift;
    $self->{_filename} = shift;
}

sub get_parser {
    my $self = shift;
    $self->{_parser};
}

sub set_parser {
    my $self = shift;
    $self->{_parser} = shift;
}

sub get_xml {
    my $self = shift;
    $self->{_xml};
}

sub set_xml {
    my $self = shift;
    $self->{_xml} = shift;
}

sub get_ioref {
    my $self = shift;
    $self->{_ioref};
}

sub set_ioref {
    my $self = shift;
    $self->{_ioref} = shift;
}

sub get_context {
    my $self = shift;
    $self->{_context};
}

sub set_context {
    my $self = shift;
    $self->{_context} = shift;
}

sub cleanup {
    my $self = shift;
    if ($XML::XPath::SafeMode) {
        my $context = $self->get_context;
        return unless $context;
        $context->dispose;
    }
}

sub set_namespace {
    my $self = shift;
    my ($prefix, $expanded) = @_;
    $self->{path_parser}->set_namespace($prefix, $expanded);
}

sub clear_namespaces {
    my $self = shift;
    $self->{path_parser}->clear_namespaces();
}

1;
__END__

#line 554

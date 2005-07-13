#line 1 "inc/SQL/Translator/Schema/Graph/CompoundEdge.pm - /Library/Perl/5.8.6/SQL/Translator/Schema/Graph/CompoundEdge.pm"
package SQL::Translator::Schema::Graph::CompoundEdge;

use strict;
use base qw(SQL::Translator::Schema::Graph::Edge);
use Class::MakeMethods::Template::Hash (
  new => ['new'],
  object => [
			 'via'  => {class => 'SQL::Translator::Schema::Graph::Node'},
			],
  'array_of_objects -class SQL::Translator::Schema::Graph::Edge' => [ qw( edges ) ],
);

1;
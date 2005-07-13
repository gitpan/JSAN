use Test::More tests => 4;
use strict;
use warnings;
use Data::Dumper;diag Dumper \@INC;

use_ok($_) for qw[JSAN JSAN::Indexer JSAN::Shell JSAN::Indexer::Creator];

#line 1 "inc/URI/snews.pm - /System/Library/Perl/Extras/5.8.6/URI/snews.pm"
package URI::snews;  # draft-gilman-news-url-01

require URI::news;
@ISA=qw(URI::news);

sub default_port { 563 }

1;

#line 1 "inc/Class/MakeMethods/Utility/TextBuilder.pm - /Library/Perl/5.8.6/Class/MakeMethods/Utility/TextBuilder.pm"
package Class::MakeMethods::Utility::TextBuilder;

$VERSION = 1.008;

@EXPORT_OK = qw( text_builder );
sub import { require Exporter and goto &Exporter::import } # lazy Exporter

use strict;
use Carp;

# $expanded_text = text_builder( $base_text, @exprs )
sub text_builder {
  my ( $text, @mod_exprs ) = @_;
  
  my @code_exprs;
  while ( scalar @mod_exprs ) {
    my $mod_expr = shift @mod_exprs;
    if ( ref $mod_expr eq 'HASH' ) {
      push @code_exprs, %$mod_expr;
    } elsif ( ref $mod_expr eq 'ARRAY' ) {
      unshift @mod_exprs, @$mod_expr;
    } elsif ( ref $mod_expr eq 'CODE' ) {
      $text = &$mod_expr( $text );
    } elsif ( ! ref $_ ) {
      $mod_expr =~ s{\*}{$text}g;
      $text = $mod_expr;
    } else {
      Carp::confess "Wierd contents of modifier array.";
    }
  }
  my %rules = @code_exprs;
  
  my @exprs;
  my @blocks;
  foreach ( sort { length($b) <=> length($a) } keys %rules ) {
    if ( s/\{\}\Z// ) {
      push @blocks, $_;
    } else {
      push @exprs, $_;
    }
  }
  push @blocks, 'UNUSED_CONSTANT' if ( ! scalar @blocks );
  push @exprs,  'UNUSED_CONSTANT' if ( ! scalar @exprs );
  
  # There has *got* to be a better way to regex matched brackets... Right?
  # Erm, well, no. It looks like Text::Balanced would do the trick, with the 
  # requirement that the below bit get re-written to not be regex-based.
  my $expr_expr = '\b(' . join('|', map "\Q$_\E", @exprs ) . ')\b';
  my $block_expr = '\b(' . join('|', map "\Q$_\E", @blocks ) . ') \{ 
      ( [^\{\}]* 
	(?: \{ 
	  [^\{\}]* 
	  (?:  \{   [^\{\}]*  \}  [^\{\}]*  )*? 
	\} [^\{\}]* )*?
      )
    \}';
  
  1 while ( 
    length $text and $text =~ s/ $expr_expr /
      my $substitute = $rules{ $1 };
      if ( ! ref $substitute ) { 
	$substitute;
      } elsif ( ref $substitute eq 'CODE' ) {
	&{ $substitute }();
      } else {
	croak "Unknown type of substitution rule: '$substitute'";
      }
    /gesx or $text =~ s/ $block_expr /
      my $substitute = $rules{ $1 . '{}' };
      my $contents = $2;
      if ( ! ref $substitute ) { 
	$substitute =~ s{\*}{$contents}g;
	$substitute;
      } elsif ( ref $substitute eq 'HASH' ) {
	$substitute->{$contents};
      } elsif ( ref $substitute eq 'CODE' ) {
	&{ $substitute }( $contents );
      } else {
	croak "Unknown type of substitution rule: '$substitute'";
      }
    /gesx
  );
  
  return $text;  
}

1;

__END__

#line 208

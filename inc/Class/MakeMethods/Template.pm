#line 1 "inc/Class/MakeMethods/Template.pm - /Library/Perl/5.8.6/Class/MakeMethods/Template.pm"
package Class::MakeMethods::Template;

use strict;
use Carp;

use Class::MakeMethods '-isasubclass';

use vars qw( $VERSION );
$VERSION = 1.008;

sub _diagnostic { &Class::MakeMethods::_diagnostic }

########################################################################
### TEMPLATE LOOKUP AND CACHING: named_method(), _definition()
########################################################################

use vars qw( %TemplateCache );

# @results = $class->named_method( $name, @arguments );
sub named_method {
  my $class = shift;
  my $name = shift;
  
  # Support direct access to cached Template information
  if (exists $TemplateCache{"$class\::$name"}) {
    return $TemplateCache{"$class\::$name"};
  }
  
  my @results = $class->$name( @_ );
  
  if ( scalar @results == 1 and ref $results[0] eq 'HASH' ) {
    # If this is a hash-definition format, cache the results for speed.
    my $def = $results[0];
    $TemplateCache{"$class\::$name"} = $def;
    _expand_definition($class, $name, $def);
    return $def;
  }
  
  return wantarray ? @results : $results[0];
}

# $mm_def = _definition( $class, $target );
sub _definition {
  my ($class, $target) = @_;
  
  while ( ! ref $target ) {
    $target =~ s/\s.*//;
    
    # If method name contains a colon or double colon, call the method on the
    # indicated class.
    my $call_class = ( ( $target =~ s/^(.*)\:{1,2}// ) 
      ? Class::MakeMethods::_find_subclass($class, $1) : $class );
    $target = $call_class->named_method( $target );
  }
  _diagnostic('mmdef_not_interpretable', $target) 
	unless ( ref($target) eq 'HASH' or ref($target) eq __PACKAGE__ );
  
  return $target;
}

########################################################################
### TEMPLATE INTERNALS: _expand_definition()
########################################################################

sub _expand_definition {
  my ($class, $name, $mm_def) = @_;
  
  return $mm_def if $mm_def->{'-parsed'};
  
  $mm_def->{'template_class'} = $class;
  $mm_def->{'template_name'} = $name;
  
  # Allow definitions to import values from each other.
  my $importer;
  foreach $importer ( qw( interface params behavior code_expr modifier ) ) {
    my $rules = $mm_def->{$importer}->{'-import'} || $mm_def->{'-import'};
    my @rules = ( ref $rules eq 'HASH' ? %$rules : ref $rules eq 'ARRAY' ? @$rules : () );
    unshift @rules, '::' . $class . ':generic' => '*' if $class->can('generic');
    while ( 
      my ($source, $names) = splice @rules, 0, 2
    ) {
      my $mmi = _definition($class, $source);
      foreach ( ( $names eq '*' ) ? keys %{ $mmi->{$importer} } 
			: ( ref $names ) ? @{ $names } : ( $names ) ) {
	my $current = $mm_def->{$importer}{$_};
	my $import = $mmi->{$importer}{$_};
	if ( ! $current ) {
	  $mm_def->{$importer}{$_} = $import;
	} elsif ( ref($current) eq 'ARRAY' ) {
	  my @imports = ref($import) ? @$import : $import;
	  foreach my $imp ( @imports ) {
	    push @$current, $imp unless ( grep { $_ eq $imp } @$current );
	  }
	}
      }
    }
    delete $mm_def->{$importer}->{'-import'};
  }
  delete $mm_def->{'-import'};
  
  _describe_definition( $mm_def ) if $Class::MakeMethods::CONTEXT{Debug};

  
  $mm_def->{'-parsed'} = "$_[1]";
  
  bless $mm_def, __PACKAGE__;
}

sub _describe_definition {
  my $mm_def = shift;
  
  my $def_type = "$mm_def->{template_class}:$mm_def->{template_name}";
  warn "----\nMethods info for $def_type:\n";
  if ( $mm_def->{interface} ) {
    warn join '', "Templates: \n", map {
	"  $_: " . _describe_value($mm_def->{interface}{$_}) . "\n"
      } keys %{$mm_def->{interface}};
  }
  if ( $mm_def->{modifier} ) {
    warn join '', "Modifiers: \n", map {
	"  $_: " . _describe_value($mm_def->{modifier}{$_}) . "\n"
      } keys %{$mm_def->{modifier}};
  }
}

sub _describe_value {
  my $value = $_[0];
  ref($value) eq 'ARRAY' ? join(', ', @$value) :
  ref($value) eq 'HASH'  ? join(', ', %$value) : 
				      "$value";
}

########################################################################
### METHOD GENERATION: make_methods()
########################################################################

sub make_methods {
  my $mm_def = shift;
  
  return unless ( scalar @_ );
  
  # Select default interface and initial method parameters
  my $defaults = { %{ ( $mm_def->{'params'} ||= {} ) } };
  $defaults->{'interface'} ||= $mm_def->{'interface'}{'-default'} || 'default';
  $defaults->{'target_class'} = $mm_def->_context('TargetClass');
  $defaults->{'template_class'} = $mm_def->{'template_class'};
  $defaults->{'template_name'} = $mm_def->{'template_name'};
  
  my %interface_cache;
  
  # Our return value is the accumulated list of method-name => method-sub pairs
  my @methods; 

  while (scalar @_) {

    ### PARSING ### Requires: $mm_def, $defaults, @_
    
    my $m_name = shift @_;
    _diagnostic('make_empty') unless ( defined $m_name and length $m_name );
    
    # Normalize: If we've got an array of names, replace it with those names 
    if ( ref $m_name eq 'ARRAY' ) {
      my @items = @{ $m_name };
      # If array is followed by a params hash, each one gets the same params
      if ( scalar @_ and ref $_[0] eq 'HASH' and ! exists $_[0]->{'name'} ) {
	my $params = shift;
	@items = map { $_, $params } @items
      }
      unshift @_, @items;
      next;
    }
    
    # Parse interfaces, modifiers and parameters
    if ( $m_name =~ s/^-// ) {
      if (  $m_name !~ s/^-// ) {
	# -param => value
	$defaults->{$m_name} = shift @_; 
      } else {
	if ( $m_name eq '' ) {
	  # '--' => { param => value ... }
	  %$defaults = ( %$defaults, %{ shift @_ } );
		
	} elsif ( exists $mm_def->{'interface'}{$m_name} ) {
	  # --interface
	  $defaults->{'interface'} = $m_name;
	
	} elsif ( exists $mm_def->{'modifier'}{$m_name} ) {
	  # --modifier
	  $defaults->{'modifier'} .= 
			    ( $defaults->{'modifier'} ? ' ' : '' ) . "-$m_name";
	
	} elsif ( exists $mm_def->{'behavior'}{$m_name} ) {
	  # --behavior as shortcut for single-method interface
	  $defaults->{'interface'} = $m_name;
	
	} else {
	  _diagnostic('make_bad_modifier', $mm_def->{'name'}, "--$m_name");
	}
      }
      next;
    }
    
    # Make a new meta-method hash
    my $m_info;
    
    # Parse string, string-then-hash, and hash-only meta-method parameters
    if ( ! ref $m_name ) {
      if ( scalar @_ and ref $_[0] eq 'HASH' and ! exists $_[0]->{'name'} ) {
	%$m_info = ( 'name' => $m_name, %{ shift @_ } );
      } else {
	$m_info = { 'name' => $m_name };
      }
    
    } elsif ( ref $m_name eq 'HASH' ) {
      unless ( exists $m_name->{'name'} and length $m_name->{'name'} ) {
	_diagnostic('make_noname');
      }
      $m_info = { %$m_name };
    
    } else {
      _diagnostic('make_unsupported', $m_name);
    }
    _diagnostic('debug_declaration', join(', ', map { defined $_ ? $_ : '(undef)' } %$m_info) );

    ### INITIALIZATION ### Requires: $mm_def, $defaults, $m_info
    
    my $interface = (
      $interface_cache{ $m_info->{'interface'} || $defaults->{'interface'} } 
	||= _interpret_interface( $mm_def, $m_info->{'interface'} || $defaults->{'interface'} )
    );
    %$m_info = ( 
      %$defaults, 
      ( $interface->{-params} ? %{$interface->{-params}} : () ),
      %$m_info 
    );

    
    # warn "Actual: " . Dumper( $m_info );


    # Expand * and *{...} strings.
    foreach (grep defined $m_info->{$_}, keys %$m_info) {
      $m_info->{$_} =~ s/\*(?:\{([^\}]+)?\})?/ $m_info->{ $1 || 'name' } /ge
    }
    if ( $m_info->{'modifier'} and $mm_def->{modifier}{-folding} ) {
      $m_info->{'modifier'} = _fold_modifiers( $m_info->{'modifier'}, 
			$mm_def->{modifier}{-folding} )
    }
    
    ### METHOD GENERATION ### Requires: $mm_def, $interface, $m_info
    
    # If the MM def provides an initialization "-init" call, run it.
    if ( local $_ = $mm_def->{'behavior'}->{'-init'} ) {
      push @methods, map $_->( $m_info ), (ref($_) eq 'ARRAY') ? @$_ : $_;
    }
    # Build Methods
    for ( grep { /^[^-]/ } keys %$interface ) { 
      my $function_name = $_;
      $function_name =~ s/\*/$m_info->{'name'}/g;
      
      my $behavior = $interface->{$_};
      
      # Fold in additional modifiers
      if ( $m_info->{'modifier'} ) { 
	if ( $behavior =~ /^\-/ and $mm_def->{modifier}{-folding} ) {
	  $behavior = $m_info->{'modifier'} = 
			_fold_modifiers( "$m_info->{'modifier'} $behavior", 
			    $mm_def->{modifier}{-folding} )
	} else {
	  $behavior = "$m_info->{'modifier'} $behavior";
	}
      }

      my $builder = 
	( $mm_def->{'-behavior_cache'}{$behavior} ) ? 
	$mm_def->{'-behavior_cache'}{$behavior} : 
	( ref($mm_def->{'behavior'}{$behavior}) eq 'CODE' ) ? 
	$mm_def->{'behavior'}{$behavior} : 
_behavior_builder( $mm_def, $behavior, $m_info );
      
      my $method = &$builder( $m_info );
      
      _diagnostic('debug_make_behave', $behavior, $function_name, $method);
      push @methods, ($function_name => $method) if ($method);
    }
    
    # If the MM def provides a "-subs" call, for forwarding and other
    # miscelaneous "subsidiary" or "contained" methods, run it.
    if ( my $subs = $mm_def->{'behavior'}->{'-subs'} ) {
      my @subs = (ref($subs) eq 'ARRAY') ? @$subs : $subs;
      foreach my $sub ( @subs ) {
	my @results = $sub->($m_info);
	if ( scalar @results == 1 and ref($results[0]) eq 'HASH' ) {
	  # If it returns a hash of helper method types, check the method info
	  # for any matching names and call the corresponding method generator.
	  my $types = shift @results;
	  foreach my $type ( keys %$types ) {
	    my $names = $m_info->{$type} or next; 
	    my @names = ref($names) eq 'ARRAY' ? @$names : split(' ', $names);
	    my $generator = $types->{$type};
	    push @results, map { $_ => &$generator($m_info, $_) } @names;
	  }	
	}
	push @methods, @results;
      }
    }
    
    # If the MM def provides a "-register" call, for registering meta-method
    # information for run-time access, run it.
    if ( local $_ = $mm_def->{'behavior'}->{'-register'} ) {
      push @methods, map $_->( $m_info ), (ref($_) eq 'ARRAY') ? @$_ : $_;
    }
  }
  
  return @methods;
}

# I'd like for the make_methods() sub to be simpler, and to take advantage
# of the standard _get_declarations parsing provided by the superclass.
# Sadly the below doesn't work, due to a few order-of-operations peculiarities 
# of parsing interfaces and modifiers, and their associated default paramters.
# Perhaps it might work if the processing of --options could be overridden with
# a callback sub, so that interfaces and their params can be parsed in order.
sub _x_get_declarations {	
  my $mm_def = shift;

  my @declarations = $mm_def::SUPER->_get_declarations( @_ );

  # use Data::Dumper;
  # warn "In: " . Dumper( \@_ );
  # warn "Auto: " . Dumper( \@declarations );

  my %interface_cache;

  while (scalar @declarations) {
    
    my $m_info = shift @declarations;

    # Parse interfaces and modifiers
    my @specials = grep $_, split '--', ( delete $m_info->{'--'} || '' );
    foreach my $special ( @specials ) {
      if ( exists $mm_def->{'interface'}{$special} ) {
	# --interface
	$m_info->{'interface'} = $special;
      
      } elsif ( exists $mm_def->{'modifier'}{$special} ) {
	# --modifier
	$m_info->{'modifier'} .= 
			  ( $m_info->{'modifier'} ? ' ' : '' ) . "-$special";
      
      } elsif ( exists $mm_def->{'behavior'}{$special} ) {
	# --behavior as shortcut for single-method interface
	$m_info->{'interface'} = $special;
      
      } else {
	_diagnostic('make_bad_modifier', $mm_def->{'name'}, "--$special");
      }
    }

    my $interface = (
	$interface_cache{ $m_info->{'interface'} } 
	  ||= _interpret_interface( $mm_def, $m_info->{'interface'} )
    );
    $m_info = { %$m_info, %{$interface->{-params}} } if $interface->{-params};

    _diagnostic('debug_declaration', join(', ', map { defined $_ ? $_ : '(undef)' } %$m_info) );
    
    # warn "Updated: " . Dumper( $m_info );
  }
}

########################################################################
### TEMPLATES: _interpret_interface()
########################################################################

sub _interpret_interface {
  my ($mm_def, $interface) = @_;
  
  if ( ref $interface eq 'HASH' ) { 
    return $interface if exists $interface->{'-parsed'};
  } 
  elsif ( ! defined $interface or ! length $interface ) { 
    _diagnostic('tmpl_empty');

  } 
  elsif ( ! ref $interface ) {
    if ( exists $mm_def->{'interface'}{ $interface } ) {
      if ( ! ref $mm_def->{'interface'}{ $interface } ) { 
	$mm_def->{'interface'}{ $interface } = 
				{ '*' => $mm_def->{'interface'}{ $interface } };
      }
    } elsif ( exists $mm_def->{'behavior'}{ $interface } ) {
      $mm_def->{'interface'}{ $interface } = { '*' => $interface };
    } else {
      _diagnostic('tmpl_unkown', $interface);
    }
    $interface = $mm_def->{'interface'}{ $interface };
    
    return $interface if exists $interface->{'-parsed'};
  }
  elsif ( ref $interface ne 'HASH' ) {
    _diagnostic('tmpl_unsupported', $interface);
  } 
  
  $interface->{'-parsed'} = "$_[1]";
  
  # Allow interface inheritance via -base specification
  if ( $interface->{'-base'} ) {
    for ( split ' ', $interface->{'-base'} ) {
      my $base = _interpret_interface( $mm_def, $_ );
      %$interface = ( %$base, %$interface );
    }
    delete $interface->{'-base'};
  }
  
  for (keys %$interface) {
    # Remove empty/undefined items.
    unless ( defined $interface->{$_} and length $interface->{$_} ) {
      delete $interface->{$_};
      next;
    }
  }
  # _diagnostic('debug_interface', $_[1], join(', ', %$interface ));
  
  return $interface;
}

########################################################################
### BEHAVIORS AND MODIFIERS: _fold_modifiers(), _behavior_builder()
########################################################################

sub _fold_modifiers {
  my $spec = shift;
  my $rules = shift;
  my %rules = @$rules;
  
  # Longest first, to prevent over-eager matching.
  my $rule = join '|', map "\Q$_\E", 
	sort { length($b) <=> length($a) } keys %rules;
  # Match repeatedly from the front.
  1 while ( $spec =~ s/($rule)/$rules{$1}/ );
  $spec =~ s/(^|\s)\s/$1/g;
  return $spec;
}

sub _behavior_builder {
  my ( $mm_def, $behavior, $m_info ) = @_;
  
  # We're going to have to do some extra work here, so we'll cache the result
  my $builder;
  
  # Separate the modifiers
  my $core_behavior = $behavior;
  my @modifiers;
  while ( $core_behavior =~ s/\-(\w+)\s// ) { push @modifiers, $1 }
  
  # Find either the built-in or universal behavior template
  if ( $mm_def->{'behavior'}{$core_behavior} ) {
    $builder = $mm_def->{'behavior'}{$core_behavior};
  } else {
    my $universal = _definition('Class::MakeMethods::Template::Universal','generic');
    $builder = $universal->{'behavior'}{$core_behavior} 
  }
  
  # Otherwise we're hosed.
  $builder or _diagnostic('make_bad_behavior', $m_info->{'name'}, $behavior);
  
  if ( ! ref $builder ) {
    # If we've got a text template, pass it off for interpretation.
    my $code = ( ! $Class::MakeMethods::Utility::DiskCache::DiskCacheDir ) ?
      _interpret_text_builder($mm_def, $core_behavior, $builder, @modifiers) 
    : _disk_cache_builder($mm_def, $core_behavior, $builder, @modifiers);
    
    # _diagnostic('debug_eval_builder', $name, $code);
    local $^W unless $Class::MakeMethods::CONTEXT{Debug};
    $builder = eval $code;
    if ( $@ ) { _diagnostic('behavior_eval', $@, $code) }
    unless (ref $builder eq 'CODE') { _diagnostic('behavior_eval', $@, $code) }
  
  } elsif ( scalar @modifiers ) {
    # Can't modify code subs
    _diagnostic('make_behavior_mod', join(', ', @modifiers), $core_behavior);
  }
  
  $mm_def->{'-behavior_cache'}{$behavior} = $builder;

  return $builder;
}

########################################################################
### CODE EXPRESSIONS: _interpret_text_builder(), _disk_cache_builder()
########################################################################

sub _interpret_text_builder {
  require Class::MakeMethods::Utility::TextBuilder;
  
  my ( $mm_def, $name, $code, @modifiers ) = @_;
  
  foreach ( @modifiers ) {
    exists $mm_def->{'modifier'}{$_} 
      or _diagnostic('behavior_mod_unknown', $name, $_);
  }
  
  my @exprs = grep { $_ } map { 
	$mm_def->{'modifier'}{ $_ }, 
	$mm_def->{'modifier'}{ "$_ $name" } || $mm_def->{'modifier'}{ "$_ *" }
      } ( '-all', ( scalar(@modifiers) ? @modifiers : '-default' ) );
  
  # Generic method template
  push @exprs, "return sub _SUB_ATTRIBS_ { \n  my \$self = shift;\n  * }";
  
  # Closure-generator
  push @exprs, "sub { my \$m_info = \$_[0]; * }";
  
  my $exprs = $mm_def->{code_expr};
  unshift @exprs, { 
	( map { $_=>$exprs->{$_} } grep /^[^-]/, keys %$exprs ),
	'_BEHAVIOR_{}' => $mm_def->{'behavior'},
	'_SUB_ATTRIBS_' => '',
  };
  
  my $result = Class::MakeMethods::Utility::TextBuilder::text_builder($code,
								       @exprs);
  
  my $modifier_string = join(' ', map "-$_", @modifiers);
  my $full_name = "$name ($mm_def->{template_class} $mm_def->{template_name}" .
		    ( $modifier_string ? " $modifier_string" : '' ) . ")";
  
  _diagnostic('debug_template_builder', $full_name, $code, $result);
  
  return $result;
}

sub _disk_cache_builder { 
  require Class::MakeMethods::Utility::DiskCache;
  my ( $mm_def, $core_behavior, $builder, @modifiers ) = @_;
  
  Class::MakeMethods::Utility::DiskCache::disk_cache( 
    "$mm_def->{template_class}::$mm_def->{template_name}", 
    join('.', $core_behavior, @modifiers),
    \&_interpret_text_builder, ($mm_def, $core_behavior, $builder, @modifiers)
  );
}

1;

__END__


#line 1234

#line 1256

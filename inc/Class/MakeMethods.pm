#line 1 "inc/Class/MakeMethods.pm - /Library/Perl/5.8.6/Class/MakeMethods.pm"
### Class::MakeMethods
  # Copyright 2002, 2003 Matthew Simon Cavalletto
  # See documentation, license, and other information after _END_.

package Class::MakeMethods;

require 5.00307; # for the UNIVERSAL::isa method.
use strict;
use Carp;

use vars qw( $VERSION );
$VERSION = 1.010;

use vars qw( %CONTEXT %DIAGNOSTICS );

########################################################################
### MODULE IMPORT: import(), _import_version()
########################################################################

sub import {
  my $class = shift;

  if ( scalar @_ and $_[0] =~ m/^\d/ ) {
    $class->_import_version( shift );
  }
  
  if ( scalar @_ == 1 and $_[0] eq '-isasubclass' ) {
    shift;
    my $target_class = ( caller )[0];
    no strict;
    push @{"$target_class\::ISA"}, $class;
  }
  
  $class->make( @_ ) if ( scalar @_ );
}

sub _import_version {
  my $class = shift;
  my $wanted = shift;
  
  no strict;
  my $version = ${ $class.'::VERSION '};
  
  # If passed a version number, ensure that we measure up.
  # Based on similar functionality in Exporter.pm
  if ( ! $version or $version < $wanted ) {
    my $file = "$class.pm";
    $file =~ s!::!/!g;
    $file = $INC{$file} ? " ($INC{$file})" : '';
    _diagnostic('mm_version_fail', $class, $wanted, $version || '(undef)', $file);
  }
}

########################################################################
### METHOD GENERATION: make()
########################################################################

sub make {
  local $CONTEXT{MakerClass} = shift;
  
  # Find the first class in the caller() stack that's not a subclass of us 
  local $CONTEXT{TargetClass};
  my $i = 0;
  do {
    $CONTEXT{TargetClass} = ( caller($i ++) )[0];
  } while UNIVERSAL::isa($CONTEXT{TargetClass}, __PACKAGE__ );
  
  my @methods;
  
  # For compatibility with 5.004, which fails to splice use's constant @_
  my @declarations = @_; 
  
  if (@_ % 2) { _diagnostic('make_odd_args', $CONTEXT{MakerClass}); }
  while ( scalar @declarations ) {
    # The list passed to import should alternate between the names of the
    # meta-method to call to generate the methods, and arguments to it.
    my ($name, $args) = splice(@declarations, 0, 2);
    unless ( defined $name ) {
      croak "Undefined name";
    }
    
    # Leading dash on the first argument of a pair means it's a
    # global/general option to be stored in CONTEXT.
    if ( $name =~ s/^\-// ) {
      
      # To prevent difficult-to-predict retroactive behaviour, start by
      # flushing any pending methods before letting settings take effect
      if ( scalar @methods ) { 
	_install_methods( $CONTEXT{MakerClass}, @methods );
	@methods = ();
      }
      
      if ( $name eq 'MakerClass' ) {
	# Switch base package for remainder of args
	$CONTEXT{MakerClass} = _find_subclass($CONTEXT{MakerClass}, $args);
      } else {
	$CONTEXT{$name} = $args;
      }
      
      next;
    }
    
    # Argument normalization
    my @args = (
      ! ref($args) ? split(' ', $args) : # If a string, it is split on spaces.
      ref($args) eq 'ARRAY' ? (@$args) : # If an arrayref, use its contents.
      ( $args )     			 # If a hashref, it is used directly
    );

    # If the type argument contains an array of method types, do the first
    # now, and put the others back in the queue to be processed subsequently.
    if ( ref($name) eq 'ARRAY' ) {	
      ($name, my @name) = @$name;	
      unshift @declarations, map { $_=>[@args] } @name;
    }
    
    # If the type argument contains space characters, use the first word
    # as the type, and prepend the remaining items to the argument list.
    if ( $name =~ /\s/ ) {
      my @items = split ' ', $name;
      $name = shift( @items );
      unshift @args, @items;
    }
    
    # If name contains a colon or double colon, treat the preceeding part 
    # as the subclass name but only for this one set of methods.
    local $CONTEXT{MakerClass} = _find_subclass($CONTEXT{MakerClass}, $1)
		if ($name =~ s/^(.*?)\:{1,2}(\w+)$/$2/);
    
    # Meta-method invocation via named_method or direct method call
    my @results = (
	$CONTEXT{MakerClass}->can('named_method') ? 
			$CONTEXT{MakerClass}->named_method( $name, @args ) : 
	$CONTEXT{MakerClass}->can($name) ?
			$CONTEXT{MakerClass}->$name( @args ) : 
	    croak "Can't generate $CONTEXT{MakerClass}->$name() methods"
    );
    # warn "$CONTEXT{MakerClass} $name - ", join(', ', @results) . "\n";
    
    ### A method-generator may be implemented in any of the following ways:
    
    # SELF-CONTAINED: It may return nothing, if there are no methods
    # to install, or if it has installed the methods itself.
    # (We also accept a single false value, for backward compatibility 
    # with generators that are written as foreach loops, which return ''!)
    if ( ! scalar @results or scalar @results == 1 and ! $results[0] ) { } 
    
    # ALIAS: It may return a string containing a meta-method type to run 
    # instead. Put the arguments back in the queue and go through again.
    elsif ( scalar @results == 1 and ! ref $results[0]) {
      unshift @declarations, $results[0], \@args;
    } 
    
    # REWRITER: It may return one or more array reference containing a meta-
    # method type and arguments which should be created to complete this 
    # request. Put the arguments back in the queue and go through again.
    elsif ( ! grep { ref $_ ne 'ARRAY' } @results ) {
      unshift @declarations, ( map { shift(@$_), $_ } @results );
    } 
    
    # CODE REFS: It may provide a list of name, code pairs to install
    elsif ( ! scalar @results % 2 and ! ref $results[0] ) {
      push @methods, @results;
    } 
    
    # GENERATOR OBJECT: It may return an object reference which will construct
    # the relevant methods.
    elsif ( UNIVERSAL::can( $results[0], 'make_methods' ) ) {
      push @methods, ( shift @results )->make_methods(@results, @args);
    } 
    
    else {
      _diagnostic('make_bad_meta', $name, join(', ', map "'$_'", @results));
    }
  }
  
  _install_methods( $CONTEXT{MakerClass}, @methods );
  
  return;
}

########################################################################
### DECLARATION PARSING: _get_declarations()
########################################################################

sub _get_declarations {
  my $class = shift;
  
  my @results;
  my %defaults;
  
  while (scalar @_) {
    my $m_name = shift @_;
    if ( ! defined $m_name or ! length $m_name ) {
      _diagnostic('make_empty') 
    }

    # Various forms of default parameters
    elsif ( substr($m_name, 0, 1) eq '-' ) {
      if ( substr($m_name, 1, 1) ne '-' ) {
	# Parse default values in the format "-param => value"
	$defaults{ substr($m_name, 1) } = shift @_;
      } elsif ( length($m_name) == 2 ) {
	# Parse hash of default values in the format "-- => { ... }"
	ref($_[0]) eq 'HASH' or _diagnostic('make_unsupported', $m_name.$_[0]);
	%defaults = ( %defaults, %{ shift @_ } );
      } else {
	# Parse "special" arguments in the format "--foobar"
	$defaults{ '--' } .= $m_name;
      }
    }
    
    # Parse string and string-then-hash declarations
    elsif ( ! ref $m_name ) {  
      if ( scalar @_ and ref $_[0] eq 'HASH' and ! exists $_[0]->{'name'} ) {
	push @results, { %defaults, 'name' => $m_name, %{ shift @_ } };
      } else {
	push @results, { %defaults, 'name' => $m_name };
      }
    } 
    
    # Parse hash-only declarations
    elsif ( ref $m_name eq 'HASH' ) {
      if ( length $m_name->{'name'} ) {
	push @results, { %defaults, %$m_name };
      } else {
	_diagnostic('make_noname');
      }
    }
    
    # Normalize: If we've got an array of names, replace it with those names 
    elsif ( ref $m_name eq 'ARRAY' ) {
      my @items = @{ $m_name };
      # If array is followed by an params hash, each one gets the same params
      if ( scalar @_ and ref $_[0] eq 'HASH' and ! exists $_[0]->{'name'} ) {
	my $params = shift;
	@items = map { $_, $params } @items
      }
      unshift @_, @items;
      next;
    }
    
    else {
      _diagnostic('make_unsupported', $m_name);
    }
    
  }
  
  return @results;
}

########################################################################
### FUNCTION INSTALLATION: _install_methods()
########################################################################

sub _install_methods {
  my ($class, %methods) = @_;
  
  no strict 'refs';
  
  # print STDERR "CLASS: $class\n";
  my $package = $CONTEXT{TargetClass};
  
  my ($name, $code);
  while (($name, $code) = each %methods) {
    
    # Skip this if the target package already has a function by the given name.
    next if ( ! $CONTEXT{ForceInstall} and 
				defined *{$package. '::'. $name}{CODE} );
   
    if ( ! ref $code ) {
      local $SIG{__DIE__};
      local $^W;
      my $coderef = eval $code;
      if ( $@ ) {
	_diagnostic('inst_eval_syntax', $name, $@, $code);
      } elsif ( ref $coderef ne 'CODE' ) {
	_diagnostic('inst_eval_result', $name, $coderef, $code);
      }
      $code = $coderef;
    } elsif ( ref $code ne 'CODE' ) {
      _diagnostic('inst_result', $name, $code);
    }
    
    # Add the code refence to the target package
    # _diagnostic('debug_install', $package, $name, $code);
    local $^W = 0 if ( $CONTEXT{ForceInstall} );
    *{$package . '::' . $name} = $code;

  }
  return;
}

########################################################################
### SUBCLASS LOADING: _find_subclass()
########################################################################

# $pckg = _find_subclass( $class, $optional_package_name );
sub _find_subclass {
  my $class = shift; 
  my $package = shift or die "No package for _find_subclass";
  
  $package =  $package =~ s/^::// ? $package :
		"Class::MakeMethods::$package";
  
  (my $file = $package . '.pm' ) =~ s|::|/|go;
  return $package if ( $::INC{ $file } );
  
  no strict 'refs';
  return $package if ( @{$package . '::ISA'} );
  
  local $SIG{__DIE__} = '';
  eval { require $file };
  $::INC{ $package } = $::INC{ $file };
  if ( $@ ) { _diagnostic('mm_package_fail', $package, $@) }
  
  return $package
}

########################################################################
### CONTEXT: _context(), %CONTEXT
########################################################################

sub _context {
  my $class = shift; 
  return %CONTEXT if ( ! scalar @_ );
  my $key = shift;
  return $CONTEXT{$key} if ( ! scalar @_ );
  $CONTEXT{$key} = shift;
}

BEGIN {
  $CONTEXT{Debug} ||= 0;
}

########################################################################
### DIAGNOSTICS: _diagnostic(), %DIAGNOSTICS
########################################################################

sub _diagnostic {
  my $case = shift;
  my $message = $DIAGNOSTICS{$case};
  $message =~ s/\A\s*\((\w)\)\s*//;
  my $severity = $1 || 'I';
  if ( $severity eq 'Q' ) {
    carp( sprintf( $message, @_ ) ) if ( $CONTEXT{Debug} );
  } elsif ( $severity eq 'W' ) {
    carp( sprintf( $message, @_ ) ) if ( $^W );
  } elsif ( $severity eq 'F' ) {
    croak( sprintf( $message, @_ ) )
  } else {
    confess( sprintf( $message, @_ ) )
  }
}


BEGIN { %DIAGNOSTICS = (

  ### BASE CLASS DIAGNOSTICS
  
  # _diagnostic('debug_install', $package, $name, $code)
  debug_install => q|(W) Installing function %s::%s (%s)|,
  
  # _diagnostic('make_odd_args', $CONTEXT{MakerClass})
  make_odd_args => q|(F) Odd number of arguments passed to %s method generator|,
  
  # _diagnostic('make_bad_meta', $name, join(', ', map "'$_'", @results)
  make_bad_meta => q|(I) Unexpected return value from method constructor %s: %s|,
  
  # _diagnostic('inst_eval_syntax', $name, $@, $code)
  inst_eval_syntax => q|(I) Unable to compile generated method %s(): %s| . 
      qq|\n  (There's probably a syntax error in this generated code.)\n%s\n|,
  
  # _diagnostic('inst_eval_result', $name, $coderef, $code)
  inst_eval_result => q|(I) Unexpected return value from compilation of %s(): '%s'| . 
      qq|\n  (This generated code should have returned a code ref.)\n%s\n|,
  
  # _diagnostic('inst_result', $name, $code)
  inst_result => q|(I) Unable to install code for %s() method: '%s'|,
  
  # _diagnostic('mm_package_fail', $package, $@)
  mm_package_fail => q|(F) Unable to dynamically load %s: %s|,
  
  # _diagnostic('mm_version_fail', $class, $wanted, $version || '(undef)
  mm_version_fail => q|(F) %s %s required--this is only version %s%s|,
  
  ### STANDARD SUBCLASS DIAGNOSTICS
  
  # _diagnostic('make_empty')
  make_empty => q|(F) Can't parse meta-method declaration: argument is empty or undefined|,
  
  # _diagnostic('make_noname')
  make_noname => q|(F) Can't parse meta-method declaration: missing name attribute.| . 
      qq|\n  (Perhaps a trailing attributes hash has become separated from its name?)|,
  
  # _diagnostic('make_unsupported', $m_name)
  make_unsupported => q|(F) Can't parse meta-method declaration: unsupported declaration type '%s'|,
  
  ### TEMPLATE SUBCLASS DIAGNOSTICS 
    # ToDo: Should be moved to the Class::MakeMethods::Template package
  
  debug_declaration => q|(Q) Meta-method declaration parsed: %s|,
  debug_make_behave => q|(Q) Building meta-method behavior %s: %s(%s)|,
  mmdef_not_interpretable => qq|(I) Not an interpretable meta-method: '%s'| .
      qq|\n  (Perhaps a meta-method attempted to import from a non-templated meta-method?)|,
  make_bad_modifier => q|(F) Can't parse meta-method declaration: unknown option for %s: %s|,
  make_bad_behavior => q|(F) Can't make method %s(): template specifies unknown behavior '%s'|,
  behavior_mod_unknown => q|(F) Unknown modification to %s behavior: -%s|,
  debug_template_builder => qq|(Q) Template interpretation for %s:\n%s|.
      qq|\n---------\n%s\n---------\n|,
  debug_template => q|(Q) Parsed template '%s': %s|,
  debug_eval_builder => q|(Q) Compiling behavior builder '%s':| . qq|\n%s|,
  make_behavior_mod => q|(F) Can't apply modifiers (%s) to code behavior %s|,
  behavior_eval => q|(I) Class::MakeMethods behavior compilation error: %s| . 
      qq|\n  (There's probably a syntax error in the below code.)\n%s|,
  tmpl_unkown => q|(F) Can't interpret meta-method template: unknown template name '%s'|,
  tmpl_empty => q|(F) Can't interpret meta-method template: argument is empty or undefined|,
  tmpl_unsupported => q|(F) Can't interpret meta-method template: unsupported template type '%s'|,
) }

1;

__END__


#line 1521

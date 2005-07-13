#line 1 "inc/Class/MakeMethods/Template/Generic.pm - /Library/Perl/5.8.6/Class/MakeMethods/Template/Generic.pm"
#line 32

########################################################################

package Class::MakeMethods::Template::Generic;

use Class::MakeMethods::Template '-isasubclass';

$VERSION = 1.008;
use strict;
use Carp;

# use AutoLoader 'AUTOLOAD';

########################################################################

sub generic {
  {
    'params' => {
    },
    'modifier' => {
      '-import' => {  'Template::Universal:generic' => '*' },
    },
    'code_expr' => { 
      '-import' => {  'Template::Universal:generic' => '*'  },
      '_VALUE_' => undef,
      '_REF_VALUE_' => q{ _VALUE_ },
      '_GET_VALUE_' => q{ _VALUE_ },
      '_SET_VALUE_{}' => q{ ( _VALUE_ = * ) },
      '_PROTECTED_SET_VALUE_{}' => q{ (_ACCESS_PROTECTED_ and _SET_VALUE_{*}) },
      '_PRIVATE_SET_VALUE_{}' => q{ ( _ACCESS_PRIVATE_ and _SET_VALUE_{*} ) },
    },
  }
}

# 1;

# __END__

########################################################################

#line 217

sub new {
  {
    '-import' => { 
      # 'Template::Generic:generic' => '*',
    },
    'interface' => {
      default		=> 'with_methods',
      with_values	=> 'with_values',
      with_methods	=> 'with_methods', 	
      with_init		=> 'with_init',
      and_then_init     => 'and_then_init',
      new_and_init   => { '*'=>'new_with_init', 'init'=>'method_init'},
      instance_with_methods => 'instance_with_methods', 	
      copy	    	=> 'copy_with_values',
      copy_with_values	=> 'copy_with_values',
      copy_with_methods	=> 'copy_with_methods', 	
      copy_instance_with_values	=> 'copy_instance_with_values',
      copy_instance_with_methods => 'copy_instance_with_methods', 	
    },
    'behavior' => {
      'with_methods' => q{
	  $self = _EMPTY_NEW_INSTANCE_;
	  _CALL_METHODS_FROM_HASH_
	  return $self;
        },
      'with_values' => q{
	  $self = _EMPTY_NEW_INSTANCE_;
	  _SET_VALUES_FROM_HASH_
	  return $self;
	},
      'with_init' => q{
	  $self = _EMPTY_NEW_INSTANCE_;
	  my $init_method = $m_info->{'init_method'} || 'init';
	  $self->$init_method( @_ );
	  return $self;
	},
      'and_then_init' => q{
	  $self = _EMPTY_NEW_INSTANCE_;
	  _CALL_METHODS_FROM_HASH_
	  my $init_method = $m_info->{'init_method'} || 'init';
	  $self->$init_method();
	  return $self;
	},
      'instance_with_methods' => q{
	  $self = ref ($self) ? $self : _EMPTY_NEW_INSTANCE_;
	  _CALL_METHODS_FROM_HASH_
	  return $self;
        },
      'copy_with_values' => q{ 
	  @_ = ( %$self, @_ );
	  $self = _EMPTY_NEW_INSTANCE_;
	  _SET_VALUES_FROM_HASH_
	  return $self;
	},
      'copy_with_methods' => q{ 
	  @_ = ( %$self, @_ );
	  $self = _EMPTY_NEW_INSTANCE_;
	  _CALL_METHODS_FROM_HASH_
	  return $self;
	},
      'copy_instance_with_values' => q{
	  $self = bless { ( ref $self ? %$self : () ) }, _SELF_CLASS_;
	  _SET_VALUES_FROM_HASH_
	  return $self;
	},
      'copy_instance_with_methods' => q{
	  $self = bless { ref $self ? %$self : () }, _SELF_CLASS_;
	  _CALL_METHODS_FROM_HASH_
	  return $self;
	},
    },
  }
}

########################################################################

#line 444

sub scalar {
  {
    '-import' => { 'Template::Generic:generic' => '*' },
    'interface' => {
      default	    => 'get_set',
      get_set       => { '*'=>'get_set' },
      noclear       => { '*'=>'get_set' },
      with_clear    => { '*'=>'get_set', 'clear_*'=>'clear' },
      
      read_only	    => { '*'=>'get' },
      get_private_set    => 'get_private_set',
      get_protected_set    => 'get_protected_set',
      
      eiffel	    => { '*'=>'get',     'set_*'=>'set_return' },
      java	    => { 'get*'=>'get',  'set*'=>'set_return' },
      
      init_and_get  => { '*'=>'get_init', -params=>{ init_method=>'init_*' } },
      
    },
    'behavior' => {
      'get'	=> q{ _GET_VALUE_ },
      'set'	=> q{ _SET_VALUE_{ shift() } },
      'set_return' => q{ _BEHAVIOR_{set}; return },
      'clear'	=> q{ _SET_VALUE_{ undef } },
      'defined'	=> q{ defined _VALUE_ },
      
      'get_set'	=> q { 
	  if ( scalar @_ ) {
	    _BEHAVIOR_{set}
	  } else {
	    _BEHAVIOR_{get}
	  }
	},
      'get_set_chain' => q { 
	  if ( scalar @_ ) {
	    _BEHAVIOR_{set};
	    return _SELF_
	  } else {
	    _BEHAVIOR_{get}
	  }
	},
      'get_set_prev' => q { 
	  my $value = _BEHAVIOR_{get};
	  if ( scalar @_ ) {
	    _BEHAVIOR_{set};
	  }
	  return $value;
	},
      
      'get_private_set' => q{ 
	  if ( scalar @_ ) { 
	    _PRIVATE_SET_VALUE_{ shift() } 
	    } else {
	    _BEHAVIOR_{get}
	  }
	},
      'get_protected_set' => q{ 
	  if ( scalar @_ ) { 
	    _PROTECTED_SET_VALUE_{ shift() } 
	    } else {
	    _BEHAVIOR_{get}
	  }
	},
      'get_init' => q{
	  if ( ! defined _VALUE_ ) {
	    my $init_method = _ATTR_REQUIRED_{'init_method'};
	    _SET_VALUE_{ _SELF_->$init_method( @_ ) };
	  } else {
	    _BEHAVIOR_{get}
	  }
	},
      
    },
    'params' => {
      new_method => 'new'
    },
  } 
}

########################################################################

#line 590

sub string {
  {
    '-import' => { 'Template::Generic:scalar' => '*' },
    'interface' => {
      get_concat    => { '*'=>'get_concat', 'clear_*'=>'clear', 
		-params=>{ 'join' => '' }, },
    },
    'params' => {
      'return_value_undefined' => '',
    },
    'behavior' => {
      'get' => q{ 
	  if ( defined( my $value = _GET_VALUE_) ) { 
	    _GET_VALUE_;
	  } else {  
	    _STATIC_ATTR_{return_value_undefined};
	  }
	},
      'set' => q{ 
	  my $new_value = shift();
	  _SET_VALUE_{ "$new_value" };
  	},
      'concat' => q{ 
	  my $new_value = shift();
	  if ( defined( my $value = _GET_VALUE_) ) { 
	    _SET_VALUE_{join( _STATIC_ATTR_{join}, $value, $new_value)};
	  } else {
	    _SET_VALUE_{ "$new_value" };
	  }
  	},
      'get_concat' => q{
	  if ( scalar @_ ) {
	    _BEHAVIOR_{concat}
	  } else {
	    _BEHAVIOR_{get}
	  }
	},
    },
  }
}

########################################################################

#line 681

sub string_index {
  ( {
    '-import' => { 'Template::Generic:generic' => '*' },
    'params' => { 
      'new_method' => 'new',
    },
    'interface' => {
      default => { '*'=>'get_set', 'clear_*'=>'clear', 'find_*'=>'find' },
      find_or_new=>{'*'=>'get_set', 'clear_*'=>'clear', 'find_*'=>'find_or_new'}
    },
    'code_expr' => { 
      _REMOVE_FROM_INDEX_ => q{ 
	  if (defined ( my $old_v = _GET_VALUE_ ) ) {
	    delete _ATTR_{'index'}{ $old_v };
	  }
	},
      _ADD_TO_INDEX_ => q{ 
	  if (defined ( my $new_value = _GET_VALUE_ ) ) {
	    if ( my $old_item = _ATTR_{'index'}{$new_value} ) {
	      # There's already an object stored under that value so we
	      # need to unset it's value.
	      # And maybe issue a warning? Or croak?
	      my $m_name = _ATTR_{'name'};
	      $old_item->$m_name( undef );
	    }
	    
	    # Put ourself in the index under that value
	    _ATTR_{'index'}{$new_value} = _SELF_;
	  }
	},
      _INDEX_HASH_ => '_ATTR_{index}',
    },
    'behavior' => {
      '-init' => [ sub { 
	  my $m_info = $_[0]; 
	  defined $m_info->{'index'} or $m_info->{'index'} = {};
	  return;
	} ],
      'get' => q{ 
	  return _GET_VALUE_; 
	},
      'set' => q{ 
	  my $new_value = shift;
	  
	  _REMOVE_FROM_INDEX_
	  
	  # Set our value to new
	  _SET_VALUE_{ $new_value };
	  
	  _ADD_TO_INDEX_
	},
      'get_set' => q{
	  if ( scalar @_ ) {
	    _BEHAVIOR_{set}
	  } else {
	    _BEHAVIOR_{get}
	  }
	},
      'clear' => q{
	  _REMOVE_FROM_INDEX_
	  _SET_VALUE_{ undef };
	},
      'find' => q{
	  if ( scalar @_ ) {
	    return @{ _ATTR_{'index'} }{ @_ };
	  } else {
	    return _INDEX_HASH_
	  }
	},
      'find_or_new' => q{
	  if ( scalar @_ ) {
	    my $class = _SELF_CLASS_;
	    my $new_method = _ATTR_REQUIRED_{'new_method'};
	    my $m_name = _ATTR_{'name'};
	    foreach (@_) {
	      next if defined _ATTR_{'index'}{$_};
	      # create new instance and set its value; it'll add itself to index
	      $class->$new_method()->$m_name($_);
	    }
	    return @{ _ATTR_{'index'} }{ @_ };
	  } else {
	    return _INDEX_HASH_
	  }
	},
    },
  } )
}

########################################################################

#line 819

sub number {
  {
    '-import' => { 'Template::Generic:scalar' => '*' },
    'interface' => {
      counter       => { '*'=>'get_set', '*_incr'=>'incr', '*_reset'=>'clear' },
    },
    'params' => {
      'return_value_undefined' => 0,
    },
    'behavior' => {
      'get_set' => q{ 
	  if ( scalar @_ ) {
	    local $_ = shift;
	    if ( defined $_ ) {
	      croak "Can't set _STATIC_ATTR_{name} to non-numeric value '$_'"
					if ( /[^\+\-\,\d\.e]/ );
	      s/\,//g; 
	    }
	    _SET_VALUE_{ $_ }
	  }
	  defined( _GET_VALUE_ ) ? _GET_VALUE_ 
				 : _STATIC_ATTR_{return_value_undefined}
	},
      'incr' => q{ 
	  _VALUE_ ||= 0; 
	  _VALUE_ += ( scalar @_ ? shift : 1 ) 
	},
      'decr' => q{ 
	  _VALUE_ ||= 0; 
	  _VALUE_ -= ( scalar @_ ? shift : 1 ) 
	},
    },
  }
}

########################################################################

#line 903

sub boolean {
  {
    '-import' => { 'Template::Generic:scalar' => '*' },
    'interface' => {
      default => {'*'=>'get_set', 'clear_*'=>'set_false',
						      'set_*'=>'set_true'},
      flag_set_clear => {'*'=>'get_set', 'clear_*'=>'set_false',
						      'set_*'=>'set_true'},
    },
    'behavior' => {
      'get'	=> q{ _GET_VALUE_ || 0 },
      'set'	=> q{ 
	if ( shift ) {
	  _BEHAVIOR_{set_true}
	} else {
	  _BEHAVIOR_{set_false}
	}
      },      
      'set_true' => q{ _SET_VALUE_{ 1 } },
      'set_false' => q{ _SET_VALUE_{ 0 } },
      'set_value' => q{ 
	_SET_VALUE_{ scalar @_ ? shift : 1 }
      },
    },
  }
}

########################################################################

#line 1022

sub bits {
  {
    '-import' => { 
      # 'Template::Generic:generic' => '*',
    },
    'interface' => {
      default => { 
	'*'=>'get_set', 'set_*'=>'set_true', 'clear_*'=>'set_false',
	'bit_fields'=>'bit_names', 'bit_string'=>'bit_string',
	'bit_list'=>'bit_list', 'bit_hash'=>'bit_hash',
      },
      class_methods => { 
	'bit_fields'=>'bit_names', 'bit_string'=>'bit_string', 
	'bit_list'=>'bit_list', 'bit_hash'=>'bit_hash',
      },
    },
    'code_expr' => {
      '_VEC_POS_VALUE_{}' => 'vec(_VALUE_, *, 1)',
      _VEC_VALUE_ => '_VEC_POS_VALUE_{ _ATTR_{bfp} }',
      _CLASS_INFO_ => '$Class::MakeMethods::Template::Hash::bits{_STATIC_ATTR_{target_class}}',
    },
    'modifier' => {
      '-all' => [ q{
	  defined _VALUE_ or _VALUE_ = "";
	  *
	} ],
    },
    'behavior' => {
      '-init' => sub {
	my $m_info = $_[0]; 
	
	$m_info->{bfp} ||= do {
	  my $array = ( $Class::MakeMethods::Template::Hash::bits{$m_info->{target_class}} ||= [] );
	  my $idx;
	  foreach ( 0..$#$array ) { 
	    if ( $array->[$_] eq $m_info->{'name'} ) { $idx = $_; last }
	  }
          unless ( $idx ) {
	    push @$array, $m_info->{'name'}; 
	    $idx = $#$array;
	  }
	  $idx;
	};
	
	return;	
      },
      'bit_names' => q{
	  @{ _CLASS_INFO_ };
	},
      'bit_string' => q{
	  if ( @_ ) {
	    _SET_VALUE_{ shift @_ };
	  } else {
	    _VALUE_;
	  }
	},
      'bits_size' => q{
	  8 * length( _VALUE_ );
	},
      'bits_complement' => q{
	  ~ _VALUE_;
	},
      'bit_hash' => q{
	  my @bits = @{ _CLASS_INFO_ };
	  if ( @_ ) {
	    my %bits = @_;
	    _SET_VALUE_{ pack 'b*', join '', map { $_ ? 1 : 0 } @bits{ @bits } };
	    return @_;
	  } else {
	    map { $bits[$_], vec(_VALUE_, $_, 1) } 0 .. $#bits
	  }
	},
      'bit_list' => q{
	  if ( @_ ) {
	    _SET_VALUE_{ pack 'b*', join( '', map { $_ ? 1 : 0 } @_ ) };
	    return map { $_ ? 1 : 0 } @_;
	  } else {
	    split //, unpack "b*", _VALUE_;
	  }
	},
      'bit_pos_get' => q{
	  vec(_VALUE_, $_[0], 1)
	},
      'bit_pos_set' => q{
	  vec(_VALUE_, $_[0], 1) = ( $_[1] ? 1 : 0 )
	},
      
      'get_set' => q{
	  if ( @_ ) {
	    _VEC_VALUE_ = ( $_[0] ? 1 : 0 );
	  } else {
	    _VEC_VALUE_;
	  }
	},
      'get' => q{
	  _VEC_VALUE_;
	},
      'set' => q{
	  _VEC_VALUE_ = ( $_[0] ? 1 : 0 );
	},
      'set_true' => q{
	  _VEC_VALUE_ = 1;
	},
      'set_false' => q{
	  _VEC_VALUE_ = 0;
	},
  
    },
  }
}


########################################################################

#line 1241

sub array {
  {
    '-import' => { 'Template::Generic:generic' => '*' },
    'interface' => {
      default => { 
	'*'=>'get_set', 
	map( ($_.'_*' => $_ ), qw( pop push unshift shift splice clear count )),
	map( ('*_'.$_ => $_ ), qw( ref index ) ),
      },
      minimal => { '*'=>'get_set', '*_clear'=>'clear' },
      get_set_items => { '*'=>'get_set_items' },
      x_verb => { 
	'*'=>'get_set', 
	map( ('*_'.$_ => $_ ), qw(pop push unshift shift splice clear count ref index )),
      },
      get_set_ref => { '*'=>'get_set_ref' },
      get_set_ref_help => { '*'=>'get_set_ref', '-base'=>'default' },
    },
    'modifier' => {
      '-all' => [ q{ _ENSURE_REF_VALUE_; * } ],
    },
    'code_expr' => { 
      '_ENSURE_REF_VALUE_' => q{ _REF_VALUE_ ||= []; },
    },
    'behavior' => {
      'get_set' => q{
	  @{_REF_VALUE_} = @_ if ( scalar @_ );
 	  return wantarray ? @{_GET_VALUE_} : _REF_VALUE_;
	},
      'get_set_ref' => q{
	  @{_REF_VALUE_} = ( ( scalar(@_) == 1 and ref($_[0]) eq 'ARRAY' ) ? @{$_[0]} : @_ ) if ( scalar @_ );
 	  return wantarray ? @{_GET_VALUE_} : _REF_VALUE_;
	},
      'get_push' => q{
	  push @{_REF_VALUE_}, map { ref $_ eq 'ARRAY' ? @$_ : ($_) } @_;
 	  return wantarray ? @{_GET_VALUE_} : _REF_VALUE_;
	},
      'ref' => q{ _REF_VALUE_ },
      'get' => q{ return wantarray ? @{_GET_VALUE_} : _REF_VALUE_ },
      'set' => q{ @{_REF_VALUE_} = @_ },
      'pop' => q{ pop @{_REF_VALUE_} },
      'push' => q{ push @{_REF_VALUE_}, @_ },
      'shift' => q{ shift @{_REF_VALUE_} },
      'unshift' => q{ unshift @{_REF_VALUE_}, @_ },
      'slice' => q{ _GET_VALUE_->[ @_ ] },
      'splice' => q{ splice @{_REF_VALUE_}, shift, shift, @_ },
      'count' => q{ scalar @{_GET_VALUE_} },
      'clear' => q{ @{ _REF_VALUE_ } = () },
      'index' => q{
	  my $list = _REF_VALUE_; 
	  ( scalar(@_) == 1 ) ? $list->[shift]
	  : wantarray ? (map $list->[$_], @_) : [map $list->[$_], @_] 
	},
      'get_set_items' => q{
	  if ( scalar @_ == 0 ) {
	    return _REF_VALUE_;
	  } elsif ( scalar @_ == 1 ) {
	    return _GET_VALUE_->[ shift() ];
	  } else {
	    _BEHAVIOR_{set_items}
	  }
	},
      'set_items' => q{
	! (@_ % 2) or croak "Odd number of items in assigment to _STATIC_ATTR_{name}";
	while ( scalar @_ ) {
	  my ($index, $value) = splice @_, 0, 2;
	  _REF_VALUE_->[ $index ] = $value;
	}
	return _REF_VALUE_;
      },
    }
  }
}

########################################################################

#line 1410

sub hash {
  {
    '-import' => { 'Template::Generic:generic' => '*' },
    'interface' => {
      'default' => { 
	'*'=>'get_set', 
	map {'*_'.$_ => $_} qw(push set keys values delete exists tally clear),
      },
      get_set_items => { '*'=>'get_set_items' },
    },
    'modifier' => {
      '-all' => [ q{ _ENSURE_REF_VALUE_; * } ],
    },
    'code_expr' => { 
      '_ENSURE_REF_VALUE_' => q{ _REF_VALUE_ ||= {}; },
      _HASH_GET_ => q{
	( wantarray ? %{_GET_VALUE_} : _REF_VALUE_ )
      },
      _HASH_GET_VALUE_ => q{
	  ( ref $_[0] eq 'ARRAY' ? @{ _GET_VALUE_ }{ @{ $_[0] } } 
				 : _REF_VALUE_->{ $_[0] } )
      },
      _HASH_SET_ => q{
	! (@_ % 2) or croak "Odd number of items in assigment to _STATIC_ATTR_{name}";
	%{_REF_VALUE_} = @_
      },
      _HASH_PUSH_ => q{
	! (@_ % 2) 
	  or croak "Odd number of items in assigment to _STATIC_ATTR_{name}";
	my $count;
	while ( scalar @_ ) { 
	  local $_ = shift; 
	  _REF_VALUE_->{ $_ } = shift();
	  ++ $count;
	}
	$count;
      },
    },
    'behavior' => {
      'get_set' => q {
	  # If called with no arguments, return hash contents
	  return _HASH_GET_ if (scalar @_ == 0);
	  
	  # If called with a hash ref, act as if contents of hash were passed
	  # local @_ = %{ $_[0] } if ( scalar @_ == 1 and ref $_[0] eq 'HASH' );
	  @_ = %{ $_[0] } if ( scalar @_ == 1 and ref $_[0] eq 'HASH' );
	  
	  # If called with an index, get that value, or a slice for array refs
          return _HASH_GET_VALUE_ if (scalar @_ == 1 );
	
	  # Push on new values and return complete set
	  _HASH_SET_;
	  return _HASH_GET_;
	},

      'get_push' => q{
	  # If called with no arguments, return hash contents
	  return _HASH_GET_ if (scalar @_ == 0);
	  
	  # If called with a hash ref, act as if contents of hash were passed
	  # local @_ = %{ $_[0] } if ( scalar @_ == 1 and ref $_[0] eq 'HASH' );
	  @_ = %{ $_[0] } if ( scalar @_ == 1 and ref $_[0] eq 'HASH' );
	
	  # If called with an index, get that value, or a slice for array refs
          return _HASH_GET_VALUE_ if (scalar @_ == 1 );
	
	  # Push on new values and return complete set
	  _HASH_PUSH_;
	  return _HASH_GET_;
	},
      'get_set_items' => q{
	  if ( scalar @_ == 0 ) {
	    return _REF_VALUE_;
	  } elsif ( scalar @_ == 1 ) {
	    return _REF_VALUE_->{ shift() };
	  } else {
	    while ( scalar @_ ) {
	      my ($index, $value) = splice @_, 0, 2;
	      _REF_VALUE_->{ $index } = $value;
	    }
	    return _REF_VALUE_;
	  }
	},
      'get' => q{ _HASH_GET_ },
      'set' => q{ _HASH_SET_ },
      'push' => q{ 
	  # If called with a hash ref, act as if contents of hash were passed
	  # local @_ = %{ $_[0] } if ( scalar @_ == 1 and ref $_[0] eq 'HASH' );
	  @_ = %{ $_[0] } if ( scalar @_ == 1 and ref $_[0] eq 'HASH' );

	  _HASH_PUSH_ 
	},

      'keys' => q{ keys %{_GET_VALUE_} },
      'values' => q{ values %{_GET_VALUE_} },
      'unique_values' => q{ 
	    values %{ { map { $_=>$_ } values %{_GET_VALUE_} } } 
	},
      'delete' => q{ scalar @_ <= 1 ? delete @{ _REF_VALUE_ }{ $_[0] } 
			      : map { delete @{ _REF_VALUE_ }{ $_ } } (@_) },
      'exists' => q{
	  return 0 unless defined _GET_VALUE_;
	  foreach (@_) { return 0 unless exists ( _REF_VALUE_->{$_} ) }
	  return 1;
	},
      'tally' => q{ map { ++ _REF_VALUE_->{$_} } @_ },
      'clear' => q{ %{ _REF_VALUE_ } = () },
      'ref' => q{ _REF_VALUE_ },
    },
  }
}

########################################################################

#line 1558

sub tiedhash {
  {
    '-import' => { 'Template::Generic:hash' => '*' },
    'modifier' => {
      '-all' => [ q{
	  if ( ! defined _GET_VALUE_ ) {
	    %{ _REF_VALUE_ } = ();
	    tie %{ _REF_VALUE_ }, _ATTR_REQUIRED_{tie}, @{ _ATTR_{args} };
	  }
	  *
	} ],
    },
  }
}

########################################################################

#line 1697

sub hash_of_arrays {
  {
    '-import' => {  'Template::Generic:hash' => '*' },
    'interface' => {
      default => { 
	'*'=>'get', 
	map( ('*_'.$_ => $_ ), qw(keys exists delete pop push shift unshift splice clear count index remove sift last set )),
      },
    },
    'behavior' => {
      'get' => q{
	  my @Result;
	    
	  if ( ! scalar @_ ) {
	    @Result = map @$_, values %{_VALUE_};
	    } elsif ( scalar @_ == 1 and ref ($_[0]) eq 'ARRAY' ) {
	    @Result = map @$_, @{_VALUE_}{@{$_[0]}};
	  } else {
	    my @keys = map { ref ($_) eq 'ARRAY' ? @$_ : $_ }
			grep exists _VALUE_{$_}, @_;
	    @Result = map @$_, @{_VALUE_}{@keys};
	  }
	    
	  return wantarray ? @Result : \@Result;
	},
      'pop' => q{
	  map { pop @{_VALUE_->{$_}} } @_
	},
      'last' => q{
	  map { _VALUE_->{$_}->[-1] } @_
	},
      'push' => q{
	  for ( ( ref ($_[0]) eq 'ARRAY' ? @{shift()} : shift() ) ) {
	    push @{_VALUE_->{$_}}, @_;
	  }
	},
      'shift' => q{
	  map { shift @{_VALUE_->{$_}} } @_
	},
      'unshift' => q{
	  for ( ( ref ($_[0]) eq 'ARRAY' ? @{shift()} : shift() ) ) {
	    unshift @{_VALUE_->{$_}}, @_;
	  }
	},
      'splice' => q{
	  my $key = shift;
	  splice @{ _VALUE_->{$key} }, shift, shift, @_;
	},
      'clear' => q{
	  foreach (@_) { _VALUE_->{$_} = []; }
	},
      'count' => q{
	  my $Result = 0;
	  foreach (@_) {
	    # Avoid autovivifying additional entries.
	    $Result += exists _VALUE_->{$_} ? scalar @{_VALUE_->{$_}} : 0;
	  }
	  return $Result;
	},
      'index' => q{
	  my $key_r = shift;
	  
	  my @Result;
	  my $key;
	  foreach $key ( ( ref ($key_r) eq 'ARRAY' ? @$key_r : $key_r ) ) {
	    my $ary = _VALUE_->{$key};
	    for (@_) {
	      push @Result, ( @{$ary} > $_ ) ? $ary->[$_] : undef;
	    }
	  }
	  return wantarray ? @Result : \@Result;
	},
      'set' => q{
	  my $key_r = shift;
	  
	  croak "_ATTR_{name} expects a key and then index => value pairs.\n"
		if @_ % 2;
	  while ( scalar @_ ) {
	    my $pos = shift;
	    _VALUE_->{$key_r}->[ $pos ] = shift();
	  }
	  return;
	},
      'remove' => q{
	  my $key_r = shift;
	  
	  my $key;
	  foreach $key ( ( ref ($key_r) eq 'ARRAY' ? @$key_r : $key_r ) ) {
	    my $ary = _VALUE_->{$key};
	    foreach ( sort {$b<=>$a} grep $_ < @$ary, @_ ) {
	      splice (@$ary, $_, 1);
	    }
	  }
	  return;
	},
      'sift' => q{
	my %args = ( scalar @_ == 1 and ref $_[0] eq 'HASH' ) ? %{$_[0]} : @_;
	my $hash = _VALUE_;
	my $filter_sr = $args{'filter'}  || sub { $_[0] == $_[1] };
	my $keys_ar   = $args{'keys'} || [ keys %$hash ];
	my $values_ar = $args{'values'}  || [undef];
	
	# This is harder than it looks; reverse means we want to grep out only
	# if *none* of the values matches.  I guess an evaled block, or closure
	# or somesuch is called for.
	#       my $reverse   = $args{'reverse'} || 0;

	my ($key, $i, $value);
	KEY: foreach $key (@$keys_ar) {
	  next KEY unless exists $hash->{$key};
	  INDEX: for ($i = $#{$hash->{$key}}; $i >= 0; $i--) {
	    foreach $value (@$values_ar) {
	      if ( $filter_sr->($value, $hash->{$key}[$i]) ) {
		splice @{$hash->{$key}}, $i, 1;
		next INDEX;
	      }
	    }
	  }
	}
	return;
      },
    },
  }
}

########################################################################

#line 1934

sub object {
  {
    '-import' => { 
      # 'Template::Generic:generic' => '*',
    },
    'interface' => {
      default => { '*'=>'get_set', 'clear_*'=>'clear' },
      get_set_init => { '*'=>'get_set_init', 'clear_*'=>'clear' },
      get_and_set => {'*'=>'get', 'set_*'=>'set', 'clear_*'=>'clear' },
      get_init_and_set => { '*'=>'get_init','set_*'=>'set','clear_*'=>'clear' },
      init_and_get  => { '*'=>'init_and_get', -params=>{ init_method=>'init_*' } },
    },
    'params' => { 
      new_method => 'new' 
    },
    'code_expr' => {
      '_CALL_NEW_AND_STORE_' => q{
	my $new_method = _ATTR_REQUIRED_{new_method};
	my $class = _ATTR_REQUIRED_{'class'};
	_SET_VALUE_{ $class->$new_method(@_) };
      },
    },
    'behavior' => {
      '-import' => { 
	'Template::Generic:scalar' => [ qw( get clear ) ],
      },
      'get_set' => q{
	  if ( scalar @_ ) { 
	    if (ref $_[0] and UNIVERSAL::isa($_[0], _ATTR_REQUIRED_{'class'})) { 
	      _SET_VALUE_{ shift };
	    } else {
	      _CALL_NEW_AND_STORE_
	    }
	  } else {
	    _VALUE_;
	  }
	},
      'set' => q{
	  if ( ! defined $_[0] ) {
	    _SET_VALUE_{ undef };
	  } elsif (ref $_[0] and UNIVERSAL::isa($_[0], _ATTR_REQUIRED_{'class'})) { 
	    _SET_VALUE_{ shift };
	  } else {
	    _CALL_NEW_AND_STORE_
	  }
	},
      'get_init' => q{
	  if ( ! defined _VALUE_ ) {
	    _CALL_NEW_AND_STORE_
	  }
	  _VALUE_;
	},
      'init_and_get' => q{
	  if ( ! defined _VALUE_ ) {
	    my $init_method = _ATTR_REQUIRED_{'init_method'};
	    _SET_VALUE_{ _SELF_->$init_method( @_ ) };
	  } else {
	    _BEHAVIOR_{get}
	  }
	},
      'get_set_init' => q{
	  if (ref $_[0] and UNIVERSAL::isa($_[0], _ATTR_REQUIRED_{'class'})) { 
	    _SET_VALUE_{ shift };
	  } elsif ( ! defined _VALUE_ ) {
	    _CALL_NEW_AND_STORE_
	  }
	  _VALUE_;
	},
      '-subs' => sub { 
	  {
	    'delegate' => sub { my($m_info, $name) = @_; sub { 
	      my $m_name = $m_info->{'name'};
	      my $obj = (shift)->$m_name() 
		or Carp::croak("Can't forward $name because $m_name is empty");
	      $obj->$name(@_) 
	    } },
	    'soft_delegate' => sub { my($m_info, $name) = @_; sub { 
	      my $m_name = $m_info->{'name'};
	      my $obj = (shift)->$m_name() or return;
	      $obj->$name(@_) 
	    } },
	  }
	},
    },
  }
}

########################################################################

#line 2087

sub instance {
  {
    '-import' => { 
      'Template::Generic:object' => '*',
    },
    'interface' => {
      default => 'get_set',
    },
    'code_expr' => {
      '_CALL_NEW_AND_STORE_' => q{
	my $new_method = _ATTR_REQUIRED_{new_method};
	_SET_VALUE_{ (_SELF_)->$new_method(@_) };
      },
    },
  }
}

########################################################################

#line 2140

sub array_of_objects {
  {
    '-import' => { 
      'Template::Generic:array' => '*',
    },
    'params' => {
	new_method => 'new',
      },
    'modifier' => {
      '-all get_set' => q{ _BLESS_ARGS_ * },
      '-all get_push' => q{ _BLESS_ARGS_ * },
      '-all set' => q{ _BLESS_ARGS_ * },
      '-all push' => q{ _BLESS_ARGS_ * },
      '-all unshift' => q{ _BLESS_ARGS_ * },
      # The below two methods are kinda broken, because the new values
      # don't get auto-blessed properly...
      '-all splice' => q{ * },
      '-all set_items' => q{ * },
    },
    'code_expr' => {
      '_BLESS_ARGS_' => q{
	  my $new_method = _ATTR_REQUIRED_{'new_method'};
	  @_ = map {
	    (ref $_ and UNIVERSAL::isa($_, _ATTR_REQUIRED_{class})) ? $_ 
			  : _ATTR_{'class'}->$new_method($_)
	  } @_;
	},
    },
    'behavior' => {
      '-subs' => sub { 
	  {
	    'delegate' => sub { my($m_info, $name) = @_; sub { 
	      my $m_name = $m_info->{'name'};
		map { $_->$name(@_) } (shift)->$m_name() 
	    } },
	  }
	},
    },
  }
}

########################################################################

#line 2221

sub code {
  {
    '-import' => { 
      # 'Template::Generic:generic' => '*',
    },
    'interface' => {
      default => 'call_set',
      call_set => 'call_set',
      method => 'call_method',
    },
    'behavior' => {
      '-import' => { 
	'Template::Generic:scalar' => [ qw( get_set get set clear ) ],
      },
      'call_set' => q{
	  if ( scalar @_ == 1 and ref($_[0]) eq 'CODE') {
	    _SET_VALUE_{ shift }; # Set the subroutine reference
	  } else {
	    &{ _VALUE_ }( @_ ); # Run the subroutine on the given arguments
	  }
	},
      'call_method' => q{
	  if ( scalar @_ == 1 and ref($_[0]) eq 'CODE') {
	    _SET_VALUE_{ shift };	# Set the subroutine reference
	  } else {
	    &{ _VALUE_ }( _SELF_, @_ ); # Run the subroutine on self and args
	  }
	},
    },
  }
}


########################################################################

#line 2299

sub code_or_scalar {
  {
    '-import' => { 'Template::Generic:scalar' => '*' },
    'interface' => {
      default => 'get_set_call',
      get_set => 'get_set_call',
      eiffel => { '*'=>'get_method', 'set_*'=>'set' },
      method => 'get_set_method',
    },
    'params' => {
    },
    'behavior' => {
      'get_call' => q{ 
	  my $value = _GET_VALUE_;
	  ( ref($value) eq 'CODE' ) ? &$value( @_ ) : $value
	},
      'get_method' => q{ 
	  my $value = _GET_VALUE_;
	  ( ref($value) eq 'CODE' ) ? &$value( _SELF_, @_ ) : $value
	},
      'get_set_call' => q{
	  if ( scalar @_ == 1 ) {
	    _BEHAVIOR_{set}
	  } else {
	    _BEHAVIOR_{get_call}
	  }
	},
      'get_set_method' => q{
	  if ( scalar @_ == 1 ) {
	    _BEHAVIOR_{set}
	  } else {
	    _BEHAVIOR_{get_call}
	  }
	},
    },
  }
}


########################################################################

#line 2348

1;

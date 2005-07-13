#line 1 "inc/Class/MakeMethods/Template/Hash.pm - /Library/Perl/5.8.6/Class/MakeMethods/Template/Hash.pm"
package Class::MakeMethods::Template::Hash;

use Class::MakeMethods::Template::Generic '-isasubclass';

$VERSION = 1.008;
use strict;
require 5.0;

sub generic {
  {
    'params' => {
      'hash_key' => '*',
    },
    'code_expr' => { 
      _VALUE_ => '_SELF_->{_STATIC_ATTR_{hash_key}}',
      '-import' => { 'Template::Generic:generic' => '*' },
      _EMPTY_NEW_INSTANCE_ => 'bless {}, _SELF_CLASS_',
      _SET_VALUES_FROM_HASH_ => 'while ( scalar @_ ) { local $_ = shift(); $self->{ $_ } = shift() }'
    },
    'behavior' => {
      'hash_delete' => q{ delete _VALUE_ },
      'hash_exists' => q{ exists _VALUE_ },
    },
    'modifier' => {
      # XXX the below doesn't work because modifiers can't have params,
      # although interfaces can... Either add support for default params
      # in modifiers, or else move this to another class.
      # X Should there be a version which uses caller() instead of target_class?
      'class_keys' => { 'hash_key' => '"*{target_class}::*{name}"' },
    }
  }
}

########################################################################

#line 112

# This is the only one that needs to be specifically defined.
sub bits {
  {
    '-import' => { 'Template::Generic:bits' => '*' },
    'params' => {
      'hash_key' => '*{target_class}__*{template_name}',
    },
  }
}

########################################################################

#line 145

sub struct {
  ( {
    'interface' => {
      default => { 
	  '*'=>'get_set', 'clear_*'=>'clear',
	  'struct_fields'=>'struct_fields', 
	  'struct'=>'struct', 'struct_dump'=>'struct_dump' 
      },
    },
    'params' => {
      'hash_key' => '*{target_class}__*{template_name}',
    },
    'behavior' => {
      '-init' => sub {
	my $m_info = $_[0]; 
	
	$m_info->{class} ||= $m_info->{target_class};
	
	my $class_info = 
	 ($Class::MakeMethods::Template::Hash::struct{$m_info->{class}} ||= []);
	if ( ! defined $m_info->{sfp} ) {
	  foreach ( 0..$#$class_info ) { 
	    if ( $class_info->[$_] eq $m_info->{'name'} ) {
	      $m_info->{sfp} = $_; 
	      last 
	    }
	  }
	  if ( ! defined $m_info->{sfp} ) {
	    push @$class_info, $m_info->{'name'};
	    $m_info->{sfp} = $#$class_info;
	  }
	}
	return;	
      },
      
      'struct_fields' => sub { my $m_info = $_[0]; sub {
	my $class_info = 
	  ( $Class::MakeMethods::Template::Hash::struct{$m_info->{class}} ||= [] );
	  @$class_info;
	}},
      'struct' => sub { my $m_info = $_[0]; sub {
	  my $self = shift;
	  $self->{$m_info->{hash_key}} ||= [];
	  if ( @_ ) { @{$self->{$m_info->{hash_key}}} = @_ }
	  @{$self->{$m_info->{hash_key}}};
	}},
      'struct_dump' => sub { my $m_info = $_[0]; sub {
	  my $self = shift;
	  my $class_info = 
	    ( $Class::MakeMethods::Template::Hash::struct{$m_info->{class}} ||= [] );
	  map { ($_, $self->$_()) } @$class_info;
	}},
      
      'get_set' => sub { my $m_info = $_[0]; sub {
	  my $self = shift;
	  $self->{$m_info->{hash_key}} ||= [];
	
	  if ( @_ ) {
	    $self->{$m_info->{hash_key}}->[ $m_info->{sfp} ] = shift;
	  }
	  $self->{$m_info->{hash_key}}->[ $m_info->{sfp} ];
	}},
      'clear' => sub { my $m_info = $_[0]; sub {
	  my $self = shift;
	  $self->{$m_info->{hash_key}} ||= [];
	  $self->{$m_info->{hash_key}}->[ $m_info->{sfp} ] = undef;
	}},
    },
  } )
}

########################################################################

#line 228

1;

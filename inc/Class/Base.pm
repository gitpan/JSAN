#line 1 "inc/Class/Base.pm - /Library/Perl/5.8.6/Class/Base.pm"
#============================================================= -*-perl-*-
#
# Class::Base
#
# DESCRIPTION
#   Module implementing a common base class from which other modules
#   can be derived.
#
# AUTHOR
#   Andy Wardley    <abw@kfs.org>
#
# COPYRIGHT
#   Copyright (C) 1996-2002 Andy Wardley.  All Rights Reserved.
#
#   This module is free software; you can redistribute it and/or
#   modify it under the same terms as Perl itself.
#
# REVISION
#   $Id: Base.pm,v 1.2 2002/04/05 09:48:51 abw Exp $
#
#========================================================================

package Class::Base;

use strict;

our $VERSION  = '0.03';
our $REVISION = sprintf("%d.%02d", q$Revision: 1.2 $ =~ /(\d+)\.(\d+)/);


#------------------------------------------------------------------------
# new(@config)
# new(\%config)
#
# General purpose constructor method which expects a hash reference of 
# configuration parameters, or a list of name => value pairs which are 
# folded into a hash.  Blesses a hash into an object and calls its 
# init() method, passing the parameter hash reference.  Returns a new
# object derived from Class::Base, or undef on error.
#------------------------------------------------------------------------

sub new {
    my $class  = shift;

    # allow hash ref as first argument, otherwise fold args into hash
    my $config = defined $_[0] && UNIVERSAL::isa($_[0], 'HASH') 
	? shift : { @_ };

    no strict 'refs';
    my $debug = defined $config->{ debug } 
                      ? $config->{ debug }
              : defined $config->{ DEBUG }
                      ? $config->{ DEBUG }
                      : ( ${"$class\::DEBUG"} || 0 );

    my $self = bless {
	_ID    => $config->{ id    } || $config->{ ID    } || $class,
	_DEBUG => $debug,
	_ERROR => '',
    }, $class;

    return $self->init($config)
	|| $class->error($self->error());
}


#------------------------------------------------------------------------
# init()
#
# Initialisation method called by the new() constructor and passing a 
# reference to a hash array containing any configuration items specified
# as constructor arguments.  Should return $self on success or undef on 
# error, via a call to the error() method to set the error message.
#------------------------------------------------------------------------

sub init {
    my ($self, $config) = @_;
    return $self;
}


#------------------------------------------------------------------------
# clone()
#
# Method to perform a simple clone of the current object hash and return
# a new object.
#------------------------------------------------------------------------

sub clone {
    my $self = shift;
    bless { %$self }, ref($self);
}


#------------------------------------------------------------------------
# error()
# error($msg, ...)
# 
# May be called as a class or object method to set or retrieve the 
# package variable $ERROR (class method) or internal member 
# $self->{ _ERROR } (object method).  The presence of parameters indicates
# that the error value should be set.  Undef is then returned.  In the
# abscence of parameters, the current error value is returned.
#------------------------------------------------------------------------

sub error {
    my $self = shift;
    my $errvar;

    { 
	# get a reference to the object or package variable we're munging
	no strict qw( refs );
	$errvar = ref $self ? \$self->{ _ERROR } : \${"$self\::ERROR"};
    }
    if (@_) {
	# don't join if first arg is an object (may force stringification)
	$$errvar = ref($_[0]) ? shift : join('', @_);
	return undef;
    }
    else {
	return $$errvar;
    }
}



#------------------------------------------------------------------------
# id($new_id)
#
# Method to get/set the internal _ID field which is used to identify
# the object for the purposes of debugging, etc.
#------------------------------------------------------------------------

sub id {
    my $self = shift;

    # set _ID with $obj->id('foo')
    return  ($self->{ _ID } = shift) if ref $self && @_;

    # otherwise return id as $self->{ _ID } or class name 
    my $id = $self->{ _ID } if ref $self;
    $id ||= ref($self) || $self;

    return $id;
}


#------------------------------------------------------------------------
# params($vals, @keys)
# params($vals, \@keys)
# params($vals, \%keys)
#
# Utility method to examine the $config hash for any keys specified in
# @keys and copy the values into $self.  Keys should be specified as a 
# list or reference to a list of UPPER CASE names.  The method looks 
# for either the name in either UPPER or lower case in the $config 
# hash and copies the value, if defined, into $self.  The keys can 
# also be specified as a reference to a hash containing default values
# or references to handler subroutines which will be called, passing 
# ($self, $config, $UPPER_KEY_NAME) as arguments.
#------------------------------------------------------------------------

sub params {
    my $self = shift;
    my $vals = shift;
    my ($keys, @names);
    my ($key, $lckey, $default, $value, @values);


    if (@_) {
	if (ref $_[0] eq 'ARRAY') {
	    $keys  = shift;
	    @names = @$keys;
	    $keys  = { map { ($_, undef) } @names };
	}
	elsif (ref $_[0] eq 'HASH') {
	    $keys  = shift;
	    @names = keys %$keys;
	}
	else {
	    @names = @_;
	    $keys  = { map { ($_, undef) } @names };
	}
    }
    else {
	$keys = { };
    }

    foreach $key (@names) {
	$lckey = lc $key;

	# look for value provided in $vals hash
	defined($value = $vals->{ $key })
	    || ($value = $vals->{ $lckey });

	# look for default which may be a code handler
	if (defined ($default = $keys->{ $key })
	    && ref $default eq 'CODE') {
	    eval {
		$value = &$default($self, $key, $value);
	    };
	    return $self->error($@) if $@;
	}
	else {
	    $value = $default unless defined $value;
	    $self->{ $key } = $value if defined $value;
	}
	push(@values, $value);
	delete @$vals{ $key, lc $key };
    }
    return wantarray ? @values : \@values;
}


#------------------------------------------------------------------------
# debug(@args)
#
# Debug method which prints all arguments passed to STDERR if and only if
# the appropriate DEBUG flag(s) are set.  If called as an object method
# where the object has a _DEBUG member defined then the value of that 
# flag is used.  Otherwise, the $DEBUG package variable in the caller's
# class is used as the flag to enable/disable debugging. 
#------------------------------------------------------------------------

sub debug {
    my $self  = shift;
    my ($flag);

    if (ref $self && defined $self->{ _DEBUG }) {
	$flag = $self->{ _DEBUG };
    }
    else {
	# go looking for package variable
	no strict 'refs';
	$self = ref $self || $self;
	$flag = ${"$self\::DEBUG"};
    }

    return unless $flag;

    print STDERR '[', $self->id, '] ', @_;
}


#------------------------------------------------------------------------
# debugging($flag)
#
# Method to turn debugging on/off (when called with an argument) or to 
# retrieve the current debugging status (when called without).  Changes
# to the debugging status are propagated to the $DEBUG variable in the 
# caller's package.
#------------------------------------------------------------------------

sub debugging {
    my $self  = shift;
    my $class = ref $self;
    my $flag;

    no strict 'refs';

    my $dbgvar = ref $self ? \$self->{ _DEBUG } : \${"$self\::DEBUG"};

    return @_ ? ($$dbgvar = shift)
	      :  $$dbgvar;

}


1;


#line 793

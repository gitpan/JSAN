#line 1 "inc/Class/Accessor.pm - /Library/Perl/5.8.6/Class/Accessor.pm"
package Class::Accessor;
require 5.00502;
use strict;
$Class::Accessor::VERSION = '0.19';

#line 128

sub new {
    my($proto, $fields) = @_;
    my($class) = ref $proto || $proto;

    $fields = {} unless defined $fields;

    # make a copy of $fields.
    bless {%$fields}, $class;
}

#line 155

sub mk_accessors {
    my($self, @fields) = @_;

    $self->_mk_accessors('make_accessor', @fields);
}


{
    no strict 'refs';

    sub _mk_accessors {
        my($self, $maker, @fields) = @_;
        my $class = ref $self || $self;

        # So we don't have to do lots of lookups inside the loop.
        $maker = $self->can($maker) unless ref $maker;

        foreach my $field (@fields) {
            if( $field eq 'DESTROY' ) {
                require Carp;
                &Carp::carp("Having a data accessor named DESTROY  in ".
                             "'$class' is unwise.");
            }

            my $accessor = $self->$maker($field);
            my $alias = "_${field}_accessor";

            *{$class."\:\:$field"}  = $accessor
              unless defined &{$class."\:\:$field"};

            *{$class."\:\:$alias"}  = $accessor
              unless defined &{$class."\:\:$alias"};
        }
    }
}

#line 211

sub mk_ro_accessors {
    my($self, @fields) = @_;

    $self->_mk_accessors('make_ro_accessor', @fields);
}

#line 239

sub mk_wo_accessors {
    my($self, @fields) = @_;

    $self->_mk_accessors('make_wo_accessor', @fields);
}

#line 285

sub set {
    my($self, $key) = splice(@_, 0, 2);

    if(@_ == 1) {
        $self->{$key} = $_[0];
    }
    elsif(@_ > 1) {
        $self->{$key} = [@_];
    }
    else {
        require Carp;
        &Carp::confess("Wrong number of arguments received");
    }
}

#line 311

sub get {
    my $self = shift;

    if(@_ == 1) {
        return $self->{$_[0]};
    }
    elsif( @_ > 1 ) {
        return @{$self}{@_};
    }
    else {
        require Carp;
        &Carp::confess("Wrong number of arguments received.");
    }
}

#line 338

sub make_accessor {
    my ($class, $field) = @_;

    # Build a closure around $field.
    return sub {
        my $self = shift;

        if(@_) {
            return $self->set($field, @_);
        }
        else {
            return $self->get($field);
        }
    };
}

#line 365

sub make_ro_accessor {
    my($class, $field) = @_;

    return sub {
        my $self = shift;

        if(@_) {
            my $caller = caller;
            require Carp;
            Carp::croak("'$caller' cannot alter the value of '$field' on ".
                        "objects of class '$class'");
        }
        else {
            return $self->get($field);
        }
    };
}

#line 394

sub make_wo_accessor {
    my($class, $field) = @_;

    return sub {
        my $self = shift;

        unless (@_) {
            my $caller = caller;
            require Carp;
            Carp::croak("'$caller' cannot access the value of '$field' on ".
                        "objects of class '$class'");
        }
        else {
            return $self->set($field, @_);
        }
    };
}

#line 611

1;

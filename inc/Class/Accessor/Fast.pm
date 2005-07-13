#line 1 "inc/Class/Accessor/Fast.pm - /Library/Perl/5.8.6/Class/Accessor/Fast.pm"
package Class::Accessor::Fast;
use base 'Class::Accessor';
use strict;
$Class::Accessor::Fast::VERSION = '0.19';

#line 32

sub make_accessor {
    my($class, $field) = @_;

    return sub {
        my $self = shift;
        return $self->{$field} unless @_;
        $self->{$field} = (@_ == 1 ? $_[0] : [@_]);
    };
}


sub make_ro_accessor {
    my($class, $field) = @_;

    return sub {
        return $_[0]->{$field} unless @_ > 1;
        my $caller = caller;
        require Carp;
        Carp::croak("'$caller' cannot alter the value of '$field' on ".
                    "objects of class '$class'");
    };
}


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
            return $self->{$field} = (@_ == 1 ? $_[0] : [@_]);
        }
    };
}


#line 93

1;

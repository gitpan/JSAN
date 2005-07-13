#line 1 "inc/Log/Log4perl/Config/Watch.pm - /Library/Perl/5.8.6/Log/Log4perl/Config/Watch.pm"
#!/usr/bin/perl
###########################################
use warnings;
use strict;

package Log::Log4perl::Config::Watch;

use constant _INTERNAL_DEBUG => 0;

our $NEXT_CHECK_TIME;
our $SIGNAL_CAUGHT;

###########################################
sub new {
###########################################
    my($class, %options) = @_;

    my $self = { file            => "",
                 check_interval  => 30,
                 signal          => undef,
                 %options,
                 _last_checked_at => 0,
                 _last_timestamp  => 0,
               };

    bless $self, $class;

    if($self->{signal}) {
            # We're in signal mode, set up the handler
        $SIG{$self->{signal}} = sub { $SIGNAL_CAUGHT = 1; };
            # Reset the marker. The handler is going to modify it.
        $SIGNAL_CAUGHT = 0;
    } else {
            # Just called to initialize
        $self->change_detected();
    }

    return $self;
}

###########################################
sub file {
###########################################
    my($self) = @_;

    return $self->{file};
}

###########################################
sub signal {
###########################################
    my($self) = @_;

    return $self->{signal};
}

###########################################
sub check_interval {
###########################################
    my($self) = @_;

    return $self->{check_interval};
}

###########################################
sub change_detected {
###########################################
    my($self, $time) = @_;

    $time = time() unless defined $time;

    print "Calling change_detected (time=$time)\n" if _INTERNAL_DEBUG;

        # Do we need to check?
    if($self->{_last_checked_at} + 
       $self->{check_interval} > $time) {
        print "No need to check\n" if _INTERNAL_DEBUG;
        return ""; # don't need to check, return false
    }
       
    my $new_timestamp = (stat($self->{file}))[9];
       # Sometimes, when the file is being updated, obtaining its
       # timestamp fails. Ignore it, try again later.
    return "" unless defined $new_timestamp;

    $self->{_last_checked_at} = $time;

    # Set global var for optimizations in case we just have one watcher
    # (like in Log::Log4perl)
    $NEXT_CHECK_TIME = $time + $self->{check_interval};

    if($new_timestamp > $self->{_last_timestamp}) {
        $self->{_last_timestamp} = $new_timestamp;
        print "Change detected (store=$new_timestamp)!\n" if _INTERNAL_DEBUG;
        return 1; # Has changed
    }
       
    print "Hasn't changed (file=$new_timestamp ",
          "stored=$self->{_last_timestamp})!\n" if _INTERNAL_DEBUG;
    return "";  # Hasn't changed
}

1;

__END__

#line 201

#line 211

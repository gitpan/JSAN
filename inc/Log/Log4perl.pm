#line 1 "inc/Log/Log4perl.pm - /Library/Perl/5.8.6/Log/Log4perl.pm"
##################################################
package Log::Log4perl;
##################################################

END { local($?); Log::Log4perl::Logger::cleanup(); }

use 5.006;
use strict;
use warnings;

use Log::Log4perl::Util;
use Log::Log4perl::Logger;
use Log::Log4perl::Level;
use Log::Log4perl::Config;
use Log::Log4perl::Appender;

use constant _INTERNAL_DEBUG => 1;

our $VERSION = '0.51';

   # set this to '1' if you're using a wrapper
   # around Log::Log4perl
our $caller_depth = 0;

    #this is a mapping of convenience names to opcode masks used in
    #$ALLOWED_CODE_OPS_IN_CONFIG_FILE below
our %ALLOWED_CODE_OPS = (
    'safe'        => [ ':browse' ],
    'restrictive' => [ ':default' ],
);

    #set this to the opcodes which are allowed when
    #$ALLOW_CODE_IN_CONFIG_FILE is set to a true value
    #if undefined, there are no restrictions on code that can be
    #excuted
our @ALLOWED_CODE_OPS_IN_CONFIG_FILE;

    #this hash lists things that should be exported into the Safe
    #compartment.  The keys are the package the symbol should be
    #exported from and the values are array references to the names
    #of the symbols (including the leading type specifier)
our %VARS_SHARED_WITH_SAFE_COMPARTMENT = (
    main => [ '%ENV' ],
);

    #setting this to a true value will allow Perl code to be executed
    #within the config file.  It works in conjunction with
    #$ALLOWED_CODE_OPS_IN_CONFIG_FILE, which if defined restricts the
    #opcodes which can be executed using the 'Safe' module.
    #setting this to a false value disables code execution in the
    #config file
our $ALLOW_CODE_IN_CONFIG_FILE = 1;

    #arrays in a log message will be joined using this character,
    #see Log::Log4perl::Appender::DBI
our $JOIN_MSG_ARRAY_CHAR = '';

    #version required for XML::DOM, to enable XML Config parsing
    #and XML Config unit tests
our $DOM_VERSION_REQUIRED = '1.29'; 

our $CHATTY_DESTROY_METHODS = 0;

##################################################
sub import {
##################################################
    my($class) = shift;

    no strict qw(refs);

    my $caller_pkg = caller();

    my(%tags) = map { $_ => 1 } @_;

        # Lazy man's logger
    if(exists $tags{':easy'}) {
        $tags{':levels'} = 1;
        $tags{':nowarn'} = 1;
        $tags{'get_logger'} = 1;
    }

    if(exists $tags{get_logger}) {
        # Export get_logger into the calling module's 

        *{"$caller_pkg\::get_logger"} = *get_logger;

        delete $tags{get_logger};
    }

    if(exists $tags{':levels'}) {
        # Export log levels ($DEBUG, $INFO etc.) from Log4perl::Level
        my $caller_pkg = caller();

        for my $key (keys %Log::Log4perl::Level::PRIORITY) {
            my $name  = "$caller_pkg\::$key";
               # Need to split this up in two lines, or CVS will
               # mess it up.
            my $value = $
                        Log::Log4perl::Level::PRIORITY{$key};
            *{"$name"} = \$value;
        }

        delete $tags{':levels'};
    }

        # Lazy man's logger
    if(exists $tags{':easy'}) {
        delete $tags{':easy'};

            # Define default logger object in caller's package
        my $logger = get_logger("$caller_pkg");
        ${$caller_pkg . '::_default_logger'} = $logger;
        
            # Define DEBUG, INFO, etc. routines in caller's package
        for(qw(DEBUG INFO WARN ERROR FATAL)) {
            my $level   = $_;
            my $lclevel = lc($_);
            *{"$caller_pkg\::$_"} = sub { 
                Log::Log4perl::Logger::init_warn() unless 
                    $Log::Log4perl::Logger::INITIALIZED or
                    $Log::Log4perl::Logger::NON_INIT_WARNED;
                $logger->{$level}->($logger, @_, $level);
            };
        }

            # Define LOGDIE, LOGWARN

        *{"$caller_pkg\::LOGDIE"} = sub {
            Log::Log4perl::Logger::init_warn() unless 
                    $Log::Log4perl::Logger::INITIALIZED or
                    $Log::Log4perl::Logger::NON_INIT_WARNED;
            $logger->{FATAL}->($logger, @_, "FATAL");
            CORE::die(Log::Log4perl::Logger::callerline(join '', @_));
        };

        *{"$caller_pkg\::LOGWARN"} = sub { 
            Log::Log4perl::Logger::init_warn() unless 
                    $Log::Log4perl::Logger::INITIALIZED or
                    $Log::Log4perl::Logger::NON_INIT_WARNED;
            $logger->{WARN}->($logger, @_, "WARN");
            CORE::warn(Log::Log4perl::Logger::callerline(join '', @_));
        };
    }

    if(exists $tags{':nowarn'}) {
        $Log::Log4perl::Logger::NON_INIT_WARNED = 1;
        delete $tags{':nowarn'};
    }

    if(exists $tags{':resurrect'}) {
        my $FILTER_MODULE = "Filter::Util::Call";
        if(! Log::Log4perl::Util::module_available($FILTER_MODULE)) {
            die "$FILTER_MODULE required with :unhide" .
                "(install from CPAN)";
        }
        eval "require $FILTER_MODULE" or die "Cannot pull in $FILTER_MODULE";
        Filter::Util::Call::filter_add(
            sub {
                my($status);
                s/^\s*###l4p// if
                    ($status = Filter::Util::Call::filter_read()) > 0;
                $status;
                });
        delete $tags{':resurrect'};
    }

    if(keys %tags) {
        # We received an Option we couldn't understand.
        die "Unknown Option(s): @{[keys %tags]}";
    }
}

##################################################
sub initialized {
##################################################
    return $Log::Log4perl::Logger::INITIALIZED;
}

##################################################
sub new {
##################################################
    die "THIS CLASS ISN'T FOR DIRECT USE. " .
        "PLEASE CHECK 'perldoc " . __PACKAGE__ . "'.";
}

##################################################
sub reset { # Mainly for debugging/testing
##################################################
    # Delegate this to the logger ...
    return Log::Log4perl::Logger->reset();
}

##################################################
sub init_once { # Call init only if it hasn't been
                # called yet.
##################################################
    init(@_) unless $Log::Log4perl::Logger::INITIALIZED;
}

##################################################
sub init { # Read the config file
##################################################
    my($class, @args) = @_;

    #woops, they called ::init instead of ->init, let's be forgiving
    if ($class ne __PACKAGE__) {
        unshift(@args, $class);
    }

    # Delegate this to the config module
    return Log::Log4perl::Config->init(@args);
}

##################################################
sub init_and_watch { 
##################################################
    my($class, @args) = @_;

    #woops, they called ::init instead of ->init, let's be forgiving
    if ($class ne __PACKAGE__) {
        unshift(@args, $class);
    }

    # Delegate this to the config module
    return Log::Log4perl::Config->init_and_watch(@args);
}


##################################################
sub easy_init { # Initialize the root logger with a screen appender
##################################################
    my($class, @args) = @_;

    # Did somebody call us with Log::Log4perl::easy_init()?
    if(ref($class) or $class =~ /^\d+$/) {
        unshift @args, $class;
    }

    # Reset everything first
    Log::Log4perl->reset();

    my @loggers = ();

    my %default = ( level    => $DEBUG,
                    file     => "STDERR",
                    category => "",
                    layout   => "%d %m%n",
                  );

    if(!@args) {
        push @loggers, \%default;
    } else {
        for my $arg (@args) {
            if($arg =~ /^\d+$/) {
                my %logger = (%default, level => $arg);
                push @loggers, \%logger;
            } elsif(ref($arg) eq "HASH") {
                my %logger = (%default, %$arg);
                push @loggers, \%logger;
            }
        }
    }

    for my $logger (@loggers) {

        my $app;

        if($logger->{file} =~ /^stderr$/i) {
            $app = Log::Log4perl::Appender->new(
                "Log::Log4perl::Appender::Screen");
        } elsif($logger->{file} =~ /^stdout$/i) {
            $app = Log::Log4perl::Appender->new(
                "Log::Log4perl::Appender::Screen",
                stderr => 0);
        } elsif($logger->{file} =~ /^(>)?(>)?/) {
            my $mode = ($2 ? "append" : "write");
            $logger->{file} =~ s/>+//g;
            $app = Log::Log4perl::Appender->new(
                "Log::Log4perl::Appender::File",
                filename => $logger->{file},
                mode     => $mode);
        }

        my $layout = Log::Log4perl::Layout::PatternLayout->new(
                                                        $logger->{layout});
        $app->layout($layout);

        my $log = Log::Log4perl->get_logger($logger->{category});
        $log->level($logger->{level});
        $log->add_appender($app);
    }

    $Log::Log4perl::Logger::INITIALIZED = 1;
}

##################################################
sub get_logger {  # Get an instance (shortcut)
##################################################
    my($class, @args) = @_;

    if(!defined $class) {
        # Called as ::get_logger()
        unshift(@args, scalar caller());
    } elsif($class eq __PACKAGE__ and !defined $args[0]) {
        # Called as ->get_logger()
        unshift(@args, scalar caller());
    } elsif($class ne __PACKAGE__) {
        # Called as ::get_logger($category)
        unshift(@args, $class);
    } else {
        # Called as ->get_logger($category)
    }

    # Delegate this to the logger module
    return Log::Log4perl::Logger->get_logger(@args);
}

##################################################
sub appenders {  # Get all defined appenders hashref
##################################################
    return \%Log::Log4perl::Logger::APPENDER_BY_NAME;
}

##################################################
sub appender_thresholds_adjust {  # Readjust appender thresholds
##################################################
        # If someone calls L4p-> and not L4p::
    shift if $_[0] eq __PACKAGE__;
    my($delta, $appenders) = @_;

    if(defined $appenders) {
            # Map names to objects
        $appenders = [map { 
                       die "Unkown appender: '$_'" unless exists
                          $Log::Log4perl::Logger::APPENDER_BY_NAME{
                            $_};
                       $Log::Log4perl::Logger::APPENDER_BY_NAME{
                         $_} 
                      } @$appenders];
    } else {
            # Just hand over all known appenders
        $appenders = [values %{Log::Log4perl::appenders()}] unless 
            defined $appenders;
    }

        # Change all appender thresholds;
    foreach my $app (@$appenders) {
        my $old_thres = $app->threshold();
        my $new_thres;
        if($delta > 0) {
            $new_thres = Log::Log4perl::Level::get_higher_level(
                             $old_thres, $delta);
        } else {
            $new_thres = Log::Log4perl::Level::get_lower_level(
                             $old_thres, -$delta);
        }

        $app->threshold($new_thres);
    }
}

##################################################
sub appender_by_name {  # Get an appender by name
##################################################
        # If someone calls L4p->appender_by_name and not L4p::appender_by_name
    shift if $_[0] eq __PACKAGE__;

    my($name) = @_;

    if(exists $Log::Log4perl::Logger::APPENDER_BY_NAME{
                $name}) {
        return $Log::Log4perl::Logger::APPENDER_BY_NAME{
                 $name}->{appender};
    } else {
        return undef;
    }
}

##################################################
sub eradicate_appender {  # Remove an appender from the system
##################################################
        # If someone calls L4p->... and not L4p::...
    shift if $_[0] eq __PACKAGE__;
    Log::Log4perl::Logger->eradicate_appender(@_);
}

##################################################
sub infiltrate_lwp {  # 
##################################################
    no warnings qw(redefine);

    my $l4p_wrapper = sub {
        my($prio, @message) = @_;
        $Log::Log4perl::caller_depth += 2;
        get_logger(caller(1))->log($prio, @message);
        $Log::Log4perl::caller_depth -= 2;
    };

    *LWP::Debug::trace = sub { 
        $l4p_wrapper->($INFO, @_); 
    };
    *LWP::Debug::conns =
    *LWP::Debug::debug = sub { 
        $l4p_wrapper->($DEBUG, @_); 
    };
}

1;

__END__

#line 2406

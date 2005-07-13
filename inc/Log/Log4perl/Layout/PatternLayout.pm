#line 1 "inc/Log/Log4perl/Layout/PatternLayout.pm - /Library/Perl/5.8.6/Log/Log4perl/Layout/PatternLayout.pm"
##################################################
package Log::Log4perl::Layout::PatternLayout;
##################################################

use 5.006;
use strict;
use warnings;
use Carp;
use Log::Log4perl::Util;
use Log::Log4perl::Level;
use Log::Log4perl::DateFormat;
use Log::Log4perl::NDC;
use Log::Log4perl::MDC;
use File::Spec;

our $TIME_HIRES_AVAILABLE;
our $TIME_HIRES_AVAILABLE_WARNED = 0;
our $HOSTNAME;
our $PROGRAM_START_TIME;

our %GLOBAL_USER_DEFINED_CSPECS = ();

our $CSPECS = 'cCdFHIlLmMnpPrtTxX%';


BEGIN {
    # Check if we've got Time::HiRes. If not, don't make a big fuss,
    # just set a flag so we know later on that we can't have fine-grained
    # time stamps
    $TIME_HIRES_AVAILABLE = 0;
    if(Log::Log4perl::Util::module_available("Time::HiRes")) {
        require Time::HiRes;
        $TIME_HIRES_AVAILABLE = 1;
        $PROGRAM_START_TIME = [Time::HiRes::gettimeofday()];
    } else {
        $PROGRAM_START_TIME = time();
    }

    # Check if we've got Sys::Hostname. If not, just punt.
    $HOSTNAME = "unknown.host";
    if(Log::Log4perl::Util::module_available("Sys::Hostname")) {
        require Sys::Hostname;
        $HOSTNAME = Sys::Hostname::hostname();
    }
}

##################################################
sub current_time {
##################################################
    # Return secs and optionally msecs if we have Time::HiRes
    if($TIME_HIRES_AVAILABLE) {
        return (Time::HiRes::gettimeofday());
    } else {
        return (time(), 0);
    }
}

use base qw(Log::Log4perl::Layout);

no strict qw(refs);

##################################################
sub new {
##################################################
    my $class = shift;
    $class = ref ($class) || $class;

    my $options       = ref $_[0] eq "HASH" ? shift : {};
    my $layout_string = @_ ? shift : '%m%n';
    
    if(exists $options->{ConversionPattern}->{value}) {
        $layout_string = $options->{ConversionPattern}->{value};
    }

    my $self = {
        time_function         => \&current_time,
        format                => undef,
        info_needed           => {},
        stack                 => [],
        CSPECS                => $CSPECS,
        dontCollapseArrayRefs => $options->{dontCollapseArrayRefs}{value},
    };

    if(exists $options->{time_function}) {
        $self->{time_function} = $options->{time_function};
    }

    bless $self, $class;

    #add the global user-defined cspecs
    foreach my $f (keys %GLOBAL_USER_DEFINED_CSPECS){
            #add it to the list of letters
        $self->{CSPECS} .= $f;
             #for globals, the coderef is already evaled, 
        $self->{USER_DEFINED_CSPECS}{$f} = $GLOBAL_USER_DEFINED_CSPECS{$f};
    }

    #add the user-defined cspecs local to this appender
    foreach my $f (keys %{$options->{cspec}}){
        $self->add_layout_cspec($f, $options->{cspec}{$f}{value});
    }

    $self->define($layout_string);

    return $self;
}

##################################################
sub define {
##################################################
    my($self, $format) = @_;

        # If the message contains a %m followed by a newline,
        # make a note of that so that we can cut a superfluous 
        # \n off the message later on
    if($format =~ /%m%n/) {
        $self->{message_chompable} = 1;
    } else {
        $self->{message_chompable} = 0;
    }

    # Parse the format
    $format =~ s/%(-?\d*(?:\.\d+)?) 
                       ([$self->{CSPECS}])
                       (?:{(.*?)})*/
                       rep($self, $1, $2, $3);
                      /gex;

    $self->{printformat} = $format;
}

##################################################
sub rep {
##################################################
    my($self, $num, $op, $curlies) = @_;

    return "%%" if $op eq "%";

    # If it's a %d{...} construct, initialize a simple date
    # format formatter, so that we can quickly render later on.
    # If it's just %d, assume %d{yyyy/MM/dd HH:mm:ss}
    my $sdf;
    if($op eq "d") {
        if(defined $curlies) {
            $sdf = Log::Log4perl::DateFormat->new($curlies);
        } else {
            $sdf = Log::Log4perl::DateFormat->new("yyyy/MM/dd HH:mm:ss");
        }
    }

    push @{$self->{stack}}, [$op, $sdf || $curlies];

    $self->{info_needed}->{$op}++;

    return "%${num}s";
}

##################################################
sub render {
##################################################
    my($self, $message, $category, $priority, $caller_level) = @_;

    $caller_level = 0 unless defined  $caller_level;

    my %info    = ();

    $info{m}    = $message;
        # See 'define'
    chomp $info{m} if $self->{message_chompable};

    my @results = ();

    if($self->{info_needed}->{L} or
       $self->{info_needed}->{F} or
       $self->{info_needed}->{C} or
       $self->{info_needed}->{l} or
       $self->{info_needed}->{M} or
       0
      ) {
        my ($package, $filename, $line, 
            $subroutine, $hasargs,
            $wantarray, $evaltext, $is_require, 
            $hints, $bitmask) = caller($caller_level);

        # If caller() choked because of a whacko caller level,
        # correct undefined values to '[undef]' in order to prevent 
        # warning messages when interpolating later
        unless(defined $bitmask) {
            for($package, 
                $filename, $line,
                $subroutine, $hasargs,
                $wantarray, $evaltext, $is_require,
                $hints, $bitmask) {
                $_ = '[undef]' unless defined $_;
            }
        }

        $info{L} = $line;
        $info{F} = $filename;
        $info{C} = $package;

        if($self->{info_needed}->{M} or
           $self->{info_needed}->{l} or
           0) {
            # To obtain the name of the subroutine which triggered the 
            # logger, we need to go one additional level up.
            my $levels_up = 1; 
            {
                $subroutine = (caller($caller_level+$levels_up))[3];
                    # If we're inside an eval, go up one level further.
                if(defined $subroutine and
                   $subroutine eq "(eval)") {
                    $levels_up++;
                    redo;
                }
            }
            $subroutine = "main::" unless $subroutine;
            $info{M} = $subroutine;
            $info{l} = "$subroutine $filename ($line)";
        }
    }

    $info{X} = "[No curlies defined]";
    $info{x} = Log::Log4perl::NDC->get() if $self->{info_needed}->{x};
    $info{c} = $category;
    $info{d} = 1; # Dummy value, corrected later
    $info{n} = "\n";
    $info{p} = $priority;
    $info{P} = $$;
    $info{H} = $HOSTNAME;

    if($self->{info_needed}->{r}) {
        if($TIME_HIRES_AVAILABLE) {
            $info{r} = 
                int((Time::HiRes::tv_interval ( $PROGRAM_START_TIME ))*1000);
        } else {
            if(! $TIME_HIRES_AVAILABLE_WARNED) {
                $TIME_HIRES_AVAILABLE_WARNED++;
                # warn "Requested %r pattern without installed Time::HiRes\n";
            }
            $info{r} = time() - $PROGRAM_START_TIME;
        }
    }

        # Stack trace wanted?
    if($self->{info_needed}->{T}) {
        my $mess = Carp::longmess(); 
        chomp($mess);
        $mess =~ s/(?:\A\s*at.*\n|^\s*Log::Log4perl.*\n|^\s*)//mg;
        $mess =~ s/\n/, /g;
        $info{T} = $mess;
    }

        # As long as they're not implemented yet ..
    $info{t} = "N/A";

    foreach my $cspec (keys %{$self->{USER_DEFINED_CSPECS}}){
        next unless $self->{info_needed}->{$cspec};
        $info{$cspec} = $self->{USER_DEFINED_CSPECS}->{$cspec}->($self, 
                              $message, $category, $priority, $caller_level+1);
    }

        # Iterate over all info fields on the stack
    for my $e (@{$self->{stack}}) {
        my($op, $curlies) = @$e;
        if(exists $info{$op}) {
            my $result = $info{$op};
            if($curlies) {
                $result = $self->curly_action($op, $curlies, $info{$op});
            } else {
                # just for %d
                if($op eq 'd') {
                    $result = $info{$op}->format($self->{time_function}->());
                }
            }
            $result = "[undef]" unless defined $result;
            push @results, $result;
        } else {
            warn "Format %'$op' not implemented (yet)";
            push @results, "FORMAT-ERROR";
        }
    }

    #print STDERR "sprintf $self->{printformat}--$results[0]--\n";

    return (sprintf $self->{printformat}, @results);
}

##################################################
sub curly_action {
##################################################
    my($self, $ops, $curlies, $data) = @_;

    if($ops eq "c") {
        $data = shrink_category($data, $curlies);
    } elsif($ops eq "C") {
        $data = shrink_category($data, $curlies);
    } elsif($ops eq "X") {
        $data = Log::Log4perl::MDC->get($curlies);
    } elsif($ops eq "d") {
        $data = $curlies->format($self->{time_function}->());
    } elsif($ops eq "F") {
        my @parts = File::Spec->splitdir($data);
            # Limit it to max curlies entries
        if(@parts > $curlies) {
            splice @parts, 0, @parts - $curlies;
        }
        $data = File::Spec->catfile(@parts);
    }

    return $data;
}

##################################################
sub shrink_category {
##################################################
    my($category, $len) = @_;

    my @components = split /\.|::/, $category;

    if(@components > $len) {
        splice @components, 0, @components - $len;
        $category = join '.', @components;
    } 

    return $category;
}

##################################################
sub add_global_cspec {
##################################################
# This is a Class method.
# Accepts a coderef or text
##################################################

    unless($Log::Log4perl::ALLOW_CODE_IN_CONFIG_FILE) {
        die "\$Log::Log4perl::ALLOW_CODE_IN_CONFIG_FILE setting " .
            "prohibits user defined cspecs";
    }

    my ($letter, $perlcode) = @_;

    croak "Illegal value '$letter' in call to add_global_cspec()"
        unless ($letter =~ /^[a-zA-Z]$/);

    croak "Missing argument for perlcode for 'cspec.$letter' ".
          "in call to add_global_cspec()"
        unless $perlcode;

    croak "Please don't redefine built-in cspecs [$CSPECS]\n".
          "like you do for \"cspec.$letter\"\n "
        if ($CSPECS =~/$letter/);

    if (ref $perlcode eq 'CODE') {
        $GLOBAL_USER_DEFINED_CSPECS{$letter} = $perlcode;

    }elsif (! ref $perlcode){
        
        $GLOBAL_USER_DEFINED_CSPECS{$letter} = 
            Log::Log4perl::Config::compile_if_perl($perlcode);

        if ($@) {
            die qq{Compilation failed for your perl code for }.
                qq{"log4j.PatternLayout.cspec.$letter":\n}.
                qq{This is the error message: \t$@\n}.
                qq{This is the code that failed: \n$perlcode\n};
        }

        croak "eval'ing your perlcode for 'log4j.PatternLayout.cspec.$letter' ".
              "doesn't return a coderef \n".
              "Here is the perl code: \n\t$perlcode\n "
            unless (ref $GLOBAL_USER_DEFINED_CSPECS{$letter} eq 'CODE');

    }else{
        croak "I don't know how to handle perlcode=$perlcode ".
              "for 'cspec.$letter' in call to add_global_cspec()";
    }
}

##################################################
sub add_layout_cspec {
##################################################
# object method
# adds a cspec just for this layout
##################################################
    my ($self, $letter, $perlcode) = @_;

    unless($Log::Log4perl::ALLOW_CODE_IN_CONFIG_FILE) {
        die "\$Log::Log4perl::ALLOW_CODE_IN_CONFIG_FILE setting " .
            "prohibits user defined cspecs";
    }

    croak "Illegal value '$letter' in call to add_layout_cspec()"
        unless ($letter =~ /^[a-zA-Z]$/);

    croak "Missing argument for perlcode for 'cspec.$letter' ".
          "in call to add_layout_cspec()"
        unless $perlcode;

    croak "Please don't redefine built-in cspecs [$CSPECS] \n".
          "like you do for 'cspec.$letter'"
        if ($CSPECS =~/$letter/);

    if (ref $perlcode eq 'CODE') {

        $self->{USER_DEFINED_CSPECS}{$letter} = $perlcode;

    }elsif (! ref $perlcode){
        
        $self->{USER_DEFINED_CSPECS}{$letter} =
            Log::Log4perl::Config::compile_if_perl($perlcode);

        if ($@) {
            die qq{Compilation failed for your perl code for }.
                qq{"cspec.$letter":\n}.
                qq{This is the error message: \t$@\n}.
                qq{This is the code that failed: \n$perlcode\n};
        }
        croak "eval'ing your perlcode for 'cspec.$letter' ".
              "doesn't return a coderef \n".
              "Here is the perl code: \n\t$perlcode\n "
            unless (ref $self->{USER_DEFINED_CSPECS}{$letter} eq 'CODE');


    }else{
        croak "I don't know how to handle perlcode=$perlcode ".
              "for 'cspec.$letter' in call to add_layout_cspec()";
    }

    $self->{CSPECS} .= $letter;
}


1;

__END__

#line 658

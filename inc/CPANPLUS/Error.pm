#line 1 "inc/CPANPLUS/Error.pm - /Library/Perl/5.8.6/CPANPLUS/Error.pm"
package CPANPLUS::Error;

use strict;
use CPANPLUS::inc;
use Log::Message private => 0;;

#line 61

BEGIN {
    use Exporter;
    use Params::Check   qw[check];
    use vars            qw[@EXPORT @ISA $ERROR_FH $MSG_FH];

    @ISA        = 'Exporter';
    @EXPORT     = qw[error msg];

    my $log     = new Log::Message;

    for my $func ( @EXPORT ) {
        no strict 'refs';
        *$func = sub {
                        my $msg     = shift;
                        $log->store(
                                message => $msg,
                                tag     => uc $func,
                                level   => $func,
                                extra   => [@_]
                        );
                };
    }

    sub flush {
        return reverse $log->flush;
    }

    sub stack {
        return $log->retrieve( chrono => 1 );
    }

    sub stack_as_string {
        my $class = shift;
        my $trace = shift() ? 1 : 0;

        return join $/, map {
                        '[' . $_->tag . '] [' . $_->when . '] ' .
                        ($trace ? $_->message . ' ' . $_->longmess
                                : $_->message);
                    } __PACKAGE__->stack;
    }
}

#line 120
local $| = 1;
$ERROR_FH   = \*STDERR;
$MSG_FH     = \*STDOUT;

package Log::Message::Handlers;
use Carp ();

{

    sub msg {
        my $self    = shift;
        my $verbose = shift;

        ### so you don't want us to print the msg? ###
        return if defined $verbose && $verbose == 0;

        my $old_fh = select $CPANPLUS::Error::MSG_FH;
        print '['. $self->tag (). '] ' . $self->message . "\n";
        select $old_fh;

        return;
    }

    sub error {
        my $self    = shift;
        my $verbose = shift;

        ### so you don't want us to print the error? ###
        return if defined $verbose && $verbose == 0;

        my $old_fh = select $CPANPLUS::Error::ERROR_FH;

        ### is only going to be 1 for now anyway ###
        my $cb      = (CPANPLUS::Internals->_return_all_objects)[0];

        ### maybe we didn't initialize an internals object (yet) ###
        my $debug   = $cb ? $cb->configure_object->get_conf('debug') : 0;
        my $msg     = '['. $self->tag . '] ' . $self->message;

        ### i'm getting this warning in the test suite:
        ### Ambiguous call resolved as CORE::warn(), qualify as such or
        ### use & at CPANPLUS/Error.pm line 57.
        ### no idea where it's coming from, since there's no 'sub warn'
        ### anywhere to be found, but i'll mark it explicitly nonetheless
        ### --kane
        print $debug ? Carp::shortmess($msg) : $msg . "\n";

        select $old_fh;

        return;
    }
}

1;

# Local variables:
# c-indentation-style: bsd
# c-basic-offset: 4
# indent-tabs-mode: nil
# End:
# vim: expandtab shiftwidth=4:

#line 1 "inc/Log/Log4perl/Config/PropertyConfigurator.pm - /Library/Perl/5.8.6/Log/Log4perl/Config/PropertyConfigurator.pm"
package Log::Log4perl::Config::PropertyConfigurator;
use Log::Log4perl::Config::BaseConfigurator;

use warnings;
use strict;

our @ISA = qw(Log::Log4perl::Config::BaseConfigurator);

#poor man's export
*eval_if_perl = \&Log::Log4perl::Config::eval_if_perl;
*unlog4j      = \&Log::Log4perl::Config::unlog4j;

use constant _INTERNAL_DEBUG => 0;

################################################
sub parse {
################################################
    my($self, $newtext) = @_;

    $self->text($newtext) if defined $newtext;

    my $text = $self->{text};

    die "Config parser has nothing to parse" unless defined $text;

    my $data = {};
    my %var_subst = ();

    while (@$text) {
        $_ = shift @$text;
        s/^\s*#.*//;
        next unless /\S/;
    
        while (/(.+?)\\\s*$/) {
            my $prev = $1;
            my $next = shift(@$text);
            $next =~ s/^ +//g;  #leading spaces
            $next =~ s/^#.*//;
            $_ = $prev. $next;
            chomp;
        }

        if(my($key, $val) = /(\S+?)\s*=\s*(.*)/) {

            $val =~ s/\s+$//;

                # Everything could potentially be a variable assignment
            $var_subst{$key} = $val;

                # Substitute any variables
            $val =~ s/\${(.*?)}/
                      Log::Log4perl::Config::var_subst($1, \%var_subst)/gex;

            $val = eval_if_perl($val) if 
                $key !~ /\.(cspec\.)|warp_message|filter/;
            $key = unlog4j($key);

            my $how_deep = 0;
            my $ptr = $data;
            for my $part (split /\.|::/, $key) {
                $ptr->{$part} = {} unless exists $ptr->{$part};
                $ptr = $ptr->{$part};
                ++$how_deep;
            }

            #here's where we deal with turning multiple values like this:
            # log4j.appender.jabbender.to = him@a.jabber.server
            # log4j.appender.jabbender.to = her@a.jabber.server
            #into an arrayref like this:
            #to => { value => 
            #       ["him\@a.jabber.server", "her\@a.jabber.server"] },
            if (exists $ptr->{value} && $how_deep > 2) {
                if (ref ($ptr->{value}) ne 'ARRAY') {
                    my $temp = $ptr->{value};
                    $ptr->{value} = [];
                    push (@{$ptr->{value}}, $temp);
                }
                push (@{$ptr->{value}}, $val);
            }else{
                $ptr->{value} = $val;
            }
        }
    }
    return $data;
}

1;

__END__

#line 130

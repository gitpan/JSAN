#line 1 "inc/Log/Log4perl/Config/BaseConfigurator.pm - /Library/Perl/5.8.6/Log/Log4perl/Config/BaseConfigurator.pm"
package Log::Log4perl::Config::BaseConfigurator;

use warnings;
use strict;

################################################
sub new {
################################################
    my($class, %options) = @_;

    my $self = { 
        %options,
               };

    $self->file($self->{file}) if exists $self->{file};
    $self->text($self->{text}) if exists $self->{text};

    bless $self, $class;
}

################################################
sub text {
################################################
    my($self, $text) = @_;

        # $text is an array of scalars (lines)
    if(defined $text) {
        if(ref $text eq "ARRAY") {
            $self->{text} = $text;
        } else {
            $self->{text} = [split "\n", $text];
        }
    }

    return $self->{text};
}

################################################
sub file {
################################################
    my($self, $filename) = @_;

    open FILE, "<$filename" or die "Cannot open $filename ($!)";
    $self->{text} = [<FILE>];
    close FILE;
}

################################################
sub parse {
################################################
    die __PACKAGE__ . "::parse() is a virtual method. " .
        "It must be implemented " .
        "in a derived class (currently: ", ref(shift), ")";
}

1;

__END__

#line 199

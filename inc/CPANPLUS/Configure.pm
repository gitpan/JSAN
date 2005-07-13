#line 1 "inc/CPANPLUS/Configure.pm - /Library/Perl/5.8.6/CPANPLUS/Configure.pm"
package CPANPLUS::Configure;
use strict;

use CPANPLUS::inc;
use CPANPLUS::Internals::Constants;
use CPANPLUS::Error                 qw[error msg];

use Log::Message;
use Module::Load                qw[load];
use Params::Check               qw[check];
use Locale::Maketext::Simple    Class => 'CPANPLUS', Style => 'gettext';

use vars                        qw[$AUTOLOAD $VERSION $MIN_CONFIG_VERSION];

local $Params::Check::VERBOSE = 1;

### require, avoid circular use ###
require CPANPLUS::Internals;
$VERSION = $CPANPLUS::Internals::VERSION = $CPANPLUS::Internals::VERSION;

### The minimum required config version
### Update this if we have incompatible config changes
#$MIN_CONFIG_VERSION = $VERSION;
$MIN_CONFIG_VERSION = '0.050_04';


#line 63

sub new {
    my $class = shift;
    my %hash  = @_;

    ### ok, we need to find your config now ###
    $class->_load_cpanplus_config() or return;

    ### minimum version requirement.
    ### this code may change between releases, depending on
    ### compatibillity with previous versions.
    unless( $class->_config_version_sufficient ) {
        error(loc(  "Your config is of version '%1' but '%2' requires ".
                    "a config of '%3' or higher. Your '%4' is of " .
                    "version '%5', but your config requires a version ".
                    "of '%6' or higher. You will need to reconfigure",
                    $CPANPLUS::Config::VERSION, 'CPANPLUS',
                    $MIN_CONFIG_VERSION, 'CPANPLUS', $VERSION,
                    ($CPANPLUS::Config::MIN_CPANPLUS_VERSION || 0) ));
        return;
    }

    my $self = bless {
                    _conf   => CPANPLUS::Config->new(),
                    _error  => Log::Message->new(),
                }, $class;

    unless( $self->_load_args( options => \%hash ) ) {
        error(loc(qq[Unable to initialize configuration!]));
        return;
    }

    return $self;
}


### allow loading of an alternate configuration file ###
sub _load_cpanplus_config {
    my $class = shift;

    ### apparently we loaded it already ###
    return 1 if $INC{'CPANPLUS/Config.pm'};

    my $tried;
    my $env = ENV_CPANPLUS_CONFIG;

    ### check it has length, and is an actual file ###
    if ( defined $ENV{$env} and length $ENV{$env} and
        -f $ENV{$env} and -s _
    ) {
        eval{ load $ENV{$env} };
        $tried++;
        $INC{'CPANPLUS/Config.pm'} = $ENV{$env} unless $@;
    }

    my $ok;
    $@
        ? error( loc("Could not load your personal config: %1: %2",
                    $ENV{$env}, "$@"), "\n",
                loc("Falling back to system-wide config."), "\n" )
        : ($ok = 1) if $tried;

    unless($ok) {
        eval { load CPANPLUS::Config };
        error("$@"), return if $@;
    }

    return 1;
}

### this code may change between releases, depending on backwards
### compatibility between configs.
### if this is returning false, you can also not just use your
### old config as base for your new config -- sorry :(
sub _config_version_sufficient {

    my $fail;

    ### first check if the config is good enough for this version of CPANPLUS
    CONFIG: {
        ### If they're the same, we're done already.
        last CONFIG if $CPANPLUS::Config::VERSION eq $VERSION;

        ### Split the version numbers into a major part and a devel part.
        my $config_version = $CPANPLUS::Config::VERSION;
        $config_version =~ s/_(\d+)$//;
        my $config_devel = $1 || 0;

        my $version = $MIN_CONFIG_VERSION;
        $version =~ s/_(\d+)$//;
        my $devel = $1 || 0;

        ### If the configuration has a newer major version than us,
        ### it's sufficient.
        last CONFIG if $config_version > $version;

        ### If the configuration has the same major version and a newer devel
        ### version than us, it's sufficient.
        last CONFIG if $config_version == $version && $config_devel >= $devel;

        ### ok, the versions are no good, it's WRONG
        $fail++

    }

    ### now check if CPANPLUS is good enough for the config we've loaded
    CPANPLUS: {
        ### we know it failed already...
        last CPANPLUS if $fail;

        ### no minversion specified? that's also too old
        ++$fail && last CPANPLUS 
            unless $CPANPLUS::Config::MIN_CPANPLUS_VERSION;;

        ### If they're the same, we're done already.
        last CPANPLUS if $CPANPLUS::Config::VERSION eq $VERSION;

        ### Split the version numbers into a major part and a devel part.
        my $cp_version = $VERSION;
        $cp_version =~ s/_(\d+)$//;
        my $cp_devel = $1 || 0;

        my $version = $CPANPLUS::Config::MIN_CPANPLUS_VERSION;
        $version =~ s/_(\d+)$//;
        my $devel = $1 || 0;

        ### If cpanplus has a newer major version than what we minimally
        ### require, it's enough
        last CPANPLUS if $cp_version > $version;

        ### If cpanplus has the same major version and a newer devel
        ### version than what we minimally require, it's enough
        last CPANPLUS if $cp_version == $version && $cp_devel >= $devel;

        ### ok, the versions are no good, it's WRONG
        $fail++
    }

    ### Otherwise, the configuration does not have a newer version than us;
    ### it's insufficient.
    return if $fail;

    return 1;
}



#line 221

sub can_save {
    my $self = shift;
    my $env  = ENV_CPANPLUS_CONFIG;
    my $file = shift || $ENV{$env} || $INC{'CPANPLUS/Config.pm'};
    return 1 unless -e $file;

    chmod 0644, $file;
    return (-w $file);
}

#line 243

sub save {
    my $self = shift;
    my $env  = ENV_CPANPLUS_CONFIG;
    my $file = shift || $ENV{$env} || $INC{'CPANPLUS/Config.pm'};

    return unless $self->can_save($file);

    my $time = gmtime;

    load Data::Dumper;
    my $data = Data::Dumper->Dump([$self->conf], ['conf']);

    ## get rid of the bless'ing
    $data =~ s/=\s*bless\s*\(\s*\{/= {/;
    $data =~ s/\s*},\s*'[A-Za-z0-9:]+'\s*\);/\n    };/;

    ### use a variable to make sure the pod parser doesn't snag it
    my $is = '=';

    my $msg = <<_END_OF_CONFIG_;
###############################################
###           CPANPLUS::Config              ###
###  Configuration structure for CPANPLUS   ###
###############################################

#last changed: $time GMT

### minimal pod, so you can find it with perldoc -l, etc
${is}pod

${is}head1 NAME

CPANPLUS::Config

${is}head1 DESCRIPTION

This is your CPANPLUS configuration file. Editing this
config changes the way CPANPLUS will behave

${is}cut

package CPANPLUS::Config;

\$VERSION = "$MIN_CONFIG_VERSION";

\$MIN_CPANPLUS_VERSION = "$CPANPLUS::Config::MIN_CPANPLUS_VERSION";

use strict;

sub new {
    my \$class = shift;

    my $data
    bless(\$conf, \$class);
    return \$conf;

} #new


1;

_END_OF_CONFIG_

    ### make a backup ###
    rename $file, "$file~", if -f $file;

    my $fh = new FileHandle;
    $fh->open(">$file")
        or (error(loc("Could not open '%1' for writing: %2", $file, $!)),
            return );

    $fh->print($msg);
    $fh->close;

    return 1;
}

#line 328

sub conf {
    my $self = shift;
    $self->{_conf} = shift if $_[0];
    return $self->{_conf};
}

#line 344

sub _load_args {
    my $self = shift;
    my %hash = @_;

    my $opts;
    my $tmpl = {
        options => { default => {}, strict_type => 1, store => \$opts },
    };

    my $args = check( $tmpl, \%hash ) or return;

    for my $option ( keys %$opts ) {

        # translate to calling syntax
        my $method;
        if( $option =~ /^_/) {
            ($method = $option) =~ s/^(_)?/$1set_/;
        } else {
            $method = 'set_' . $option;
        }

        $self->$method( %{$opts->{$option}} );
    }

    ### XXX return values?? where does this GO? ###
    #CPANPLUS::Configure->Setup->init( conf => $self )
    #    unless $self->_get_build('make');

    return 1;
}

#line 385

sub options {
    my $self = shift;
    my $conf = $self->conf;
    my %hash = @_;

    my $type;
    my $tmpl = {
        type    => { required       => 1, default   => '',
                     strict_type    => 1, store     => \$type },
    };

    check($tmpl, \%hash) or return;

    return sort keys %{$conf->{$type}} if $conf->{$type};
    return;
}

#line 464

sub AUTOLOAD {
    my $self = shift;
    my $conf = $self->conf;

    unless( scalar @_ ) {
        error loc("No arguments provided!");
        return;
    }

    my $name = $AUTOLOAD;
    $name =~ s/.+:://;

    my ($private, $action, $field) =
                $name =~ m/^(_)?((?:[gs]et|add))_([a-z]+)$/;

    my $type = '';
    $type .= '_'    if $private;
    $type .= $field if $field;

    unless ( exists $conf->{$type} ) {
        error loc("Invalid method type: '%1'", $name);
        return;
    }

    ### retrieve a current value for an existing key ###
    if( $action eq 'get' ) {
        for my $key (@_) {
            my @list = ();

            if( exists $conf->{$type}->{$key} ) {
                push @list, $conf->{$type}->{$key};

            ### XXX EU::AI compatibility hack to provide lookups like in
            ### cpanplus 0.04x; we renamed ->_get_build('base') to
            ### ->get_conf('base')
            } elsif ( $type eq '_build' and $key eq 'base' ) {
                return $self->get_conf($key);  
                
            } else {     
                error loc(q[No such key '%1' in field '%2'], $key, $type);
                return;
            }

            return wantarray ? @list : $list[0];
        }

    ### set an existing key to a new value ###
    } elsif ( $action eq 'set' ) {
        my %args = @_;

        while( my($key,$val) = each %args ) {

            if( exists $conf->{$type}->{$key} ) {
                $conf->{$type}->{$key} = $val;

            } else {
                error loc(q[No such key '%1' in field '%2'], $key, $type);
                return;
            }
        }

        return 1;

    ### add a new key to the config ###
    } elsif ( $action eq 'add' ) {
        my %args = @_;

        while( my($key,$val) = each %args ) {

            if( exists $conf->{$type}->{$key} ) {
                error( loc( q[Key '%1' already exists for field '%2'],
                            $key, $type));
                return;
            } else {
                $conf->{$type}->{$key} = $val;
            }
        }
        return 1;
    } else {

        error loc(q[Unknown action '%1'], $action);
        return;
    }
}

sub DESTROY { 1 };

1;

#line 576

# Local variables:
# c-indentation-style: bsd
# c-basic-offset: 4
# indent-tabs-mode: nil
# End:
# vim: expandtab shiftwidth=4:


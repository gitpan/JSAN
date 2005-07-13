#line 1 "inc/IO/Socket/SSL.pm - /Library/Perl/5.8.6/IO/Socket/SSL.pm"
#!/usr/bin/perl -w
#
# IO::Socket::SSL: 
#    a drop-in replacement for IO::Socket::INET that encapsulates
#    data passed over a network with SSL.
#
# Current Code Shepherd: Peter Behroozi, <behrooz at fas.harvard.edu>
#
# The original version of this module was written by 
# Marko Asplund, <marko.asplund at kronodoc.fi>, who drew from
# Crypt::SSLeay (Net::SSL) by Gisle Aas.
#

package IO::Socket::SSL;

use IO::Socket;
use Net::SSLeay 1.08;
use Carp;
use strict;
use vars qw(@ISA $VERSION $DEBUG $ERROR $GLOBAL_CONTEXT_ARGS);

BEGIN {
    # Declare @ISA, $VERSION, $GLOBAL_CONTEXT_ARGS
    @ISA = qw(IO::Socket::INET);
    $VERSION = '0.96';
    $GLOBAL_CONTEXT_ARGS = {};

    #Make $DEBUG another name for $Net::SSLeay::trace
    *DEBUG = \$Net::SSLeay::trace;

    # Do Net::SSLeay initialization
    Net::SSLeay::load_error_strings();
    Net::SSLeay::SSLeay_add_ssl_algorithms();
    Net::SSLeay::randomize();
}

sub import { foreach (@_) { @ISA=qw(IO::Socket::INET), next if /inet4/i;
			    @ISA=qw(IO::Socket::INET6), next if /inet6/i;
			    $DEBUG=$1 if /debug(\d)/; }}

# You might be expecting to find a new() subroutine here, but that is
# not how IO::Socket::INET works.  All configuration gets performed in
# the calls to configure() and either connect() or accept().

#Call to configure occurs when a new socket is made using
#IO::Socket::INET.  Returns false (empty list) on failure.
sub configure {
    my ($self, $arg_hash) = @_;
    return _invalid_object() unless($self);

    $self->configure_SSL($arg_hash)
	|| return;

    return ($self->SUPER::configure($arg_hash)
	|| $self->error("@ISA configuration failed"));
}

sub configure_SSL {
    my ($self, $arg_hash) = @_;

    my $is_server = $arg_hash->{'SSL_server'} || $arg_hash->{'Listen'} || 0;
    my %default_args =
	('SSL_server'    => $is_server,
	 'SSL_key_file'  => $is_server ? 'certs/server-key.pem'  : 'certs/client-key.pem',
	 'SSL_cert_file' => $is_server ? 'certs/server-cert.pem' : 'certs/client-cert.pem',
	 'SSL_ca_file'   => 'certs/my-ca.pem',
	 'SSL_ca_path'   => 'ca/',
	 'SSL_use_cert'  => $is_server,
	 'SSL_check_crl' => 0,
	 'SSL_version'   => 'sslv23',
	 'SSL_verify_mode' => Net::SSLeay::VERIFY_NONE(),
	 'SSL_verify_callback' => 0,
	 'SSL_cipher_list' => 'ALL:!LOW:!EXP');

    #Replace nonexistent entries with defaults
    $arg_hash = { %default_args, %$GLOBAL_CONTEXT_ARGS, %$arg_hash };

    #Avoid passing undef arguments to Net::SSLeay
    !defined($arg_hash->{$_}) and ($arg_hash->{$_} = '') foreach (keys %$arg_hash);

    ${*$self}{'_SSL_arguments'} = $arg_hash;
    ${*$self}{'_SSL_ctx'} = new IO::Socket::SSL::SSL_Context($arg_hash) || return;
    ${*$self}{'_SSL_opened'} = 1 if ($is_server);

    return $self;
}


#Call to connect occurs when a new client socket is made using
#IO::Socket::INET
sub connect {
    my $self = shift || return _invalid_object();

    my $socket = $self->SUPER::connect(@_)
	|| return $self->error("@ISA connect attempt failed");

    return $self->connect_SSL($socket) || $self->fatal_ssl_error;
}


sub connect_SSL {
    my ($self, $socket) = @_;
    my $arg_hash = ${*$self}{'_SSL_arguments'};
    ${*$self}{'_SSL_opened'}=1;

    my $fileno = ${*$self}{'_SSL_fileno'} = fileno($socket);
    return $self->error("Socket has no fileno") unless (defined $fileno);

    my $ctx = ${*$self}{'_SSL_ctx'};  # Reference to real context
    my $ssl = ${*$self}{'_SSL_object'} = Net::SSLeay::new($ctx->{context})
	|| return $self->error("SSL structure creation failed");

    Net::SSLeay::set_fd($ssl, $fileno)
	|| return $self->error("SSL filehandle association failed");

    Net::SSLeay::set_cipher_list($ssl, $arg_hash->{'SSL_cipher_list'})
	|| return $self->error("Failed to set SSL cipher list");

    my ($addr, $port) = @{$arg_hash}{'PeerAddr','PeerPort'};
    my $session = $ctx->session_cache($addr, $port);
    Net::SSLeay::set_session($ssl, $session) if ($session);

    while (Net::SSLeay::connect($ssl)<1) {
	$self->error("SSL connect attempt failed");
	if ($self->errstr =~ /SSL wants a (write|read) first!/) {
	    require IO::Select;
	    my $sel = new IO::Select($socket);
	    my $timeout = $arg_hash->{Timeout} || undef;
	    next if (($1 eq 'write') ? $sel->can_write($timeout) : $sel->can_read($timeout));
	}
	return;
    }

    if ($ctx->has_session_cache && !$session) {
	$ctx->session_cache($addr, $port, Net::SSLeay::get1_session($ssl));
    }

    tie *{$self}, "IO::Socket::SSL::SSL_HANDLE", $self;

    return $self;
}


#Call to accept occurs when a new client connects to a server using
#IO::Socket::SSL
sub accept {
    my $self = shift || return _invalid_object();
    my $class = shift || 'IO::Socket::SSL';
    my $arg_hash = ${*$self}{'_SSL_arguments'};

    my $socket = $self->SUPER::accept($class)
	|| return $self->error("@ISA accept failed");

    return ($socket->accept_SSL(${*$self}{'_SSL_ctx'}, $arg_hash)
	    || $self->error($ERROR) || $socket->fatal_ssl_error);
}

sub accept_SSL {
    my ($socket, $ctx, $arg_hash) = @_;
    ${*$socket}{'_SSL_arguments'} = { %$arg_hash, SSL_server => 0 };
    ${*$socket}{'_SSL_ctx'} = $ctx;
    ${*$socket}{'_SSL_opened'} = 1;

    my $fileno = ${*$socket}{'_SSL_fileno'} = fileno($socket);
    return $socket->error("Socket has no fileno") unless (defined $fileno);

    my $ssl = ${*$socket}{'_SSL_object'} = Net::SSLeay::new($ctx->{context})
	|| return $socket->error("SSL structure creation failed");

    Net::SSLeay::set_fd($ssl, $fileno)
	|| return $socket->error("SSL filehandle association failed");

    Net::SSLeay::set_cipher_list($ssl, $arg_hash->{'SSL_cipher_list'})
	|| return $socket->error("Failed to set SSL cipher list");

    while (Net::SSLeay::accept($ssl)<1) {
	$socket->error("SSL accept attempt failed");
	if ($socket->errstr =~ /SSL wants a (write|read) first!/) {
	    require IO::Select;
	    my $sel = new IO::Select($socket);
	    my $timeout = $arg_hash->{Timeout} || undef;
	    next if (($1 eq 'write') ? $sel->can_write($timeout) : $sel->can_read($timeout));
	}
	return;
    }

    tie *{$socket}, "IO::Socket::SSL::SSL_HANDLE", $socket;

    return $socket;
}


####### I/O subroutines ########################
sub generic_read {
    my ($self, $read_func, undef, $length, $offset) = @_;
    my $ssl = $self->_get_ssl_object || return;

    my $data = $read_func->($ssl, $length);
    return $self->error("SSL read error") unless (defined $data);

    my $buffer=\$_[2];
    $length = length($data);
    $$buffer ||= '';
    $offset ||= 0;
    if ($offset>length($$buffer)) {
	$$buffer.="\0" x ($offset-length($$buffer));  #mimic behavior of read
    }

    substr($$buffer, $offset, length($$buffer), $data);
    return $length;
}

sub read {
    my $self = shift;
    return $self->generic_read(\&Net::SSLeay::read, @_);
}

sub peek {
    my $self = shift;
    if ($Net::SSLeay::VERSION >= 1.19 && Net::SSLeay::OPENSSL_VERSION_NUMBER() >= 0x0090601f) {
	return $self->generic_read(\&Net::SSLeay::peek, @_);
    } else {
	return $self->error("SSL_peek not supported for Net::SSLeay < v1.19 or OpenSSL < v0.9.6a");
    }
}

sub write {
    my ($self, undef, $length, $offset) = @_;
    my $ssl = $self->_get_ssl_object || return;

    my $buffer = \$_[1];
    my $buf_len = length($$buffer);
    $length ||= $buf_len;
    $offset ||= 0;
    return $self->error("Invalid offset for SSL write") if ($offset>$buf_len);
    return 0 if ($offset==$buf_len);


    my $written = Net::SSLeay::ssl_write_all
	($ssl, \substr($$buffer, $offset, $length));

    return $self->error("SSL write error") if ($written<0);
    return $written;
}

sub print {
    my $self = shift;
    my $ssl = $self->_get_ssl_object || return;

    unless ($\ or $,) {
	foreach my $msg (@_) {
	    next unless defined $msg;
	    defined(Net::SSLeay::write($ssl, $msg))
		|| return $self->error("SSL print error");
	}
    } else {
	defined(Net::SSLeay::write($ssl, join(($, or ''), @_, ($\ or ''))))
	    || return $self->error("SSL print error");
    }
    return 1;
}

sub printf {
    my ($self,$format) = (shift,shift);
    local $\;
    return $self->print(sprintf($format, @_));
}

sub getc {
    my $self = shift;
    my $buffer;
    return $buffer if $self->read($buffer, 1, 0);
}

sub readline {
    my $self = shift;
    my $ssl = $self->_get_ssl_object || return;

    if (wantarray) {
	return split (/^/, Net::SSLeay::ssl_read_all($ssl));
    }
    my $line = Net::SSLeay::ssl_read_until($ssl);
    return ($line ne '') ? $line : $self->error("SSL read error");
}

sub close {
    my $self = shift || return _invalid_object();
    my $close_args = (ref($_[0]) eq 'HASH') ? $_[0] : {@_};
    return $self->error("SSL object already closed") unless (${*$self}{'_SSL_opened'});

    if (my $ssl = ${*$self}{'_SSL_object'}) {
	local $SIG{PIPE} = sub{};
	$close_args->{'SSL_no_shutdown'} or Net::SSLeay::shutdown($ssl);
	Net::SSLeay::free($ssl);
	delete ${*$self}{'_SSL_object'};
    }

    if ($close_args->{'SSL_ctx_free'}) {
	my $ctx = ${*$self}{'_SSL_ctx'};
	delete ${*$self}{'_SSL_ctx'};
	$ctx->DESTROY();
    }

    if ($Net::SSLeay::VERSION>=1.18 and ${*$self}{'_SSL_certificate'}) {
	Net::SSLeay::X509_free(${*$self}{'_SSL_certificate'});
    }

    ${*$self}{'_SSL_opened'} = 0;
    my $arg_hash = ${*$self}{'_SSL_arguments'};
    untie(*$self) unless ($arg_hash->{'SSL_server'}
		       or $close_args->{_SSL_in_DESTROY});

    $self->SUPER::close unless ($close_args->{_SSL_in_DESTROY});
}

sub kill_socket {
    my $self = shift;
    shutdown($self, 2);
    $self->close(SSL_no_shutdown => 1) if (${*$self}{'_SSL_opened'});
    delete(${*$self}{'_SSL_ctx'});
    return;
}

sub fileno {
    my $self = shift;
    return ${*$self}{'_SSL_fileno'} || $self->SUPER::fileno();
}


####### IO::Socket::SSL specific functions #######
# _get_ssl_object is for internal use ONLY!
sub _get_ssl_object {
    my $self = shift;
    my $ssl = ${*$self}{'_SSL_object'};
    return IO::Socket::SSL->error("Undefined SSL object") unless($ssl);
    return $ssl;
}

# default error for undefined arguments
sub _invalid_object {
    return IO::Socket::SSL->error("Undefined IO::Socket::SSL object");
}


sub pending {
    my $ssl = shift()->_get_ssl_object || return;
    return Net::SSLeay::pending($ssl);
}

sub start_SSL {
    my ($class,$socket) = (shift,shift);
    return $class->error("Not a socket") unless(ref($socket));
    my $arg_hash = (ref($_[0]) eq 'HASH') ? $_[0] : {@_};
    my $original_class = ref($socket);

    bless $socket, $class;
    $socket->configure_SSL($arg_hash) or bless($socket, $original_class) && return;
    $arg_hash = ${*$socket}{'_SSL_arguments'};

    my $result = ($arg_hash->{'SSL_server'} ?
		    $socket->accept_SSL (${*$socket}{'_SSL_ctx'}, $arg_hash)
		  : $socket->connect_SSL($socket));

    return $result ? $socket : bless($socket, $original_class) && ();
}

sub new_from_fd {
    my ($class, $fd) = (shift,shift);
    # Check for accidental inclusion of MODE in the argument list
    if (length($_[0]) < 4) {
	(my $mode = $_[0]) =~ tr/+<>//d;
	shift unless length($mode);
    }
    my $handle = IO::Socket::INET->new_from_fd($fd, '+<')
	|| return($class->error("Could not create socket from file descriptor."));

    # Annoying workaround for Perl 5.6.1 and below:
    $handle = IO::Socket::INET->new_from_fd($handle, '+<');

    return $class->start_SSL($handle, @_);
}

sub dump_peer_certificate {
    my $ssl = shift()->_get_ssl_object || return;
    return Net::SSLeay::dump_peer_certificate($ssl);
}

sub peer_certificate {
    my ($self, $field) = @_;
    my $ssl = $self->_get_ssl_object || return;

    my $cert = ${*$self}{'_SSL_certificate'} ||= Net::SSLeay::get_peer_certificate($ssl) ||
	return $self->error("Could not retrieve peer certificate");

    my $name = ($field eq "issuer" or $field eq "authority") ?
	Net::SSLeay::X509_get_issuer_name($cert) :
	Net::SSLeay::X509_get_subject_name($cert);

    return $self->error("Could not retrieve peer certificate $field") unless ($name);
    return Net::SSLeay::X509_NAME_oneline($name);
}

sub get_cipher {
    my $ssl = shift()->_get_ssl_object || return;
    return Net::SSLeay::get_cipher($ssl);
}

sub errstr {
    my $self = shift;
    return ((ref($self) ? ${*$self}{'_SSL_last_err'} : $ERROR) or '');
}

sub fatal_ssl_error {
    my $self = shift;
    my $error_trap = ${*$self}{'_SSL_arguments'}->{'SSL_error_trap'};
    if (defined $error_trap and ref($error_trap) eq 'CODE') {
	$error_trap->($self, $self->errstr()."\n".$self->get_ssleay_error());
    } else { $self->kill_socket; }
    return;
}

sub get_ssleay_error {
    #Net::SSLeay will print out the errors itself unless we explicitly
    #undefine $Net::SSLeay::trace while running print_errs()
    local $Net::SSLeay::trace;
    return Net::SSLeay::print_errs('SSL error: ') || '';
}

sub error {
    my ($self, $error, $destroy_socket) = @_;
    foreach ($error) {
	if (/ print / || / write / || / read / || / connect / || / accept /) {
	    my $ssl = ${*$self}{'_SSL_object'};
	    my $ssl_error = $ssl ? Net::SSLeay::get_error($ssl, -1) : 0;
	    if ($ssl_error == Net::SSLeay::ERROR_WANT_READ()) {
		$error.="\nSSL wants a read first!";
	    } elsif ($ssl_error == Net::SSLeay::ERROR_WANT_WRITE()) {
		$error.="\nSSL wants a write first!";
	    } else {
		$error.=Net::SSLeay::ERR_error_string
		    (Net::SSLeay::ERR_get_error());
	    }
	}
    }
    carp $error."\n".$self->get_ssleay_error() if $DEBUG;
    ${*$self}{'_SSL_last_err'} = $error if (ref($self));
    $ERROR = $error;
    return;
}


sub DESTROY {
    my $self = shift || return;
    $self->close(_SSL_in_DESTROY => 1, SSL_no_shutdown => 1) if (${*$self}{'_SSL_opened'});
    delete(${*$self}{'_SSL_ctx'});
}


#######Extra Backwards Compatibility Functionality#######
sub socket_to_SSL { IO::Socket::SSL->start_SSL(@_); }
sub socketToSSL { IO::Socket::SSL->start_SSL(@_); }
sub sysread { &IO::Socket::SSL::read; }
sub syswrite { &IO::Socket::SSL::write; }
sub issuer_name { return(shift()->peer_certificate("issuer")) }
sub subject_name { return(shift()->peer_certificate("subject")) }
sub get_peer_certificate { return shift() }

sub context_init {
    return($GLOBAL_CONTEXT_ARGS = (ref($_[0]) eq 'HASH') ? $_[0] : {@_});
}

sub set_default_context {
    $GLOBAL_CONTEXT_ARGS->{'SSL_reuse_ctx'} = shift;
}


sub opened {
    my $self = shift;
    return IO::Handle::opened($self) && ${*$self}{'_SSL_opened'};
}

sub want_read {
    my $self = shift;
    return scalar($self->errstr() =~ /SSL wants a read first!/);
}

sub want_write {
    my $self = shift;
    return scalar($self->errstr() =~ /SSL wants a write first!/);
}


#Redundant IO::Handle functionality
sub getline  { return(scalar shift->readline()) }
sub getlines { if (wantarray()) { return(shift->readline()) }
	       else { croak("Use of getlines() not allowed in scalar context");  }}

#Useless IO::Handle functionality
sub truncate { croak("Use of truncate() not allowed with SSL") }
sub stat     { croak("Use of stat() not allowed with SSL"    ) }
sub setbuf   { croak("Use of setbuf() not allowed with SSL"  ) }
sub setvbuf  { croak("Use of setvbuf() not allowed with SSL" ) }
sub fdopen   { croak("Use of fdopen() not allowed with SSL"  ) }

#Unsupported socket functionality
sub ungetc { croak("Use of ungetc() not implemented in IO::Socket::SSL") }
sub send   { croak("Use of send() not implemented in IO::Socket::SSL; use print/printf/syswrite instead") }
sub recv   { croak("Use of recv() not implemented in IO::Socket::SSL; use read/sysread instead") }

package IO::Socket::SSL::SSL_HANDLE;
use strict;
use vars qw($HAVE_WEAKREF);

BEGIN {
    local ($@, $SIG{__DIE__});
    
    #Use Scalar::Util or WeakRef if possible:
    eval "use Scalar::Util qw(weaken isweak); 1" or
	eval "use WeakRef";
    $HAVE_WEAKREF = $@ ? 0 : 1;
}

sub TIEHANDLE {
    my ($class, $handle) = @_;
    weaken($handle) if $HAVE_WEAKREF;
    bless \$handle, $class;
}

sub READ     { return ${shift()}->read    (@_) }
sub READLINE { return ${shift()}->readline(@_) }
sub GETC     { return ${shift()}->getc    (@_) }

sub PRINT    { return ${shift()}->print   (@_) }
sub PRINTF   { return ${shift()}->printf  (@_) }
sub WRITE    { return ${shift()}->write   (@_) }

sub FILENO   { return ${shift()}->fileno  (@_) }

sub CLOSE {                          #<---- Do not change this function!
    my $ssl = ${$_[0]};
    local @_;
    return $ssl->close();
}


package IO::Socket::SSL::SSL_Context;
use strict;

# Note that the final object will actually be a reference to the scalar
# (C-style pointer) returned by Net::SSLeay::CTX_*_new() so that
# it can be blessed.
sub new 
{
    my $class = shift;
    my $arg_hash = (ref($_[0]) eq 'HASH') ? $_[0] : {@_};

    my $ctx_object = $arg_hash->{'SSL_reuse_ctx'};
    if ($ctx_object) {
	return $ctx_object if ($ctx_object->isa('IO::Socket::SSL::SSL_Context') and
			       $ctx_object->{context});
	
	# The following "double entendre" applies only if someone passed
	# in an IO::Socket::SSL object instead of an actual context.
	return $ctx_object if ($ctx_object = ${*$ctx_object}{'_SSL_ctx'});
    }

    my $ctx;
    foreach ($arg_hash->{'SSL_version'}) {
	$ctx = /^sslv2$/i ? Net::SSLeay::CTX_v2_new() :
	       /^sslv3$/i ? Net::SSLeay::CTX_v3_new() :
	       /^tlsv1$/i ? Net::SSLeay::CTX_tlsv1_new() :
	                    Net::SSLeay::CTX_new();
    }

    $ctx || return IO::Socket::SSL->error("SSL Context init failed");

    Net::SSLeay::CTX_set_options($ctx, Net::SSLeay::OP_ALL());

    my ($verify_mode, $verify_cb) = @{$arg_hash}{'SSL_verify_mode','SSL_verify_callback'};
    unless ($verify_mode == Net::SSLeay::VERIFY_NONE())
    {
	&Net::SSLeay::CTX_load_verify_locations
	    ($ctx, @{$arg_hash}{'SSL_ca_file','SSL_ca_path'}) ||
	    return IO::Socket::SSL->error("Invalid certificate authority locations");
    }

    if ($arg_hash->{'SSL_check_crl'}) {
	if (Net::SSLeay::OPENSSL_VERSION_NUMBER() >= 0x0090702f)
	{
	    Net::SSLeay::X509_STORE_CTX_set_flags
		(Net::SSLeay::CTX_get_cert_store($ctx),
		 Net::SSLeay::X509_V_FLAG_CRL_CHECK());
	} else {
	    return IO::Socket::SSL->error("CRL not supported for OpenSSL < v0.9.7b");
	}
    }

    if ($arg_hash->{'SSL_server'} || $arg_hash->{'SSL_use_cert'}) {
	my $filetype = Net::SSLeay::FILETYPE_PEM();

	if ($arg_hash->{'SSL_passwd_cb'}) {
	    if ($Net::SSLeay::VERSION < 1.16) {
		return IO::Socket::SSL->error("Password callbacks are not supported for Net::SSLeay < v1.16");
	    } else {
		Net::SSLeay::CTX_set_default_passwd_cb
		    ($ctx, $arg_hash->{'SSL_passwd_cb'});
	    }
	}

	Net::SSLeay::CTX_use_PrivateKey_file
	    ($ctx, $arg_hash->{'SSL_key_file'}, $filetype)
	    || return IO::Socket::SSL->error("Failed to open Private Key");

	Net::SSLeay::CTX_use_certificate_file
	    ($ctx, $arg_hash->{'SSL_cert_file'}, $filetype)
	    || return IO::Socket::SSL->error("Failed to open Certificate");
    }

    my $verify_callback = $verify_cb &&
	sub {
	    my ($ok, $ctx_store) = @_;
	    my ($cert, $error);
	    if ($ctx_store) {
		$cert = Net::SSLeay::X509_STORE_CTX_get_current_cert($ctx_store);
		$error = Net::SSLeay::X509_STORE_CTX_get_error($ctx_store);
		$cert &&= Net::SSLeay::X509_NAME_oneline(Net::SSLeay::X509_get_issuer_name($cert)).
		    Net::SSLeay::X509_NAME_oneline(Net::SSLeay::X509_get_subject_name($cert));
		$error &&= Net::SSLeay::ERR_error_string($error);
	    }
	    return $verify_cb->($ok, $ctx_store, $cert, $error);
	};

    Net::SSLeay::CTX_set_verify($ctx, $verify_mode, $verify_callback);

    $ctx_object = { context => $ctx };
    if ($arg_hash->{'SSL_session_cache_size'}) {
	if ($Net::SSLeay::VERSION < 1.26) {
	    return IO::Socket::SSL->error("Session caches not supported for Net::SSLeay < v1.26");
	} else {
	    $ctx_object->{'session_cache'} =
		new IO::Socket::SSL::Session_Cache($arg_hash) || undef;
	}
    }

    return bless $ctx_object, $class;
}


sub session_cache {
    my $ctx = shift;
    my $cache = $ctx->{'session_cache'};
    return unless defined $cache;
    my ($addr, $port) = (shift, shift);
    my $key = "$addr:$port";
    my $session = shift;

    return (defined($session) ? $cache->add_session($key, $session)
	                      : $cache->get_session($key));
}

sub has_session_cache {
    my $ctx = shift;
    return (defined $ctx->{'session_cache'});
}


sub DESTROY {
    my $self = shift;
    $self->{context} and Net::SSLeay::CTX_free($self->{context});
    delete(@{$self}{'context','session_cache'});
}


package IO::Socket::SSL::Session_Cache;
use strict;

sub new {
    my ($class, $arg_hash) = @_;
    my $cache = { _maxsize => $arg_hash->{'SSL_session_cache_size'}};
    return unless ($cache->{_maxsize} > 0);
    return bless $cache, $class;
}


sub get_session {
    my ($self, $key) = @_;
    my $session = $self->{$key} || return;
    return $session->{session} if ($self->{'_head'} eq $session);
    $session->{prev}->{next} = $session->{next};
    $session->{next}->{prev} = $session->{prev};
    $session->{next} = $self->{'_head'};
    $session->{prev} = $self->{'_head'}->{prev};
    $self->{'_head'}->{prev} = $self->{'_head'}->{prev}->{next} = $session;
    $self->{'_head'} = $session;
    return $session->{session};
}

sub add_session {
    my ($self, $key, $val) = @_;
    
    return if ($key eq '_maxsize' or $key eq '_head');

    if ((keys %$self) > $self->{'_maxsize'} + 1) {
	my $last = $self->{'_head'}->{prev};
	&Net::SSLeay::SESSION_free($last->{session});
	delete($self->{$last->{key}});
	$self->{'_head'}->{prev} = $self->{'_head'}->{prev}->{prev};
	delete($self->{'_head'}) if ($self->{'_maxsize'} == 1);
    }

    my $session = $self->{$key} = { session => $val, key => $key };

    if ($self->{'_head'}) {
	$session->{next} = $self->{'_head'};
	$session->{prev} = $self->{'_head'}->{prev};
	$self->{'_head'}->{prev}->{next} = $session;
	$self->{'_head'}->{prev} = $session;
    } else {
	$session->{next} = $session->{prev} = $session;
    }
    $self->{'_head'} = $session;
    return $session;
}

sub DESTROY {
    my $self = shift;
    delete(@{$self}{'_head','_maxsize'});
    foreach my $key (keys %$self) {
	Net::SSLeay::SESSION_free($self->{$key}->{session});
    }
} 


'True Value';


#line 1226

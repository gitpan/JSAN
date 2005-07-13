#line 1 "inc/Module/Build.pm - /Library/Perl/5.8.6/Module/Build.pm"
package Module::Build;

# This module doesn't do much of anything itself, it inherits from the
# modules that do the real work.  The only real thing it has to do is
# figure out which OS-specific module to pull in.  Many of the
# OS-specific modules don't do anything either - most of the work is
# done in Module::Build::Base.

use strict;
use File::Spec ();
use File::Path ();
use File::Basename ();

use Module::Build::Base;

use vars qw($VERSION @ISA);
@ISA = qw(Module::Build::Base);
$VERSION = '0.2611';
$VERSION = eval $VERSION;

# Okay, this is the brute-force method of finding out what kind of
# platform we're on.  I don't know of a systematic way.  These values
# came from the latest (bleadperl) perlport.pod.

my %OSTYPES = qw(
		 aix       Unix
		 bsdos     Unix
		 dgux      Unix
		 dynixptx  Unix
		 freebsd   Unix
		 linux     Unix
		 hpux      Unix
		 irix      Unix
		 darwin    Unix
		 machten   Unix
		 next      Unix
		 openbsd   Unix
		 netbsd    Unix
		 dec_osf   Unix
		 svr4      Unix
		 svr5      Unix
		 sco_sv    Unix
		 unicos    Unix
		 unicosmk  Unix
		 solaris   Unix
		 sunos     Unix
		 cygwin    Unix
		 os2       Unix
		 
		 dos       Windows
		 MSWin32   Windows

		 os390     EBCDIC
		 os400     EBCDIC
		 posix-bc  EBCDIC
		 vmesa     EBCDIC

		 MacOS     MacOS
		 VMS       VMS
		 VOS       VOS
		 riscos    RiscOS
		 amigaos   Amiga
		 mpeix     MPEiX
		);

sub _interpose_module {
  my ($self, $mod) = @_;
  eval "use $mod";
  die $@ if $@;

  no strict 'refs';
  my $top_class = $mod;
  while (@{"${top_class}::ISA"}) {
    last if ${"${top_class}::ISA"}[0] eq $ISA[0];
    $top_class = ${"${top_class}::ISA"}[0];
  }

  @{"${top_class}::ISA"} = @ISA;
  @ISA = ($mod);
}

if (grep {-e File::Spec->catfile($_, qw(Module Build Platform), $^O) . '.pm'} @INC) {
  __PACKAGE__->_interpose_module("Module::Build::Platform::$^O");

} elsif (exists $OSTYPES{$^O}) {
  __PACKAGE__->_interpose_module("Module::Build::Platform::$OSTYPES{$^O}");

} else {
  warn "Unknown OS type '$^O' - using default settings\n";
}

sub os_type { $OSTYPES{$^O} }

1;
__END__


#line 1911

#line 1 "inc/Module/Build/Platform/os2.pm - /Library/Perl/5.8.6/Module/Build/Platform/os2.pm"
package Module::Build::Platform::os2;

use strict;
use Module::Build::Platform::Unix;

use vars qw(@ISA);
@ISA = qw(Module::Build::Platform::Unix);

sub manpage_separator { '.' }

sub need_prelink_c { 1 }

# Apparently C compilation is pretty broken here, just disable it
# until we figure it out
sub have_c_compiler { 0 }

1;
__END__


#line 41

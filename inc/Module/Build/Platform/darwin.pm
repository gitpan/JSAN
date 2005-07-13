#line 1 "inc/Module/Build/Platform/darwin.pm - /Library/Perl/5.8.6/Module/Build/Platform/darwin.pm"
package Module::Build::Platform::darwin;

use strict;
use Module::Build::Platform::Unix;

use vars qw(@ISA);
@ISA = qw(Module::Build::Platform::Unix);

sub compile_c {
  my ($self, $file) = @_;

  # Perhaps they'll fix this in later versions, so don't tinker if it's fixed
  return $self->SUPER::compile_c($file) unless $self->{config}{ccflags} =~ /-flat_namespace/;

  # -flat_namespace isn't a compile flag, it's a linker flag.  But
  # it's mistakenly in Config.pm as both.  Make the correction here.
  local $self->{config}{ccflags} = $self->{config}{ccflags};
  $self->{config}{ccflags} =~ s/-flat_namespace//;
  $self->SUPER::compile_c($file);
}


1;
__END__


#line 47

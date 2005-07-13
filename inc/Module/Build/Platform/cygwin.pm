#line 1 "inc/Module/Build/Platform/cygwin.pm - /Library/Perl/5.8.6/Module/Build/Platform/cygwin.pm"
package Module::Build::Platform::cygwin;

use strict;
use Module::Build::Platform::Unix;

use vars qw(@ISA);
@ISA = qw(Module::Build::Platform::Unix);

sub link_c {
  my ($self, $to, $file_base) = @_;
  my ($cf, $p) = ($self->{config}, $self->{properties}); # For convenience
  my $flags = $p->{extra_linker_flags};
  local $p->{extra_linker_flags} = ['-L'.File::Spec->catdir($cf->{archlibexp}, 'CORE'),
				    '-lperl',
				    ref $flags ? @$flags : $self->split_like_shell($flags)];
  return $self->SUPER::link_c($to, $file_base);
}

sub manpage_separator {
   '.'
}

1;
__END__


#line 47

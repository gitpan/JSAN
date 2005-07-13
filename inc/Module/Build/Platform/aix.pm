#line 1 "inc/Module/Build/Platform/aix.pm - /Library/Perl/5.8.6/Module/Build/Platform/aix.pm"
package Module::Build::Platform::aix;

use strict;
use Module::Build::Platform::Unix;

use vars qw(@ISA);
@ISA = qw(Module::Build::Platform::Unix);

sub need_prelink_c { 1 }

sub link_c {
  my ($self, $to, $file_base) = @_;
  my $cf = $self->{config};

  $file_base =~ tr/"//d; # remove any quotes
  my $perl_inc = File::Spec->catdir($cf->{archlibexp}, 'CORE'); #location of perl.exp

  # Massage some very naughty bits in %Config
  local $cf->{lddlflags} = $cf->{lddlflags};
  for ($cf->{lddlflags}) {
    s/\Q$(BASEEXT)\E/$file_base/;
    s/\Q$(PERL_INC)\E/$perl_inc/;
  }

  return $self->SUPER::link_c($to, $file_base);
}


1;
__END__


#line 53

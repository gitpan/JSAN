#line 1 "inc/ExtUtils/MM_BeOS.pm - /System/Library/Perl/5.8.6/ExtUtils/MM_BeOS.pm"
package ExtUtils::MM_BeOS;

#line 20

use Config;
use File::Spec;
require ExtUtils::MM_Any;
require ExtUtils::MM_Unix;

use vars qw(@ISA $VERSION);
@ISA = qw( ExtUtils::MM_Any ExtUtils::MM_Unix );
$VERSION = 1.04;


#line 36

sub os_flavor {
    return('BeOS');
}

#line 46

sub init_linker {
    my($self) = shift;

    $self->{PERL_ARCHIVE} ||= 
      File::Spec->catdir('$(PERL_INC)',$Config{libperl});
    $self->{PERL_ARCHIVE_AFTER} ||= '';
    $self->{EXPORT_LIST}  ||= '';
}

=back

1;
__END__


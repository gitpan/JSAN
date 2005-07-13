#line 1 "inc/Log/Log4perl/Util.pm - /Library/Perl/5.8.6/Log/Log4perl/Util.pm"
package Log::Log4perl::Util;

use File::Spec;

##################################################
sub module_available {  # Check if a module is available
##################################################
# This has to be here, otherwise the following 'use'
# statements will fail.
##################################################
    my($full_name) = @_;

    my $relpath = File::Spec->catfile(split /::/, $full_name) . '.pm';

        # Work around a bug in Activestate's "perlapp", which uses
        # forward slashes instead of Win32 ones.
    my $relpath_with_forward_slashes = 
        join('/', (split /::/, $full_name)) . '.pm';

    return 1 if exists $INC{$relpath} or
                exists $INC{$relpath_with_forward_slashes};
    
    foreach my $dir (@INC) {
        if(ref $dir) {
            # This is fairly obscure 'require'-functionality, nevertheless
            # trying to implement them as diligently as possible. For
            # details, check "perldoc -f require".
            if(ref $dir eq "CODE") {
                return 1 if $dir->($dir, $relpath);
            } elsif(ref $dir eq "ARRAY") {
                return 1 if $dir->[0]->($dir, $relpath);
            } elsif(ref $dir and 
                    ref $dir !~ /^(GLOB|SCALAR|HASH|REF|LVALUE)$/) {
                return 1 if $dir->INC();
            }
        } else {
            # That's the regular case
            return 1 if -r File::Spec->catfile($dir, $relpath);
        }
    }
              
    return 0;
}

1;

__END__

#line 70
#line 1 "inc/Module/Pluggable.pm - /Library/Perl/5.8.6/Module/Pluggable.pm"
package Module::Pluggable;

use strict;
use vars qw($VERSION);
use File::Find ();
use File::Basename;
use File::Spec::Functions qw(splitdir catdir abs2rel);
use Carp qw(croak carp);


# ObQuote:
# Bob Porter: Looks like you've been missing a lot of work lately. 
# Peter Gibbons: I wouldn't say I've been missing it, Bob! 


$VERSION = '2.8';

#line 234


sub import {
    my $class   = shift;
    my %opts    = @_;

    # override 'require'
    $opts{'require'} = 1 if $opts{'inner'};

    if ($opts{'par'}) {
    
    }

    my ($package, $filename) = caller;

    # automatically turn a scalar search path or namespace into a arrayref
    for (qw(search_path search_dirs)) {
        $opts{$_} = [ $opts{$_} ] if exists $opts{$_} && !ref($opts{$_});
    }


    # the default name for the method is 'plugins'
    my $sub = $opts{'sub_name'} || 'plugins';
  

    # get our package 
    my ($pkg) = $opts{'package'} || $package;

    my $subroutine = sub {
        my $self = shift;


        # default search path is '<Module>::<Name>::Plugin'
        $opts{'search_path'} = ["${pkg}::Plugin"] unless $opts{'search_path'}; 

        # predeclare
        my @plugins;

        
        # check to see if we're running under test
        my @SEARCHDIR = exists $INC{"blib.pm"} && $filename =~ m!(^|/)blib/! ? grep {/blib/} @INC : @INC;

        # add any search_dir params
        unshift @SEARCHDIR, @{$opts{'search_dirs'}} if defined $opts{'search_dirs'};


        # go through our @INC
        foreach my $dir (@SEARCHDIR) {

            # and each directory in our search path
            foreach my $searchpath (@{$opts{'search_path'}}) {
                # create the search directory in a cross platform goodness way
                my $sp = catdir($dir, (split /::/, $searchpath));
                # if it doesn't exist or it's not a dir then skip it
                next unless ( -e $sp && -d _ ); # Use the cached stat the second time


                # find all the .pm files in it
                # this isn't perfect and won't find multiple plugins per file
                #my $cwd = Cwd::getcwd;
                my @files = ();
                File::Find::find( { no_chdir => 1, wanted =>
                    sub { # Inlined from File::Find::Rule C< name => '*.pm' >
                        return unless $File::Find::name =~ /\.pm$/;
                        (my $path = $File::Find::name) =~ s#^\\./##;
                        push @files, $path;
                    }},
                    $sp );
                #chdir $cwd;

                # foreach one we've found 
                foreach my $file (@files) {
                    next unless $file =~ m!\.pm$!;
                    # parse the file to get the name
                    my ($name, $directory) = fileparse($file, qr{\.pm});
                    $directory = abs2rel($directory, $sp);
                    # then create the class name in a cross platform way
                    $directory =~ s/^[a-z]://i if($^O =~ /MSWin32|dos/);       # remove volume
                    my $plugin = join "::", splitdir catdir($searchpath, $directory, $name);
                    if (defined $opts{'instantiate'} || $opts{'require'}) { 
                        eval "CORE::require $plugin";
                        carp "Couldn't require $plugin : $@" if $@;
                    }
                    push @plugins, $plugin;
                }

                # now add stuff that may have been in package
                # NOTE we should probably use all the stuff we've been given already
                # but then we can't unload it :(
                unless (exists $opts{inner} && !$opts{inner}) {
                    for (list_packages($searchpath)) {
                        if (defined $opts{'instantiate'} || $opts{'require'}) {
                            eval "CORE::require $_";
                            # *No warnings here* 
                            # next if $@;
                        }    
                        push @plugins, $_;
                    } # for list packages
                } # unless inner
            } # foreach $searchpath
        } # foreach $dir




        # push @plugins, map { print STDERR "$_\n"; $_->require } list_packages($_) for (@{$opts{'search_path'}});
        
        # return blank unless we've found anything
        return () unless @plugins;


        # exceptions
        my %only;   
        my %except; 
        my $only;
        my $except;

        if (defined $opts{'only'}) {
            if (ref($opts{'only'}) eq 'ARRAY') {
                %only   = map { $_ => 1 } @{$opts{'only'}};
            } elsif (ref($opts{'only'}) eq 'Regexp') {
                $only = $opts{'only'}
            } elsif (ref($opts{'only'}) eq '') {
                $only{$opts{'only'}} = 1;
            }
        }
        

        if (defined $opts{'except'}) {
            if (ref($opts{'except'}) eq 'ARRAY') {
                %except   = map { $_ => 1 } @{$opts{'except'}};
            } elsif (ref($opts{'except'}) eq 'Regexp') {
                $except = $opts{'except'}
            } elsif (ref($opts{'except'}) eq '') {
                $except{$opts{'except'}} = 1;
            }
        }






        # remove duplicates
        # probably not necessary but hey ho
        my %plugins;
        for(@plugins) {
            next if ($_ =~ /::::ISA::CACHE$/); 
            next if (keys %only   && !$only{$_}     );
            next unless (!defined $only || m!$only! );

            next if (keys %except &&  $except{$_}   );
            next if (defined $except &&  m!$except! );
            $plugins{$_} = 1;
        }

        # are we instantiating or requring?
        if (defined $opts{'instantiate'}) {
            my $method = $opts{'instantiate'};
            return map { $_->$method(@_) } keys %plugins;
        } else { 
            # no? just return the names
            return keys %plugins;
        }


    };


    my $searchsub = sub {
              my $self = shift;
              my ($action,@paths) = @_;
 
              push @{$opts{'search_path'}}, @paths    if($action eq 'add');
              $opts{'search_path'}       = \@paths    if($action eq 'new');
              return $opts{'search_path'};
    };


    no strict 'refs';
    no warnings 'redefine';
    *{"$pkg\::$sub"} = $subroutine;
    *{"$pkg\::search_path"} = $searchsub;
}


sub list_packages {
            my $pack = shift; $pack .= "::" unless $pack =~ m!::$!;

            no strict 'refs';
            my @packs;
            for (grep !/^main::$/, grep /::$/, keys %{$pack})
            {
                s!::$!!;
                my @children = list_packages($pack.$_);
                push @packs, "$pack$_" unless @children or /^::/; 
                push @packs, @children;
            }
            return @packs;
}


1;

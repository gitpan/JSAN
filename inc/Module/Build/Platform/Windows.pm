#line 1 "inc/Module/Build/Platform/Windows.pm - /Library/Perl/5.8.6/Module/Build/Platform/Windows.pm"
package Module::Build::Platform::Windows;

use strict;

use File::Basename;
use File::Spec;

use Module::Build::Base;

use vars qw(@ISA);
@ISA = qw(Module::Build::Base);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  my $cf = $self->{config};

  # Inherit from an appropriate compiler driver class
  unshift @ISA, "Module::Build::Platform::Windows::" . $self->compiler_type;

  # Find 'pl2bat.bat' utility used for installing perl scripts.
  # This search is probably overkill, as I've never met a MSWin32 perl
  # where these locations differed from each other.
  my @potential_dirs = map { File::Spec->canonpath($_) }
    @${cf}{qw(installscript installbin installsitebin installvendorbin)},
    File::Basename::dirname($self->{properties}{perl});

  foreach my $dir (@potential_dirs) {
    my $potential_file = File::Spec->catfile($dir, 'pl2bat.bat');
    if ( -f $potential_file && !-d _ ) {
      $cf->{pl2bat} = $potential_file;
      last;
    }
  }

  return $self;
}

sub resume {
  my $class = shift;
  my $self = $class->SUPER::resume(@_);

  # Inherit from an appropriate compiler driver class
  unshift @ISA, "Module::Build::Platform::Windows::" . $self->compiler_type;
  return $self;
}

sub compiler_type {
  my $self = shift;
  my $cc = $self->{config}{cc};

  return (  $cc =~ /cl(\.exe)?$/ ? 'MSVC'
	  : $cc =~ /bcc32(\.exe)?$/ ? 'BCC'
	  : 'GCC');
}

sub compile_c {
  my ($self, $file) = @_;
  my ($cf, $p) = ($self->{config}, $self->{properties});

  my ($basename, $srcdir) =
    ( File::Basename::fileparse($file, '\.[^.]+$') )[0,1];

  my %spec = (
    srcdir      => $srcdir,
    builddir    => $srcdir,
    basename    => $basename,
    source      => $file,
    output      => File::Spec->catfile($srcdir, $basename) . $cf->{obj_ext},
    cc          => $cf->{cc},
    cflags      => [
                     $self->split_like_shell($cf->{ccflags}),
                     $self->split_like_shell($cf->{cccdlflags}),
                   ],
    optimize    => [ $self->split_like_shell($cf->{optimize})    ],
    defines     => [ '' ],
    includes    => $p->{include_dirs} || [],
    perlinc     => [
                     File::Spec->catdir($cf->{archlib}, 'CORE'),
                     $self->split_like_shell($cf->{incpath}),
                   ],
    use_scripts => 1, # XXX provide user option to change this???
  );

  $self->add_to_cleanup($spec{output});

  return $spec{output}
    if $self->up_to_date($spec{source}, $spec{output});

  $self->normalize_filespecs(
    \$spec{source},
    \$spec{output},
     $spec{includes},
     $spec{perlinc},
  );

  # Add -I flag to includes, *once*
  foreach my $path ( @{ $spec{includes} || [] },
                     @{ $spec{perlinc}  || [] } ) {
    $path = '-I' . $path unless $path =~ /-I/;
  }

  my @cmds = $self->format_compiler_cmd(%spec);
  while ( my $cmd = shift @cmds ) {
    $self->do_system( @$cmd )
      or die "error building $cf->{dlext} file from '$file'";
  }

  return $spec{output};
}

sub need_prelink_c { 1 }

sub link_c {
  my ($self, $to, $file_base) = @_;
  my ($cf, $p) = ($self->{config}, $self->{properties});

  my $basename = File::Basename::basename( $file_base );
  my $mylib = File::Spec->catfile( $to, "$basename.$cf->{dlext}" );

  my %spec = (
    srcdir        => File::Basename::dirname($file_base),
    builddir      => $to,
    basename      => $basename,
    startup       => [ ],
    objects       => [ "$file_base$cf->{obj_ext}", @{$p->{objects} || []} ],
    libs          => [ ],
    output        => $mylib,
    ld            => $cf->{ld},
    libperl       => $cf->{libperl},
    perllibs      => [ $self->split_like_shell($cf->{perllibs})  ],
    libpath       => [ $self->split_like_shell($cf->{libpth})    ],
    lddlflags     => [ $self->split_like_shell($cf->{lddlflags}) ],
    other_ldflags => [ $self->split_like_shell($self->{properties}{extra_linker_flags} || '') ],
    use_scripts   => 1, # XXX provide user option to change this???
  );

  $spec{srcdir}   = File::Spec->canonpath( $spec{srcdir}   );
  $spec{builddir} = File::Spec->canonpath( $spec{builddir} );

  $spec{output}    ||= File::Spec->catfile( $spec{builddir},
                                            $spec{basename}  . $cf->{dlext}   );
  $spec{implib}    ||= File::Spec->catfile( $spec{builddir},
                                            $spec{basename}  . $cf->{lib_ext} );
  $spec{explib}    ||= File::Spec->catfile( $spec{builddir},
                                            $spec{basename}  . '.exp'  );
  $spec{def_file}  ||= File::Spec->catfile( $spec{srcdir}  ,
                                            $spec{basename}  . '.def'  );
  $spec{base_file} ||= File::Spec->catfile( $spec{srcdir}  ,
                                            $spec{basename}  . '.base' );

  $self->add_to_cleanup(
    grep defined,
    @{[ @spec{qw(output implib explib def_file base_file map_file)} ]}
  );

  return if $self->up_to_date( $spec{objects}, $spec{output} );

  foreach my $opt ( qw(output implib explib def_file map_file base_file) ) {
    $self->normalize_filespecs( \$spec{$opt} );
  }

  foreach my $opt ( qw(libpath startup objects) ) {
    $self->normalize_filespecs( $spec{$opt} );
  }

  $self->prelink_c( $to, $file_base );

  my @cmds = $self->format_linker_cmd(%spec);
  while ( my $cmd = shift @cmds ) {
    $self->do_system( @$cmd );
  }

  return $spec{output};
}

# canonize & quote paths
sub normalize_filespecs {
  my ($self, @specs) = @_;
  foreach my $spec ( grep defined, @specs ) {
    if ( ref $spec eq 'ARRAY') {
      $self->normalize_filespecs( map {\$_} grep defined, @$spec )
    } elsif ( ref $spec eq 'SCALAR' ) {
      $$spec =~ tr/"//d if $$spec;
      next unless $$spec;
      $$spec = '"' . File::Spec->canonpath($$spec) . '"';
    } else {
      die "Don't know how to normalize " . (ref $spec || $spec) . "\n";
    }
  }
}

sub _generic_write_compiler_script {
  my ($self, %spec) = @_;

  my $script = File::Spec->catfile( $spec{srcdir},
                                    $spec{basename} . '.ccs' );

  $self->add_to_cleanup($script);

  print "Generating script '$script'\n";

  open( SCRIPT, ">$script" )
    or die( "Could not create script '$script': $!" );

  print SCRIPT join( "\n",
    map { ref $_ ? @{$_} : $_ }
    grep defined,
    delete(
      @spec{ qw(includes cflags optimize defines perlinc) } )
  );

  close SCRIPT;

  push @{$spec{includes}}, qq{\@"$script"};

  return %spec;
}

sub make_executable {
  my $self = shift;
  $self->SUPER::make_executable(@_);

  my $pl2bat = $self->{config}{pl2bat};

  if ( defined($pl2bat) && length($pl2bat) ) {
    foreach my $script (@_) {
      # Don't run 'pl2bat.bat' for the 'Build' script;
      # there is no easy way to get the resulting 'Build.bat'
      # to delete itself when doing a 'Build realclean'.
      next if ( $script eq $self->{properties}{build_script} );

      (my $script_bat = $script) =~ s/\.plx?//i;
      $script_bat .= '.bat' unless $script_bat =~ /\.bat$/i;

      my $status = $self->do_system($pl2bat, '<', $script, '>', $script_bat);
      if ( $status && -f $script_bat ) {
        $self->SUPER::make_executable($script_bat);
      } else {
        warn "Unable to convert '$script' to an executable.\n";
      }
    }
  } else {
    warn "Could not find 'pl2bat.bat' utility needed to make scripts executable.\n"
       . "Unable to convert scripts ( " . join(', ', @_) . " ) to executables.\n";
  }
}


sub manpage_separator {
    return '.';
}

sub split_like_shell {
  # As it turns out, Windows command-parsing is very different from
  # Unix command-parsing.  Double-quotes mean different things,
  # backslashes don't necessarily mean escapes, and so on.  So we
  # can't use Text::ParseWords::shellwords() to break a command string
  # into words.  The algorithm below was bashed out by Randy and Ken
  # (mostly Randy), and there are a lot of regression tests, so we
  # should feel free to adjust if desired.
  
  (my $self, local $_) = @_;
  
  return @$_ if defined() && UNIVERSAL::isa($_, 'ARRAY');
  
  my @argv;
  return @argv unless defined() && length();
  
  my $arg = '';
  my( $i, $quote_mode ) = ( 0, 0 );
  
  while ( $i < length() ) {
    
    my $ch      = substr( $_, $i  , 1 );
    my $next_ch = substr( $_, $i+1, 1 );
    
    if ( $ch eq '\\' && $next_ch eq '"' ) {
      $arg .= '"';
      $i++;
    } elsif ( $ch eq '\\' && $next_ch eq '\\' ) {
      $arg .= '\\';
      $i++;
    } elsif ( $ch eq '"' && $next_ch eq '"' && $quote_mode ) {
      $quote_mode = !$quote_mode;
      $arg .= '"';
      $i++;
    } elsif ( $ch eq '"' && $next_ch eq '"' && !$quote_mode &&
	      ( $i + 2 == length()  ||
		substr( $_, $i + 2, 1 ) eq ' ' )
	    ) { # for cases like: a"" => [ 'a' ]
      push( @argv, $arg );
      $arg = '';
      $i += 2;
    } elsif ( $ch eq '"' ) {
      $quote_mode = !$quote_mode;
    } elsif ( $ch eq ' ' && !$quote_mode ) {
      push( @argv, $arg ) if $arg;
      $arg = '';
      ++$i while substr( $_, $i + 1, 1 ) eq ' ';
    } else {
      $arg .= $ch;
    }
    
    $i++;
  }
  
  push( @argv, $arg ) if defined( $arg ) && length( $arg );
  return @argv;
}

1;

########################################################################

#line 333

########################################################################
package Module::Build::Platform::Windows::MSVC;

sub format_compiler_cmd {
  my ($self, %spec) = @_;

  %spec = $self->write_compiler_script(%spec)
    if $spec{use_scripts};

  return [ grep {defined && length} (
    $spec{cc},'-nologo','-c',
    @{$spec{includes}}      ,
    @{$spec{cflags}}        ,
    @{$spec{optimize}}      ,
    @{$spec{defines}}       ,
    @{$spec{perlinc}}       ,
    "-Fo$spec{output}"      ,
    $spec{source}           ,
  ) ];
}

sub write_compiler_script {
  my $self = shift;
  $self->_generic_write_compiler_script(@_);
}

sub format_linker_cmd {
  my ($self, %spec) = @_;

  foreach my $path ( @{$spec{libpath}} ) {
    $path = "-libpath:$path";
  }

  $spec{def_file}  &&= '-def:'    . $spec{def_file};
  $spec{output}    &&= '-out:'    . $spec{output};
  $spec{implib}    &&= '-implib:' . $spec{implib};
  $spec{map_file}  &&= '-map:'    . $spec{map_file};

  %spec = $self->write_linker_script(%spec)
    if $spec{use_scripts};

  return [ grep {defined && length} (
    $spec{ld}               ,
    @{$spec{lddlflags}}     ,
    @{$spec{libpath}}       ,
    @{$spec{other_ldflags}} ,
    @{$spec{startup}}       ,
    @{$spec{objects}}       ,
    $spec{map_file}         ,
    $spec{libperl}          ,
    @{$spec{perllibs}}      ,
    $spec{def_file}         ,
    $spec{implib}           ,
    $spec{output}           ,
  ) ];
}

sub write_linker_script {
  my ($self, %spec) = @_;

  my $script = File::Spec->catfile( $spec{srcdir},
                                    $spec{basename} . '.lds' );

  $self->add_to_cleanup($script);

  print "Generating script '$script'\n";

  open( SCRIPT, ">$script" )
    or die( "Could not create script '$script': $!" );

  print SCRIPT join( "\n",
    map { ref $_ ? @{$_} : $_ }
    grep defined,
    delete(
      @spec{ qw(lddlflags libpath other_ldflags
                startup objects libperl perllibs
                def_file implib map_file)            } )
  );

  close SCRIPT;

  push @{$spec{lddlflags}}, qq{\@"$script"};

  return %spec;
}

1;

########################################################################
package Module::Build::Platform::Windows::BCC;

sub format_compiler_cmd {
  my ($self, %spec) = @_;

  %spec = $self->write_compiler_script(%spec)
    if $spec{use_scripts};

  return [ grep {defined && length} (
    $spec{cc}, '-c'         ,
    @{$spec{includes}}      ,
    @{$spec{cflags}}        ,
    @{$spec{optimize}}      ,
    @{$spec{defines}}       ,
    @{$spec{perlinc}}       ,
    "-o$spec{output}"       ,
    $spec{source}           ,
  ) ];
}

sub write_compiler_script {
  my $self = shift;
  $self->_generic_write_compiler_script(@_);
}

sub format_linker_cmd {
  my ($self, %spec) = @_;

  foreach my $path ( @{$spec{libpath}} ) {
    $path = "-L$path";
  }

  push( @{$spec{startup}}, 'c0d32.obj' )
    unless ( $spec{starup} && @{$spec{startup}} );

  %spec = $self->write_linker_script(%spec)
    if $spec{use_scripts};

  return [ grep {defined && length} (
    $spec{ld}               ,
    @{$spec{lddlflags}}     ,
    @{$spec{libpath}}       ,
    @{$spec{other_ldflags}} ,
    @{$spec{startup}}       ,
    @{$spec{objects}}       , ',',
    $spec{output}           , ',',
    $spec{map_file}         , ',',
    $spec{libperl}          ,
    @{$spec{perllibs}}      , ',',
    $spec{def_file}
  ) ];
}

sub write_linker_script {
  my ($self, %spec) = @_;

  # To work around Borlands "unique" commandline syntax,
  # two scripts are used:

  my $ld_script = File::Spec->catfile( $spec{srcdir},
                                       $spec{basename} . '.lds' );
  my $ld_libs   = File::Spec->catfile( $spec{srcdir},
                                       $spec{basename} . '.lbs' );

  $self->add_to_cleanup($ld_script, $ld_libs);

  print "Generating scripts '$ld_script' and '$ld_libs'.\n";

  # Script 1: contains options & names of object files.
  open( LD_SCRIPT, ">$ld_script" )
    or die( "Could not create linker script '$ld_script': $!" );

  print LD_SCRIPT join( " +\n",
    map { @{$_} }
    grep defined,
    delete(
      @spec{ qw(lddlflags libpath other_ldflags startup objects) } )
  );

  close LD_SCRIPT;

  # Script 2: contains name of libs to link against.
  open( LD_LIBS, ">$ld_libs" )
    or die( "Could not create linker script '$ld_libs': $!" );

  print LD_LIBS join( " +\n",
     (delete $spec{libperl}  || ''),
    @{delete $spec{perllibs} || []},
  );

  close LD_LIBS;

  push @{$spec{lddlflags}}, qq{\@"$ld_script"};
  push @{$spec{perllibs}},  qq{\@"$ld_libs"};

  return %spec;
}

1;

########################################################################
package Module::Build::Platform::Windows::GCC;

sub format_compiler_cmd {
  my ($self, %spec) = @_;

  return [ grep {defined && length} (
    $spec{cc}, '-c'         ,
    @{$spec{includes}}      ,
    @{$spec{cflags}}        ,
    @{$spec{optimize}}      ,
    @{$spec{defines}}       ,
    @{$spec{perlinc}}       ,
    '-o', $spec{output}     ,
    $spec{source}           ,
  ) ];
}

sub format_linker_cmd {
  my ($self, %spec) = @_;

  # The Config.pm variable 'libperl' is hardcoded to the full name
  # of the perl import library (i.e. 'libperl56.a'). GCC will not
  # find it unless the 'lib' prefix & the extension are stripped.
  $spec{libperl} =~ s/^(?:lib)?([^.]+).*$/-l$1/;

  unshift( @{$spec{other_ldflags}}, '-nostartfiles' )
    if ( $spec{startup} && @{$spec{startup}} );

  # From ExtUtils::MM_Win32:
  #
  ## one thing for GCC/Mingw32:
  ## we try to overcome non-relocateable-DLL problems by generating
  ##    a (hopefully unique) image-base from the dll's name
  ## -- BKS, 10-19-1999
  File::Basename::basename( $spec{output} ) =~ /(....)(.{0,4})/;
  $spec{image_base} = sprintf( "0x%x0000", unpack('n', $1 ^ $2) );

  %spec = $self->write_linker_script(%spec)
    if $spec{use_scripts};

  foreach my $path ( @{$spec{libpath}} ) {
    $path = "-L$path";
  }

  my @cmds; # Stores the series of commands needed to build the module.

  push @cmds, [
    'dlltool', '--def'        , $spec{def_file},
               '--output-exp' , $spec{explib}
  ];

  push @cmds, [ grep {defined && length} (
    $spec{ld}                 ,
    '-o', $spec{output}       ,
    "-Wl,--base-file,$spec{base_file}"   ,
    "-Wl,--image-base,$spec{image_base}" ,
    @{$spec{lddlflags}}       ,
    @{$spec{libpath}}         ,
    @{$spec{startup}}         ,
    @{$spec{objects}}         ,
    @{$spec{other_ldflags}}   ,
    $spec{libperl}            ,
    @{$spec{perllibs}}        ,
    $spec{explib}             ,
    $spec{map_file} ? ('-Map', $spec{map_file}) : ''
  ) ];

  push @cmds, [
    'dlltool', '--def'        , $spec{def_file},
               '--output-exp' , $spec{explib},
               '--base-file'  , $spec{base_file}
  ];

  push @cmds, [ grep {defined && length} (
    $spec{ld}                 ,
    '-o', $spec{output}       ,
    "-Wl,--image-base,$spec{image_base}" ,
    @{$spec{lddlflags}}       ,
    @{$spec{libpath}}         ,
    @{$spec{startup}}         ,
    @{$spec{objects}}         ,
    @{$spec{other_ldflags}}   ,
    $spec{libperl}            ,
    @{$spec{perllibs}}        ,
    $spec{explib}             ,
    $spec{map_file} ? ('-Map', $spec{map_file}) : ''
  ) ];

  return @cmds;
}

sub write_linker_script {
  my ($self, %spec) = @_;

  my $script = File::Spec->catfile( $spec{srcdir},
                                    $spec{basename} . '.lds' );

  $self->add_to_cleanup($script);

  print "Generating script '$script'\n";

  open( SCRIPT, ">$script" )
    or die( "Could not create script '$script': $!" );

  print( SCRIPT 'SEARCH_DIR(' . $_ . ")\n" )
    for @{delete $spec{libpath} || []};

  # gcc takes only one startup file, so the first object in startup is
  # specified as the startup file and any others are shifted into the
  # beginning of the list of objects.
  if ( $spec{startup} && @{$spec{startup}} ) {
    print SCRIPT 'STARTUP(' . shift( @{$spec{startup}} ) . ")\n";
    unshift @{$spec{objects}},
      @{delete $spec{startup} || []};
  }

  print SCRIPT 'INPUT(' . join( ',',
    @{delete $spec{objects}  || []}
  ) . ")\n";

  print SCRIPT 'INPUT(' . join( ' ',
     (delete $spec{libperl}  || ''),
    @{delete $spec{perllibs} || []},
  ) . ")\n";

  close SCRIPT;

  push @{$spec{other_ldflags}}, '"' . $script . '"';

  return %spec;
}

1;

__END__

#line 686
#line 1 "inc/Module/Build/Platform/MacOS.pm - /Library/Perl/5.8.6/Module/Build/Platform/MacOS.pm"
package Module::Build::Platform::MacOS;

use strict;
use Module::Build::Base;
use base qw(Module::Build::Base);

use ExtUtils::Install;

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(@_);
  
  # $Config{sitelib} and $Config{sitearch} are, unfortunately, missing.
  $self->{config}{sitelib}  ||= $self->{config}{installsitelib};
  $self->{config}{sitearch} ||= $self->{config}{installsitearch};
  
  # For some reason $Config{startperl} is filled with a bunch of crap.
  $self->{config}{startperl} =~ s/.*Exit \{Status\}\s//;
  
  return $self;
}

sub make_executable {
  my $self = shift;
  require MacPerl;
  foreach (@_) {
    MacPerl::SetFileInfo('McPL', 'TEXT', $_);
  }
}

sub dispatch {
  my $self = shift;

  if( !@_ and !@ARGV ) {
    require MacPerl;
      
    # What comes first in the action list.
    my @action_list = qw(build test install);
    my %actions = map {+($_, 1)} $self->known_actions;
    delete @actions{@action_list};
    push @action_list, sort { $a cmp $b } keys %actions;

    my %toolserver = map {+$_ => 1} qw(test disttest diff testdb);
    foreach (@action_list) {
      $_ .= ' *' if $toolserver{$_};
    }
    
    my $cmd = MacPerl::Pick("What build command? ('*' requires ToolServer)", @action_list);
    return unless defined $cmd;
    $cmd =~ s/ \*$//;
    $ARGV[0] = ($cmd);
    
    my $args = MacPerl::Ask('Any extra arguments?  (ie. verbose=1)', '');
    return unless defined $args;
    push @ARGV, $self->split_like_shell($args);
  }
  
  $self->SUPER::dispatch(@_);
}

sub ACTION_realclean {
  my $self = shift;
  chmod 0666, $self->{properties}{build_script};
  $self->SUPER::ACTION_realclean;
}

# ExtUtils::Install has a hard-coded '.' directory in versions less
# than 1.30.  We use a sneaky trick to turn that into ':'.
#
# Note that we do it here in a cross-platform way, so this code could
# actually go in Module::Build::Base.  But we put it here to be less
# intrusive for other platforms.

sub ACTION_install {
  my $self = shift;
  
  return $self->SUPER::ACTION_install(@_)
    if eval {ExtUtils::Install->VERSION('1.30'); 1};
    
  local $^W = 0; # Avoid a 'redefine' warning
  local *ExtUtils::Install::find = sub {
    my ($code, @dirs) = @_;

    @dirs = map { $_ eq '.' ? File::Spec->curdir : $_ } @dirs;

    return File::Find::find($code, @dirs);
  };
  
  return $self->SUPER::ACTION_install(@_);
}

sub need_prelink_c { 1 }

1;
__END__

#line 145

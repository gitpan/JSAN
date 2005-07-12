package JSAN::Shell;
use strict;
use warnings;

use JSAN::Index;
use LWP::Simple qw[mirror is_success get];
use base qw[Class::Accessor::Fast];
use File::Temp qw[tempdir];
use Cwd;
use File::Path;

our $SHELL;

__PACKAGE__->mk_accessors(qw[_index my_mirror]);
sub new {
    return $SHELL if $SHELL;
    my ($class) = shift;
    my $self = $class->SUPER::new({@_});
    $self->my_mirror('http://openjsan.org') unless $self->my_mirror;
    return $SHELL = $self;
}

sub index {
    my ($self) = @_;
    return $self->_index if $self->_index;
    $self->_index(JSAN::Index->new);
    return $self->_index;
}

sub install {
    my ($self, $lib, $prefix) = @_;
    die "You must supply a prefix to install to" unless $prefix;
    mkpath($prefix);
    my $library = $self->index->library->retrieve($lib);
    die "No such library $lib" unless $library;
    
    my $release = $library->release;
    my $link = join '', $self->my_mirror, $release->source;
    my $dir  = tempdir(CLEANUP => 0);
    my $file = (split /\//, $link)[-1];
    print $release->source . " -> $dir/$file\n";
    my $tarball = get($link);
    die "Downloading dist [$link] failed." unless $tarball;
    
    my $pwd = getcwd();
    chdir "$dir";
    print "Unpacking $file\n";
    open DIST, "> $file" or die $!;
    print DIST $tarball;
    close DIST;
    `tar xzvf $file`;

    print "Installing libraries to $prefix\n";
    chdir join '-', $release->distribution->name, $release->version;
    `cp -r lib/* $prefix`;

    chdir $pwd;
}

sub index_create {
    my ($self) = @_;
    my $mirror = join '/', $self->my_mirror, 'index.yaml';
    JSAN::Index->create_index_db($mirror);
}
sub index_get {
    my ($self) = @_;
    my $rc = mirror($self->my_mirror . "/index.sqlite", $JSAN::Index::INDEX_DB);
    die "Could not mirror index" unless -e $JSAN::Index::INDEX_DB;
    print "Downloaded index.\n";
}

1;

__END__

=head1 NAME

JSAN::Shell -- JavaScript Archive Network (JSAN) Shell Backend

=head1 AUTHOR

Casey West <F<casey@geeknest.com>>.

=head1 COPYRIGHT

  Copyright (c) 2005 Casey West.  All rights reserved.
  This module is free software; you can redistribute it and/or modify it
  under the same terms as Perl itself.

=cut


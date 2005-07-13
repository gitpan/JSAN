#line 1 "inc/MLDBM.pm - /System/Library/Perl/Extras/5.8.6/MLDBM.pm"
#
# MLDBM.pm
#
# store multi-level hash structure in single level tied hash (read DBM)
#
# Documentation at the __END__
#
# Gurusamy Sarathy <gsar@umich.edu>
# Raphael Manfredi <Raphael_Manfredi@grenoble.hp.com>
#

require 5.004;
use strict;

####################################################################
package MLDBM::Serializer;	## deferred

use Carp;

#
# The serialization interface comprises of just three methods:
# new(), serialize() and deserialize().  Only the last two are
# _required_ to be implemented by any MLDBM serialization wrapper.
#

sub new { bless {}, shift };

sub serialize { confess "deferred" };

sub deserialize { confess "deferred" };


#
# Attributes:
#
#    dumpmeth:
#	the preferred dumping method.
#
#    removetaint:
#	untainting flag; when true, data will be untainted after
#	extraction from the database.
#
#    key:
#	the magic string used to recognize non-natively stored data.
#
# Attribute access methods:
#
#	These defaults allow readonly access. Sub-class may override
#	them to allow write access if any of these attributes
#	makes sense for it.
#

sub DumpMeth	{
    my $s = shift;
    confess "can't set dumpmeth with " . ref($s) if @_;
    $s->_attrib('dumpmeth');
}

sub RemoveTaint	{
    my $s = shift;
    confess "can't set untaint with " . ref($s) if @_;
    $s->_attrib('removetaint');
}

sub Key	{
    my $s = shift;
    confess "can't set key with " . ref($s) if @_;
    $s->_attrib('key');
}

sub _attrib {
    my ($s, $a, $v) = @_;
    if (ref $s and @_ > 2) {
	$s->{$a} = $v;
	return $s;
    }
    $s->{$a};
}

####################################################################
package MLDBM;

$MLDBM::VERSION = $MLDBM::VERSION = '2.01';

require Tie::Hash;
@MLDBM::ISA = 'Tie::Hash';

use Carp;

#
# the DB package to use (we default to SDBM since it comes with perl)
# you might want to change this default to something more efficient
# like DB_File (you can always override it in the use list)
#
$MLDBM::UseDB		= "SDBM_File"		unless $MLDBM::UseDB;
$MLDBM::Serializer	= 'Data::Dumper'	unless $MLDBM::Serializer;
$MLDBM::Key		= '$MlDbM'		unless $MLDBM::Key;
$MLDBM::DumpMeth	= ""			unless $MLDBM::DumpMeth;
$MLDBM::RemoveTaint	= 0			unless $MLDBM::RemoveTaint;

#
# A private way to load packages at runtime.
my $loadpack = sub {
    my $pack = shift;
    $pack =~ s|::|/|g;
    $pack .= ".pm";
    eval { require $pack };
    if ($@) {
	carp "MLDBM error: " . 
	  "Please make sure $pack is a properly installed package.\n" .
	    "\tPerl says: \"$@\"";
	return undef;
    }
    1;
};


#
# TIEHASH interface methods
#
sub TIEHASH {
    my $c = shift;
    my $s = bless {}, $c;

    #
    # Create the right serializer object.
    my $szr = $MLDBM::Serializer;
    unless (ref $szr) {
	$szr = "MLDBM::Serializer::$szr"	# allow convenient short names
	  unless $szr =~ /^MLDBM::Serializer::/;
	&$loadpack($szr) or return undef;
	$szr = $szr->new($MLDBM::DumpMeth,
			 $MLDBM::RemoveTaint,
			 $MLDBM::Key);
    }
    $s->Serializer($szr);

    #
    # Create the right TIEHASH  object.
    my $db = $MLDBM::UseDB;
    unless (ref $db) {
	&$loadpack($db) or return undef;
	$db = $db->TIEHASH(@_)
	  or carp "MLDBM error: Second level tie failed, \"$!\""
	    and return undef;
    }
    $s->UseDB($db);

    return $s;
}

sub FETCH {
    my ($s, $k) = @_;
    my $ret = $s->{DB}->FETCH($k);
    $s->{SR}->deserialize($ret);
}

sub STORE {
    my ($s, $k, $v) = @_;
    $v = $s->{SR}->serialize($v);
    $s->{DB}->STORE($k, $v);
}

sub DELETE	{ my $s = shift; $s->{DB}->DELETE(@_); }
sub FIRSTKEY	{ my $s = shift; $s->{DB}->FIRSTKEY(@_); }
sub NEXTKEY	{ my $s = shift; $s->{DB}->NEXTKEY(@_); }
sub EXISTS	{ my $s = shift; $s->{DB}->EXISTS(@_); }
sub CLEAR	{ my $s = shift; $s->{DB}->CLEAR(@_); }

sub new		{ &TIEHASH }

#
# delegate messages to the underlying DBM
#
sub AUTOLOAD {
    return if $MLDBM::AUTOLOAD =~ /::DESTROY$/;
    my $s = shift;
    if (ref $s) {			# twas a method call
	my $dbname = ref($s->{DB});
	# permit inheritance
	$MLDBM::AUTOLOAD =~ s/^.*::([^:]+)$/$dbname\:\:$1/;
	$s->{DB}->$MLDBM::AUTOLOAD(@_);
    }
}

#
# delegate messages to the underlying Serializer
#
sub DumpMeth	{ my $s = shift; $s->{SR}->DumpMeth(@_); }
sub RemoveTaint	{ my $s = shift; $s->{SR}->RemoveTaint(@_); }
sub Key		{ my $s = shift; $s->{SR}->Key(@_); }

#
# get/set the DB object
#
sub UseDB 	{ my $s = shift; @_ ? ($s->{DB} = shift) : $s->{DB}; }

#
# get/set the Serializer object
#
sub Serializer	{ my $s = shift; @_ ? ($s->{SR} = shift) : $s->{SR}; }

#
# stuff to do at 'use' time
#
sub import {
    my ($pack, $dbpack, $szr, $dumpmeth, $removetaint, $key) = @_;
    $MLDBM::UseDB = $dbpack if defined $dbpack and $dbpack;
    $MLDBM::Serializer = $szr if defined $szr and $szr;
    # undocumented, may change!
    $MLDBM::DumpMeth = $dumpmeth if defined $dumpmeth;
    $MLDBM::RemoveTaint = $removetaint if defined $removetaint;
    $MLDBM::Key = $key if defined $key and $key;
}

# helper subroutine for tests to compare to arbitrary data structures
# for equivalency
sub _compare {
    use vars qw(%compared);
    local %compared;
    return _cmp(@_);
}

sub _cmp {
    my($a, $b) = @_;

    # catch circular loops
    return(1) if $compared{$a.'&*&*&*&*&*'.$b}++;
#    print "$a $b\n";
#    print &Data::Dumper::Dumper($a, $b);

    if(ref($a) and ref($a) eq ref($b)) {
	if(eval { @$a }) {
#	    print "HERE ".@$a." ".@$b."\n";
	    @$a == @$b or return 0;
#	    print @$a, ' ', @$b, "\n";
#	    print "HERE2\n";

	    for(0..@$a-1) {
		&_cmp($a->[$_], $b->[$_]) or return 0;
	    }
	} elsif(eval { %$a }) {
	    keys %$a == keys %$b or return 0;
	    for (keys %$a) {
		&_cmp($a->{$_}, $b->{$_}) or return 0;
	    }
	} elsif(eval { $$a }) {
	    &_cmp($$a, $$b) or return 0;
	} else {
	    die("data $a $b not handled");
	}
	return 1;
    } elsif(! ref($a) and ! ref($b)) {
	return ($a eq $b);
    } else {
	return 0;
    }

}

1;

__END__

#line 553

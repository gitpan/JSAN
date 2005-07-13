#line 1 "inc/Class/DBI/DATA/Schema.pm - /Library/Perl/5.8.6/Class/DBI/DATA/Schema.pm"
package Class::DBI::DATA::Schema;

#line 29

use strict;
use warnings;

our $VERSION = '0.04';

#line 56

sub import {
	my ($self, %args) = @_;
	my $caller = caller();

	my $translating = 0;
	if ($args{translate}) {
		eval "use SQL::Translator";
		$@ ? warn "Cannot translate without SQL::Translator" : ($translating = 1);
	}

	my $CACHE = "";
	if ($args{cache}) {
		eval "use Cache::File; use Digest::MD5";
		$@
			? warn "Cannot cache without Cache::File and Digest::MD5"
			: (
			$CACHE = Cache::File->new(
				cache_root      => $args{cache},
				cache_umask     => $args{cache_umask} || 000,
				default_expires => $args{cache_duration} || '30 day',
			));
	}

	my $translate = sub {
		my $sql = shift;
		if (my ($from, $to) = @{ $args{translate} || [] }) {
			my $key    = $CACHE ? Digest::MD5::md5_base64($sql) : "";
			my $cached = $CACHE ? $CACHE->get($key)             : "";
			return $cached if $cached;

			my $translator = SQL::Translator->new(no_comments => 1, trace => 0);

			# Ahem.
			local $SIG{__WARN__} = sub { };
			local *Parse::RecDescent::_error = sub ($;$) { };
			$sql = eval {
				$translator->translate(
					parser   => $from,
					producer => $to,
					data     => \$sql,
				);
			} || $sql;
			$CACHE->set($key => $sql) if $CACHE;
		}
		$sql;
	};

	my $transform = sub {
		my $sql = shift;
		return join ";", map $translate->("$_;"), grep /\S/, split /;/, $sql;
	};

	my $get_statements = sub {
		my $h = shift;
		local $/ = undef;
		chomp(my $sql = <$h>);
		return grep /\S/, split /;/, $translating ? $transform->($sql) : $sql;
	};

	my %cache;

	no strict 'refs';
	*{"$caller\::run_data_sql"} = sub {
		my $class = shift;
		no strict 'refs';
		$cache{$class} ||= [ $get_statements->(*{"$class\::DATA"}{IO}) ];
		$class->db_Main->do($_) foreach @{ $cache{$class} };
		return 1;
		}

}

#line 145

1;

#line 1 "inc/Class/Data/Inheritable.pm - /Library/Perl/5.8.6/Class/Data/Inheritable.pm"
package Class::Data::Inheritable;

use strict qw(vars subs);
use vars qw($VERSION);
$VERSION = '0.02';

#line 101

sub mk_classdata {
    my ($declaredclass, $attribute, $data) = @_;

    my $accessor = sub {
        my $wantclass = ref($_[0]) || $_[0];

        return $wantclass->mk_classdata($attribute)->(@_)
          if @_>1 && $wantclass ne $declaredclass;

        $data = $_[1] if @_>1;
        return $data;
    };

    my $alias = "_${attribute}_accessor";
    *{$declaredclass.'::'.$attribute} = $accessor;
    *{$declaredclass.'::'.$alias}     = $accessor;
}

#line 142

1;

package vars;

use 5.006;

our $VERSION = '1.05';

use warnings::register;
use strict qw(vars subs);

sub import {
    my $callpack = caller;
    my (undef, @imports) = @_;
    my ($sym, $ch);
    foreach (@imports) {
        if (($ch, $sym) = /^([\$\@\%\*\&])(.+)/) {
	    if ($sym =~ /\W/) {
		# time for a more-detailed check-up
		if ($sym =~ /^\w+[[{].*[]}]$/) {
		    require Carp;
		    Carp::croak("Can't declare individual elements of hash or array");
		} elsif (warnings::enabled() and length($sym) == 1 and $sym !~ tr/a-zA-Z//) {
		    warnings::warn("No need to declare built-in vars");
		} elsif  (($^H & strict::bits('vars'))) {
		    require Carp;
		    Carp::croak("'$_' is not a valid variable name under strict vars");
		}
	    }
	    $sym = "${callpack}::$sym" unless $sym =~ /::/;
	    *$sym =
		(  $ch eq "\$" ? \$$sym
		 : $ch eq "\@" ? \@$sym
		 : $ch eq "\%" ? \%$sym
		 : $ch eq "\*" ? \*$sym
		 : $ch eq "\&" ? \&$sym 
		 : do {
		     require Carp;
		     Carp::croak("'$_' is not a valid variable name");
		 });
	} else {
	    require Carp;
	    Carp::croak("'$_' is not a valid variable name");
	}
    }
};

1;
__END__


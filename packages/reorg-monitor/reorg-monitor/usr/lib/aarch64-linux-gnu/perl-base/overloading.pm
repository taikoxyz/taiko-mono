package overloading;
use warnings;

our $VERSION = '0.02';

my $HINT_NO_AMAGIC = 0x01000000; # see perl.h

require 5.010001;

sub _ops_to_nums {
    require overload::numbers;

    map { exists $overload::numbers::names{"($_"}
	? $overload::numbers::names{"($_"}
	: do { require Carp; Carp::croak("'$_' is not a valid overload") }
    } @_;
}

sub import {
    my ( $class, @ops ) = @_;

    if ( @ops ) {
	if ( $^H{overloading} ) {
	    vec($^H{overloading} , $_, 1) = 0 for _ops_to_nums(@ops);
	}

	if ( $^H{overloading} !~ /[^\0]/ ) {
	    delete $^H{overloading};
	    $^H &= ~$HINT_NO_AMAGIC;
	}
    } else {
	delete $^H{overloading};
	$^H &= ~$HINT_NO_AMAGIC;
    }
}

sub unimport {
    my ( $class, @ops ) = @_;

    if ( exists $^H{overloading} or not $^H & $HINT_NO_AMAGIC ) {
	if ( @ops ) {
	    vec($^H{overloading} ||= '', $_, 1) = 1 for _ops_to_nums(@ops);
	} else {
	    delete $^H{overloading};
	}
    }

    $^H |= $HINT_NO_AMAGIC;
}

1;
__END__


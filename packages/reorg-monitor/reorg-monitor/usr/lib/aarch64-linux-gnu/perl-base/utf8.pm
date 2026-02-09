package utf8;

use strict;
use warnings;

our $hint_bits = 0x00800000;

our $VERSION = '1.24';
our $AUTOLOAD;

sub import {
    $^H |= $hint_bits;
}

sub unimport {
    $^H &= ~$hint_bits;
}

sub AUTOLOAD {
    goto &$AUTOLOAD if defined &$AUTOLOAD;
    require Carp;
    Carp::croak("Undefined subroutine $AUTOLOAD called");
}

1;
__END__


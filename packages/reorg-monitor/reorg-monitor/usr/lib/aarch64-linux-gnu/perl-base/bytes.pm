package bytes;

use strict;
use warnings;

our $VERSION = '1.08';

$bytes::hint_bits = 0x00000008;

sub import {
    $^H |= $bytes::hint_bits;
}

sub unimport {
    $^H &= ~$bytes::hint_bits;
}

our $AUTOLOAD;
sub AUTOLOAD {
    require "bytes_heavy.pl";
    goto &$AUTOLOAD if defined &$AUTOLOAD;
    require Carp;
    Carp::croak("Undefined subroutine $AUTOLOAD called");
}

sub length (_);
sub chr (_);
sub ord (_);
sub substr ($$;$$);
sub index ($$;$);
sub rindex ($$;$);

1;
__END__


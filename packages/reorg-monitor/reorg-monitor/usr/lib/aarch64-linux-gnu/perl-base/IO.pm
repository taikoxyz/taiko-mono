#

package IO;

use XSLoader ();
use Carp;
use strict;
use warnings;

our $VERSION = "1.50";
XSLoader::load 'IO', $VERSION;

sub import {
    shift;

    warnings::warnif('deprecated', qq{Parameterless "use IO" deprecated})
        if @_ == 0 ;
    
    my @l = @_ ? @_ : qw(Handle Seekable File Pipe Socket Dir);

    local @INC = @INC;
    pop @INC if $INC[-1] eq '.';
    eval join("", map { "require IO::" . (/(\w+)/)[0] . ";\n" } @l)
	or croak $@;
}

1;

__END__


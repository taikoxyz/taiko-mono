#

package IO::File;

use 5.008_001;
use strict;
use Carp;
use Symbol;
use SelectSaver;
use IO::Seekable;

require Exporter;

our @ISA = qw(IO::Handle IO::Seekable Exporter);

our $VERSION = "1.48";

our @EXPORT = @IO::Seekable::EXPORT;

eval {
    # Make all Fcntl O_XXX constants available for importing
    require Fcntl;
    my @O = grep /^O_/, @Fcntl::EXPORT;
    Fcntl->import(@O);  # first we import what we want to export
    push(@EXPORT, @O);
};

################################################
## Constructor
##

sub new {
    my $type = shift;
    my $class = ref($type) || $type || "IO::File";
    @_ >= 0 && @_ <= 3
	or croak "usage: $class->new([FILENAME [,MODE [,PERMS]]])";
    my $fh = $class->SUPER::new();
    if (@_) {
	$fh->open(@_)
	    or return undef;
    }
    $fh;
}

################################################
## Open
##

sub open {
    @_ >= 2 && @_ <= 4 or croak 'usage: $fh->open(FILENAME [,MODE [,PERMS]])';
    my ($fh, $file) = @_;
    if (@_ > 2) {
	my ($mode, $perms) = @_[2, 3];
	if ($mode =~ /^\d+$/) {
	    defined $perms or $perms = 0666;
	    return sysopen($fh, $file, $mode, $perms);
	} elsif ($mode =~ /:/) {
	    return open($fh, $mode, $file) if @_ == 3;
	    croak 'usage: $fh->open(FILENAME, IOLAYERS)';
	} else {
            return open($fh, IO::Handle::_open_mode_string($mode), $file);
        }
    }
    open($fh, $file);
}

################################################
## Binmode
##

sub binmode {
    ( @_ == 1 or @_ == 2 ) or croak 'usage $fh->binmode([LAYER])';

    my($fh, $layer) = @_;

    return binmode $$fh unless $layer;
    return binmode $$fh, $layer;
}

1;

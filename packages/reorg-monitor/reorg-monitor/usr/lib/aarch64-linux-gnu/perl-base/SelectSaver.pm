package SelectSaver;

our $VERSION = '1.02';

require 5.000;
use Carp;
use Symbol;

sub new {
    @_ >= 1 && @_ <= 2 or croak 'usage: SelectSaver->new( [FILEHANDLE] )';
    my $fh = select;
    my $self = bless \$fh, $_[0];
    select qualify($_[1], caller) if @_ > 1;
    $self;
}

sub DESTROY {
    my $self = $_[0];
    select $$self;
}

1;

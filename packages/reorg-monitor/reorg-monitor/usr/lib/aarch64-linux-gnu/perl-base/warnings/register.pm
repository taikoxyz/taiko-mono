package warnings::register;

our $VERSION = '1.04';
require warnings;

# left here as cruft in case other users were using this undocumented routine
# -- rjbs, 2010-09-08
sub mkMask
{
    my ($bit) = @_;
    my $mask = "";

    vec($mask, $bit, 1) = 1;
    return $mask;
}

sub import
{
    shift;
    my @categories = @_;

    my $package = (caller(0))[0];
    warnings::register_categories($package);

    warnings::register_categories($package . "::$_") for @categories;
}
1;
__END__


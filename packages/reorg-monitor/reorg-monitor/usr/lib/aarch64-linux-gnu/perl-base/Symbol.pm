package Symbol;

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(gensym ungensym qualify qualify_to_ref);
our @EXPORT_OK = qw(delete_package geniosym);

our $VERSION = '1.09';

my $genpkg = "Symbol::";
my $genseq = 0;

my %global = map {$_ => 1} qw(ARGV ARGVOUT ENV INC SIG STDERR STDIN STDOUT);

#
# Note that we never _copy_ the glob; we just make a ref to it.
# If we did copy it, then SVf_FAKE would be set on the copy, and
# glob-specific behaviors (e.g. C<*$ref = \&func>) wouldn't work.
#
sub gensym () {
    my $name = "GEN" . $genseq++;
    no strict 'refs';
    my $ref = \*{$genpkg . $name};
    delete $$genpkg{$name};
    $ref;
}

sub geniosym () {
    my $sym = gensym();
    # force the IO slot to be filled
    select(select $sym);
    *$sym{IO};
}

sub ungensym ($) {}

sub qualify ($;$) {
    my ($name) = @_;
    if (!ref($name) && index($name, '::') == -1 && index($name, "'") == -1) {
	my $pkg;
	# Global names: special character, "^xyz", or other. 
	if ($name =~ /^(([^a-z])|(\^[a-z_]+))\z/i || $global{$name}) {
	    # RGS 2001-11-05 : translate leading ^X to control-char
	    $name =~ s/^\^([a-z_])/'qq(\c'.$1.')'/eei;
	    $pkg = "main";
	}
	else {
	    $pkg = (@_ > 1) ? $_[1] : caller;
	}
	$name = $pkg . "::" . $name;
    }
    $name;
}

sub qualify_to_ref ($;$) {
    no strict 'refs';
    return \*{ qualify $_[0], @_ > 1 ? $_[1] : caller };
}

#
# of Safe.pm lineage
#
sub delete_package ($) {
    my $pkg = shift;

    # expand to full symbol table name if needed

    unless ($pkg =~ /^main::.*::$/) {
        $pkg = "main$pkg"	if	$pkg =~ /^::/;
        $pkg = "main::$pkg"	unless	$pkg =~ /^main::/;
        $pkg .= '::'		unless	$pkg =~ /::$/;
    }

    my($stem, $leaf) = $pkg =~ m/(.*::)(\w+::)$/;
    no strict 'refs';
    my $stem_symtab = *{$stem}{HASH};
    return unless defined $stem_symtab and exists $stem_symtab->{$leaf};

    # free all the symbols in the package

    my $leaf_symtab = *{$stem_symtab->{$leaf}}{HASH};
    foreach my $name (keys %$leaf_symtab) {
        undef *{$pkg . $name};
    }
    use strict 'refs';

    # delete the symbol table

    %$leaf_symtab = ();
    delete $stem_symtab->{$leaf};
}

1;

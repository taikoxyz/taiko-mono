package attributes;

our $VERSION = 0.34;

@EXPORT_OK = qw(get reftype);
@EXPORT = ();
%EXPORT_TAGS = (ALL => [@EXPORT, @EXPORT_OK]);

use strict;

sub croak {
    require Carp;
    goto &Carp::croak;
}

sub carp {
    require Carp;
    goto &Carp::carp;
}

# Hash of SV type (CODE, SCALAR, etc.) to regex matching deprecated
# attributes for that type.
my %deprecated;

my %msg = (
    lvalue => 'lvalue attribute applied to already-defined subroutine',
   -lvalue => 'lvalue attribute removed from already-defined subroutine',
    const  => 'Useless use of attribute "const"',
);

sub _modify_attrs_and_deprecate {
    my $svtype = shift;
    # After we've removed a deprecated attribute from the XS code, we need to
    # remove it here, else it ends up in @badattrs. (If we do the deprecation in
    # XS, we can't control the warning based on *our* caller's lexical settings,
    # and the warned line is in this package)
    grep {
	$deprecated{$svtype} && /$deprecated{$svtype}/ ? do {
	    require warnings;
	    warnings::warnif('deprecated', "Attribute \"$1\" is deprecated, " .
                                           "and will disappear in Perl 5.28");
	    0;
	} : $svtype eq 'CODE' && exists $msg{$_} ? do {
	    require warnings;
	    warnings::warnif(
		'misc',
		 $msg{$_}
	    );
	    0;
	} : 1
    } _modify_attrs(@_);
}

sub import {
    @_ > 2 && ref $_[2] or do {
	require Exporter;
	goto &Exporter::import;
    };
    my (undef,$home_stash,$svref,@attrs) = @_;

    my $svtype = uc reftype($svref);
    my $pkgmeth;
    $pkgmeth = UNIVERSAL::can($home_stash, "MODIFY_${svtype}_ATTRIBUTES")
	if defined $home_stash && $home_stash ne '';
    my @badattrs;
    if ($pkgmeth) {
	my @pkgattrs = _modify_attrs_and_deprecate($svtype, $svref, @attrs);
	@badattrs = $pkgmeth->($home_stash, $svref, @pkgattrs);
	if (!@badattrs && @pkgattrs) {
            require warnings;
	    return unless warnings::enabled('reserved');
	    @pkgattrs = grep { m/\A[[:lower:]]+(?:\z|\()/ } @pkgattrs;
	    if (@pkgattrs) {
		for my $attr (@pkgattrs) {
		    $attr =~ s/\(.+\z//s;
		}
		my $s = ((@pkgattrs == 1) ? '' : 's');
		carp "$svtype package attribute$s " .
		    "may clash with future reserved word$s: " .
		    join(' : ' , @pkgattrs);
	    }
	}
    }
    else {
	@badattrs = _modify_attrs_and_deprecate($svtype, $svref, @attrs);
    }
    if (@badattrs) {
	croak "Invalid $svtype attribute" .
	    (( @badattrs == 1 ) ? '' : 's') .
	    ": " .
	    join(' : ', @badattrs);
    }
}

sub get ($) {
    @_ == 1  && ref $_[0] or
	croak 'Usage: '.__PACKAGE__.'::get $ref';
    my $svref = shift;
    my $svtype = uc reftype($svref);
    my $stash = _guess_stash($svref);
    $stash = caller unless defined $stash;
    my $pkgmeth;
    $pkgmeth = UNIVERSAL::can($stash, "FETCH_${svtype}_ATTRIBUTES")
	if defined $stash && $stash ne '';
    return $pkgmeth ?
		(_fetch_attrs($svref), $pkgmeth->($stash, $svref)) :
		(_fetch_attrs($svref))
	;
}

sub require_version { goto &UNIVERSAL::VERSION }

require XSLoader;
XSLoader::load();

1;
__END__
#The POD goes here


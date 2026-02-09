package constant;
use 5.008;
use strict;
use warnings::register;

our $VERSION = '1.33';
our %declared;

#=======================================================================

# Some names are evil choices.
my %keywords = map +($_, 1), qw{ BEGIN INIT CHECK END DESTROY AUTOLOAD };
$keywords{UNITCHECK}++ if $] > 5.009;

my %forced_into_main = map +($_, 1),
    qw{ STDIN STDOUT STDERR ARGV ARGVOUT ENV INC SIG };

my %forbidden = (%keywords, %forced_into_main);

my $normal_constant_name = qr/^_?[^\W_0-9]\w*\z/;
my $tolerable = qr/^[A-Za-z_]\w*\z/;
my $boolean = qr/^[01]?\z/;

BEGIN {
    # We'd like to do use constant _CAN_PCS => $] > 5.009002
    # but that's a bit tricky before we load the constant module :-)
    # By doing this, we save several run time checks for *every* call
    # to import.
    my $const = $] > 5.009002;
    my $downgrade = $] < 5.015004; # && $] >= 5.008
    my $constarray = exists &_make_const;
    if ($const) {
	Internals::SvREADONLY($const, 1);
	Internals::SvREADONLY($downgrade, 1);
	$constant::{_CAN_PCS}   = \$const;
	$constant::{_DOWNGRADE} = \$downgrade;
	$constant::{_CAN_PCS_FOR_ARRAY} = \$constarray;
    }
    else {
	no strict 'refs';
	*{"_CAN_PCS"}   = sub () {$const};
	*{"_DOWNGRADE"} = sub () { $downgrade };
	*{"_CAN_PCS_FOR_ARRAY"} = sub () { $constarray };
    }
}

#=======================================================================
# import() - import symbols into user's namespace
#
# What we actually do is define a function in the caller's namespace
# which returns the value. The function we create will normally
# be inlined as a constant, thereby avoiding further sub calling 
# overhead.
#=======================================================================
sub import {
    my $class = shift;
    return unless @_;			# Ignore 'use constant;'
    my $constants;
    my $multiple  = ref $_[0];
    my $caller = caller;
    my $flush_mro;
    my $symtab;

    if (_CAN_PCS) {
	no strict 'refs';
	$symtab = \%{$caller . '::'};
    };

    if ( $multiple ) {
	if (ref $_[0] ne 'HASH') {
	    require Carp;
	    Carp::croak("Invalid reference type '".ref(shift)."' not 'HASH'");
	}
	$constants = shift;
    } else {
	unless (defined $_[0]) {
	    require Carp;
	    Carp::croak("Can't use undef as constant name");
	}
	$constants->{+shift} = undef;
    }

    foreach my $name ( keys %$constants ) {
	my $pkg;
	my $symtab = $symtab;
	my $orig_name = $name;
	if ($name =~ s/(.*)(?:::|')(?=.)//s) {
	    $pkg = $1;
	    if (_CAN_PCS && $pkg ne $caller) {
		no strict 'refs';
		$symtab = \%{$pkg . '::'};
	    }
	}
	else {
	    $pkg = $caller;
	}

	# Normal constant name
	if ($name =~ $normal_constant_name and !$forbidden{$name}) {
	    # Everything is okay

	# Name forced into main, but we're not in main. Fatal.
	} elsif ($forced_into_main{$name} and $pkg ne 'main') {
	    require Carp;
	    Carp::croak("Constant name '$name' is forced into main::");

	# Starts with double underscore. Fatal.
	} elsif ($name =~ /^__/) {
	    require Carp;
	    Carp::croak("Constant name '$name' begins with '__'");

	# Maybe the name is tolerable
	} elsif ($name =~ $tolerable) {
	    # Then we'll warn only if you've asked for warnings
	    if (warnings::enabled()) {
		if ($keywords{$name}) {
		    warnings::warn("Constant name '$name' is a Perl keyword");
		} elsif ($forced_into_main{$name}) {
		    warnings::warn("Constant name '$name' is " .
			"forced into package main::");
		}
	    }

	# Looks like a boolean
	# use constant FRED == fred;
	} elsif ($name =~ $boolean) {
            require Carp;
	    if (@_) {
		Carp::croak("Constant name '$name' is invalid");
	    } else {
		Carp::croak("Constant name looks like boolean value");
	    }

	} else {
	   # Must have bad characters
            require Carp;
	    Carp::croak("Constant name '$name' has invalid characters");
	}

	{
	    no strict 'refs';
	    my $full_name = "${pkg}::$name";
	    $declared{$full_name}++;
	    if ($multiple || @_ == 1) {
		my $scalar = $multiple ? $constants->{$orig_name} : $_[0];

		if (_DOWNGRADE) { # for 5.8 to 5.14
		    # Work around perl bug #31991: Sub names (actually glob
		    # names in general) ignore the UTF8 flag. So we have to
		    # turn it off to get the "right" symbol table entry.
		    utf8::is_utf8 $name and utf8::encode $name;
		}

		# The constant serves to optimise this entire block out on
		# 5.8 and earlier.
		if (_CAN_PCS) {
		    # Use a reference as a proxy for a constant subroutine.
		    # If this is not a glob yet, it saves space.  If it is
		    # a glob, we must still create it this way to get the
		    # right internal flags set, as constants are distinct
		    # from subroutines created with sub(){...}.
		    # The check in Perl_ck_rvconst knows that inlinable
		    # constants from cv_const_sv are read only. So we have to:
		    Internals::SvREADONLY($scalar, 1);
		    if (!exists $symtab->{$name}) {
			$symtab->{$name} = \$scalar;
			++$flush_mro->{$pkg};
		    }
		    else {
			local $constant::{_dummy} = \$scalar;
			*$full_name = \&{"_dummy"};
		    }
		} else {
		    *$full_name = sub () { $scalar };
		}
	    } elsif (@_) {
		my @list = @_;
		if (_CAN_PCS_FOR_ARRAY) {
		    _make_const($list[$_]) for 0..$#list;
		    _make_const(@list);
		    if (!exists $symtab->{$name}) {
			$symtab->{$name} = \@list;
			$flush_mro->{$pkg}++;
		    }
		    else {
			local $constant::{_dummy} = \@list;
			*$full_name = \&{"_dummy"};
		    }
		}
		else { *$full_name = sub () { @list }; }
	    } else {
		*$full_name = sub () { };
	    }
	}
    }
    # Flush the cache exactly once if we make any direct symbol table changes.
    if (_CAN_PCS && $flush_mro) {
	mro::method_changed_in($_) for keys %$flush_mro;
    }
}

1;

__END__


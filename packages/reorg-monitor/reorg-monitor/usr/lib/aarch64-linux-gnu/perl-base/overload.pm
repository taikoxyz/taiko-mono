package overload;

use strict;
no strict 'refs';
no warnings 'experimental::builtin';

our $VERSION = '1.35';

our %ops = (
    with_assign         => "+ - * / % ** << >> x .",
    assign              => "+= -= *= /= %= **= <<= >>= x= .=",
    num_comparison      => "< <= >  >= == !=",
    '3way_comparison'   => "<=> cmp",
    str_comparison      => "lt le gt ge eq ne",
    binary              => '& &= | |= ^ ^= &. &.= |. |.= ^. ^.=',
    unary               => "neg ! ~ ~.",
    mutators            => '++ --',
    func                => "atan2 cos sin exp abs log sqrt int",
    conversion          => 'bool "" 0+ qr',
    iterators           => '<>',
    filetest            => "-X",
    dereferencing       => '${} @{} %{} &{} *{}',
    matching            => '~~',
    special             => 'nomethod fallback =',
);

my %ops_seen;
@ops_seen{ map split(/ /), values %ops } = ();

sub nil {}

sub OVERLOAD {
  my $package = shift;
  my %arg = @_;
  my $sub;
  *{$package . "::(("} = \&nil; # Make it findable via fetchmethod.
  for (keys %arg) {
    if ($_ eq 'fallback') {
      for my $sym (*{$package . "::()"}) {
	*$sym = \&nil; # Make it findable via fetchmethod.
	$$sym = $arg{$_};
      }
    } else {
      warnings::warnif("overload arg '$_' is invalid")
        unless exists $ops_seen{$_};
      $sub = $arg{$_};
      if (not ref $sub) {
	$ {$package . "::(" . $_} = $sub;
	$sub = \&nil;
      }
      #print STDERR "Setting '$ {'package'}::\cO$_' to \\&'$sub'.\n";
      *{$package . "::(" . $_} = \&{ $sub };
    }
  }
}

sub import {
  my $package = (caller())[0];
  # *{$package . "::OVERLOAD"} = \&OVERLOAD;
  shift;
  $package->overload::OVERLOAD(@_);
}

sub unimport {
  my $package = (caller())[0];
  shift;
  *{$package . "::(("} = \&nil;
  for (@_) {
      warnings::warnif("overload arg '$_' is invalid")
        unless exists $ops_seen{$_};
      delete $ {$package . "::"}{$_ eq 'fallback' ? '()' : "(" .$_};
  }
}

sub Overloaded {
  my $package = shift;
  $package = ref $package if ref $package;
  mycan ($package, '()') || mycan ($package, '((');
}

sub ov_method {
  my $globref = shift;
  return undef unless $globref;
  my $sub = \&{*$globref};
  no overloading;
  return $sub if $sub != \&nil;
  return shift->can($ {*$globref});
}

sub OverloadedStringify {
  my $package = shift;
  $package = ref $package if ref $package;
  #$package->can('(""')
  ov_method mycan($package, '(""'), $package
    or ov_method mycan($package, '(0+'), $package
    or ov_method mycan($package, '(bool'), $package
    or ov_method mycan($package, '(nomethod'), $package;
}

sub Method {
  my $package = shift;
  if(ref $package) {
    local $@;
    local $!;
    $package = builtin::blessed($package);
    return undef if !defined $package;
  }
  #my $meth = $package->can('(' . shift);
  ov_method mycan($package, '(' . shift), $package;
  #return $meth if $meth ne \&nil;
  #return $ {*{$meth}};
}

sub AddrRef {
  no overloading;
  "$_[0]";
}

*StrVal = *AddrRef;

sub mycan {				# Real can would leave stubs.
  my ($package, $meth) = @_;

  local $@;
  local $!;
  require mro;

  my $mro = mro::get_linear_isa($package);
  foreach my $p (@$mro) {
    my $fqmeth = $p . q{::} . $meth;
    return \*{$fqmeth} if defined &{$fqmeth};
  }

  return undef;
}

my %constants = (
	      'integer'	  =>  0x1000, # HINT_NEW_INTEGER
	      'float'	  =>  0x2000, # HINT_NEW_FLOAT
	      'binary'	  =>  0x4000, # HINT_NEW_BINARY
	      'q'	  =>  0x8000, # HINT_NEW_STRING
	      'qr'	  => 0x10000, # HINT_NEW_RE
	     );

use warnings::register;
sub constant {
  # Arguments: what, sub
  while (@_) {
    if (@_ == 1) {
        warnings::warnif ("Odd number of arguments for overload::constant");
        last;
    }
    elsif (!exists $constants {$_ [0]}) {
        warnings::warnif ("'$_[0]' is not an overloadable type");
    }
    elsif (!ref $_ [1] || "$_[1]" !~ /(^|=)CODE\(0x[0-9a-f]+\)$/) {
        # Can't use C<ref $_[1] eq "CODE"> above as code references can be
        # blessed, and C<ref> would return the package the ref is blessed into.
        if (warnings::enabled) {
            $_ [1] = "undef" unless defined $_ [1];
            warnings::warn ("'$_[1]' is not a code reference");
        }
    }
    else {
        $^H{$_[0]} = $_[1];
        $^H |= $constants{$_[0]};
    }
    shift, shift;
  }
}

sub remove_constant {
  # Arguments: what, sub
  while (@_) {
    delete $^H{$_[0]};
    $^H &= ~ $constants{$_[0]};
    shift, shift;
  }
}

1;

__END__


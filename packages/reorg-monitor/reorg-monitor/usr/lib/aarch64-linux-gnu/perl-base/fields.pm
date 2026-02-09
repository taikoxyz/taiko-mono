use 5.008;
package fields;

require 5.005;
use strict;
no strict 'refs';
unless( eval q{require warnings::register; warnings::register->import; 1} ) {
    *warnings::warnif = sub { 
        require Carp;
        Carp::carp(@_);
    }
}
our %attr;

our $VERSION = '2.24';
$VERSION =~ tr/_//d;

# constant.pm is slow
sub PUBLIC     () { 2**0  }
sub PRIVATE    () { 2**1  }
sub INHERITED  () { 2**2  }
sub PROTECTED  () { 2**3  }

# The %attr hash holds the attributes of the currently assigned fields
# per class.  The hash is indexed by class names and the hash value is
# an array reference.  The first element in the array is the lowest field
# number not belonging to a base class.  The remaining elements' indices
# are the field numbers.  The values are integer bit masks, or undef
# in the case of base class private fields (which occupy a slot but are
# otherwise irrelevant to the class).

sub import {
    my $class = shift;
    return unless @_;
    my $package = caller(0);
    # avoid possible typo warnings
    %{"$package\::FIELDS"} = () unless %{"$package\::FIELDS"};
    my $fields = \%{"$package\::FIELDS"};
    my $fattr = ($attr{$package} ||= [1]);
    my $next = @$fattr;

    # Quiet pseudo-hash deprecation warning for uses of fields::new.
    bless \%{"$package\::FIELDS"}, 'pseudohash';

    if ($next > $fattr->[0]
        and ($fields->{$_[0]} || 0) >= $fattr->[0])
    {
        # There are already fields not belonging to base classes.
        # Looks like a possible module reload...
        $next = $fattr->[0];
    }
    foreach my $f (@_) {
        my $fno = $fields->{$f};

        # Allow the module to be reloaded so long as field positions
        # have not changed.
        if ($fno and $fno != $next) {
            require Carp;
            if ($fno < $fattr->[0]) {
              if ($] < 5.006001) {
                warn("Hides field '$f' in base class") if $^W;
              } else {
                warnings::warnif("Hides field '$f' in base class") ;
              }
            } else {
                Carp::croak("Field name '$f' already in use");
            }
        }
        $fields->{$f} = $next;
        $fattr->[$next] = ($f =~ /^_/) ? PRIVATE : PUBLIC;
        $next += 1;
    }
    if (@$fattr > $next) {
        # Well, we gave them the benefit of the doubt by guessing the
        # module was reloaded, but they appear to be declaring fields
        # in more than one place.  We can't be sure (without some extra
        # bookkeeping) that the rest of the fields will be declared or
        # have the same positions, so punt.
        require Carp;
        Carp::croak ("Reloaded module must declare all fields at once");
    }
}

sub inherit {
    require base;
    goto &base::inherit_fields;
}

sub _dump  # sometimes useful for debugging
{
    for my $pkg (sort keys %attr) {
        print "\n$pkg";
        if (@{"$pkg\::ISA"}) {
            print " (", join(", ", @{"$pkg\::ISA"}), ")";
        }
        print "\n";
        my $fields = \%{"$pkg\::FIELDS"};
        for my $f (sort {$fields->{$a} <=> $fields->{$b}} keys %$fields) {
            my $no = $fields->{$f};
            print "   $no: $f";
            my $fattr = $attr{$pkg}[$no];
            if (defined $fattr) {
                my @a;
                push(@a, "public")    if $fattr & PUBLIC;
                push(@a, "private")   if $fattr & PRIVATE;
                push(@a, "inherited") if $fattr & INHERITED;
                print "\t(", join(", ", @a), ")";
            }
            print "\n";
        }
    }
}

if ($] < 5.009) {
  *new = sub {
    my $class = shift;
    $class = ref $class if ref $class;
    return bless [\%{$class . "::FIELDS"}], $class;
  }
} else {
  *new = sub {
    my $class = shift;
    $class = ref $class if ref $class;
    require Hash::Util;
    my $self = bless {}, $class;

    # The lock_keys() prototype won't work since we require Hash::Util :(
    &Hash::Util::lock_keys(\%$self, _accessible_keys($class));
    return $self;
  }
}

sub _accessible_keys {
    my ($class) = @_;
    return (
        keys %{$class.'::FIELDS'},
        map(_accessible_keys($_), @{$class.'::ISA'}),
    );
}

sub phash {
    die "Pseudo-hashes have been removed from Perl" if $] >= 5.009;
    my $h;
    my $v;
    if (@_) {
       if (ref $_[0] eq 'ARRAY') {
           my $a = shift;
           @$h{@$a} = 1 .. @$a;
           if (@_) {
               $v = shift;
               unless (! @_ and ref $v eq 'ARRAY') {
                   require Carp;
                   Carp::croak ("Expected at most two array refs\n");
               }
           }
       }
       else {
           if (@_ % 2) {
               require Carp;
               Carp::croak ("Odd number of elements initializing pseudo-hash\n");
           }
           my $i = 0;
           @$h{grep ++$i % 2, @_} = 1 .. @_ / 2;
           $i = 0;
           $v = [grep $i++ % 2, @_];
       }
    }
    else {
       $h = {};
       $v = [];
    }
    [ $h, @$v ];

}

1;

__END__


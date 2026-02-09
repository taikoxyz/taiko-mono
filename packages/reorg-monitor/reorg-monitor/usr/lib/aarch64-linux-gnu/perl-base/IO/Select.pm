# IO::Select.pm
#
# Copyright (c) 1997-8 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package IO::Select;

use     strict;
use warnings::register;
require Exporter;

our $VERSION = "1.49";

our @ISA = qw(Exporter); # This is only so we can do version checking

sub VEC_BITS () {0}
sub FD_COUNT () {1}
sub FIRST_FD () {2}

sub new
{
 my $self = shift;
 my $type = ref($self) || $self;

 my $vec = bless [undef,0], $type;

 $vec->add(@_)
    if @_;

 $vec;
}

sub add
{
 shift->_update('add', @_);
}

sub remove
{
 shift->_update('remove', @_);
}

sub exists
{
 my $vec = shift;
 my $fno = $vec->_fileno(shift);
 return undef unless defined $fno;
 $vec->[$fno + FIRST_FD];
}

sub _fileno
{
 my($self, $f) = @_;
 return unless defined $f;
 $f = $f->[0] if ref($f) eq 'ARRAY';
 if($f =~ /^[0-9]+$/) { # plain file number
  return $f;
 }
 elsif(defined(my $fd = fileno($f))) {
  return $fd;
 }
 else {
  # Neither a plain file number nor an opened filehandle; but maybe it was
  # previously registered and has since been closed. ->remove still wants to
  # know what fileno it had
  foreach my $i ( FIRST_FD .. $#$self ) {
   return $i - FIRST_FD if defined $self->[$i] && $self->[$i] == $f;
  }
  return undef;
 }
}

sub _update
{
 my $vec = shift;
 my $add = shift eq 'add';

 my $bits = $vec->[VEC_BITS];
 $bits = '' unless defined $bits;

 my $count = 0;
 my $f;
 foreach $f (@_)
  {
   my $fn = $vec->_fileno($f);
   if ($add) {
     next unless defined $fn;
     my $i = $fn + FIRST_FD;
     if (defined $vec->[$i]) {
	 $vec->[$i] = $f;  # if array rest might be different, so we update
	 next;
     }
     $vec->[FD_COUNT]++;
     vec($bits, $fn, 1) = 1;
     $vec->[$i] = $f;
   } else {      # remove
     if ( ! defined $fn ) { # remove if fileno undef'd
       $fn = 0;
       for my $fe (@{$vec}[FIRST_FD .. $#$vec]) {
         if (defined($fe) && $fe == $f) {
	   $vec->[FD_COUNT]--;
	   $fe = undef;
	   vec($bits, $fn, 1) = 0;
	   last;
	 }
	 ++$fn;
       }
     }
     else {
       my $i = $fn + FIRST_FD;
       next unless defined $vec->[$i];
       $vec->[FD_COUNT]--;
       vec($bits, $fn, 1) = 0;
       $vec->[$i] = undef;
     }
   }
   $count++;
  }
 $vec->[VEC_BITS] = $vec->[FD_COUNT] ? $bits : undef;
 $count;
}

sub can_read
{
 my $vec = shift;
 my $timeout = shift;
 my $r = $vec->[VEC_BITS];

 defined($r) && (select($r,undef,undef,$timeout) > 0)
    ? handles($vec, $r)
    : ();
}

sub can_write
{
 my $vec = shift;
 my $timeout = shift;
 my $w = $vec->[VEC_BITS];

 defined($w) && (select(undef,$w,undef,$timeout) > 0)
    ? handles($vec, $w)
    : ();
}

sub has_exception
{
 my $vec = shift;
 my $timeout = shift;
 my $e = $vec->[VEC_BITS];

 defined($e) && (select(undef,undef,$e,$timeout) > 0)
    ? handles($vec, $e)
    : ();
}

sub has_error
{
 warnings::warn("Call to deprecated method 'has_error', use 'has_exception'")
	if warnings::enabled();
 goto &has_exception;
}

sub count
{
 my $vec = shift;
 $vec->[FD_COUNT];
}

sub bits
{
 my $vec = shift;
 $vec->[VEC_BITS];
}

sub as_string  # for debugging
{
 my $vec = shift;
 my $str = ref($vec) . ": ";
 my $bits = $vec->bits;
 my $count = $vec->count;
 $str .= defined($bits) ? unpack("b*", $bits) : "undef";
 $str .= " $count";
 my @handles = @$vec;
 splice(@handles, 0, FIRST_FD);
 for (@handles) {
     $str .= " " . (defined($_) ? "$_" : "-");
 }
 $str;
}

sub _max
{
 my($a,$b,$c) = @_;
 $a > $b
    ? $a > $c
        ? $a
        : $c
    : $b > $c
        ? $b
        : $c;
}

sub select
{
 shift
   if defined $_[0] && !ref($_[0]);

 my($r,$w,$e,$t) = @_;
 my @result = ();

 my $rb = defined $r ? $r->[VEC_BITS] : undef;
 my $wb = defined $w ? $w->[VEC_BITS] : undef;
 my $eb = defined $e ? $e->[VEC_BITS] : undef;

 if(select($rb,$wb,$eb,$t) > 0)
  {
   my @r = ();
   my @w = ();
   my @e = ();
   my $i = _max(defined $r ? scalar(@$r)-1 : 0,
                defined $w ? scalar(@$w)-1 : 0,
                defined $e ? scalar(@$e)-1 : 0);

   for( ; $i >= FIRST_FD ; $i--)
    {
     my $j = $i - FIRST_FD;
     push(@r, $r->[$i])
        if defined $rb && defined $r->[$i] && vec($rb, $j, 1);
     push(@w, $w->[$i])
        if defined $wb && defined $w->[$i] && vec($wb, $j, 1);
     push(@e, $e->[$i])
        if defined $eb && defined $e->[$i] && vec($eb, $j, 1);
    }

   @result = (\@r, \@w, \@e);
  }
 @result;
}

sub handles
{
 my $vec = shift;
 my $bits = shift;
 my @h = ();
 my $i;
 my $max = scalar(@$vec) - 1;

 for ($i = FIRST_FD; $i <= $max; $i++)
  {
   next unless defined $vec->[$i];
   push(@h, $vec->[$i])
      if !defined($bits) || vec($bits, $i - FIRST_FD, 1);
  }
 
 @h;
}

1;
__END__


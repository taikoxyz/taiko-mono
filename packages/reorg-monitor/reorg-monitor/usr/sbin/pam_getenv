#!/usr/bin/perl -w

=head1 NAME

pam_getenv - get environment variables from /etc/environment

=head1 SYNOPSIS

pam_getenv B<[-l] [-s]> I<env_var>

=head1 DESCRIPTION

This tool  will print out the value of I<env_var> from F</etc/environment>.  It will attempt to expand environment variable references in the definition of I<env_var> but will fail if PAM items are expanded.

The B<-l> option indicates the script should return an environment variable related to default locale information.

The B<-s> option indicates that the script should return an
system default environment variable.

Currently neither the B<-l> or B<-s> options do anything.  They are
included because future versions of Debian may have a separate
repository for the initial environment used by init scripts and for
system locale information.  These options will allow this script to be
a stable interface even in that environment.

=cut

# Copyright 2004 by Sam Hartman
# This script may be copied under the terms of the GNU GPL
# version 2, or at your option any later version.

use strict;
use vars qw(*CONFIGFILE *ENVFILE);

sub read_line($) {
  my $fh = shift;
  my $line;
  local $_;
  line: while (<$fh>) {
    chomp;
    s/^\s+//;
s/\#.*$//;
    next if $_ eq "";
    if (s/\\\s*$//) {
      $line .= $_;
      next line;
    }

    $line .= $_;
    last;
  }
  $line;
  
}


sub parse_line($) {
  my $var;
  my (%x, @x);
  local $_ = shift;
  return undef unless defined $_ and s/(\S+)\s//;
  $var->{Name} = $1;
  s/^\s*//;
  @x = split(/=([^"\s]\S*|"[^"]*")\s*/, $_);
  unless (scalar(@x)%2 == 0) {
    push @x, undef;
  }
  %x = @x;
  @{$var}{"Default", "Override"} =
    @x{"DEFAULT", "OVERRIDE"};
  $var;
}

sub expand_val($) {
  my ($val) = @_;
return undef unless $val;
	die "Cannot handle PAM items\n" if /(?<!\\)\@/;
  $val =~ s/(?<!\\)\$\{([^}]+)\}/$ENV{$1}||""/eg;
  return $val;
}

my $lookup;

while ($_ = shift) {
  next if $_ eq "-s";
  next if $_ eq "-l";
  $lookup = $_;
  last;
}
unless (defined $lookup) {
  die "Usage: pam_getenv [-l] [-s] env_var\n";
}

my %allvars;

open (CONFIGFILE, "/etc/security/pam_env.conf")
  or die "Cannot open environment file: $!\n";

while (my $var = parse_line(read_line(\*CONFIGFILE))) {
  my $val;
  unless ($val = expand_val($var->{Override})) {
    $val = expand_val($var->{Default});
  }
  $allvars{$var->{Name}} = $val;
}

if (open (ENVFILE, "/etc/environment")) {
  while (my $line = read_line(\*ENVFILE)) {
    $line =~ s/^export //;
    $line =~ /(.*?)=(.+)/ or next;
    my ($var, $val) = ($1, $2);
    # This is bizarre logic (" and ' match each other, quotes are only
    # significant at the start and end of the string, and the trailing quote
    # may be omitted), but it's what pam_env does.
    $val =~ s/^["'](.*?)["']?$/$1/;
    $allvars{$var} = $val;
  }
}

if (exists $allvars{$lookup}) {
  print $allvars{$lookup}, "\n";
  exit(0);
}

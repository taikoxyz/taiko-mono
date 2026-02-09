#!/usr/bin/perl -w

=head1 NAME

Debconf::Client::ConfModule - client module for ConfModules

=head1 SYNOPSIS

 use Debconf::Client::ConfModule ':all';
 version('2.0');
 my $capb=capb('backup');
 input("medium", "foo/bar");
 my @ret=go();
 if ($ret[0] == 30) {
 	# Back button pressed.
 	...
 }
 ...

=head1 DESCRIPTION

This is a module to ease writing ConfModules for Debian's configuration
management system. It can communicate with a FrontEnd via the debconf
protocol (which is documented in full in the debconf_specification in
Debian policy).

The design is that each command in the protocol is represented by one
function in this module (with the name lower-cased).  Call the function and
pass in any parameters you want to follow the command. If the function is
called in scalar context, it will return any textual return code. If it is
called in list context, an array consisting of the numeric return code and
the textual return code will be returned.

This module uses Exporter to export all functions it defines. To import
everything, simply import ":all".

=over 4

=cut

package Debconf::Client::ConfModule;
use strict;
use base qw(Exporter);

# List all valid commands here.
our @EXPORT_OK=qw(version capb stop reset title input beginblock endblock go
	      unset set get register unregister clear previous_module
	      start_frontend fset fget subst purge metaget visible exist
	      settitle info progress data x_loadtemplatefile);

# Import :all to get everything.		   
our %EXPORT_TAGS = (all => [@EXPORT_OK]);

# Set up valid command lookup hash.
my %commands;
map { $commands{uc $_}=1; } @EXPORT_OK;

# Unbuffered output is required.
$|=1;

=item import

Ensure that a FrontEnd is running.  It's a little hackish. If
DEBIAN_HAS_FRONTEND is set, a FrontEnd is assumed to be running.
If not, one is started up automatically and stdin and out are
connected to it. Note that this function is always run when the
module is loaded in the usual way.

=cut

sub import {
	if (! $ENV{DEBIAN_HAS_FRONTEND}) {
		$ENV{PERL_DL_NONLAZY}=1;
		if (exists $ENV{DEBCONF_USE_CDEBCONF} and
		    $ENV{DEBCONF_USE_CDEBCONF} ne '') {
			exec "/usr/lib/cdebconf/debconf", $0, @ARGV;
		} else {
			exec "/usr/share/debconf/frontend", $0, @ARGV;
		}
	}

	# Make the Exporter still work.
	Debconf::Client::ConfModule->export_to_level(1, @_);

	# A truly gross hack. This is only needed if
	# /usr/share/debconf/confmodule is loaded, and then this
	# perl module is used. In that case, this module needs to write
	# to fd #3, rather than stdout. See changelog 0.3.74.
	if (exists $ENV{DEBCONF_REDIR} && $ENV{DEBCONF_REDIR}) {
		open(STDOUT,">&3");
	}
}

=item stop

The frontend doesn't send a return code here, so we cannot try to read it
or we'll block.

=cut

sub stop {
	print "STOP\n";
	return;
}

=item AUTOLOAD

Creates handler functions for commands on the fly.

=cut

sub AUTOLOAD {
	my $command = uc our $AUTOLOAD;
	$command =~ s|.*:||; # strip fully-qualified portion

	die "Unsupported command `$command'."
		unless $commands{$command};
	
	no strict 'refs';
	*$AUTOLOAD = sub {
		my $c=join (' ', $command, @_);
	
		# Newlines in input can really badly confuse the protocol, so
		# detect and warn.
		if ($c=~m/\n/) {
			warn "Warning: Newline present in parameters passed to debconf.\n";
			warn "This will probably cause strange things to happen!\n";
		}

		print "$c\n";
		my $ret=<STDIN>;
		chomp $ret;
		my @ret=split(/\s/, $ret, 2);
		if ($ret[0] eq '1') {
			# escaped data
			local $_;
			my $unescaped='';
			for (split /(\\.)/, $ret[1]) {
				s/\\(.)/$1 eq "n" ? "\n" : $1/eg;
				$unescaped.=$_;
			}
			$ret[0]='0';
			$ret[1]=$unescaped;
		}
		return @ret if wantarray;
		return $ret[1];
	};
	goto &$AUTOLOAD;
}

=back

=head1 SEE ALSO

The debconf specification
(/usr/share/doc/debian-policy/debconf_specification.txt.gz).

=head1 AUTHOR

Joey Hess <joeyh@debian.org>

=cut

1

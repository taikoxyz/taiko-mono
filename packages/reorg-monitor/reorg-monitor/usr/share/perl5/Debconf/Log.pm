#!/usr/bin/perl
# This file was preprocessed, do not edit!


package Debconf::Log;
use strict;
use base qw(Exporter);
our @EXPORT_OK=qw(debug warn);
our %EXPORT_TAGS = (all => [@EXPORT_OK]); # Import :all to get everything.
require Debconf::Config; # not use; there are recursive use loops


my $log_open=0;
sub debug {
	my $type=shift;
	
	my $debug=Debconf::Config->debug;
	if ($debug && $type =~ /$debug/) {
		print STDERR "debconf ($type): ".join(" ", @_)."\n";
	}
	
	my $log=Debconf::Config->log;
	if ($log && $type =~ /$log/) {
		require Sys::Syslog;
		unless ($log_open) {
			Sys::Syslog::setlogsock('unix');
			Sys::Syslog::openlog('debconf', '', 'user');
			$log_open=1;
		}
		eval { # ignore all exceptions this throws
			Sys::Syslog::syslog('debug', "($type): ".
				join(" ", @_));
		};
	}
}


sub warn {
	print STDERR "debconf: ".join(" ", @_)."\n"
		unless Debconf::Config->nowarnings eq 'yes';
}


1

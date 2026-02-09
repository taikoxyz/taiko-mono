#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::FrontEnd::ScreenSize;
use strict;
use Debconf::Gettext;
use base qw(Debconf::FrontEnd);


sub init {
	my $this=shift;

	$this->SUPER::init(@_);

	$this->resize; # Get current screen size.
	$SIG{WINCH}=sub {
		if (defined $this) {
			$this->resize;
		}
	};
}


sub resize {
	my $this=shift;

	if (exists $ENV{LINES}) {
		$this->screenheight($ENV{'LINES'});
		$this->screenheight_guessed(0);
	}
	else {
		my ($rows)=`stty -a 2>/dev/null` =~ m/rows (\d+)/s;
		if ($rows) {
			$this->screenheight($rows);
			$this->screenheight_guessed(0);
		}
		else {
			$this->screenheight(25);
			$this->screenheight_guessed(1);
		}
	}

	if (exists $ENV{COLUMNS}) {
		$this->screenwidth($ENV{'COLUMNS'});
	}
	else {
		my ($cols)=`stty -a 2>/dev/null` =~ m/columns (\d+)/s;
		$this->screenwidth($cols || 80);
	}
}


1

#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::FrontEnd::Noninteractive;
use strict;
use Debconf::Encoding qw(width wrap);
use Debconf::Gettext;
use base qw(Debconf::FrontEnd);



sub init { 
        my $this=shift;

        $this->SUPER::init(@_);

        $this->need_tty(0);
}


sub display {
	my $this=shift;
	my $text=shift;

	$Debconf::Encoding::columns=76;
	$this->display_nowrap(wrap('','',$text));
}


sub display_nowrap {
	my $this=shift;
	my $text=shift;

	my @lines=split(/\n/, $text);
	push @lines, "" if $text=~/\n$/;

	my $title=$this->title;
	if (length $title) {
		unshift @lines, $title, ('-' x width $title), '';
		$this->title('');
	}

	foreach (@lines) {
		print "$_\n";
	}
}

1

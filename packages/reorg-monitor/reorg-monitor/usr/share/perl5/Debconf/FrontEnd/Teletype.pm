#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::FrontEnd::Teletype;
use strict;
use Debconf::Encoding qw(width wrap);
use Debconf::Gettext;
use Debconf::Config;
use base qw(Debconf::FrontEnd::ScreenSize);


sub init {
	my $this=shift;

	$this->SUPER::init(@_);
	$this->interactive(1);
	$this->linecount(0);
}


sub display {
	my $this=shift;
	my $text=shift;
	
	$Debconf::Encoding::columns=$this->screenwidth;
	$this->display_nowrap(wrap('','',$text));
}


sub display_nowrap {
	my $this=shift;
	my $text=shift;

	return if Debconf::Config->terse eq 'true';

	my @lines=split(/\n/, $text);
	push @lines, "" if $text=~/\n$/;
	
	my $title=$this->title;
	if (length $title) {
		unshift @lines, $title, ('-' x width $title), '';
		$this->title('');
	}

	foreach (@lines) {
		if (! $this->screenheight_guessed && $this->screenheight > 2 &&
		    $this->linecount($this->linecount+1) > $this->screenheight - 2) {
			my $resp=$this->prompt(
				prompt => '['.gettext("More").']',
				default => '',
				completions => [],
			);
			if (defined $resp && $resp eq 'q') {
				last;
			}
		}
		print "$_\n";
	}
}


sub prompt {
	my $this=shift;
	my %params=@_;

	$this->linecount(0);
	local $|=1;
	print "$params{prompt} ";
	my $ret=<STDIN>;
	chomp $ret if defined $ret;
	$this->display_nowrap("\n");
	return $ret;
}


sub prompt_password {
	my $this=shift;
	my %params=@_;

	delete $params{default};
	system('stty -echo 2>/dev/null');
	my $ret=$this->Debconf::FrontEnd::Teletype::prompt(%params);
	system('stty sane 2>/dev/null');
	return $ret;
}


1

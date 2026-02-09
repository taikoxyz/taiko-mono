#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Teletype::Boolean;
use strict;
use Debconf::Gettext;
use base qw(Debconf::Element);


sub show {
	my $this=shift;

	my $y=gettext("yes");
	my $n=gettext("no");

	$this->frontend->display($this->question->extended_description."\n");

	my $default='';
	$default=$this->question->value if defined $this->question->value;
	if ($default eq 'true') {
		$default=$y;
	}
	elsif ($default eq 'false') {
		$default=$n;
	}

	my $description=$this->question->description;
	if (Debconf::Config->terse eq 'false') {
		$description.=" [$y/$n]";
	}

	my $value='';

	while (1) {
		$_=$this->frontend->prompt(
			default => $default,
			completions => [$y, $n],
			prompt => $description,
			question => $this->question,
		);
		return unless defined $_;

		if (substr($y, 0, 1) ne substr($n, 0, 1)) {
			$y=substr($y, 0, 1);
			$n=substr($n, 0, 1);
		}
		if (/^\Q$y\E/i) {
			$value='true';
			last;
		}
		elsif (/^\Q$n\E/i) {
			$value='false';
			last;
		}

		if (/^y/i) {
			$value='true';
			last;
		}
		elsif (/^n/i) {
			$value='false';
			last;
		}
	}
	
	$this->frontend->display("\n");
	$this->value($value);
}


1

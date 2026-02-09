#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Noninteractive::Select;
use strict;
use base qw(Debconf::Element::Noninteractive);


sub show {
	my $this=shift;

	$this->question->template->i18n('');
	my @choices=$this->question->choices_split;
	$this->question->template->i18n(1);
	my $value=$this->question->value;
	$value='' unless defined $value;
	my $inlist=0;
	map { $inlist=1 if $_ eq $value } @choices;

	if (! $inlist) {
		if (@choices) {
			$this->value($choices[0]);
		}
		else {
			$this->value('');
		}
	}
	else {
		$this->value($value);
	}
}


1

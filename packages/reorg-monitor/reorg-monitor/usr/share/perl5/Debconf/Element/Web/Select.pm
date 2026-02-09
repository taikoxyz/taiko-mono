#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Web::Select;
use strict;
use base qw(Debconf::Element::Select);


sub show {
	my $this=shift;

	$_=$this->question->extended_description;
	s/\n/\n<br>\n/g;
	$_.="\n<p>\n";

	my $default=$this->translate_default;
	my $id=$this->id;
	$_.="<b>".$this->question->description."</b>\n<select name=\"$id\">\n";
	my $c=0;
	foreach my $x ($this->question->choices_split) {
		if ($x ne $default) {
			$_.="<option value=".$c++.">$x\n";
		}
		else {
			$_.="<option value=".$c++." selected>$x\n";
		}
	}
	$_.="</select>\n";
	
	return $_;
}


sub value {
	my $this=shift;

	return $this->SUPER::value() unless @_;
	my $value=shift;

	$this->question->template->i18n('');
	my @choices=$this->question->choices_split;
	$this->question->template->i18n(1);
	$this->SUPER::value($choices[$value]);
}


1

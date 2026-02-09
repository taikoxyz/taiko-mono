#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Web::Multiselect;
use strict;
use base qw(Debconf::Element::Multiselect);


sub show {
	my $this=shift;

	$_=$this->question->extended_description;
	s/\n/\n<br>\n/g;
	$_.="\n<p>\n";

	my %value = map { $_ => 1 } $this->translate_default;

	my $id=$this->id;
	$_.="<b>".$this->question->description."</b>\n<select multiple name=\"$id\">\n";
	my $c=0;
	foreach my $x ($this->question->choices_split) {
		if (! $value{$x}) {
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

	my @values=@_;

	$this->question->template->i18n('');
	my @choices=$this->question->choices_split;
	$this->question->template->i18n(1);
	
	$this->SUPER::value(join(', ',  $this->order_values(map { $choices[$_] } @values)));
}


1

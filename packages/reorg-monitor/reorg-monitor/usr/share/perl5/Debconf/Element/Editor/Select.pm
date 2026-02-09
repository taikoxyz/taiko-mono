#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Editor::Select;
use strict;
use Debconf::Gettext;
use base qw(Debconf::Element::Select);


sub show {
	my $this=shift;

	my $default=$this->translate_default;
	my @choices=$this->question->choices_split;

	$this->frontend->comment($this->question->extended_description."\n\n".
		"(".gettext("Choices").": ".join(", ", @choices).")\n".
		$this->question->description."\n");
	$this->frontend->item($this->question->name, $default);
}


sub value {
	my $this=shift;

	return $this->SUPER::value() unless @_;
	my $value=shift;
	
	my %valid=map { $_ => 1 } $this->question->choices_split;
	
	if ($valid{$value}) {
		return $this->SUPER::value($this->translate_to_C($value));
	}
	else {
		return $this->SUPER::value($this->question->value);
	}
}


1

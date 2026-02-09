#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Editor::Multiselect;
use strict;
use Debconf::Gettext;
use base qw(Debconf::Element::Multiselect);


sub show {
	my $this=shift;

	my @choices=$this->question->choices_split;

	$this->frontend->comment($this->question->extended_description."\n\n".
		"(".gettext("Choices").": ".join(", ", @choices).")\n".
		gettext("(Enter zero or more items separated by a comma followed by a space (', ').)")."\n".
		$this->question->description."\n");

	$this->frontend->item($this->question->name, join ", ", $this->translate_default);
}


sub value {
	my $this=shift;

	return $this->SUPER::value() unless @_;
	my @values=split(',\s+', shift);

	my %valid=map { $_ => 1 } $this->question->choices_split;
	
	$this->SUPER::value(join(', ', $this->order_values(
			map { $this->translate_to_C($_) }
			grep { $valid{$_} } @values)));
}


1

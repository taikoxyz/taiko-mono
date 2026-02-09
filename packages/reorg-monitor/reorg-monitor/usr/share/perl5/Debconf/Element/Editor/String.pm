#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Editor::String;
use strict;
use base qw(Debconf::Element);


sub show {
	my $this=shift;

	$this->frontend->comment($this->question->extended_description."\n\n".
		$this->question->description."\n");

	my $default='';
	$default=$this->question->value if defined $this->question->value;

	$this->frontend->item($this->question->name, $default);
}

1

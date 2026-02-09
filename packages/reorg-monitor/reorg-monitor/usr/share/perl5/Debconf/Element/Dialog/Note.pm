#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Dialog::Note;
use strict;
use base qw(Debconf::Element);


sub show {
	my $this=shift;

	$this->frontend->showtext($this->question, 
		$this->question->description."\n\n".
		$this->question->extended_description
	);
	$this->value('');
}

1

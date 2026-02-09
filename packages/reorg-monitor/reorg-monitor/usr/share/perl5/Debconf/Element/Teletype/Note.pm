#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Teletype::Note;
use strict;
use base qw(Debconf::Element);



sub visible {
        my $this=shift;

	return (Debconf::Config->terse eq 'false');
}

sub show {
	my $this=shift;

	$this->frontend->display($this->question->description."\n\n".
		$this->question->extended_description."\n");

	$this->value('');
}

1

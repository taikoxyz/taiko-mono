#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Noninteractive::Text;
use strict;
use base qw(Debconf::Element::Noninteractive);


sub show {
	my $this=shift;

	$this->value('');
}

1

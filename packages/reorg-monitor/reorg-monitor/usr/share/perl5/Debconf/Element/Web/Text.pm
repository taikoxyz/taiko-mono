#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Web::Text;
use strict;
use base qw(Debconf::Element);


sub show {
	my $this=shift;

	$_=$this->question->extended_description;
	s/\n/\n<br>\n/g;
	$_.="\n<p>\n";

	return "<b>".$this->question->description."</b>$_<p>";
}


1

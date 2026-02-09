#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Web::Password;
use strict;
use base qw(Debconf::Element);


sub show {
	my $this=shift;

	$_=$this->question->extended_description;
	s/\n/\n<br>\n/g;
	$_.="\n<p>\n";

	my $default='';
	$default=$this->question->value if defined $this->question->value;
	my $id=$this->id;
	$_.="<b>".$this->question->description."</b><input type=password name=\"$id\" value=\"$default\">\n";

	return $_;
}


1

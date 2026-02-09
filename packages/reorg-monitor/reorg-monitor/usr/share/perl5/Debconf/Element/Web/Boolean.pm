#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Web::Boolean;
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
	$_.="<input type=checkbox name=\"$id\"". ($default eq 'true' ? ' checked' : ''). ">\n<b>".
		$this->question->description."</b>";

	return $_;
}


sub value {
	my $this=shift;

	return $this->SUPER::value() unless @_;
	my $value=shift;
	$this->SUPER::value($value eq 'on' ? 'true' : 'false');
}


1

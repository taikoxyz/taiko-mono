#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Editor::Boolean;
use strict;
use Debconf::Gettext;
use base qw(Debconf::Element);



sub show {
	my $this=shift;

	$this->frontend->comment($this->question->extended_description."\n\n".
		"(".gettext("Choices").": ".join(", ", gettext("yes"), gettext("no")).")\n".
		$this->question->description."\n");

	my $default='';
	$default=$this->question->value if defined $this->question->value;
	if ($default eq 'true') {
		$default=gettext("yes");
	}
	elsif ($default eq 'false') {
		$default=gettext("no");
	}

	$this->frontend->item($this->question->name, $default);
}


sub value {
	my $this=shift;
	
	return $this->SUPER::value() unless @_;
	my $value=shift;
	
	if ($value eq 'yes' || $value eq gettext("yes")) {
		return $this->SUPER::value('true');
	}
	elsif ($value eq 'no' || $value eq gettext("no")) {
		return $this->SUPER::value('false');
	}
	else {
		return $this->SUPER::value($this->question->value);
	}
}


1

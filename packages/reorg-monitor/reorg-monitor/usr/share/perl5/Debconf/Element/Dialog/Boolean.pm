#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Dialog::Boolean;
use strict;
use base qw(Debconf::Element);


sub show {
	my $this=shift;

	my @params=('--yesno');
	push @params, $this->frontend->dashsep if $this->frontend->dashsep;
	push @params, $this->frontend->makeprompt($this->question, 1);
	if (defined $this->question->value && $this->question->value eq 'false') {
		unshift @params, '--defaultno';
	}

	my ($ret, $value)=$this->frontend->showdialog($this->question, @params);
	if (defined $ret) {
		$this->value($ret eq 0 ? 'true' : 'false');
	}
	else {
		my $default='';
		$default=$this->question->value
			if defined $this->question->value;
		$this->value($default);
	}
}

1

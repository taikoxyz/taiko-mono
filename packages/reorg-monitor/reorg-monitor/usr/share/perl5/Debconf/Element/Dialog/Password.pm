#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Dialog::Password;
use strict;
use base qw(Debconf::Element);


sub show {
	my $this=shift;
	
	my ($text, $lines, $columns)=
		$this->frontend->makeprompt($this->question);

	my @params=('--passwordbox');
	push @params, $this->frontend->dashsep if $this->frontend->dashsep;
	push @params, ($text, $lines + $this->frontend->spacer, $columns);
	my $ret=$this->frontend->showdialog($this->question, @params);

	if (! defined $ret || $ret eq '') {
		my $default='';
		$default=$this->question->value
			if defined $this->question->value;
		$this->value($default);
	}
	else {
		$this->value($ret);
	}
}

1

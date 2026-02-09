#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Teletype::Progress;
use strict;
use base qw(Debconf::Element);


sub start {
	my $this=shift;

	$this->frontend->title($this->question->description);
	$this->frontend->display('');
	$this->last(0);
}

sub set {
	my $this=shift;
	my $value=shift;

	$this->progress_cur($value);

	use integer;
	my $new = ($this->progress_cur() - $this->progress_min()) * 100 / ($this->progress_max() - $this->progress_min());
	$this->last(0) if $new < $this->last;
	return if $new / 10 == $this->last / 10;

	$this->last($new);
	$this->frontend->display("..$new%");

	return 1;
}

sub info {
	return 1;
}

sub stop {
	my $this=shift;

	$this->frontend->display("\n");
	$this->frontend->title($this->frontend->requested_title);
}

1;

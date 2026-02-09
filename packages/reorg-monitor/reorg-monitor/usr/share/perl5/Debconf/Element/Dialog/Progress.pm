#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Dialog::Progress;
use strict;
use base qw(Debconf::Element);


sub _communicate {
	my $this=shift;
	my $data=shift;
	my $dialoginput = $this->frontend->dialog_input_wtr;

	print $dialoginput $data;
}

sub _percent {
	my $this=shift;

	use integer;
	return (($this->progress_cur() - $this->progress_min()) * 100 / ($this->progress_max() - $this->progress_min()));
}

sub start {
	my $this=shift;

	$this->frontend->title($this->question->description);

	my ($text, $lines, $columns);
	if (defined $this->_info) {
		($text, $lines, $columns)=$this->frontend->sizetext($this->_info->description);
	} else {
		($text, $lines, $columns)=$this->frontend->sizetext(' ');
	}
	if ($this->frontend->screenwidth - $this->frontend->columnspacer > $columns) {
		$columns = $this->frontend->screenwidth - $this->frontend->columnspacer;
	}

	my @params=('--gauge');
	push @params, $this->frontend->dashsep if $this->frontend->dashsep;
	push @params, ($text, $lines + $this->frontend->spacer, $columns, $this->_percent);

	$this->frontend->startdialog($this->question, 1, @params);

	$this->_lines($lines);
	$this->_columns($columns);
}

sub set {
	my $this=shift;
	my $value=shift;

	$this->progress_cur($value);
	$this->_communicate($this->_percent . "\n");

	return 1;
}

sub info {
	my $this=shift;
	my $question=shift;

	$this->_info($question);

	my ($text, $lines, $columns)=$this->frontend->sizetext($question->description);
	if ($lines > $this->_lines or $columns > $this->_columns) {
		$this->stop;
		$this->start;
	}


	$this->_communicate(
		sprintf("XXX\n%d\n%s\nXXX\n%d\n",
			$this->_percent, $text, $this->_percent));

	return 1;
}

sub stop {
	my $this=shift;

	$this->frontend->waitdialog;
	$this->frontend->title($this->frontend->requested_title);
}

1

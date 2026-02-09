#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Gnome::Progress;
use strict;
use Gtk3;
use utf8;
use Debconf::Encoding qw(to_Unicode);
use base qw(Debconf::Element::Gnome);


sub _fraction {
	my $this=shift;

	return (($this->progress_cur() - $this->progress_min()) / ($this->progress_max() - $this->progress_min()));
}

sub start {
	my $this=shift;
	my $description=to_Unicode($this->question->description);
	my $frontend=$this->frontend;

	$this->SUPER::init(@_);
	$this->multiline(1);
	$this->expand(1);

	$frontend->title($description);

	$this->widget(Gtk3::ProgressBar->new());
	$this->widget->show;
	$this->widget->set_text(' ');
	$this->addwidget($this->widget);
	$this->addhelp;
}

sub set {
	my $this=shift;
	my $value=shift;

	$this->progress_cur($value);
	$this->widget->set_fraction($this->_fraction);

	return 1;
}

sub info {
	my $this=shift;
	my $question=shift;

	$this->widget->set_text(to_Unicode($question->description));
	
	return 1;
}

sub stop {
	my $this=shift;
	my $frontend=$this->frontend;

	$frontend->title($frontend->requested_title);
}

1;

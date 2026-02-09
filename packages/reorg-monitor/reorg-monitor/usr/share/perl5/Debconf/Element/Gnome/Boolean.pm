#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Gnome::Boolean;
use strict;
use Gtk3;
use utf8;
use Debconf::Encoding qw(to_Unicode);
use base qw(Debconf::Element::Gnome);


sub init {
	my $this=shift;
	my $description=to_Unicode($this->question->description);
	
	$this->SUPER::init(@_);
	
	$this->widget(Gtk3::CheckButton->new($description));
	$this->widget->show;
	$this->widget->set_active(($this->question->value eq 'true') ? 1 : 0);
	$this->addwidget($this->widget);
	$this->tip( $this->widget );
	$this->addhelp;
}


sub value {
	my $this=shift;

	if ($this->widget->get_active) {
		return "true";
	}
	else {
		return "false";
	}
}


1

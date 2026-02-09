#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Gnome::Password;
use strict;
use Gtk3;
use utf8;
use base qw(Debconf::Element::Gnome);



sub init {
	my $this=shift;

	$this->SUPER::init(@_);
	$this->adddescription;

	$this->widget(Gtk3::Entry->new);
	$this->widget->show;
	$this->widget->set_visibility(0);
	$this->addwidget($this->widget);
	$this->tip( $this->widget );
	$this->addhelp;
}


sub value {
	my $this=shift;
	
	my $text = $this->widget->get_chars(0, -1);
	$text = $this->question->value if $text eq '';
	return $text;
}


1

#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Gnome::String;
use strict;
use Gtk3;
use utf8;
use Debconf::Encoding qw(to_Unicode);
use base qw(Debconf::Element::Gnome);


sub init {
	my $this=shift;

	$this->SUPER::init(@_);

	$this->widget(Gtk3::Entry->new);
	$this->widget->show;

	my $default='';
	$default=$this->question->value if defined $this->question->value;
	
	$this->widget->set_text(to_Unicode($default));

	$this->adddescription;
	$this->addwidget($this->widget);
	$this->tip( $this->widget );
	$this->addhelp;
}


sub value {
	my $this=shift;

	return $this->widget->get_chars(0, -1);
}


1

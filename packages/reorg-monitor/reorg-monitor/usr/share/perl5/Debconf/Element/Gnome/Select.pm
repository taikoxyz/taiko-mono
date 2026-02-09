#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Gnome::Select;
use strict;
use Gtk3;
use utf8;
use Debconf::Encoding qw(to_Unicode);
use base qw(Debconf::Element::Gnome Debconf::Element::Select);


sub init {
	my $this=shift;

	my $default=$this->translate_default;
	my @choices=$this->question->choices_split;

	$this->SUPER::init(@_);

	$this->widget(Gtk3::ComboBoxText->new);
	$this->widget->show;

	foreach my $choice (@choices) {
		$this->widget->append_text(to_Unicode($choice));
	}

	$this->widget->set_active(0);
	for (my $choice=0; $choice <= $#choices; $choice++) {
		if ($choices[$choice] eq $default) {
			$this->widget->set_active($choice);
			last;
		}
	}

	$this->adddescription;
	$this->addwidget($this->widget);
	$this->tip( $this->widget );
	$this->addhelp;
}


sub value {
	my $this=shift;

	return $this->translate_to_C_uni($this->widget->get_active_text);
}

*visible = \&Debconf::Element::Select::visible;


1

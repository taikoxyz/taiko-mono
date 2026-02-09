#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Gnome::Text;
use strict;
use Debconf::Gettext;
use utf8;
use base qw(Debconf::Element::Gnome);


sub init {
	my $this=shift;

	$this->SUPER::init(@_);
	$this->adddescription; # yeah, that's all
}


1

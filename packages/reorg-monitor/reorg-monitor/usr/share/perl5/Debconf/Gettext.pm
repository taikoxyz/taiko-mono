#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Gettext;
use strict;


BEGIN {
	eval 'use Locale::gettext';
	if ($@) {
		eval q{
			sub gettext {
				return shift;
			}
		};
	}
	else {
		textdomain('debconf');
	}
}

use base qw(Exporter);
our @EXPORT=qw(gettext);


1

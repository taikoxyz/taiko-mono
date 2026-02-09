#!/usr/bin/perl
# This file was preprocessed, do not edit!


package Debconf::Path;
use strict;
use File::Spec;


sub find {
	my $program=shift;
	my @path=File::Spec->path();
	for my $dir (@path) {
		my $file=File::Spec->catfile($dir, $program);
		return 1 if -x $file;
	}
	return '';
}


1

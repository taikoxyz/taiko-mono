#!/usr/bin/perl
# This file was preprocessed, do not edit!


package Debconf::TmpFile;
use strict;
use IO::File;
use Fcntl;
use File::Temp;


my $filename;

sub open {
	my $fh; # will be autovivified
	my $ext=shift || '';
	($fh, $filename) = File::Temp::tempfile(SUFFIX => $ext);
	return $fh;
}


sub filename {
	return $filename;
}


sub cleanup {
	unlink $filename;
}


1

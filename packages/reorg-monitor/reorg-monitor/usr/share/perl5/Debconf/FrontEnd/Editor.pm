#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::FrontEnd::Editor;
use strict;
use Debconf::Encoding q(wrap);
use Debconf::TmpFile;
use Debconf::Gettext;
use base qw(Debconf::FrontEnd::ScreenSize);

my $fh;


sub init {
	my $this=shift;

	$this->SUPER::init(@_);
	$this->interactive(1);
}


sub comment {
	my $this=shift;
	my $comment=shift;

	print $fh wrap('# ','# ',$comment);
	$this->filecontents(1);
}


sub divider {
	my $this=shift;

	print $fh ("\n".('#' x ($this->screenwidth - 1))."\n");
}


sub item {
	my $this=shift;
	my $name=shift;
	my $value=shift;

	print $fh "$name=\"$value\"\n\n";
	$this->filecontents(1);
}


sub go {
	my $this=shift;
	my @elements=@{$this->elements};
	return 1 unless @elements;
	
	$fh = Debconf::TmpFile::open('.sh');

	$this->comment(gettext("You are using the editor-based debconf frontend to configure your system. See the end of this document for detailed instructions."));
	$this->divider;
	print $fh ("\n");

	$this->filecontents('');
	foreach my $element (@elements) {
		$element->show;
	}

	if (! $this->filecontents) {
		Debconf::TmpFile::cleanup();
		return 1;
	}
	
	$this->divider;
	$this->comment(gettext("The editor-based debconf frontend presents you with one or more text files to edit. This is one such text file. If you are familiar with standard unix configuration files, this file will look familiar to you -- it contains comments interspersed with configuration items. Edit the file, changing any items as necessary, and then save it and exit. At that point, debconf will read the edited file, and use the values you entered to configure the system."));
	print $fh ("\n");
	close $fh;
	
	my $editor=$ENV{EDITOR} || $ENV{VISUAL} || '/usr/bin/editor';
	system "$editor ".Debconf::TmpFile->filename;

	my %eltname=map { $_->question->name => $_ } @elements;
	open (IN, "<".Debconf::TmpFile::filename());
	while (<IN>) {
		next if /^\s*#/;

		if (/(.*?)="(.*)"/ && $eltname{$1}) {
			$eltname{$1}->value($2);
		}
	}
	close IN;
	
	Debconf::TmpFile::cleanup();

	return 1;
}


sub screenwidth {
	my $this=shift;

	$Debconf::Encoding::columns=$this->SUPER::screenwidth(@_);
}


1

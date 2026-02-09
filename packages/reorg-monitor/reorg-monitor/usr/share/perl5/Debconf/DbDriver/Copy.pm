#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::DbDriver::Copy;
use strict;
use Debconf::Log qw{:all};
use base 'Debconf::DbDriver';


sub copy {
	my $this=shift;
	my $item=shift;
	my $src=shift;
	my $dest=shift;
	
	debug "db $this->{name}" => "copying $item from $src->{name} to $dest->{name}";
	
	my @owners=$src->owners($item);
	if (! @owners) {
		@owners=("unknown");
	}
	foreach my $owner (@owners) {
		my $template = Debconf::Template->get($src->getfield($item, 'template'));
		my $type="";
		$type = $template->type if $template;
		$dest->addowner($item, $owner, $type);
	}
	foreach my $field ($src->fields($item)) {
		$dest->setfield($item, $field, $src->getfield($item, $field));
	}
	foreach my $flag ($src->flags($item)) {
		$dest->setflag($item, $flag, $src->getflag($item, $flag));
	}
	foreach my $var ($src->variables($item)) {
		$dest->setvariable($item, $var, $src->getvariable($item, $var));
	}
}


1

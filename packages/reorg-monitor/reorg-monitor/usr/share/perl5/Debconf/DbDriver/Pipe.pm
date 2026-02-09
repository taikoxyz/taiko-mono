#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::DbDriver::Pipe;
use strict;
use Debconf::Log qw(:all);
use base 'Debconf::DbDriver::Cache';


use fields qw(infd outfd format);


sub init {
	my $this=shift;

	$this->{format} = "822" unless exists $this->{format};

	$this->error("No format specified") unless $this->{format};
	eval "use Debconf::Format::$this->{format}";
	if ($@) {
		$this->error("Error setting up format object $this->{format}: $@");
	}
	$this->{format}="Debconf::Format::$this->{format}"->new;
	if (not ref $this->{format}) {
		$this->error("Unable to make format object");
	}

	my $fh;
	if (defined $this->{infd}) {
		if ($this->{infd} ne 'none') {
			open ($fh, "<&=$this->{infd}") or
				$this->error("could not open file descriptor #$this->{infd}: $!");
		}
	}
	else {	
		open ($fh, '-');
	}

	$this->SUPER::init(@_);

	debug "db $this->{name}" => "loading database";

	if (defined $fh) {
		while (! eof $fh) {
			my ($item, $cache)=$this->{format}->read($fh);
			$this->{cache}->{$item}=$cache;
		}
		close $fh;
	}
}


sub shutdown {
	my $this=shift;

	return if $this->{readonly};

	my $fh;
	if (defined $this->{outfd}) {
		if ($this->{outfd} ne 'none') {
			open ($fh, ">&=$this->{outfd}") or
				$this->error("could not open file descriptor #$this->{outfd}: $!");
		}
	}
	else {
		open ($fh, '>-');
	}
	
	if (defined $fh) {
		$this->{format}->beginfile;
		foreach my $item (sort keys %{$this->{cache}}) {
			next unless defined $this->{cache}->{$item}; # skip deleted
			$this->{format}->write($fh, $this->{cache}->{$item}, $item)
				or $this->error("could not write to pipe: $!");
		}
		$this->{format}->endfile;
		close $fh or $this->error("could not close pipe: $!");
	}

	return 1;
}


sub load {
	return undef;
}


1

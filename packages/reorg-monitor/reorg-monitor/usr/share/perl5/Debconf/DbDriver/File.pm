#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::DbDriver::File;
use strict;
use Debconf::Log qw(:all);
use Cwd 'abs_path';
use POSIX ();
use Fcntl qw(:DEFAULT :flock);
use IO::Handle;
use base 'Debconf::DbDriver::Cache';


use fields qw(filename mode format _fh);


sub init {
	my $this=shift;

	if (exists $this->{mode}) {
		$this->{mode} = oct($this->{mode});
	}
	else {
		$this->{mode} = 0600;
	}
	$this->{format} = "822" unless exists $this->{format};
	$this->{backup} = 1 unless exists $this->{backup};

	$this->error("No format specified") unless $this->{format};
	eval "use Debconf::Format::$this->{format}";
	if ($@) {
		$this->error("Error setting up format object $this->{format}: $@");
	}
	$this->{format}="Debconf::Format::$this->{format}"->new;
	if (not ref $this->{format}) {
		$this->error("Unable to make format object");
	}

	$this->error("No filename specified") unless $this->{filename};

	my ($directory)=$this->{filename}=~m!^(.*)/[^/]+!;
	if (length $directory and ! -d $directory) {
		mkdir $directory || $this->error("mkdir $directory:$!");
	}

	if (exists $this->{root}) {
		$this->{filename} = $this->{root} . $this->{filename};
	}
	$this->{filename} = abs_path($this->{filename});

	debug "db $this->{name}" => "started; filename is $this->{filename}";
	
	if (! -e $this->{filename}) {
		$this->{backup}=0;
		sysopen(my $fh, $this->{filename}, 
				O_WRONLY|O_TRUNC|O_CREAT,$this->{mode}) or
			$this->error("could not open $this->{filename}");
		close $fh;
	}

	my $implicit_readonly=0;
	if (! $this->{readonly}) {
		if (open ($this->{_fh}, "+<", $this->{filename})) {
			while (! flock($this->{_fh}, LOCK_EX | LOCK_NB)) {
				next if $! == &POSIX::EINTR;
				$this->error("$this->{filename} is locked by another process: $!");
				last;
			}
		}
		else {
			$implicit_readonly=1;
		}
	}
	if ($this->{readonly} || $implicit_readonly) {
		if (! open ($this->{_fh}, "<", $this->{filename})) {
			$this->error("could not open $this->{filename}: $!");
			return; # always abort, even if not throwing fatal error
		}
	}

	$this->SUPER::init(@_);

	debug "db $this->{name}" => "loading database";

	while (! eof $this->{_fh}) {
		my ($item, $cache)=$this->{format}->read($this->{_fh});
		$this->{cache}->{$item}=$cache;
	}
	if ($this->{readonly} || $implicit_readonly) {
		close $this->{_fh};
	}
}


sub shutdown {
	my $this=shift;

	return if $this->{readonly};

	if (grep $this->{dirty}->{$_}, keys %{$this->{cache}}) {
		debug "db $this->{name}" => "saving database";
	}
	else {
		debug "db $this->{name}" => "no database changes, not saving";

		delete $this->{_fh};

		return 1;
	}

	sysopen(my $fh, $this->{filename}."-new",
			O_WRONLY|O_TRUNC|O_CREAT,$this->{mode}) or
		$this->error("could not write $this->{filename}-new: $!");
	while (! flock($fh, LOCK_EX | LOCK_NB)) {
		next if $! == &POSIX::EINTR;
		$this->error("$this->{filename}-new is locked by another process: $!");
		last;
	}
	$this->{format}->beginfile;
	foreach my $item (sort keys %{$this->{cache}}) {
		next unless defined $this->{cache}->{$item}; # skip deleted
		$this->{format}->write($fh, $this->{cache}->{$item}, $item)
			or $this->error("could not write $this->{filename}-new: $!");
	}
	$this->{format}->endfile;

	$fh->flush or $this->error("could not flush $this->{filename}-new: $!");
	$fh->sync or $this->error("could not sync $this->{filename}-new: $!");

	if (-e $this->{filename} && $this->{backup}) {
		rename($this->{filename}, $this->{filename}."-old") or
			debug "db $this->{name}" => "rename failed: $!";
	}
	rename($this->{filename}."-new", $this->{filename}) or
		$this->error("rename failed: $!");

	delete $this->{_fh};

	return 1;
}


sub load {
	return undef;
}


1

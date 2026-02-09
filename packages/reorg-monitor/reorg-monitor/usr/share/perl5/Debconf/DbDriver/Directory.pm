#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::DbDriver::Directory;
use strict;
use Debconf::Log qw(:all);
use IO::File;
use POSIX ();
use Fcntl qw(:DEFAULT :flock);
use Debconf::Iterator;
use base 'Debconf::DbDriver::Cache';


use fields qw(directory extension lock format);


sub init {
	my $this=shift;

	$this->{extension} = "" unless exists $this->{extension};
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

	$this->error("No directory specified") unless $this->{directory};
	if (exists $this->{root}) {
		$this->{directory} = $this->{root} . $this->{directory};
	}
	if (not -d $this->{directory} and not $this->{readonly}) {
		mkdir $this->{directory} ||
			$this->error("mkdir $this->{directory}:$!");
	}
	if (not -d $this->{directory}) {
		$this->error($this->{directory}." does not exist");
	}
	debug "db $this->{name}" => "started; directory is $this->{directory}";
	
	if (! $this->{readonly}) {
		open ($this->{lock}, ">".$this->{directory}."/.lock") or
			$this->error("could not lock $this->{directory}: $!");
		while (! flock($this->{lock}, LOCK_EX | LOCK_NB)) {
			next if $! == &POSIX::EINTR;
			$this->error("$this->{directory} is locked by another process: $!");
			last;
		}
	}
}


sub load {
	my $this=shift;
	my $item=shift;

	debug "db $this->{name}" => "loading $item";
	my $file=$this->{directory}.'/'.$this->filename($item);
	return unless -e $file;

	my $fh=IO::File->new;
	open($fh, $file) or $this->error("$file: $!");
	$this->cacheadd($this->{format}->read($fh));
	close $fh;
}


sub save {
	my $this=shift;
	my $item=shift;
	my $data=shift;
	
	return unless $this->accept($item);
	return if $this->{readonly};
	debug "db $this->{name}" => "saving $item";
	
	my $file=$this->{directory}.'/'.$this->filename($item);

	my $fh=IO::File->new;
	if ($this->ispassword($item)) {
		sysopen($fh, $file."-new", O_WRONLY|O_TRUNC|O_CREAT, 0600)
			or $this->error("$file-new: $!");
	}
	else {
		open($fh, ">$file-new") or $this->error("$file-new: $!");
	}
	$this->{format}->beginfile;
	$this->{format}->write($fh, $data, $item)
		or $this->error("could not write $file-new: $!");
	$this->{format}->endfile;
	
	$fh->flush or $this->error("could not flush $file-new: $!");
	$fh->sync or $this->error("could not sync $file-new: $!");
	close $fh or $this->error("could not close $file-new: $!");
	
	if (-e $file && $this->{backup}) {
		rename($file, $file."-old") or
			debug "db $this->{name}" => "rename failed: $!";
	}
	rename("$file-new", $file) or $this->error("rename failed: $!");
}


sub shutdown {
	my $this=shift;
	
	$this->SUPER::shutdown(@_);
	delete $this->{lock};
	return 1;
}


sub exists {
	my $this=shift;
	my $name=shift;
	
	my $incache=$this->SUPER::exists($name);
	return $incache if (!defined $incache or $incache);

	return -e $this->{directory}.'/'.$this->filename($name);
}


sub remove {
	my $this=shift;
	my $name=shift;

	return if $this->{readonly} or not $this->accept($name);
	debug "db $this->{name}" => "removing $name";
	my $file=$this->{directory}.'/'.$this->filename($name);
	unlink $file or return undef;
	if (-e $file."-old") {
		unlink $file."-old" or return undef;
	}
	return 1;
}


sub accept {
	my $this=shift;
	my $name=shift;

	return if $name=~m#\.\./# or $name=~m#/\.\.#;
	$this->SUPER::accept($name, @_);
}


1

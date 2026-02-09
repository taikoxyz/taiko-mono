#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::DbDriver::PackageDir;
use strict;
use Debconf::Log qw(:all);
use IO::File;
use Fcntl qw(:DEFAULT :flock);
use Debconf::Iterator;
use base 'Debconf::DbDriver::Directory';


use fields qw(mode _loaded);


sub init {
	my $this=shift;

	if (exists $this->{mode}) {
		$this->{mode} = oct($this->{mode});
	}
	else {
		$this->{mode} = 0600;
	}
	$this->SUPER::init(@_);
}


sub loadfile {
	my $this=shift;
	my $file=$this->{directory}."/".shift;

	return if $this->{_loaded}->{$file};
	$this->{_loaded}->{$file}=1;
	
	debug "db $this->{name}" => "loading $file";
	return unless -e $file;

	my $fh=IO::File->new;
	open($fh, $file) or $this->error("$file: $!");
	my @item = $this->{format}->read($fh);
	while (@item) {
		$this->cacheadd(@item);
		@item = $this->{format}->read($fh);
	}
	close $fh;
}


sub load {
	my $this=shift;
	my $item=shift;
	$this->loadfile($this->filename($item));
}


sub filename {
	my $this=shift;
	my $item=shift;

	if ($item =~ m!^([^/]+)(?:/|$)!) {
		return $1.$this->{extension};
	}
	else {
		$this->error("failed parsing item name \"$item\"\n");
	}
}


sub iterator {
	my $this=shift;
	
	my $handle;
	opendir($handle, $this->{directory}) ||
		$this->error("opendir: $!");

	while (my $file=readdir($handle)) {
		next if length $this->{extension} and
		        not $file=~m/$this->{extension}/;
		next unless -f $this->{directory}."/".$file;
		next if $file eq '.lock' || $file =~ /-old$/;
		$this->loadfile($file);
	}

	$this->SUPER::iterator;
}


sub exists {
	my $this=shift;
	my $name=shift;
	my $incache=$this->Debconf::DbDriver::Cache::exists($name);
	return $incache if (!defined $incache or $incache);
	my $file=$this->{directory}.'/'.$this->filename($name);
	return unless -e $file;

	$this->load($name);
	
	return $this->Debconf::DbDriver::Cache::exists($name);
}


sub shutdown {
	my $this=shift;

	return if $this->{readonly};

	my (%files, %filecontents, %killfiles, %dirtyfiles);
	foreach my $item (keys %{$this->{cache}}) {
		my $file=$this->filename($item);
		$files{$file}++;
		
		if (! defined $this->{cache}->{$item}) {
			$killfiles{$file}++;
			delete $this->{cache}->{$item};
		}
		else {
			push @{$filecontents{$file}}, $item;
		}

		if ($this->{dirty}->{$item}) {
			$dirtyfiles{$file}++;
			$this->{dirty}->{$item}=0;
		}
	}

	foreach my $file (keys %files) {
		if (! $filecontents{$file} && $killfiles{$file}) {
			debug "db $this->{name}" => "removing $file";
			my $filename=$this->{directory}."/".$file;
			unlink $filename or
				$this->error("unable to remove $filename: $!");
			if (-e $filename."-old") {
				unlink $filename."-old" or
					$this->error("unable to remove $filename-old: $!");
			}
		}
		elsif ($dirtyfiles{$file}) {
			debug "db $this->{name}" => "saving $file";
			my $filename=$this->{directory}."/".$file;
		
			sysopen(my $fh, $filename."-new",
			                O_WRONLY|O_TRUNC|O_CREAT,$this->{mode}) or
				$this->error("could not write $filename-new: $!");
			$this->{format}->beginfile;
			foreach my $item (@{$filecontents{$file}}) {
				$this->{format}->write($fh, $this->{cache}->{$item}, $item)
					or $this->error("could not write $filename-new: $!");
			}
			$this->{format}->endfile;

			$fh->flush or $this->error("could not flush $filename-new: $!");
			$fh->sync or $this->error("could not sync $filename-new: $!");

			if (-e $filename && $this->{backup}) {
				rename($filename, $filename."-old") or
					debug "db $this->{name}" => "rename failed: $!";
			}
			rename($filename."-new", $filename) or
				$this->error("rename failed: $!");
		}
	}
	
	$this->SUPER::shutdown(@_);
	return 1;
}


1

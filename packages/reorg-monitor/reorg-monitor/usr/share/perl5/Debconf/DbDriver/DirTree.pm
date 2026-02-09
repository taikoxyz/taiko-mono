#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::DbDriver::DirTree;
use strict;
use Debconf::Log qw(:all);
use base 'Debconf::DbDriver::Directory';


sub init {
	my $this=shift;
	if (! defined $this->{extension} or ! length $this->{extension}) {
		$this->{extension}=".dat";
	}
	$this->SUPER::init(@_);
}


sub save {
	my $this=shift;
	my $item=shift;

	return unless $this->accept($item);
	return if $this->{readonly};
	
	my @dirs=split(m:/:, $this->filename($item));
	pop @dirs; # the base filename
	my $base=$this->{directory};
	foreach (@dirs) {
		$base.="/$_";
		next if -d $base;
		mkdir $base or $this->error("mkdir $base: $!");
	}
	
	$this->SUPER::save($item, @_);
}


sub filename {
	my $this=shift;
	my $item=shift;
	$item =~ s/\.\.//g;
	return $item.$this->{extension};
}


sub iterator {
	my $this=shift;
	
	my @stack=();
	my $currentdir="";
	my $handle;
	opendir($handle, $this->{directory}) or
		$this->error("opendir: $this->{directory}: $!");
		
	my $iterator=Debconf::Iterator->new(callback => sub {
		my $i;
		while ($handle or @stack) {
			while (@stack and not $handle) {
				$currentdir=pop @stack;
				opendir($handle, "$this->{directory}/$currentdir") or
					$this->error("opendir: $this->{directory}/$currentdir: $!");
			}
			$i=readdir($handle);
			if (not defined $i) {
			closedir $handle;
				$handle=undef;
				next;
			}
			next if $i eq '.lock' || $i =~ /-old$/;
			if (-d "$this->{directory}/$currentdir$i") {
				if ($i ne '..' and $i ne '.') {
					push @stack, "$currentdir$i/";
				}
				next;
			}
			next unless $i=~s/$this->{extension}$//;
			return $currentdir.$i;
		}
		return undef;
	});

	$this->SUPER::iterator($iterator);
}


sub remove {
	my $this=shift;
	my $item=shift;

	my $ret=$this->SUPER::remove($item);
	return $ret unless $ret;

	my $dir=$this->filename($item);
	while ($dir=~s:(.*)/[^/]*:$1: and length $dir) {
		rmdir "$this->{directory}/$dir" or last; # not empty, I presume
	}
	return $ret;
}


1

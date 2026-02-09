#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::DbDriver::Cache;
use strict;
use Debconf::Log qw{:all};
use base 'Debconf::DbDriver';


use fields qw(cache dirty);


sub iterator {
	my $this=shift;
	my $subiterator=shift;

	my @items=keys %{$this->{cache}};
	my $iterator=Debconf::Iterator->new(callback => sub {
		while (my $item = pop @items) {
			next unless defined $this->{cache}->{$item};
			return $item;
		}
		return unless $subiterator;
		my $ret;
		do {
			$ret=$subiterator->iterate;
		} while defined $ret and exists $this->{cache}->{$ret};
		return $ret;
	});
	return $iterator;
}


sub exists {
	my $this=shift;
	my $item=shift;

	return $this->{cache}->{$item}
		if exists $this->{cache}->{$item};
	return 0;
}


sub init {
	my $this=shift;

	$this->{cache} = {} unless exists $this->{cache};
}


sub cacheadd {
	my $this=shift;
	my $item=shift;
	my $entry=shift;

	return if exists $this->{cache}->{$item};

	$this->{cache}->{$item}=$entry;
	$this->{dirty}->{$item}=0;
}


sub cachedata {
	my $this=shift;
	my $item=shift;
	
	return $this->{cache}->{$item};
}


sub cached {
	my $this=shift;
	my $item=shift;

	unless (exists $this->{cache}->{$item}) {
		debug "db $this->{name}" => "cache miss on $item";
		$this->load($item);
	}
	return $this->{cache}->{$item};
}


sub shutdown {
	my $this=shift;
	
	return if $this->{readonly};

	my $ret=1;
	foreach my $item (keys %{$this->{cache}}) {
		if (not defined $this->{cache}->{$item}) {
			$ret=undef unless defined $this->remove($item);
			delete $this->{cache}->{$item};
		}
		elsif ($this->{dirty}->{$item}) {
			$ret=undef unless defined $this->save($item, $this->{cache}->{$item});
			$this->{dirty}->{$item}=0;
		}
	}
	return $ret;
}


sub addowner {
	my $this=shift;
	my $item=shift;
	my $owner=shift;
	my $type=shift;

	return if $this->{readonly};
	$this->cached($item);

	if (! defined $this->{cache}->{$item}) {
		return if ! $this->accept($item, $type);
		debug "db $this->{name}" => "creating in-cache $item";
		$this->{cache}->{$item}={
			owners => {},
			fields => {},
			variables => {},
			flags => {},
		}
	}

	if (! exists $this->{cache}->{$item}->{owners}->{$owner}) {
		$this->{cache}->{$item}->{owners}->{$owner}=1;
		$this->{dirty}->{$item}=1;
	}
	return $owner;
}


sub removeowner {
	my $this=shift;
	my $item=shift;
	my $owner=shift;

	return if $this->{readonly};
	return unless $this->cached($item);

	if (exists $this->{cache}->{$item}->{owners}->{$owner}) {
		delete $this->{cache}->{$item}->{owners}->{$owner};
		$this->{dirty}->{$item}=1;
	}
	unless (keys %{$this->{cache}->{$item}->{owners}}) {
		$this->{cache}->{$item}=undef;
		$this->{dirty}->{$item}=1;
	}
	return $owner;
}


sub owners {
	my $this=shift;
	my $item=shift;

	return unless $this->cached($item);
	return keys %{$this->{cache}->{$item}->{owners}};
}


sub getfield {
	my $this=shift;
	my $item=shift;
	my $field=shift;
	
	return unless $this->cached($item);
	return $this->{cache}->{$item}->{fields}->{$field};
}


sub setfield {
	my $this=shift;
	my $item=shift;
	my $field=shift;
	my $value=shift;

	return if $this->{readonly};
	return unless $this->cached($item);
	$this->{dirty}->{$item}=1;
	return $this->{cache}->{$item}->{fields}->{$field} = $value;	
}


sub removefield {
	my $this=shift;
	my $item=shift;
	my $field=shift;

	return if $this->{readonly};
	return unless $this->cached($item);
	$this->{dirty}->{$item}=1;
	return delete $this->{cache}->{$item}->{fields}->{$field};
}


sub fields {
	my $this=shift;
	my $item=shift;
	
	return unless $this->cached($item);
	return keys %{$this->{cache}->{$item}->{fields}};
}


sub getflag {
	my $this=shift;
	my $item=shift;
	my $flag=shift;
	
	return unless $this->cached($item);
	return $this->{cache}->{$item}->{flags}->{$flag}
		if exists $this->{cache}->{$item}->{flags}->{$flag};
	return 'false';
}


sub setflag {
	my $this=shift;
	my $item=shift;
	my $flag=shift;
	my $value=shift;

	return if $this->{readonly};
	return unless $this->cached($item);
	$this->{dirty}->{$item}=1;
	return $this->{cache}->{$item}->{flags}->{$flag} = $value;
}


sub flags {
	my $this=shift;
	my $item=shift;

	return unless $this->cached($item);
	return keys %{$this->{cache}->{$item}->{flags}};
}


sub getvariable {
	my $this=shift;
	my $item=shift;
	my $variable=shift;

	return unless $this->cached($item);
	return $this->{cache}->{$item}->{variables}->{$variable};
}


sub setvariable {
	my $this=shift;
	my $item=shift;
	my $variable=shift;
	my $value=shift;

	return if $this->{readonly};
	return unless $this->cached($item);
	$this->{dirty}->{$item}=1;
	return $this->{cache}->{$item}->{variables}->{$variable} = $value;
}


sub variables {
	my $this=shift;
	my $item=shift;

	return unless $this->cached($item);
	return keys %{$this->{cache}->{$item}->{variables}};
}


1

#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::DbDriver::Stack;
use strict;
use Debconf::Log qw{:all};
use Debconf::Iterator;
use base 'Debconf::DbDriver::Copy';



use fields qw(stack stack_change_errors);


sub init {
	my $this=shift;

	if (! ref $this->{stack}) {
		my @stack;
		foreach my $name (split(/\s*,\s/, $this->{stack})) {
			my $driver=$this->driver($name);
			unless (defined $driver) {
				$this->error("could not find a db named \"$name\" to use in the stack (it should be defined before the stack in the config file)");
				next;
			}
			push @stack, $driver;
		}
		$this->{stack}=[@stack];
	}

	$this->error("no stack set") if ! ref $this->{stack};
	$this->error("stack is empty") if ! @{$this->{stack}};
}


sub iterator {
	my $this=shift;

	my %seen;
	my @iterators = map { $_->iterator } @{$this->{stack}};
	my $i = pop @iterators;
	my $iterator=Debconf::Iterator->new(callback => sub {
		for (;;) {
			while (my $ret = $i->iterate) {
				next if $seen{$ret};
				$seen{$ret}=1;
				return $ret;
			}
			$i = pop @iterators;
			return undef unless defined $i;
		}
	});
}


sub shutdown {
	my $this=shift;

	my $ret=1;
	foreach my $driver (@{$this->{stack}}) {
		$ret=undef if not defined $driver->shutdown(@_);
	}

	if ($this->{stack_change_errors}) {
		$this->error("unable to save changes to: ".
			join(" ", @{$this->{stack_change_errors}}));
		$ret=undef;
	}

	return $ret;
}


sub exists {
	my $this=shift;

	foreach my $driver (@{$this->{stack}}) {
		return 1 if $driver->exists(@_);
	}
	return 0;
}

sub _query {
	my $this=shift;
	my $command=shift;
	shift; # this again
	
	debug "db $this->{name}" => "trying to $command(@_) ..";
	foreach my $driver (@{$this->{stack}}) {
		if (wantarray) {
			my @ret=$driver->$command(@_);
			debug "db $this->{name}" => "$command done by $driver->{name}" if @ret;
			return @ret if @ret;
		}
		else {
			my $ret=$driver->$command(@_);
			debug "db $this->{name}" => "$command done by $driver->{name}" if defined $ret;
			return $ret if defined $ret;
		}
	}
	return; # failure
}

sub _change {
	my $this=shift;
	my $command=shift;
	shift; # this again
	my $item=shift;

	debug "db $this->{name}" => "trying to $command($item @_) ..";

	foreach my $driver (@{$this->{stack}}) {
		if ($driver->exists($item)) {
			last if $driver->{readonly}; # nope, hit a readonly one
			debug "db $this->{name}" => "passing to $driver->{name} ..";
			return $driver->$command($item, @_);
		}
	}

	my $src=0;

	foreach my $driver (@{$this->{stack}}) {
		if ($driver->exists($item)) {
			my $ret=$this->_nochange($driver, $command, $item, @_);
			if (defined $ret) {
				debug "db $this->{name}" => "skipped $command($item) as it would have no effect";
				return $ret;
			}

			$src=$driver;
			last
		}
	}

	my $writer;
	foreach my $driver (@{$this->{stack}}) {
		if ($driver == $src) {
			push @{$this->{stack_change_errors}}, $item;
			return;
		}
		if (! $driver->{readonly}) {
			if ($command eq 'addowner') {
				if ($driver->accept($item, $_[1])) {
					$writer=$driver;
					last;
				}
			}
			elsif ($driver->accept($item)) {
				$writer=$driver;
				last;
			}
		}
	}
	
	unless ($writer) {
		debug "db $this->{name}" => "FAILED $command";
		return;
	}

	if ($src) {		
		$this->copy($item, $src, $writer);
	}

	debug "db $this->{name}" => "passing to $writer->{name} ..";
	return $writer->$command($item, @_);
}

sub _nochange {
	my $this=shift;
	my $driver=shift;
	my $command=shift;
	my $item=shift;

	if ($command eq 'addowner') {
		my $value=shift;
		foreach my $owner ($driver->owners($item)) {
			return $value if $owner eq $value;
		}
		return;
	}
	elsif ($command eq 'removeowner') {
		my $value=shift;
		
		foreach my $owner ($driver->owners($item)) {
			return if $owner eq $value;
		}
		return $value; # no change
	}
	elsif ($command eq 'removefield') {
		my $value=shift;
		
		foreach my $field ($driver->fields($item)) {
			return if $field eq $value;
		}
		return $value; # no change
	}

	my @list;
	my $get;
	if ($command eq 'setfield') {
		@list=$driver->fields($item);
		$get='getfield';
	}
	elsif ($command eq 'setflag') {
		@list=$driver->flags($item);
		$get='getflag';
	}
	elsif ($command eq 'setvariable') {
		@list=$driver->variables($item);
		$get='getvariable';
	}
	else {
		$this->error("internal error; bad command: $command");
	}

	my $thing=shift;
	my $value=shift;
	my $currentvalue=$driver->$get($item, $thing);
	
	my $exists=0;
	foreach my $i (@list) {
		$exists=1, last if $thing eq $i;
	}
	return $currentvalue unless $exists;

	return $currentvalue if $currentvalue eq $value;
	return undef;
}

sub addowner	{ $_[0]->_change('addowner', @_)	}
sub removeowner { $_[0]->_change('removeowner', @_)	}
sub owners	{ $_[0]->_query('owners', @_)		}
sub getfield	{ $_[0]->_query('getfield', @_)		}
sub setfield	{ $_[0]->_change('setfield', @_)	}
sub removefield { $_[0]->_change('removefield', @_)	}
sub fields	{ $_[0]->_query('fields', @_)		}
sub getflag	{ $_[0]->_query('getflag', @_)		}
sub setflag	{ $_[0]->_change('setflag', @_)		}
sub flags	{ $_[0]->_query('flags', @_)		}
sub getvariable { $_[0]->_query('getvariable', @_)	}
sub setvariable { $_[0]->_change('setvariable', @_)	}
sub variables	{ $_[0]->_query('variables', @_)	}


1

#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::DbDriver::Debug;
use strict;
use Debconf::Log qw{:all};
use base 'Debconf::DbDriver';



use fields qw(db);


sub init {
	my $this=shift;

	if (! ref $this->{db}) {
		$this->{db}=$this->driver($this->{db});
		unless (defined $this->{db}) {
			$this->error("could not find db");
		}
	}
}

sub DESTROY {}

sub AUTOLOAD {
	my $this=shift;
	(my $command = our $AUTOLOAD) =~ s/.*://;

	debug "db $this->{name}" => "running $command(".join(",", map { "'$_'" } @_).") ..";
	if (wantarray) {
		my @ret=$this->{db}->$command(@_);
		debug "db $this->{name}" => "$command returned (".join(", ", @ret).")";
		return @ret if @ret;
	}
	else {
		my $ret=$this->{db}->$command(@_);
		if (defined $ret) {
			debug "db $this->{name}" => "$command returned \'$ret\'";
			return $ret;
		}
		else  {
			debug "db $this->{name}" => "$command returned undef";
		}
	}
	return; # failure
}


1

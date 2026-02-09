#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::DbDriver::Backup;
use strict;
use Debconf::Log qw{:all};
use base 'Debconf::DbDriver::Copy';



use fields qw(db backupdb);


sub init {
	my $this=shift;

	foreach my $f (qw(db backupdb)) {
		if (! ref $this->{$f}) {
			my $db=$this->driver($this->{$f});
			unless (defined $f) {
				$this->error("could not find a db named \"$this->{$f}\"");
			}
			$this->{$f}=$db;
		}
	}
}


sub copy {
	my $this=shift;
	my $item=shift;

	$this->SUPER::copy($item, $this->{db}, $this->{backupdb});
}


sub shutdown {
	my $this=shift;
	
	$this->{backupdb}->shutdown(@_);
	$this->{db}->shutdown(@_);
}

sub _query {
	my $this=shift;
	my $command=shift;
	shift; # this again
	
	return $this->{db}->$command(@_);
}

sub _change {
	my $this=shift;
	my $command=shift;
	shift; # this again

	my $ret=$this->{db}->$command(@_);
	if (defined $ret) {
		$this->{backupdb}->$command(@_);
	}
	return $ret;
}

sub iterator	{ $_[0]->_query('iterator', @_)		}
sub exists	{ $_[0]->_query('exists', @_)		}
sub addowner	{ $_[0]->_change('addowner', @_)	}
sub removeowner { $_[0]->_change('removeowner', @_)	}
sub owners	{ $_[0]->_query('owners', @_)		}
sub getfield	{ $_[0]->_query('getfield', @_)		}
sub setfield	{ $_[0]->_change('setfield', @_)	}
sub fields	{ $_[0]->_query('fields', @_)		}
sub getflag	{ $_[0]->_query('getflag', @_)		}
sub setflag	{ $_[0]->_change('setflag', @_)		}
sub flags	{ $_[0]->_query('flags', @_)		}
sub getvariable { $_[0]->_query('getvariable', @_)	}
sub setvariable { $_[0]->_change('setvariable', @_)	}
sub variables	{ $_[0]->_query('variables', @_)	}


1

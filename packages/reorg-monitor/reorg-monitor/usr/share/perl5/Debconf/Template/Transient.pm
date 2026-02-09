#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Template::Transient;
use strict;
use base 'Debconf::Template';
use fields qw(_fields);



sub new {
	my $this=shift;
	my $template=shift;
	
	unless (ref $this) {
		$this = fields::new($this);
	}
	$this->{template}=$template;
	$this->{_fields}={};
	return $this;
}


sub get {
	die "get not supported on transient templates";
}


sub fields {
	my $this=shift;

	return keys %{$this->{_fields}};
}

                
sub clearall {
	my $this=shift;

	foreach my $field (keys %{$this->{_fields}}) {
		delete $this->{_fields}->{$field};
	}
}


{
	my @langs=Debconf::Template::_getlangs();

	sub AUTOLOAD {
		(my $field = our $AUTOLOAD) =~ s/.*://;
		no strict 'refs';
		*$AUTOLOAD = sub {
			my $this=shift;

			return $this->{_fields}->{$field}=shift if @_;
		
			if ($Debconf::Template::i18n && @langs) {
				foreach my $lang (@langs) {
					return $this->{_fields}->{$field.'-'.lc($lang)}
						if exists $this->{_fields}->{$field.'-'.lc($lang)};
				}
			}
			return $this->{_fields}->{$field};
		};
		goto &$AUTOLOAD;
	}
}


1

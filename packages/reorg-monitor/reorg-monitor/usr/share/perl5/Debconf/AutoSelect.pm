#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::AutoSelect;
use strict;
use Debconf::Gettext;
use Debconf::ConfModule;
use Debconf::Config;
use Debconf::Log qw(:all);
use base qw(Exporter);
our @EXPORT_OK = qw(make_frontend make_confmodule);
our %EXPORT_TAGS = (all => [@EXPORT_OK]);

BEGIN {
	eval {
		require Glib::Object::Introspection;
	};
}


my %fallback=(
	'Kde'			=>	['Qt', 'Dialog', 'Readline', 'Teletype'],
	'Qt'			=>	['Dialog', 'Readline', 'Teletype'],
	'Gnome'			=>	['Dialog', 'Readline', 'Teletype'],
	'Web'			=>	['Dialog', 'Readline', 'Teletype'],
	'Dialog'		=>	['Readline', 'Teletype'],
	'Gtk'			=>	['Dialog', 'Readline', 'Teletype'],
	'Readline'		=>	['Teletype', 'Dialog'],
	'Editor'		=>	['Readline', 'Teletype'],
	'Slang'			=>	['Dialog', 'Readline', 'Teletype'],
	'Text'			=> 	['Readline', 'Teletype', 'Dialog'],

);

my $frontend;
my $type;


sub make_frontend {
	my $script=shift;
	my $starttype=ucfirst($type) if defined $type;
	if (! defined $starttype || ! length $starttype) {
		$starttype = Debconf::Config->frontend;
		if ($starttype =~ /^[A-Z]/) {
			warn "Please do not capitalize the first letter of the debconf frontend.";
		}
		$starttype=ucfirst($starttype);
	}

	my $showfallback=0;
	foreach $type ($starttype, @{$fallback{$starttype}}, 'Noninteractive') {
		if (! $showfallback) {
			debug user => "trying frontend $type";
		}
		else {
			warn(sprintf(gettext("falling back to frontend: %s"), $type));
		}
		$frontend=eval qq{
			use Debconf::FrontEnd::$type;
			Debconf::FrontEnd::$type->new();
		};
		return $frontend if defined $frontend;

		warn sprintf(gettext("unable to initialize frontend: %s"), $type);
		$@=~s/\n.*//s;
		warn "($@)";
		$showfallback=1;
	}

	die sprintf(gettext("Unable to start a frontend: %s"), $@);
}


sub make_confmodule {
	my $confmodule=Debconf::ConfModule->new(frontend => $frontend);

	$confmodule->startup(@_) if @_;
	
	return $confmodule;
}


1

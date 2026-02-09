#!/usr/bin/perl
# This is a stub module that just uses the new module, and is here for
# backwards-compatability with pograms that use the old name.
package Debian::DebConf::Client::ConfModule;
use Debconf::Client::ConfModule;
use Debconf::Log qw{debug};
print STDERR "Debian::DebConf::Client::ConfModule is deprecated, please use Debconf::Client::ConfModule instead.\n";

sub import {
	splice @_, 0, 1 => Debconf::Client::ConfModule;
	goto &{Debconf::Client::ConfModule->can('import')};
}

sub AUTOLOAD {
	(my $sub = $AUTOLOAD) =~ s/.*:://;
	*$sub = \&{"Debconf::Client::ConfModule::$sub"};
	goto &$sub;
}

1

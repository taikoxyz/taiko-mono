#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Noninteractive::Error;
use strict;
use Text::Wrap;
use Debconf::Gettext;
use Debconf::Config;
use Debconf::Log ':all';
use Debconf::Path;
use base qw(Debconf::Element::Noninteractive);



sub show {
	my $this=shift;

	if ($this->question->flag('seen') ne 'true') {
		$this->sendmail(gettext("Debconf is not confident this error message was displayed, so it mailed it to you."));

	$this->frontend->display($this->question->description."\n\n".
		$this->question->extended_description."\n");
	}
	$this->value('');
}


sub sendmail {
	my $this=shift;
	my $footer=shift;
	return unless length Debconf::Config->admin_email;
	if (Debconf::Path::find("mail")) {
		debug user => "mailing a note";
	    	my $title=gettext("Debconf").": ".
			$this->frontend->title." -- ".
			$this->question->description;
		unless (open(MAIL, "|-")) { # child
			exec("mail", "-s", $title, Debconf::Config->admin_email) or return '';
		}
		my $old_columns=$Text::Wrap::columns;
		$Text::Wrap::columns=75;
		if ($this->question->extended_description ne '') {
			print MAIL wrap('', '', $this->question->extended_description);
		}
		else {
			print MAIL wrap('', '', $this->question->description);
		}
		print MAIL "\n\n";
		my $hostname=`hostname -f 2>/dev/null`;
		if (! defined $hostname) {
			$hostname="unknown system";
		}
		print MAIL "-- \n", sprintf(gettext("Debconf, running at %s"), $hostname, "\n");
		print MAIL "[ ", wrap('', '', $footer), " ]\n" if $footer;
		close MAIL or return '';

		$Text::Wrap::columns=$old_columns;
	
		$this->question->flag('seen', 'true');

		return 1;
	}
}


1

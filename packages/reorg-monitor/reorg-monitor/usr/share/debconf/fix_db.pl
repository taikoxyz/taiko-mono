#!/usr/bin/perl -w
# This file was preprocessed, do not edit!
use strict;
use Debconf::Db;
use Debconf::Log q{warn};

Debconf::Db->load;

if (! @ARGV || $ARGV[0] ne 'end') {
	my $fix=0;
	my $ok;
	my $counter=0;
	do {
		$ok=1;
	
		my %templates=();
		my $ti=$Debconf::Db::templates->iterator;
		while (my $t=$ti->iterate) {
			$templates{$t}=Debconf::Template->get($t);
		}
	
		my %questions=();
		my $qi=Debconf::Question->iterator;
		while (my $q=$qi->iterate) {
			if (! defined $q->template) {
				warn "question \"".$q->name."\" has no template field; removing it.";
				$q->addowner("killme",""); # make sure it has one owner at least, so removal is triggered
				foreach my $owner (split(/, /, $q->owners)) {
					$q->removeowner($owner);
				}
				$ok=0;
				$fix=1;
			}
			elsif (! exists $templates{$q->template->template}) {
				warn "question \"".$q->name."\" uses nonexistant template ".$q->template->template."; removing it.";
				foreach my $owner (split(/, /, $q->owners)) {
					$q->removeowner($owner);
				}
				$ok=0;
				$fix=1;
			}
			else {
				$questions{$q->name}=$q;
			}
		}
		
		foreach my $t (keys %templates) {
			my @owners=$Debconf::Db::templates->owners($t);
			if (! @owners) {
				warn "template \"$t\" has no owners; removing it.";
				$Debconf::Db::templates->addowner($t, "killme","");
				$Debconf::Db::templates->removeowner($t, "killme");
				$fix=1;
			}
			foreach my $q (@owners) {
				if (! exists $questions{$q}) {
					warn "template \"$t\" claims to be used by nonexistant question \"$q\"; removing that.";
					$Debconf::Db::templates->removeowner($t, $q);
					$ok=0;
					$fix=1;
				}
			}
		}
		$counter++;
	} until ($ok || $counter > 20);

	if ($fix) {
		Debconf::Db->save;
		exec($0, "end");
		die "exec of self failed";
	}
}

foreach my $templatefile (glob("/var/lib/dpkg/info/*.templates")) {
	my ($package) = $templatefile =~ m:/var/lib/dpkg/info/(.*?).templates:;
        Debconf::Template->load($templatefile, $package);
}

Debconf::Db->save;

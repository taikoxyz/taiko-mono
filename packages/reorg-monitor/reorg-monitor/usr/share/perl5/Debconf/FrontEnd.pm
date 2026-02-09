#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::FrontEnd;
use strict;
use Debconf::Gettext;
use Debconf::Priority;
use Debconf::Log ':all';
use base qw(Debconf::Base);


sub init {
	my $this=shift;
	
	$this->elements([]);
	$this->interactive('');
	$this->capb('');
	$this->title('');
	$this->requested_title('');
	$this->info(undef);
	$this->need_tty(1);
}


sub elementtype {
	my $this=shift;
	
	my $ret;
	if (ref $this) {
		($ret) = ref($this) =~ m/Debconf::FrontEnd::(.*)/;
	}
	else {
		($ret) = $this =~ m/Debconf::FrontEnd::(.*)/;
	}
	return $ret;
}

my %nouse;

sub _loadelementclass {
	my $this=shift;
	my $type=shift;
	my $nodebug=shift;

	if (! UNIVERSAL::can("Debconf::Element::$type", 'new')) {
		return if $nouse{$type};
		eval qq{use Debconf::Element::$type};
		if ($@ || ! UNIVERSAL::can("Debconf::Element::$type", 'new')) {
			warn sprintf(gettext("Unable to load Debconf::Element::%s. Failed because: %s"), $type, $@) if ! $nodebug;
			$nouse{$type}=1;
			return;
		}
	}
}


sub makeelement {
	my $this=shift;
	my $question=shift;
	my $nodebug=shift;

	my $type=$this->elementtype.'::'.ucfirst($question->type);
	$type=~s/::$//; # in case the question has no type..

	$this->_loadelementclass($type, $nodebug);

	my $element="Debconf::Element::$type"->new(question => $question);
	return if ! ref $element;
	return $element;
}


sub add {
	my $this=shift;
	my $element=shift;

	foreach (@{$this->elements}) {
		return if $element->question == $_->question;
	}
	
	$element->frontend($this);
	push @{$this->elements}, $element;
}


sub go {
	my $this=shift;
	$this->backup('');
	foreach my $element (@{$this->elements}) {
		$element->show;
		return if $this->backup && $this->capb_backup;
	}
	return 1;
}


sub progress_start {
	my $this=shift;
	my $min=shift;
	my $max=shift;
	my $question=shift;

	my $type = $this->elementtype.'::Progress';
	$this->_loadelementclass($type);

	my $element="Debconf::Element::$type"->new(question => $question);
	unless (ref $element) {
		return;
	}
	$element->frontend($this);
	$element->progress_min($min);
	$element->progress_max($max);
	$element->progress_cur($min);

	$element->start;

	$this->progress_bar($element);
}


sub progress_set {
	my $this=shift;
	my $value=shift;

	return $this->progress_bar->set($value);
}


sub progress_step {
	my $this=shift;
	my $inc=shift;

	return $this->progress_set($this->progress_bar->progress_cur + $inc);
}


sub progress_info {
	my $this=shift;
	my $question=shift;

	return $this->progress_bar->info($question);
}


sub progress_stop {
	my $this=shift;

	$this->progress_bar->stop;
	$this->progress_bar(undef);
}


sub clear {
	my $this=shift;
	
	$this->elements([]);
}


sub default_title {
	my $this=shift;
	
	$this->title(sprintf(gettext("Configuring %s"), shift));
	$this->requested_title($this->title);
}


sub shutdown {}


1

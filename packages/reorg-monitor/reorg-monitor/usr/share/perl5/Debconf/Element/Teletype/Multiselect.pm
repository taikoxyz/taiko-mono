#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Teletype::Multiselect;
use strict;
use Debconf::Gettext;
use Debconf::Config;
use base qw(Debconf::Element::Multiselect Debconf::Element::Teletype::Select);



sub expand_ranges {
	my @ranges = @_;
	my @accumulator;
	for my $item (@ranges) {
		if ($item =~ /\A(\d+)-(\d+)\Z/) {
			my ($begin, $end) = ($1, $2);
			for (my $i = $begin; $i <= $end; $i++) {
				push @accumulator, $i;
			}
		}
		else {
			push @accumulator, $item;
		}
	}
	return @accumulator;
}

sub show {
	my $this=shift;

	my @selected;
	my $none_of_the_above=gettext("none of the above");

	my @choices=$this->question->choices_split;
	my %value = map { $_ => 1 } $this->translate_default;
	if ($this->frontend->promptdefault && $this->question->value ne '') {
		push @choices, $none_of_the_above;
	}
	my @completions=@choices;
	my $i=1;
	my %choicenum=map { $_ => $i++ } @choices;

	$this->frontend->display($this->question->extended_description."\n");

	my $default;
	if (Debconf::Config->terse eq 'false') {
		$this->printlist(@choices);
		$this->frontend->display("\n(".gettext("Enter the items or ranges you want to select, separated by spaces.").")\n");
		push @completions, 1..@choices;
		$default=join(" ", map { $choicenum{$_} }
		                   grep { $value{$_} } @choices);
	}
	else {
		$default=join(" ", grep { $value{$_} } @choices);
	}

	while (1) {
		$_=$this->frontend->prompt(
			prompt => $this->question->description,
		 	default => $default,
			completions => [@completions],
			completion_append_character => " ",
			question => $this->question,
		);
		return unless defined $_;

		@selected=split(/[	 ,]+/, $_);

		@selected=expand_ranges(@selected);

		@selected=map { $this->expandabbrev($_, @choices) } @selected;

		next if grep { $_ eq '' } @selected;

		if ($#selected > 0) {
			map { next if $_ eq $none_of_the_above } @selected;
		}

		last;
	}

	$this->frontend->display("\n");

	if (defined $selected[0] && $selected[0] eq $none_of_the_above) {
		$this->value('');
	}
	else {
		my %selected=map { $_ => 1 } @selected;

		$this->value(join(', ', $this->order_values(
				map { $this->translate_to_C($_) }
		                keys %selected)));
	}
}

1

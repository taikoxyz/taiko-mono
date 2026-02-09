#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Element::Teletype::Select;
use strict;
use Debconf::Config;
use POSIX qw(ceil);
use base qw(Debconf::Element::Select);


sub expandabbrev {
	my $this=shift;
	my $input=shift;
	my @choices=@_;

	if (Debconf::Config->terse eq 'false' and 
	    $input=~m/^[0-9]+$/ and $input ne '0' and $input <= @choices) {
		return $choices[$input - 1];
	}
	
	my @matches=();
	foreach (@choices) {
		return $_ if /^\Q$input\E$/;
		push @matches, $_ if /^\Q$input\E/;
	}
	return $matches[0] if @matches == 1;

	if (! @matches) {
		foreach (@choices) {
			return $_ if /^\Q$input\E$/i;
			push @matches, $_ if /^\Q$input\E/i;
		}
		return $matches[0] if @matches == 1;
	}
	
	return '';
}


sub printlist {
	my $this=shift;
	my @choices=@_;
	my $width=$this->frontend->screenwidth;

	my $choice_min=length $choices[0];
	map { $choice_min = length $_ if length $_ < $choice_min } @choices;
	my $max_cols=int($width / (2 + length(scalar(@choices)) +  2 + $choice_min)) - 1;
	$max_cols = $#choices if $max_cols > $#choices;

	my $max_lines;
	my $num_cols;
COLUMN:	for ($num_cols = $max_cols; $num_cols >= 0; $num_cols--) {
		my @col_width;
		my $total_width;

		$max_lines=ceil(($#choices + 1) / ($num_cols + 1));

		next if ceil(($#choices + 1) / $max_lines) - 1 < $num_cols;

		foreach (my $choice=1; $choice <= $#choices + 1; $choice++) {
			my $choice_length=2
				+ length(scalar(@choices)) + 2
				+ length($choices[$choice - 1]);
			my $current_col=ceil($choice / $max_lines) - 1;
			if (! defined $col_width[$current_col] ||
			    $choice_length > $col_width[$current_col]) {
				$col_width[$current_col]=$choice_length;
				$total_width=0;
				map { $total_width += $_ } @col_width;
				next COLUMN if $total_width > $width;
			}
		}

		last;
	}

	my $line=0;
	my $max_len=0;
	my $col=0;
	my @output=();
	for (my $choice=0; $choice <= $#choices; $choice++) {
		$output[$line] .= "  ".($choice+1).". " . $choices[$choice];
		if (length $output[$line] > $max_len) {
			$max_len = length $output[$line];
		}
		if (++$line >= $max_lines) {
			if ($col++ != $num_cols) {
				for (my $l=0; $l <= $#output; $l++) {
					$output[$l] .= ' ' x ($max_len - length $output[$l]);
				}
			}
	
			$line=0;
			$max_len=0;
		}
	}

	@output = map { s/\s+$//; $_ } @output;

	map { $this->frontend->display_nowrap($_) } @output;
}

sub show {
	my $this=shift;
	
	my $default=$this->translate_default;
	my @choices=$this->question->choices_split;	
	my @completions=@choices;

	$this->frontend->display($this->question->extended_description."\n");
	
	if (Debconf::Config->terse eq 'false') {
		for (my $choice=0; $choice <= $#choices; $choice++) {
			if ($choices[$choice] eq $default) {
				$default=$choice + 1;
				last;
			}
		}
		
		$this->printlist(@choices);
		$this->frontend->display("\n");

		push @completions, 1..@choices;
	}

	my $value;
	while (1) {
		$value=$this->frontend->prompt(
			prompt => $this->question->description,
			default => $default ? $default : '',
			completions => [@completions],
			question => $this->question,
		);
		return unless defined $value;
		$value=$this->expandabbrev($value, @choices);
		last if $value ne '';
	}
	$this->frontend->display("\n");
	$this->value($this->translate_to_C($value));
}


1

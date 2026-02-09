#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::FrontEnd::Readline;
use strict;
use Term::ReadLine;
use Debconf::Gettext;
use base qw(Debconf::FrontEnd::Teletype);


sub init {
	my $this=shift;

	$this->SUPER::init(@_);

	-t STDIN || die gettext("This frontend requires a controlling tty.")."\n";

	$Term::ReadLine::termcap_nowarn = 1; # Turn off stupid termcap warning.
	$this->readline(Term::ReadLine->new('debconf'));
	$this->readline->ornaments(1);

	if (-p STDOUT && -p STDERR) { # make readline play nice with buffered stdout
		$this->readline->newTTY(*STDIN, *STDOUT);
	}

	if (Term::ReadLine->ReadLine =~ /::Gnu$/) {
		if (exists $ENV{TERM} && $ENV{TERM} =~ /emacs/i) {
			die gettext("Term::ReadLine::GNU is incompatable with emacs shell buffers.")."\n";
		}
		
		$this->readline->add_defun('previous-question',	
			sub {
				if ($this->capb_backup) {
					$this->_skip(1);
					$this->_direction(-1);
					$this->readline->stuff_char(ord "\n");
				}
				else {
					$this->readline->ding;
				}
			}, ord "\cu");
		$this->readline->add_defun('next-question',
			sub {
				if ($this->capb_backup) {
					$this->readline->stuff_char(ord "\n");
				}
			}, ord "\cv");
		$this->readline->parse_and_bind('"\e[5~": previous-question');
		$this->readline->parse_and_bind('"\e[6~": next-question');
		$this->capb('backup');
	}
	
	if (Term::ReadLine->ReadLine =~ /::Stub$/) {
		$this->promptdefault(1);
	}
}


sub elementtype {
	return 'Teletype';
}


sub go {
	my $this=shift;

	foreach my $element (grep ! $_->visible, @{$this->elements}) {
		my $value=$element->show;
		return if $this->backup && $this->capb_backup;
		$element->question->value($value);
	}

	my @elements=grep $_->visible, @{$this->elements};
	unless (@elements) {
		$this->_didbackup('');
		return 1;
	}

	my $current=$this->_didbackup ? $#elements : 0;

	$this->_direction(1);
	for (; $current > -1 && $current < @elements; $current += $this->_direction) {
		my $value=$elements[$current]->show;
	}

	if ($current < 0) {
		$this->_didbackup(1);
		return;
	}
	else {
		$this->_didbackup('');
		return 1;
	}
}


sub prompt {
	my $this=shift;
	my %params=@_;
	my $prompt=$params{prompt}." ";
	my $default=$params{default};
	my $noshowdefault=$params{noshowdefault};
	my $completions=$params{completions};

	if ($completions) {
		my @matches;
		$this->readline->Attribs->{completion_entry_function} = sub {
			my $text=shift;
			my $state=shift;
			
			if ($state == 0) {
				@matches=();
				foreach (@{$completions}) {
					push @matches, $_ if /^\Q$text\E/i;
				}
			}

			return pop @matches;
		};
	}
	else {
		$this->readline->Attribs->{completion_entry_function} = undef;
	}

	if (exists $params{completion_append_character}) {
		$this->readline->Attribs->{completion_append_character}=$params{completion_append_character};
	}
	else {
		$this->readline->Attribs->{completion_append_character}='';
	}
	
	$this->linecount(0);
	my $ret;
	$this->_skip(0);
	if (! $noshowdefault) {
		$ret=$this->readline->readline($prompt, $default);
	}
	else {
		$ret=$this->readline->readline($prompt);
	}
	$this->display_nowrap("\n");
	return if $this->_skip;
	$this->_direction(1);
	$this->readline->addhistory($ret);
	return $ret;
}


sub prompt_password {
	my $this=shift;
	my %params=@_;

	if (Term::ReadLine->ReadLine =~ /::Perl$/) {
		return $this->SUPER::prompt_password(%params);
	}
	
	delete $params{default};
	system('stty -echo 2>/dev/null');
	my $ret=$this->prompt(@_, noshowdefault => 1, completions => []);
	system('stty sane 2>/dev/null');
	print "\n";
	return $ret;
}


1

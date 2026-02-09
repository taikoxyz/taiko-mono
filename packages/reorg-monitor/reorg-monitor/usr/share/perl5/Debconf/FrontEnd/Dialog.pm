#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::FrontEnd::Dialog;
use strict;
use Debconf::Gettext;
use Debconf::Priority;
use Debconf::TmpFile;
use Debconf::Log qw(:all);
use Debconf::Encoding qw(wrap $columns width);
use Debconf::Path;
use IPC::Open3;
use POSIX;
use Fcntl;
use base qw(Debconf::FrontEnd::ScreenSize);


sub init {
	my $this=shift;

	$this->SUPER::init(@_);

	delete $ENV{POSIXLY_CORRECT} if exists $ENV{POSIXLY_CORRECT};
	delete $ENV{POSIX_ME_HARDER} if exists $ENV{POSIX_ME_HARDER};
	
	if (! exists $ENV{TERM} || ! defined $ENV{TERM} || $ENV{TERM} eq '') { 
		die gettext("TERM is not set, so the dialog frontend is not usable.")."\n";
	}
	elsif ($ENV{TERM} =~ /emacs/i) {
		die gettext("Dialog frontend is incompatible with emacs shell buffers")."\n";
	}
	elsif ($ENV{TERM} eq 'dumb' || $ENV{TERM} eq 'unknown') {
		die gettext("Dialog frontend will not work on a dumb terminal, an emacs shell buffer, or without a controlling terminal.")."\n";
	}
	
	$this->interactive(1);
	$this->capb('backup');

	if (Debconf::Path::find("whiptail") && 
	    (! defined $ENV{DEBCONF_FORCE_DIALOG} || ! Debconf::Path::find("dialog")) &&
	    (! defined $ENV{DEBCONF_FORCE_XDIALOG} || ! Debconf::Path::find("Xdialog")) &&
	    system('whiptail --version >/dev/null 2>&1') == 0) {
		$this->program('whiptail');
		$this->dashsep('--');
		$this->borderwidth(5);
		$this->borderheight(6);
		$this->spacer(1);
		$this->titlespacer(10);
		$this->columnspacer(3);
		$this->selectspacer(13);
		$this->hasoutputfd(1);
	}
	elsif (Debconf::Path::find("dialog") &&
	       (! defined $ENV{DEBCONF_FORCE_XDIALOG} || ! Debconf::Path::find("Xdialog")) &&
	       system('dialog --version >/dev/null 2>&1') == 0) {
		$this->program('dialog');
		$this->dashsep(''); # dialog does not need (or support) 
		$this->borderwidth(7);
		$this->borderheight(6);
		$this->spacer(0);
		$this->titlespacer(4);
		$this->columnspacer(2);
		$this->selectspacer(0);
		$this->hasoutputfd(1);
	}
	elsif (Debconf::Path::find("Xdialog") && defined $ENV{DISPLAY}) {
		$this->program("Xdialog");
		$this->borderwidth(7);
		$this->borderheight(20);
		$this->spacer(0);
		$this->titlespacer(10);
		$this->selectspacer(0);
		$this->columnspacer(2);
		$this->screenheight(200);
	}
	else {
		die gettext("No usable dialog-like program is installed, so the dialog based frontend cannot be used.");
	}

	if ($this->screenheight < 13 || $this->screenwidth < 31) {
		die gettext("Dialog frontend requires a screen at least 13 lines tall and 31 columns wide.")."\n";
	}
}


sub sizetext {
	my $this=shift;
	my $text=shift;
	
	$columns = $this->screenwidth - $this->borderwidth - $this->columnspacer;
	$text=wrap('', '', $text);
	my @lines=split(/\n/, $text);
	
	my $window_columns=width($this->title) + $this->titlespacer;
	map {
		my $w=width($_);
		$window_columns = $w if $w > $window_columns;
	} @lines;
	
	return $text, $#lines + 1 + $this->borderheight,
	       $window_columns + $this->borderwidth;
}


sub ellipsize {
	my $this=shift;
	my $text=shift;

	return $text if $this->program ne 'whiptail';

	$columns = $this->screenwidth - $this->borderwidth - $this->columnspacer - $this->selectspacer;
	if (width($text) > $columns) {
		$columns -= 3;
		$text = (split(/\n/, wrap('', '', $text), 2))[0] . '...';
	}
	return $text;
}


sub hide_escape {
	my $line = $_;

	$line =~ s/\\n/\\\xe2\x81\xa0n/g;
	return $line;
}


sub showtext {
	my $this=shift;
	my $question=shift;
	my $intext=shift;

	my $lines = $this->screenheight;
	my ($text, $height, $width)=$this->sizetext($intext);

	my @lines = split(/\n/, $text);
	my $num;
	my @args=('--msgbox', join("\n", @lines));
	if ($lines - 4 - $this->borderheight <= $#lines) {
		$num=$lines - 4 - $this->borderheight;
		if ($this->program eq 'whiptail') {
			push @args, '--scrolltext';
		}
		else {
			my $fh=Debconf::TmpFile::open();
			print $fh join("\n", map &hide_escape, @lines);
			close $fh;
			@args=("--textbox", Debconf::TmpFile::filename());
		}
	}
	else {
		$num=$#lines + 1;
	}
	$this->showdialog($question, @args, $num + $this->borderheight, $width);
	if ($args[0] eq '--textbox') {
		Debconf::TmpFile::cleanup();
	}
}


sub makeprompt {
	my $this=shift;
	my $question=shift;
	my $freelines=$this->screenheight - $this->borderheight + 1;
	$freelines += shift if @_;

	my ($text, $lines, $columns)=$this->sizetext(
		$question->extended_description."\n\n".
		$question->description
	);
	
	if ($lines > $freelines) {
		$this->showtext($question, $question->extended_description);
		($text, $lines, $columns)=$this->sizetext($question->description);
	}
	
	return ($text, $lines, $columns);
}

sub startdialog {
	my $this=shift;
	my $question=shift;
	my $wantinputfd=shift;
	
	debug debug => "preparing to run dialog. Params are:" ,
		join(",", $this->program, @_);

	use vars qw{*SAVEOUT *SAVEIN};
	open(SAVEOUT, ">&STDOUT") || die $!;
	$this->dialog_saveout(\*SAVEOUT);
	if ($wantinputfd) {
		$this->dialog_savein(undef);
	} else {
		open(SAVEIN, "<&STDIN") || die $!;
		$this->dialog_savein(\*SAVEIN);
	}

	$this->dialog_savew($^W);
	$^W=0;
	
	unless ($this->capb_backup || grep { $_ eq '--defaultno' } @_) {
		if ($this->program ne 'Xdialog') {
			unshift @_, '--nocancel';
		}
		else {
			unshift @_, '--no-cancel';
		}
	}

	if ($this->program eq 'Xdialog' && $_[0] eq '--passwordbox') {
		$_[0]='--password --inputbox'
	}
	
	use vars qw{*OUTPUT_RDR *OUTPUT_WTR};
	if ($this->hasoutputfd) {
		pipe(OUTPUT_RDR, OUTPUT_WTR) || die "pipe: $!";
		my $flags=fcntl(\*OUTPUT_WTR, F_GETFD, 0);
		fcntl(\*OUTPUT_WTR, F_SETFD, $flags & ~FD_CLOEXEC);
		$this->dialog_output_rdr(\*OUTPUT_RDR);
		unshift @_, "--output-fd", fileno(\*OUTPUT_WTR);
	}
	
	my $backtitle='';
	if (defined $this->info) {
		$backtitle = $this->info->description;
	} else {
		$backtitle = gettext("Package configuration");
	}

	use vars qw{*INPUT_RDR *INPUT_WTR};
	if ($wantinputfd) {
		pipe(INPUT_RDR, INPUT_WTR) || die "pipe: $!";
		autoflush INPUT_WTR 1;
		my $flags=fcntl(\*INPUT_RDR, F_GETFD, 0);
		fcntl(\*INPUT_RDR, F_SETFD, $flags & ~FD_CLOEXEC);
		$this->dialog_input_wtr(\*INPUT_WTR);
	} else {
		$this->dialog_input_wtr(undef);
	}

	use vars qw{*ERRFH};
	my $pid = open3($wantinputfd ? '<&INPUT_RDR' : '<&STDIN', '>&STDOUT',
		\*ERRFH, $this->program,
		'--backtitle', $backtitle,
		'--title', $this->title, @_);
	$this->dialog_errfh(\*ERRFH);
	$this->dialog_pid($pid);
	close OUTPUT_WTR if $this->hasoutputfd;
}

sub waitdialog {
	my $this=shift;

	my $input_wtr=$this->dialog_input_wtr;
	if ($input_wtr) {
		close $input_wtr;
	}
	my $output_rdr=$this->dialog_output_rdr;
	my $errfh=$this->dialog_errfh;
	my $output='';
	if ($this->hasoutputfd) {
		while (<$output_rdr>) {
			$output.=$_;
		}
		my $error=0;
		while (<$errfh>) {
			print STDERR $_;
			$error++;
		}
		if ($error) {
			die sprintf("debconf: %s output the above errors, giving up!", $this->program)."\n";
		}
	}
	else {
		while (<$errfh>) { # ugh
			$output.=$_;
		}
	}
	chomp $output;

	waitpid($this->dialog_pid, 0);
	$^W=$this->dialog_savew;

	if (defined $this->dialog_savein) {
		open(STDIN, '<&', $this->dialog_savein) || die $!;
	}
	open(STDOUT, '>&', $this->dialog_saveout) || die $!;

	my $ret=$? >> 8;
	if ($ret == 255 || ($ret == 1 && join(' ', @_) !~ m/--yesno\s/)) {
		$this->backup(1);
		return undef;
	}

	if (wantarray) {
		return $ret, $output;
	}
	else {
		return $output;
	}
}


sub showdialog {
	my $this=shift;
	my $question=shift;

	@_=map &hide_escape, @_;

	if (defined $this->progress_bar) {
		$this->progress_bar->stop;
	}

	$this->startdialog($question, 0, @_);
	my (@ret, $ret);
	if (wantarray) {
		@ret=$this->waitdialog(@_);
	} else {
		$ret=$this->waitdialog(@_);
	}

	if (defined $this->progress_bar) {
		$this->progress_bar->start;
	}

	if (wantarray) {
		return @ret;
	} else {
		return $ret;
	}
}


1

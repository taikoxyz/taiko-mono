#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::ConfModule;
use strict;
use IPC::Open2;
use FileHandle;
use Debconf::Gettext;
use Debconf::Config;
use Debconf::Question;
use Debconf::Priority qw(priority_valid high_enough);
use Debconf::FrontEnd::Noninteractive;
use Debconf::Log ':all';
use Debconf::Encoding;
use base qw(Debconf::Base);


my %codes = (
	success => 0,
	escaped_data => 1,
	badparams => 10,
	syntaxerror => 20,
	input_invisible => 30,
	version_bad => 30,
	go_back => 30,
	progresscancel => 30,
	internalerror => 100,
);


sub init {
	my $this=shift;

	$this->version("2.0");
	
	$this->owner('unknown') if ! defined $this->owner;
	
	$this->frontend->capb_backup('');

	$this->seen([]);
	$this->busy([]);

	$ENV{DEBIAN_HAS_FRONTEND}=1;
}


sub startup {
	my $this=shift;
	my $confmodule=shift;

	$this->frontend->clear;
	$this->busy([]);
	
	my @args=$this->confmodule($confmodule);
	push @args, @_ if @_;
	
	debug developer => "starting ".join(' ',@args);
	$this->pid(open2($this->read_handle(FileHandle->new),
		         $this->write_handle(FileHandle->new),
			 @args)) || die $!;
		
	$this->caught_sigpipe('');
	$SIG{PIPE}=sub { $this->caught_sigpipe(128) };
}


sub communicate {
	my $this=shift;

	my $r=$this->read_handle;
	$_=<$r> || return $this->finish;
	chomp;
	my $ret=$this->process_command($_);
	my $w=$this->write_handle;
	print $w $ret."\n";
	return '' unless length $ret;
	return 1;
}


sub escape {
	my $text=shift;
	$text=~s/\\/\\\\/g;
	$text=~s/\n/\\n/g;
	return $text;
}


sub unescape_split {
	my $text=shift;
	my @words;
	my $word='';
	for my $chunk (split /(\\.|\s+)/, $text) {
		if ($chunk eq '\n') {
			$word.="\n";
		} elsif ($chunk=~/^\\(.)$/) {
			$word.=$1;
		} elsif ($chunk=~/^\s+$/) {
			push @words, $word;
			$word='';
		} else {
			$word.=$chunk;
		}
	}
	push @words, $word if $word ne '';
	return @words;
}


sub process_command {
	my $this=shift;
	
	debug developer => "<-- $_";
	chomp;
	my ($command, @params);
	if (defined $this->client_capb and grep { $_ eq 'escape' } @{$this->client_capb}) {
		($command, @params)=unescape_split($_);
	} else {
		($command, @params)=split(' ', $_);
	}
	if (! defined $command) {
		my $ret = $codes{syntaxerror}.' '.
			"Bad line \"$_\" received from confmodule.";
		debug developer => "--> $ret";
		return $ret;
	}
	$command=lc($command);
	if (lc($command) eq "stop") {
		return $this->finish;
	}
	if (! $this->can("command_$command")) {
		my $ret = $codes{syntaxerror}.' '.
		       "Unsupported command \"$command\" (full line was \"$_\") received from confmodule.";
		debug developer => "--> $ret";
		return $ret;
	}
	$command="command_$command";
	my $ret=join(' ', $this->$command(@params));
	debug developer => "--> $ret";
	if ($ret=~/\n/) {
		debug developer => 'Warning: return value is multiline, and would break the debconf protocol. Truncating to first line.';
		$ret=~s/\n.*//s;
		debug developer => "--> $ret";
	}
	return $ret;
}


sub finish {
	my $this=shift;

	waitpid $this->pid, 0 if defined $this->pid;
	$this->exitcode($this->caught_sigpipe || ($? >> 8));

	$SIG{PIPE} = sub {};
	
	foreach (@{$this->seen}) {
		my $q=Debconf::Question->get($_->name);
		$_->flag('seen', 'true') if $q;
	}
	$this->seen([]);
	
	return '';
}


sub command_input {
	my $this=shift;
	return $codes{syntaxerror}, "Incorrect number of arguments" if @_ != 2;
	my $priority=shift;
	my $question_name=shift;
	
	my $question=Debconf::Question->get($question_name) ||
		return $codes{badparams}, "\"$question_name\" doesn't exist";

	if (! priority_valid($priority)) {
		return $codes{syntaxerror}, "\"$priority\" is not a valid priority";
	}

	$question->priority($priority);
	
	my $visible=1;

	if ($question->type ne 'error') {
		$visible='' unless high_enough($priority);

		$visible='' if ! Debconf::Config->reshow &&
			       $question->flag('seen') eq 'true';
	}

	my $markseen=$visible;

	if ($visible && ! $this->frontend->interactive) {
		$visible='';
		$markseen='' unless Debconf::Config->noninteractive_seen eq 'true';
	}

	my $element;
	if ($visible) {
		$element=$this->frontend->makeelement($question);
		unless ($element) {
			return $codes{internalerror},
			       "unable to make an input element";
		}

		$visible=$element->visible;
	}

	if (! $visible) {
		$element=Debconf::FrontEnd::Noninteractive->makeelement($question, 1);

		return $codes{input_invisible}, "question skipped" unless $element;
	}

	$element->markseen($markseen);

	push @{$this->busy}, $question_name;
	
	$this->frontend->add($element);
	if ($element->visible) {
		return $codes{success}, "question will be asked";
	}
	else {
		return $codes{input_invisible}, "question skipped";
	}
}


sub command_clear {
	my $this=shift;
	return $codes{syntaxerror}, "Incorrect number of arguments" if @_ != 0;

	$this->frontend->clear;
	$this->busy([]);
	return $codes{success};
}


sub command_version {
	my $this=shift;
	return $codes{syntaxerror}, "Incorrect number of arguments" if @_ > 1;
	my $version=shift;
	if (defined $version) {
		return $codes{version_bad}, "Version too low ($version)"
			if int($version) < int($this->version);
		return $codes{version_bad}, "Version too high ($version)"
			if int($version) > int($this->version);
	}
	return $codes{success}, $this->version;
}


sub command_capb {
	my $this=shift;
	$this->client_capb([@_]);
	if (grep { $_ eq 'backup' } @_) {
		$this->frontend->capb_backup(1);
	} else {
		$this->frontend->capb_backup('');
	}
	my @capb=('multiselect', 'escape');
	push @capb, $this->frontend->capb;
	return $codes{success}, @capb;
}


sub command_title {
	my $this=shift;
	$this->frontend->title(join ' ', @_);
	$this->frontend->requested_title($this->frontend->title);

	return $codes{success};
}


sub command_settitle {
	my $this=shift;
	
	return $codes{syntaxerror}, "Incorrect number of arguments" if @_ != 1;
	my $question_name=shift;
	
	my $question=Debconf::Question->get($question_name) ||
		return $codes{badparams}, "\"$question_name\" doesn't exist";

	if ($this->frontend->can('settitle')) {
		$this->frontend->settitle($question);
	} else {
		$this->frontend->title($question->description);
	}
	$this->frontend->requested_title($this->frontend->title);
	
	return $codes{success};
}


sub command_beginblock {
	return $codes{success};
}
sub command_endblock {
	return $codes{success};
}


sub command_go {
	my $this=shift;
	return $codes{syntaxerror}, "Incorrect number of arguments" if @_ > 0;

	my $ret=$this->frontend->go;
	if ($ret && (! $this->backed_up ||
	             grep { $_->visible } @{$this->frontend->elements})) {
		foreach (@{$this->frontend->elements}) {
			$_->question->value($_->value);
			push @{$this->seen}, $_->question if $_->markseen && $_->question;
		}
		$this->frontend->clear;
		$this->busy([]);
		$this->backed_up('');
		return $codes{success}, "ok"
	}
	else {
		$this->frontend->clear;
		$this->busy([]);
		$this->backed_up(1);
		return $codes{go_back}, "backup";
	}
}


sub command_get {
	my $this=shift;
	return $codes{syntaxerror}, "Incorrect number of arguments" if @_ != 1;
	my $question_name=shift;
	my $question=Debconf::Question->get($question_name) ||
		return $codes{badparams}, "$question_name doesn't exist";

	my $value=$question->value;
	if (defined $value) {
		if (defined $this->client_capb and grep { $_ eq 'escape' } @{$this->client_capb}) {
			return $codes{escaped_data}, escape($value);
		} else {
			return $codes{success}, $value;
		}
	}
	else {
		return $codes{success}, '';
	}
}


sub command_set {
	my $this=shift;
	return $codes{syntaxerror}, "Incorrect number of arguments" if @_ < 1;
	my $question_name=shift;
	my $value=join(" ", @_);

	my $question=Debconf::Question->get($question_name) ||
		return $codes{badparams}, "$question_name doesn't exist";
	$question->value($value);
	return $codes{success}, "value set";
}


sub command_reset {
	my $this=shift;
	return $codes{syntaxerror}, "Incorrect number of arguments" if @_ != 1;
	my $question_name=shift;

	my $question=Debconf::Question->get($question_name) ||
		return $codes{badparams}, "$question_name doesn't exist";
	$question->value($question->default);
	$question->flag('seen', 'false');
	return $codes{success};
}


sub command_subst {
	my $this = shift;
	return $codes{syntaxerror}, "Incorrect number of arguments" if @_ < 2;
	my $question_name = shift;
	my $variable = shift;
	my $value = (join ' ', @_);
	
	my $question=Debconf::Question->get($question_name) ||
		return $codes{badparams}, "$question_name doesn't exist";
	my $result=$question->variable($variable,$value);
	return $codes{internalerror}, "Substitution failed" unless defined $result;
	return $codes{success};
}


sub command_register {
	my $this=shift;
	return $codes{syntaxerror}, "Incorrect number of arguments" if @_ != 2;
	my $template=shift;
	my $name=shift;
	
	my $tempobj = Debconf::Question->get($template);
	if (! $tempobj) {
		return $codes{badparams}, "No such template, \"$template\"";
	}
	my $question=Debconf::Question->get($name) || 
	             Debconf::Question->new($name, $this->owner, $tempobj->type);
	if (! $question) {
		return $codes{internalerror}, "Internal error making question";
	}
	if (! defined $question->addowner($this->owner, $tempobj->type)) {
		return $codes{internalerror}, "Internal error adding owner";
	}
	if (! $question->template($template)) {
		return $codes{internalerror}, "Internal error setting template";
	}

	return $codes{success};
}


sub command_unregister {
	my $this=shift;
	return $codes{syntaxerror}, "Incorrect number of arguments" if @_ != 1;
	my $name=shift;
	
	my $question=Debconf::Question->get($name) ||
		return $codes{badparams}, "$name doesn't exist";
	if (grep { $_ eq $name } @{$this->busy}) {
		return $codes{badparams}, "$name is busy, cannot unregister right now";
	}
	$question->removeowner($this->owner);
	return $codes{success};
}


sub command_purge {
	my $this=shift;
	return $codes{syntaxerror}, "Incorrect number of arguments" if @_ > 0;
	
	my $iterator=Debconf::Question->iterator;
	while (my $q=$iterator->iterate) {
		$q->removeowner($this->owner);
	}

	return $codes{success};
}


sub command_metaget {
	my $this=shift;
	return $codes{syntaxerror}, "Incorrect number of arguments" if @_ != 2;
	my $question_name=shift;
	my $field=shift;
	
	my $question=Debconf::Question->get($question_name) ||
		return $codes{badparams}, "$question_name doesn't exist";
	my $lcfield=lc $field;
	my $fieldval=$question->$lcfield();
	unless (defined $fieldval) {
		return $codes{badparams}, "$field does not exist";
	}
	if (defined $this->client_capb and grep { $_ eq 'escape' } @{$this->client_capb}) {
		return $codes{escaped_data}, escape($fieldval);
	} else {
		return $codes{success}, $fieldval;
	}
}


sub command_fget {
	my $this=shift;
	return $codes{syntaxerror}, "Incorrect number of arguments" if @_ != 2;
	my $question_name=shift;
	my $flag=shift;
	
	my $question=Debconf::Question->get($question_name) ||
		return $codes{badparams},  "$question_name doesn't exist";
		
	return $codes{success}, $question->flag($flag);
}


sub command_fset {
	my $this=shift;
	return $codes{syntaxerror}, "Incorrect number of arguments" if @_ < 3;
	my $question_name=shift;
	my $flag=shift;
	my $value=(join ' ', @_);
	
	my $question=Debconf::Question->get($question_name) ||
		return $codes{badparams}, "$question_name doesn't exist";

	if ($flag eq 'seen') {
		$this->seen([grep {$_ ne $question} @{$this->seen}]);
	}
		
	return $codes{success}, $question->flag($flag, $value);
}


sub command_info {
	my $this=shift;

	if (@_ == 0) {
		$this->frontend->info(undef);
	} elsif (@_ == 1) {
		my $question_name=shift;

		my $question=Debconf::Question->get($question_name) ||
			return $codes{badparams}, "\"$question_name\" doesn't exist";

		$this->frontend->info($question);
	} else {
		return $codes{syntaxerror}, "Incorrect number of arguments";
	}

	return $codes{success};
}


sub command_progress {
	my $this=shift;
	return $codes{syntaxerror}, "Incorrect number of arguments" if @_ < 1;
	my $subcommand=shift;
	$subcommand=lc($subcommand);
	
	my $ret;

	if ($subcommand eq 'start') {
		return $codes{syntaxerror}, "Incorrect number of arguments" if @_ != 3;
		my $min=shift;
		my $max=shift;
		my $question_name=shift;

		return $codes{syntaxerror}, "min ($min) > max ($max)" if $min > $max;

		my $question=Debconf::Question->get($question_name) ||
			return $codes{badparams}, "$question_name doesn't exist";

		$this->frontend->progress_start($min, $max, $question);
		$ret=1;
	}
	elsif ($subcommand eq 'set') {
		return $codes{syntaxerror}, "Incorrect number of arguments" if @_ != 1;
		my $value=shift;
		$ret = $this->frontend->progress_set($value);
	}
	elsif ($subcommand eq 'step') {
		return $codes{syntaxerror}, "Incorrect number of arguments" if @_ != 1;
		my $inc=shift;
		$ret = $this->frontend->progress_step($inc);
	}
	elsif ($subcommand eq 'info') {
		return $codes{syntaxerror}, "Incorrect number of arguments" if @_ != 1;
		my $question_name=shift;

		my $question=Debconf::Question->get($question_name) ||
			return $codes{badparams}, "$question_name doesn't exist";

		$ret = $this->frontend->progress_info($question);
	}
	elsif ($subcommand eq 'stop') {
		return $codes{syntaxerror}, "Incorrect number of arguments" if @_ != 0;
		$this->frontend->progress_stop();
		$ret=1;
	}
	else {
		return $codes{syntaxerror}, "Unknown subcommand";
	}

	if ($ret) {
		return $codes{success}, "OK";
	}
	else {
		return $codes{progresscancel}, "CANCELED";
	}
}


sub command_data {
	my $this=shift;
	return $codes{syntaxerror}, "Incorrect number of arguments" if @_ < 3;
	my $template=shift;
	my $item=shift;
	my $value=join(' ', @_);
	$value=~s/\\([n"\\])/($1 eq 'n') ? "\n" : $1/eg;

	my $tempobj=Debconf::Template->get($template);
	if (! $tempobj) {
		if ($item ne 'type') {
			return $codes{badparams}, "Template data field '$item' received before type field";
		}
		$tempobj=Debconf::Template->new($template, $this->owner, $value);
		if (! $tempobj) {
			return $codes{internalerror}, "Internal error making template";
		}
	} else {
		if ($item eq 'type') {
			return $codes{badparams}, "Template type already set";
		}
		$tempobj->$item(Debconf::Encoding::convert("UTF-8", $value));
	}

	return $codes{success};
}


sub command_visible {
	my $this=shift;
	return $codes{syntaxerror}, "Incorrect number of arguments" if @_ != 2;
	my $priority=shift;
	my $question_name=shift;
	
	my $question=Debconf::Question->get($question_name) ||
		return $codes{badparams}, "$question_name doesn't exist";
	return $codes{success}, $this->frontend->visible($question, $priority) ? "true" : "false";
}


sub command_exist {
	my $this=shift;
	return $codes{syntaxerror}, "Incorrect number of arguments" if @_ != 1;
	my $question_name=shift;
	
	return $codes{success}, 
		Debconf::Question->get($question_name) ? "true" : "false";
}


sub command_x_loadtemplatefile {
	my $this=shift;

	return $codes{syntaxerror}, "Incorrect number of arguments" if @_ < 1 || @_ > 2;

	my $file=shift;
	my $fh=FileHandle->new($file);
	if (! $fh) {
		return $codes{badparams}, "failed to open $file: $!";
	}

	my $owner=$this->owner;
	if (@_) {
		$owner=shift;
	}

	eval {
		Debconf::Template->load($fh, $owner);
	};
	if ($@) {
		$@=~s/\n/\\n/g;
		return $codes{internalerror}, $@;
	}
	return $codes{success};
}


sub AUTOLOAD {
	(my $field = our $AUTOLOAD) =~ s/.*://;

	no strict 'refs';
	*$AUTOLOAD = sub {
		my $this=shift;
		
		return $this->{$field} unless @_;
		return $this->{$field}=shift;
	};
	goto &$AUTOLOAD;
}


sub DESTROY {
	my $this=shift;
	
	$this->read_handle->close if $this->read_handle;
	$this->write_handle->close if $this->write_handle;
	
	if (defined $this->pid && $this->pid > 1) {
		kill 'TERM', $this->pid;
	}
}


1

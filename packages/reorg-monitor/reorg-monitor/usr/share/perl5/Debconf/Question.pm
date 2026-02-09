#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Question;
use strict;
use Debconf::Db;
use Debconf::Template;
use Debconf::Iterator;
use Debconf::Log qw(:all);


use fields qw(name priority);

our %question;


sub new {
	my Debconf::Question $this=shift;
	my $name=shift;
	my $owner=shift;
	my $type=shift || die "no type given for question";
	die "A question called \"$name\" already exists"
		if exists $question{$name};
	unless (ref $this) {
		$this = fields::new($this);
	}
	$this->{name}=$name;
	return unless defined $this->addowner($owner, $type);
	$this->flag('seen', 'false');
	return $question{$name}=$this;
}


sub get {
	my Debconf::Question $this=shift;
	my $name=shift;
	return $question{$name} if exists $question{$name};
	if ($Debconf::Db::config->exists($name)) {
		$this = fields::new($this);
		$this->{name}=$name;
		return $question{$name}=$this;
	}
	return undef;
}


sub iterator {
	my $this=shift;

	my $real_iterator=$Debconf::Db::config->iterator;
	return Debconf::Iterator->new(callback => sub {
		return unless my $name=$real_iterator->iterate;
		return $this->get($name);
	});
}


sub _expand_vars {
	my $this=shift;
	my $text=shift;
		
	return '' unless defined $text;

	my @vars=$Debconf::Db::config->variables($this->{name});
	
	my $rest=$text;
	my $result='';
	my $variable;
	my $varval;
	my $escape;
	while ($rest =~ m/^(.*?)(\\)?\$\{([^{}]+)\}(.*)$/sg) {
		$result.=$1;  # copy anything before the variable
		$escape=$2;
		$variable=$3;
		$rest=$4; # continue trying to expand rest of text
		if (defined $escape && length $escape) {
			$result.="\${$variable}";
		}
		else {
			$varval=$Debconf::Db::config->getvariable($this->{name}, $variable);
			$result.=$varval if defined($varval); # expand the variable
		}
	}
	$result.=$rest; # add on anything that's left.
	
	return $result;
}


sub description {
	my $this=shift;
	return $this->_expand_vars($this->template->description);
}


sub extended_description {
	my $this=shift;
	return $this->_expand_vars($this->template->extended_description);
}


sub choices {
	my $this=shift;
	
	return $this->_expand_vars($this->template->choices);
}


sub choices_split {
	my $this=shift;
	
	my @items;
	my $item='';
	for my $chunk (split /(\\[, ]|,\s+)/, $this->choices) {
		if ($chunk=~/^\\([, ])$/) {
			$item.=$1;
		} elsif ($chunk=~/^,\s+$/) {
			push @items, $item;
			$item='';
		} else {
			$item.=$chunk;
		}
	}
	push @items, $item if $item ne '';
	return @items;
}


sub variable {
	my $this=shift;
	my $var=shift;
	
	if (@_) {
		return $Debconf::Db::config->setvariable($this->{name}, $var, shift);
	}
	else {
		return $Debconf::Db::config->getvariable($this->{name}, $var);
	}
}


sub flag {
	my $this=shift;
	my $flag=shift;

	if ($flag eq 'isdefault') {
		debug developer => "The isdefault flag is deprecated, use the seen flag instead";
		if (@_) {
			my $value=(shift eq 'true') ? 'false' : 'true';
			$Debconf::Db::config->setflag($this->{name}, 'seen', $value);
		}
		return ($Debconf::Db::config->getflag($this->{name}, 'seen') eq 'true') ? 'false' : 'true';
	}

	if (@_) {
		return $Debconf::Db::config->setflag($this->{name}, $flag, shift);
	}
	else {
		return $Debconf::Db::config->getflag($this->{name}, $flag);
	}
}


sub value {
	my $this = shift;
	
	unless (@_) {
		my $ret=$Debconf::Db::config->getfield($this->{name}, 'value');
		return $ret if defined $ret;
		return $this->template->default if ref $this->template;
	} else {
		return $Debconf::Db::config->setfield($this->{name}, 'value', shift);
	}
}


sub value_split {
	my $this=shift;
	
	my $value=$this->value;
	$value='' if ! defined $value;
	my @items;
	my $item='';
	for my $chunk (split /(\\[, ]|,\s+)/, $value) {
		if ($chunk=~/^\\([, ])$/) {
			$item.=$1;
		} elsif ($chunk=~/^,\s+$/) {
			push @items, $item;
			$item='';
		} else {
			$item.=$chunk;
		}
	}
	push @items, $item if $item ne '';
	return @items;
}


sub addowner {
	my $this=shift;

	return $Debconf::Db::config->addowner($this->{name}, shift, shift);
}


sub removeowner {
	my $this=shift;

	my $template=$Debconf::Db::config->getfield($this->{name}, 'template');
	return unless $Debconf::Db::config->removeowner($this->{name}, shift);
	if (length $template and 
	    not $Debconf::Db::config->exists($this->{name})) {
		$Debconf::Db::templates->removeowner($template, $this->{name});
		delete $question{$this->{name}};
	}
}


sub owners {
	my $this=shift;

	return join(", ", sort($Debconf::Db::config->owners($this->{name})));
}


sub template {
	my $this=shift;
	if (@_) {
		my $oldtemplate=$Debconf::Db::config->getfield($this->{name}, 'template');
		my $newtemplate=shift;
		if (not defined $oldtemplate or $oldtemplate ne $newtemplate) {
			$Debconf::Db::templates->removeowner($oldtemplate, $this->{name})
				if defined $oldtemplate and length $oldtemplate;

			$Debconf::Db::config->setfield($this->{name}, 'template', $newtemplate);

			$Debconf::Db::templates->addowner($newtemplate, $this->{name},
				$Debconf::Db::templates->getfield($newtemplate, "type"));
		}
	}
	return Debconf::Template->get(
		$Debconf::Db::config->getfield($this->{name}, 'template'));
}


sub name {
	my $this=shift;

	return $this->{name};
}


sub priority {
	my $this=shift;

	$this->{priority}=shift if @_;

	return $this->{priority};
}


sub AUTOLOAD {
	(my $field = our $AUTOLOAD) =~ s/.*://;

	no strict 'refs';
	*$AUTOLOAD = sub {
		my $this=shift;

		if (@_) {
			return $Debconf::Db::config->setfield($this->{name}, $field, shift);
		}
		my $ret=$Debconf::Db::config->getfield($this->{name}, $field);
		unless (defined $ret) {
			$ret = $this->template->$field() if ref $this->template;
		}
		if (defined $ret) {
			if ($field =~ /^(?:description|extended_description|choices)-/i) {
				return $this->_expand_vars($ret);
			} else {
				return $ret;
			}
		}
	};
	goto &$AUTOLOAD;
}

sub DESTROY {
}


1

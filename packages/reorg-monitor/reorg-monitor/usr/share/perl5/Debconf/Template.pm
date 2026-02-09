#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Template;
use strict;
use POSIX;
use FileHandle;
use Debconf::Gettext;
use Text::Wrap;
use Text::Tabs;
use Debconf::Db;
use Debconf::Iterator;
use Debconf::Question;
use fields qw(template);
use Debconf::Log q{:all};
use Debconf::Encoding;
use Debconf::Config;

our %template;
$Debconf::Template::i18n=1;

our %known_field = map { $_ => 1 }
	qw{template description choices default type};

binmode(STDOUT);
binmode(STDERR);
	


sub new {
	my Debconf::Template $this=shift;
	my $template=shift || die "no template name specified";
	my $owner=shift || 'unknown';
	my $type=shift || die "no template type specified";
	
	if ($Debconf::Db::templates->exists($template) and
	    $Debconf::Db::templates->owners($template)) {
		if ($Debconf::Db::config->exists($template)) {
			my $q=Debconf::Question->get($template);
			$q->addowner($owner, $type) if $q;
		} else {
			my $q=Debconf::Question->new($template, $owner, $type);
			$q->template($template);
		}

		my @owners=$Debconf::Db::templates->owners($template);
		foreach my $question (@owners) {
			my $q=Debconf::Question->get($question);
			if (! $q) {
				warn sprintf(gettext("warning: possible database corruption. Will attempt to repair by adding back missing question %s."), $question);
				my $newq=Debconf::Question->new($question, $owner, $type);
				$newq->template($template);
			}
		}
		
		$this = fields::new($this);
		$this->{template}=$template;
		return $template{$template}=$this;
	}

	unless (ref $this) {
		$this = fields::new($this);
	}
	$this->{template}=$template;

	if ($Debconf::Db::config->exists($template)) {
		my $q=Debconf::Question->get($template);
		$q->addowner($owner, $type) if $q;
	}
	else {
		my $q=Debconf::Question->new($template, $owner, $type);
		$q->template($template);
	}
	
	return unless $Debconf::Db::templates->addowner($template, $template, $type);

	$Debconf::Db::templates->setfield($template, 'type', $type);
	return $template{$template}=$this;
}


sub get {
	my Debconf::Template $this=shift;
	my $template=shift;
	return $template{$template} if exists $template{$template};
	if ($Debconf::Db::templates->exists($template)) {
		$this = fields::new($this);
		$this->{template}=$template;
		return $template{$template}=$this;
	}
	return undef;
}


sub i18n {
	my $class=shift;
	$Debconf::Template::i18n=shift;
}


sub load {
	my $this=shift;
	my $file=shift;

	my @ret;
	my $fh;

	if (ref $file) {
		$fh=$file;
	}
	else {
		$fh=FileHandle->new($file) || die "$file: $!";
	}
	local $/="\n\n"; # read a template at a time.
	while (<$fh>) {
		my %data;
		
		my $save = sub {
			my $field=shift;
			my $value=shift;
			my $extended=shift;
			my $file=shift;

			$extended=~s/\n+$//;

			if ($field ne '') {
				if (exists $data{$field}) {
					die sprintf(gettext("Template #%s in %s has a duplicate field \"%s\" with new value \"%s\". Probably two templates are not properly separated by a lone newline.\n"), $., $file, $field, $value);
				}
				$data{$field}=$value;
				$data{"extended_$field"}=$extended
					if length $extended;
			}
		};

		s/^\n+//;
		s/\n+$//;
		my ($field, $value, $extended)=('', '', '');
		foreach my $line (split "\n", $_) {
			chomp $line;
			if ($line=~/^([-_@.A-Za-z0-9]*):\s?(.*)/) {
				$save->($field, $value, $extended, $file);
				$field=lc $1;
				$value=$2;
				$value=~s/\s*$//;
				$extended='';
				my $basefield=$field;
				$basefield=~s/-.+$//;
				if (! $known_field{$basefield}) {
					warn sprintf(gettext("Unknown template field '%s', in stanza #%s of %s\n"), $field, $., $file);
				}
			}
			elsif ($line=~/^\s\.$/) {
				$extended.="\n\n";
			}
			elsif ($line=~/^\s(\s+.*)/) {
				my $bit=$1;
				$bit=~s/\s*$//;
				$extended.="\n" if length $extended &&
				                   $extended !~ /[\n ]$/;
				$extended.=$bit."\n";
			}
			elsif ($line=~/^\s(.*)/) {
				my $bit=$1;
				$bit=~s/\s*$//;
				$extended.=' ' if length $extended &&
				                  $extended !~ /[\n ]$/;
				$extended.=$bit;
			}
			else {
				die sprintf(gettext("Template parse error near `%s', in stanza #%s of %s\n"), $line, $., $file);
			}
		}
		$save->($field, $value, $extended, $file);

		die sprintf(gettext("Template #%s in %s does not contain a 'Template:' line\n"), $., $file)
			unless $data{template};

		my $template=$this->new($data{template}, @_, $data{type});
		$template->clearall;
		foreach my $key (keys %data) {
			next if $key eq 'template';
			$template->$key($data{$key});
		}
		push @ret, $template;
	}

	return @ret;
}
					

sub template {
	my $this=shift;

	return $this->{template};
}


sub fields {
	my $this=shift;

	return $Debconf::Db::templates->fields($this->{template});
}


sub clearall {
	my $this=shift;

	foreach my $field ($this->fields) {
		$Debconf::Db::templates->removefield($this->{template}, $field);
	}
}


sub stringify {
	my $this=shift;

	my @templatestrings;
	foreach (ref $this ? $this : @_) {
		my $data='';
		foreach my $key ('template', 'type',
			(grep { $_ ne 'template' && $_ ne 'type'} sort $_->fields)) {
			next if $key=~/^extended_/;
			if ($key =~ m/-[a-z]{2}_[a-z]{2}(@[^_@.])?(-fuzzy)?$/) {
				my $casekey=$key;
				$casekey=~s/([a-z]{2})(@[^_@.]|)(-fuzzy|)$/uc($1).$2.$3/eg;
				$data.=ucfirst($casekey).": ".$_->$key."\n";
			}
			else {
				$data.=ucfirst($key).": ".$_->$key."\n";
			}
			my $e="extended_$key";
			my $ext=$_->$e;
			if (defined $ext) {
				$Text::Wrap::break = qr/\n|\s(?=\S)/;
				my $extended=expand(wrap(' ', ' ', $ext));
				$extended=~s/(\n )+\n/\n .\n/g;
				$data.=$extended."\n" if length $extended;
			}
		}
		push @templatestrings, $data;
	}
	return join("\n", @templatestrings);
}


sub _addterritory {
	my $locale=shift;
	my $territory=shift;
	$locale=~s/^([^_@.]+)/$1$territory/;
	return $locale;
}
sub _addcharset {
	my $locale=shift;
	my $charset=shift;
	$locale=~s/^([^@.]+)/$1$charset/;
	return $locale;
}
sub _getlocalelist {
	my $locale=shift;
	$locale=~s/(@[^.]+)//;
	my $modifier=$1;
	my ($lang, $territory, $charset)=($locale=~m/^
	     ([^_@.]+)      #  Language
	     (_[^_@.]+)?    #  Territory
	     (\..+)?        #  Charset
	     /x);
	my (@ret) = ($lang);
	@ret = map { $_.$modifier, $_} @ret if defined $modifier;
	@ret = map { _addterritory($_,$territory), $_} @ret if defined $territory;
	@ret = map { _addcharset($_,$charset), $_} @ret if defined $charset;
	return @ret;
}

sub _getlangs {
	my $language=setlocale(LC_MESSAGES);
	my @langs = ();
	if (exists $ENV{LANGUAGE} && $ENV{LANGUAGE} ne '') {
		foreach (split(/:/, $ENV{LANGUAGE})) {
			push (@langs, _getlocalelist($_));
		}
	}
	return @langs, _getlocalelist($language);
}

my @langs=map { lc $_ } _getlangs();

sub AUTOLOAD {
	(my $field = our $AUTOLOAD) =~ s/.*://;
	no strict 'refs';
	*$AUTOLOAD = sub {
		my $this=shift;
		if (@_) {
			return $Debconf::Db::templates->setfield($this->{template}, $field, shift);
		}
		
		my $ret;
		my $want_i18n = $Debconf::Template::i18n && Debconf::Config->c_values ne 'true';

		if ($want_i18n && @langs) {
			foreach my $lang (@langs) {
				$lang = 'en' if $lang eq 'c';

				$ret=$Debconf::Db::templates->getfield($this->{template}, $field.'-'.$lang);
				return $ret if defined $ret;
				
				if ($Debconf::Encoding::charmap) {
					foreach my $f ($Debconf::Db::templates->fields($this->{template})) {
						if ($f =~ /^\Q$field-$lang\E\.(.+)/) {
							my $encoding = $1;
							$ret = Debconf::Encoding::convert($encoding, $Debconf::Db::templates->getfield($this->{template}, lc($f)));
							return $ret if defined $ret;
						}
					}
				}

				last if $lang eq 'en';
			}
		} elsif (not $want_i18n && $field !~ /-c$/i) {
			$ret=$Debconf::Db::templates->getfield($this->{template}, $field.'-c');
			return $ret if defined $ret;
		}

		$ret=$Debconf::Db::templates->getfield($this->{template}, $field);
		return $ret if defined $ret;

		if ($field =~ /-/) {
			(my $plainfield = $field) =~ s/-.*//;
			$ret=$Debconf::Db::templates->getfield($this->{template}, $plainfield);
			return $ret if defined $ret;
			return '';
		}

		return '';
	};
	goto &$AUTOLOAD;
}

sub DESTROY {}

use overload
	'""' => sub {
		my $template=shift;
		$template->template;
	};


1

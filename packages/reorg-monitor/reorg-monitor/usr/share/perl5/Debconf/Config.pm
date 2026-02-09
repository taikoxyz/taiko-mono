#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::Config;
use strict;
use Debconf::Question;
use Debconf::Gettext;
use Debconf::Priority qw(priority_valid priority_list);
use Debconf::Log qw(warn);
use Debconf::Db;

use fields qw(config templates frontend frontend_forced priority terse reshow
              admin_email log debug nowarnings smileys sigils
              noninteractive_seen c_values);
our $config=fields::new('Debconf::Config');

our @config_files=("/etc/debconf.conf", "/usr/share/debconf/debconf.conf");
if ($ENV{DEBCONF_SYSTEMRC}) {
	unshift @config_files, $ENV{DEBCONF_SYSTEMRC};
} else {
	unshift @config_files, ((getpwuid($>))[7])."/.debconfrc";
}
	   

sub _hashify ($$) {
	my $text=shift;
	my $hash=shift;

	$text =~ s/\$\{([^}]+)\}/$ENV{$1}/eg;
	
	my %ret;
	my $i;
	foreach my $line (split /\n/, $text) {
		next if $line=~/^\s*#/; # comment
		next if $line=~/^\s*$/; # blank
		$line=~s/^\s+//;
		$line=~s/\s+$//;
		$i++;
		my ($key, $value)=split(/\s*:\s*/, $line, 2);
		$key=~tr/-/_/;
		die "Parse error" unless defined $key and length $key;
		$hash->{lc($key)}=$value;
	}
	return $i;
}
 
sub _env_to_driver {
	my $value=shift;
	
	my ($name, $options) = $value =~ m/^(\w+)(?:{(.*)})?$/;
	return unless $name;
	
	return $name if Debconf::DbDriver->driver($name);
	
	my %hash = @_; # defaults from params
	$hash{driver} = $name;
	
	if (defined $options) {
		foreach (split ' ', $options) {
			if (/^(\w+):(.*)/) {
				$hash{$1}=$2;
			}
			else {
				$hash{filename}=$_;
			}
		}
	}
	return Debconf::Db->makedriver(%hash)->{name};
}

sub load {
	my $class=shift;
	my $cf=shift;
	my @defaults=@_;
	
	if (! $cf) {
		for my $file (@config_files) {
			$file = "$ENV{DPKG_ROOT}$file" if exists $ENV{DPKG_ROOT};
			$cf=$file, last if -e $file;
		}
	}
	die "No config file found" unless $cf;

	open (DEBCONF_CONFIG, $cf) or die "$cf: $!\n";
	local $/="\n\n"; # read a stanza at a time

	1 until _hashify(<DEBCONF_CONFIG>, $config) || eof DEBCONF_CONFIG;

	if (! exists $config->{config}) {
		print STDERR "debconf: ".gettext("Config database not specified in config file.")."\n";
		exit(1);
	}
	if (! exists $config->{templates}) {
		print STDERR "debconf: ".gettext("Template database not specified in config file.")."\n";
		exit(1);
	}

	if (exists $config->{sigils} || exists $config->{smileys}) {
		print STDERR "debconf: ".gettext("The Sigils and Smileys options in the config file are no longer used. Please remove them.")."\n";
	}

	while (<DEBCONF_CONFIG>) {
		my %config=(@defaults);
		if (exists $ENV{DEBCONF_DB_REPLACE}) {
			$config{readonly} = "true";
		}
		if (exists $ENV{DPKG_ROOT}) {
			$config{root} = $ENV{DPKG_ROOT};
		}
		next unless _hashify($_, \%config);
		eval {
			Debconf::Db->makedriver(%config);
		};
		if ($@) {
			print STDERR "debconf: ".sprintf(gettext("Problem setting up the database defined by stanza %s of %s."),$., $cf)."\n";
			die $@;
		}
	}
	close DEBCONF_CONFIG;

	if (exists $ENV{DEBCONF_DB_REPLACE}) {
		$config->{config} = _env_to_driver($ENV{DEBCONF_DB_REPLACE},
			name => "_ENV_REPLACE");
		Debconf::Db->makedriver(
			driver => "Pipe",
			name => "_ENV_REPLACE_templates",
			infd => "none",
			outfd => "none",
		);
		my @template_stack = ("_ENV_REPLACE_templates", $config->{templates});
		Debconf::Db->makedriver(
			driver => "Stack",
			name => "_ENV_stack_templates",
			stack => join(", ", @template_stack),
		);
		$config->{templates} = "_ENV_stack_templates";
	}

	my @finalstack = ($config->{config});
	if (exists $ENV{DEBCONF_DB_OVERRIDE}) {
		unshift @finalstack, _env_to_driver($ENV{DEBCONF_DB_OVERRIDE},
			name => "_ENV_OVERRIDE");
	}
	if (exists $ENV{DEBCONF_DB_FALLBACK}) {
		push @finalstack, _env_to_driver($ENV{DEBCONF_DB_FALLBACK},
			name => "_ENV_FALLBACK",
			readonly => "true");
	}
	if (@finalstack > 1) {
		Debconf::Db->makedriver(
			driver => "Stack",
			name => "_ENV_stack",
			stack  => join(", ", @finalstack),
		);
		$config->{config} = "_ENV_stack";
	}
}


sub getopt {
	my $class=shift;
	my $usage=shift;

	my $showusage=sub { # closure
		print STDERR $usage."\n";
		print STDERR gettext(<<EOF);
  -f,  --frontend		Specify debconf frontend to use.
  -p,  --priority		Specify minimum priority question to show.
       --terse			Enable terse mode.
EOF
		exit 1;
	};

	return unless grep { $_ =~ /^-/ } @ARGV;
	
	require Getopt::Long;
	Getopt::Long::Configure('bundling');
	Getopt::Long::GetOptions(
		'frontend|f=s',	sub { shift; $class->frontend(shift); $config->frontend_forced(1) },
		'priority|p=s',	sub { shift; $class->priority(shift) },
		'terse',	sub { $config->{terse} = 'true' },
		'help|h',	$showusage,
		@_,
	) || $showusage->();
}


sub frontend {
	my $class=shift;
	
	return $ENV{DEBIAN_FRONTEND} if exists $ENV{DEBIAN_FRONTEND};
	$config->{frontend}=shift if @_;
	return $config->{frontend} if exists $config->{frontend};
	
	my $ret='dialog';
	my $question=Debconf::Question->get('debconf/frontend');
	if ($question) {
		$ret=lcfirst($question->value) || $ret;
	}
	return $ret;
}


sub frontend_forced {
	my ($class, $val) = @_;
	$config->{frontend_forced} = $val
		if defined $val || exists $ENV{DEBIAN_FRONTEND};
	return $config->{frontend_forced} ? 1 : 0;
}


sub priority {
	my $class=shift;
	return $ENV{DEBIAN_PRIORITY} if exists $ENV{DEBIAN_PRIORITY};
	if (@_) {
		my $newpri=shift;
		if (! priority_valid($newpri)) {
			warn(sprintf(gettext("Ignoring invalid priority \"%s\""), $newpri));
			warn(sprintf(gettext("Valid priorities are: %s"), join(" ", priority_list())));
		}
		else {
			$config->{priority}=$newpri;
		}
	}
	return $config->{priority} if exists $config->{priority};

	my $ret='high';
	my $question=Debconf::Question->get('debconf/priority');
	if ($question) {
		$ret=$question->value || $ret;
	}
	return $ret;
}


sub terse {
	my $class=shift;
	return $ENV{DEBCONF_TERSE} if exists $ENV{DEBCONF_TERSE};
	$config->{terse}=$_[0] if @_;
	return $config->{terse} if exists $config->{terse};
	return 'false';
}


sub nowarnings {
	my $class=shift;
	return $ENV{DEBCONF_NOWARNINGS} if exists $ENV{DEBCONF_NOWARNINGS};
	$config->{nowarnings}=$_[0] if @_;
	return $config->{nowarnings} if exists $config->{nowarnings};
	return 'false';
}


sub debug {
	my $class=shift;
	return $ENV{DEBCONF_DEBUG} if exists $ENV{DEBCONF_DEBUG};
	return $config->{debug} if exists $config->{debug};
	return '';
}


sub admin_email {
	my $class=shift;
	return $ENV{DEBCONF_ADMIN_EMAIL} if exists $ENV{DEBCONF_ADMIN_EMAIL};
	return $config->{admin_email} if exists $config->{admin_email};
	return 'root';
}


sub noninteractive_seen {
	my $class=shift;
	return $ENV{DEBCONF_NONINTERACTIVE_SEEN} if exists $ENV{DEBCONF_NONINTERACTIVE_SEEN};
	return $config->{noninteractive_seen} if exists $config->{noninteractive_seen};
	return 'false';
}


sub c_values {
	my $class=shift;
	return $ENV{DEBCONF_C_VALUES} if exists $ENV{DEBCONF_C_VALUES};
	return $config->{c_values} if exists $config->{c_values};
	return 'false';
}


sub AUTOLOAD {
	(my $field = our $AUTOLOAD) =~ s/.*://;
	my $class=shift;
	
	return $config->{$field}=shift if @_;
	return $config->{$field} if defined $config->{$field};
	return '';
}


1

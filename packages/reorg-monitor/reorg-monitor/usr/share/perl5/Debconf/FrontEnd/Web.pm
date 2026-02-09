#!/usr/bin/perl -w
# This file was preprocessed, do not edit!


package Debconf::FrontEnd::Web;
use IO::Socket;
use IO::Select;
use CGI;
use strict;
use Debconf::Gettext;
use base qw(Debconf::FrontEnd);



sub init {
	my $this=shift;

	$this->SUPER::init(@_);
	
	$this->port(8001) unless defined $this->port;
	$this->formid(0);
	$this->interactive(1);
	$this->capb('backup');
	$this->need_tty(0);

	$this->server(IO::Socket::INET->new(
		LocalPort => $this->port,
		Proto => 'tcp',
		Listen => 1,
		Reuse => 1,
		LocalAddr => '127.0.0.1',
	)) || die "Can't bind to ".$this->port.": $!";

	print STDERR sprintf(gettext("Note: Debconf is running in web mode. Go to http://localhost:%i/"),$this->port)."\n";
}


sub client {
	my $this=shift;
	
	$this->{client}=shift if @_;
	return $this->{client} if $this->{client};

	my $select=IO::Select->new($this->server);
	1 while ! $select->can_read(1);
	my $client=$this->server->accept;
	my $commands='';
	while (<$client>) {
		last if $_ eq "\r\n";
		$commands.=$_;
	}
	$this->commands($commands);
	$this->{client}=$client;
}


sub closeclient {
	my $this=shift;
	
	close $this->client;
	$this->client('');
}


sub showclient {
	my $this=shift;
	my $page=shift;

	my $client=$this->client;
	print $client $page;
}


sub go {
	my $this=shift;

	$this->backup('');

	my $httpheader="HTTP/1.0 200 Ok\nContent-type: text/html\n\n";
	my $form='';
	my $id=0;
	my %idtoelt;
	foreach my $elt (@{$this->elements}) {
		$idtoelt{$id}=$elt;
		$elt->id($id++);
		my $html=$elt->show;
		if ($html ne '') {
			$form.=$html."<hr>\n";
		}
	}
	return 1 if $form eq '';

	my $formid=$this->formid(1 + $this->formid);

	$form="<html>\n<title>".$this->title."</title>\n<body>\n".
	       "<form><input type=hidden name=formid value=$formid>\n".
	       $form."<p>\n";

	if ($this->capb_backup) {
		$form.="<input type=submit value=".gettext("Back")." name=back>\n";
	}
	$form.="<input type=submit value=".gettext("Next").">\n";
	$form.="</form>\n</body>\n</html>\n";

	my $query;
	do {
		$this->showclient($httpheader . $form);
	
		$this->closeclient;
		$this->client;
		
		my @get=grep { /^GET / } split(/\r\n/, $this->commands);
		my $get=shift @get;
		my ($qs)=$get=~m/^GET\s+.*?\?(.*?)(?:\s+.*)?$/;
	
		$query=CGI->new($qs);
	} until (defined $query->param('formid') &&
		 $query->param('formid') eq $formid);

	if ($this->capb_backup && defined $query->param('back')  &&
	    $query->param('back') ne '') {
		return '';
	}

	foreach my $id ($query->param) {
		next unless $idtoelt{$id};
		
		$idtoelt{$id}->value($query->param($id));
		delete $idtoelt{$id};
	}
	foreach my $elt (values %idtoelt) {
		$elt->value('');
	}
	
	return 1;
}


1

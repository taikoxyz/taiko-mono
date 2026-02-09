
package Debconf::FrontEnd::Kde;

use strict;
use warnings;
use IO::Handle;
use Fcntl;
use POSIX ":sys_wait_h";
use Debconf::Config;
use base "Debconf::FrontEnd::Passthrough";



sub clear_fd_cloexec {
	my $fh = shift;
	my $flags;
	$flags = $fh->fcntl(F_GETFD, 0);
	$flags &= ~FD_CLOEXEC;
	$fh->fcntl(F_SETFD, $flags);
}


sub init {
	my $this = shift;

	$this->need_tty(0);

	pipe my $dc2hp_readfh, my $dc2hp_writefh;
	pipe my $hp2dc_readfh, my $hp2dc_writefh;

	my $helper_pid = fork();
	if (!defined $helper_pid) {
		die "Unable to fork for execution of debconf-kde-helper: $!\n";
	} elsif ($helper_pid == 0) {
		close $hp2dc_readfh;
		close $dc2hp_writefh;
		clear_fd_cloexec($dc2hp_readfh);
		clear_fd_cloexec($hp2dc_writefh);
		my $debug = Debconf::Config->debug;
		local $ENV{QT_LOGGING_RULES} = 'org.kde.debconf.debug=false'
			unless $debug && 'kde' =~ /$debug/;
		my $fds = sprintf("%d,%d", $dc2hp_readfh->fileno(), $hp2dc_writefh->fileno());
		if (!exec("debconf-kde-helper", "--fifo-fds=$fds")) {
			print STDERR "Unable to execute debconf-kde-helper - is debconf-kde-helper installed?";
			exit(10);
		}
	}

	close $dc2hp_readfh;
	close $hp2dc_writefh;

	$this->{kde_helper_pid} = $helper_pid;
	$this->{readfh} = $hp2dc_readfh;
	$this->{writefh} = $dc2hp_writefh;
	$this->SUPER::init();

	my $timeout = 15;
	my $tag = $this->talk_with_timeout($timeout, "X_PING");
	unless (defined $tag && $tag == 0) {
		close $hp2dc_readfh;
		close $dc2hp_writefh;
		if (waitpid($helper_pid, WNOHANG) == $helper_pid) {
			die "debconf-kde-helper terminated abnormally (exit status: " . WEXITSTATUS($?) . ")\n";
		} elsif (kill(0, $helper_pid) == 1) {
			kill 9, $helper_pid;
			waitpid($helper_pid, 0);
		}
		if (defined $tag) {
			die "debconf-kde-helper failed to respond to ping. Response was $tag\n";
		} else {
			die "debconf-kde-helper did not respond to ping in $timeout seconds\n";
		}
	}
}


sub shutdown {
	my $this = shift;
	$this->SUPER::shutdown();
	if (defined $this->{kde_helper_pid}) {
	    waitpid $this->{kde_helper_pid}, 0;
		delete $this->{kde_helper_pid};
	}
}


1;

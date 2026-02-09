# IO::Socket.pm
#
# Copyright (c) 1997-8 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package IO::Socket;

use 5.008_001;

use IO::Handle;
use Socket 1.3;
use Carp;
use strict;
use Exporter;
use Errno;

# legacy

require IO::Socket::INET;
require IO::Socket::UNIX if ($^O ne 'epoc' && $^O ne 'symbian');

our @ISA = qw(IO::Handle);

our $VERSION = "1.49";

our @EXPORT_OK = qw(sockatmark);

our $errstr;

sub import {
    my $pkg = shift;
    if (@_ && $_[0] eq 'sockatmark') { # not very extensible but for now, fast
	Exporter::export_to_level('IO::Socket', 1, $pkg, 'sockatmark');
    } else {
	my $callpkg = caller;
	Exporter::export 'Socket', $callpkg, @_;
    }
}

sub new {
    my($class,%arg) = @_;
    my $sock = $class->SUPER::new();

    $sock->autoflush(1);

    ${*$sock}{'io_socket_timeout'} = delete $arg{Timeout};

    return scalar(%arg) ? $sock->configure(\%arg)
			: $sock;
}

my @domain2pkg;

sub register_domain {
    my($p,$d) = @_;
    $domain2pkg[$d] = $p;
}

sub configure {
    my($sock,$arg) = @_;
    my $domain = delete $arg->{Domain};

    croak 'IO::Socket: Cannot configure a generic socket'
	unless defined $domain;

    croak "IO::Socket: Unsupported socket domain"
	unless defined $domain2pkg[$domain];

    croak "IO::Socket: Cannot configure socket in domain '$domain'"
	unless ref($sock) eq "IO::Socket";

    bless($sock, $domain2pkg[$domain]);
    $sock->configure($arg);
}

sub socket {
    @_ == 4 or croak 'usage: $sock->socket(DOMAIN, TYPE, PROTOCOL)';
    my($sock,$domain,$type,$protocol) = @_;

    socket($sock,$domain,$type,$protocol) or
    	return undef;

    ${*$sock}{'io_socket_domain'} = $domain;
    ${*$sock}{'io_socket_type'}   = $type;

    # "A value of 0 for protocol will let the system select an
    # appropriate protocol"
    # so we need to look up what the system selected,
    # not cache PF_UNSPEC.
    ${*$sock}{'io_socket_proto'} = $protocol if $protocol;

    $sock;
}

sub socketpair {
    @_ == 4 || croak 'usage: IO::Socket->socketpair(DOMAIN, TYPE, PROTOCOL)';
    my($class,$domain,$type,$protocol) = @_;
    my $sock1 = $class->new();
    my $sock2 = $class->new();

    socketpair($sock1,$sock2,$domain,$type,$protocol) or
    	return ();

    ${*$sock1}{'io_socket_type'}  = ${*$sock2}{'io_socket_type'}  = $type;
    ${*$sock1}{'io_socket_proto'} = ${*$sock2}{'io_socket_proto'} = $protocol;

    ($sock1,$sock2);
}

sub connect {
    @_ == 2 or croak 'usage: $sock->connect(NAME)';
    my $sock = shift;
    my $addr = shift;
    my $timeout = ${*$sock}{'io_socket_timeout'};
    my $err;
    my $blocking;

    $blocking = $sock->blocking(0) if $timeout;
    if (!connect($sock, $addr)) {
	if (defined $timeout && ($!{EINPROGRESS} || $!{EWOULDBLOCK})) {
	    require IO::Select;

	    my $sel = IO::Select->new( $sock );

	    undef $!;
	    my($r,$w,$e) = IO::Select::select(undef,$sel,$sel,$timeout);
	    if(@$e[0]) {
		# Windows return from select after the timeout in case of
		# WSAECONNREFUSED(10061) if exception set is not used.
		# This behavior is different from Linux.
		# Using the exception
		# set we now emulate the behavior in Linux
		#    - Karthik Rajagopalan
		$err = $sock->getsockopt(SOL_SOCKET,SO_ERROR);
		$errstr = $@ = "connect: $err";
	    }
	    elsif(!@$w[0]) {
		$err = $! || (exists &Errno::ETIMEDOUT ? &Errno::ETIMEDOUT : 1);
		$errstr = $@ = "connect: timeout";
	    }
	    elsif (!connect($sock,$addr) &&
                not ($!{EISCONN} || ($^O eq 'MSWin32' &&
                ($! == (($] < 5.019004) ? 10022 : Errno::EINVAL))))
            ) {
		# Some systems refuse to re-connect() to
		# an already open socket and set errno to EISCONN.
		# Windows sets errno to WSAEINVAL (10022) (pre-5.19.4) or
		# EINVAL (22) (5.19.4 onwards).
		$err = $!;
		$errstr = $@ = "connect: $!";
	    }
	}
        elsif ($blocking || !($!{EINPROGRESS} || $!{EWOULDBLOCK}))  {
	    $err = $!;
	    $errstr = $@ = "connect: $!";
	}
    }

    $sock->blocking(1) if $blocking;

    $! = $err if $err;

    $err ? undef : $sock;
}

# Enable/disable blocking IO on sockets.
# Without args return the current status of blocking,
# with args change the mode as appropriate, returning the
# old setting, or in case of error during the mode change
# undef.

sub blocking {
    my $sock = shift;

    return $sock->SUPER::blocking(@_)
        if $^O ne 'MSWin32' && $^O ne 'VMS';

    # Windows handles blocking differently
    #
    # http://groups.google.co.uk/group/perl.perl5.porters/browse_thread/thread/b4e2b1d88280ddff/630b667a66e3509f?#630b667a66e3509f
    # http://msdn.microsoft.com/library/default.asp?url=/library/en-us/winsock/winsock/ioctlsocket_2.asp
    #
    # 0x8004667e is FIONBIO
    #
    # which is used to set blocking behaviour.

    # NOTE:
    # This is a little confusing, the perl keyword for this is
    # 'blocking' but the OS level behaviour is 'non-blocking', probably
    # because sockets are blocking by default.
    # Therefore internally we have to reverse the semantics.

    my $orig= !${*$sock}{io_sock_nonblocking};

    return $orig unless @_;

    my $block = shift;

    if ( !$block != !$orig ) {
        ${*$sock}{io_sock_nonblocking} = $block ? 0 : 1;
        ioctl($sock, 0x8004667e, pack("L!",${*$sock}{io_sock_nonblocking}))
            or return undef;
    }

    return $orig;
}

sub close {
    @_ == 1 or croak 'usage: $sock->close()';
    my $sock = shift;
    ${*$sock}{'io_socket_peername'} = undef;
    $sock->SUPER::close();
}

sub bind {
    @_ == 2 or croak 'usage: $sock->bind(NAME)';
    my $sock = shift;
    my $addr = shift;

    return bind($sock, $addr) ? $sock
			      : undef;
}

sub listen {
    @_ >= 1 && @_ <= 2 or croak 'usage: $sock->listen([QUEUE])';
    my($sock,$queue) = @_;
    $queue = 5
	unless $queue && $queue > 0;

    return listen($sock, $queue) ? $sock
				 : undef;
}

sub accept {
    @_ == 1 || @_ == 2 or croak 'usage $sock->accept([PKG])';
    my $sock = shift;
    my $pkg = shift || $sock;
    my $timeout = ${*$sock}{'io_socket_timeout'};
    my $new = $pkg->new(Timeout => $timeout);
    my $peer = undef;

    if(defined $timeout) {
	require IO::Select;

	my $sel = IO::Select->new( $sock );

	unless ($sel->can_read($timeout)) {
	    $errstr = $@ = 'accept: timeout';
	    $! = (exists &Errno::ETIMEDOUT ? &Errno::ETIMEDOUT : 1);
	    return;
	}
    }

    $peer = accept($new,$sock)
	or return;

    ${*$new}{$_} = ${*$sock}{$_} for qw( io_socket_domain io_socket_type io_socket_proto );

    return wantarray ? ($new, $peer)
    	      	     : $new;
}

sub sockname {
    @_ == 1 or croak 'usage: $sock->sockname()';
    getsockname($_[0]);
}

sub peername {
    @_ == 1 or croak 'usage: $sock->peername()';
    my($sock) = @_;
    ${*$sock}{'io_socket_peername'} ||= getpeername($sock);
}

sub connected {
    @_ == 1 or croak 'usage: $sock->connected()';
    my($sock) = @_;
    getpeername($sock);
}

sub send {
    @_ >= 2 && @_ <= 4 or croak 'usage: $sock->send(BUF, [FLAGS, [TO]])';
    my $sock  = $_[0];
    my $flags = $_[2] || 0;
    my $peer;

    if ($_[3]) {
        # the caller explicitly requested a TO, so use it
        # this is non-portable for "connected" UDP sockets
        $peer = $_[3];
    }
    elsif (!defined getpeername($sock)) {
        # we're not connected, so we require a peer from somewhere
        $peer = $sock->peername;

	croak 'send: Cannot determine peer address'
	    unless(defined $peer);
    }

    my $r = $peer
      ? send($sock, $_[1], $flags, $peer)
      : send($sock, $_[1], $flags);

    # remember who we send to, if it was successful
    ${*$sock}{'io_socket_peername'} = $peer
	if(@_ == 4 && defined $r);

    $r;
}

sub recv {
    @_ == 3 || @_ == 4 or croak 'usage: $sock->recv(BUF, LEN [, FLAGS])';
    my $sock  = $_[0];
    my $len   = $_[2];
    my $flags = $_[3] || 0;

    # remember who we recv'd from
    ${*$sock}{'io_socket_peername'} = recv($sock, $_[1]='', $len, $flags);
}

sub shutdown {
    @_ == 2 or croak 'usage: $sock->shutdown(HOW)';
    my($sock, $how) = @_;
    ${*$sock}{'io_socket_peername'} = undef;
    shutdown($sock, $how);
}

sub setsockopt {
    @_ == 4 or croak '$sock->setsockopt(LEVEL, OPTNAME, OPTVAL)';
    setsockopt($_[0],$_[1],$_[2],$_[3]);
}

my $intsize = length(pack("i",0));

sub getsockopt {
    @_ == 3 or croak '$sock->getsockopt(LEVEL, OPTNAME)';
    my $r = getsockopt($_[0],$_[1],$_[2]);
    # Just a guess
    $r = unpack("i", $r)
	if(defined $r && length($r) == $intsize);
    $r;
}

sub sockopt {
    my $sock = shift;
    @_ == 1 ? $sock->getsockopt(SOL_SOCKET,@_)
	    : $sock->setsockopt(SOL_SOCKET,@_);
}

sub atmark {
    @_ == 1 or croak 'usage: $sock->atmark()';
    my($sock) = @_;
    sockatmark($sock);
}

sub timeout {
    @_ == 1 || @_ == 2 or croak 'usage: $sock->timeout([VALUE])';
    my($sock,$val) = @_;
    my $r = ${*$sock}{'io_socket_timeout'};

    ${*$sock}{'io_socket_timeout'} = defined $val ? 0 + $val : $val
	if(@_ == 2);

    $r;
}

sub sockdomain {
    @_ == 1 or croak 'usage: $sock->sockdomain()';
    my $sock = shift;
    if (!defined(${*$sock}{'io_socket_domain'})) {
	my $addr = $sock->sockname();
	${*$sock}{'io_socket_domain'} = sockaddr_family($addr)
	    if (defined($addr));
    }
    ${*$sock}{'io_socket_domain'};
}

sub socktype {
    @_ == 1 or croak 'usage: $sock->socktype()';
    my $sock = shift;
    ${*$sock}{'io_socket_type'} = $sock->sockopt(Socket::SO_TYPE)
	if (!defined(${*$sock}{'io_socket_type'}) && defined(eval{Socket::SO_TYPE}));
    ${*$sock}{'io_socket_type'}
}

sub protocol {
    @_ == 1 or croak 'usage: $sock->protocol()';
    my($sock) = @_;
    ${*$sock}{'io_socket_proto'} = $sock->sockopt(Socket::SO_PROTOCOL)
	if (!defined(${*$sock}{'io_socket_proto'}) && defined(eval{Socket::SO_PROTOCOL}));
    ${*$sock}{'io_socket_proto'};
}

1;

__END__


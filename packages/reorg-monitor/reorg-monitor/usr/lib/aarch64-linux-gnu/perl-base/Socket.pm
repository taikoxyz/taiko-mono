package Socket;

use strict;
{ use v5.6.1; }

our $VERSION = '2.033';

# Still undocumented: SCM_*, SOMAXCONN, IOV_MAX, UIO_MAXIOV

use Carp;
use warnings::register;

require Exporter;
require XSLoader;
our @ISA = qw(Exporter);

# <@Nicholas> you can't change @EXPORT without breaking the implicit API
# Please put any new constants in @EXPORT_OK!

# List re-ordered to match documentation above. Try to keep the ordering
# consistent so it's easier to see which ones are or aren't documented.
our @EXPORT = qw(
	PF_802 PF_AAL PF_APPLETALK PF_CCITT PF_CHAOS PF_CTF PF_DATAKIT
	PF_DECnet PF_DLI PF_ECMA PF_GOSIP PF_HYLINK PF_IMPLINK PF_INET PF_INET6
	PF_ISO PF_KEY PF_LAST PF_LAT PF_LINK PF_MAX PF_NBS PF_NIT PF_NS PF_OSI
	PF_OSINET PF_PUP PF_ROUTE PF_SNA PF_UNIX PF_UNSPEC PF_USER PF_WAN
	PF_X25

	AF_802 AF_AAL AF_APPLETALK AF_CCITT AF_CHAOS AF_CTF AF_DATAKIT
	AF_DECnet AF_DLI AF_ECMA AF_GOSIP AF_HYLINK AF_IMPLINK AF_INET AF_INET6
	AF_ISO AF_KEY AF_LAST AF_LAT AF_LINK AF_MAX AF_NBS AF_NIT AF_NS AF_OSI
	AF_OSINET AF_PUP AF_ROUTE AF_SNA AF_UNIX AF_UNSPEC AF_USER AF_WAN
	AF_X25

	SOCK_DGRAM SOCK_RAW SOCK_RDM SOCK_SEQPACKET SOCK_STREAM

	SOL_SOCKET

	SO_ACCEPTCONN SO_ATTACH_FILTER SO_BACKLOG SO_BROADCAST SO_CHAMELEON
	SO_DEBUG SO_DETACH_FILTER SO_DGRAM_ERRIND SO_DOMAIN SO_DONTLINGER
	SO_DONTROUTE SO_ERROR SO_FAMILY SO_KEEPALIVE SO_LINGER SO_OOBINLINE
	SO_PASSCRED SO_PASSIFNAME SO_PEERCRED SO_PROTOCOL SO_PROTOTYPE
	SO_RCVBUF SO_RCVLOWAT SO_RCVTIMEO SO_REUSEADDR SO_REUSEPORT
	SO_SECURITY_AUTHENTICATION SO_SECURITY_ENCRYPTION_NETWORK
	SO_SECURITY_ENCRYPTION_TRANSPORT SO_SNDBUF SO_SNDLOWAT SO_SNDTIMEO
	SO_STATE SO_TYPE SO_USELOOPBACK SO_XOPEN SO_XSE

	IP_HDRINCL IP_OPTIONS IP_RECVOPTS IP_RECVRETOPTS IP_RETOPTS IP_TOS
	IP_TTL

	MSG_BCAST MSG_BTAG MSG_CTLFLAGS MSG_CTLIGNORE MSG_CTRUNC MSG_DONTROUTE
	MSG_DONTWAIT MSG_EOF MSG_EOR MSG_ERRQUEUE MSG_ETAG MSG_FASTOPEN MSG_FIN
	MSG_MAXIOVLEN MSG_MCAST MSG_NOSIGNAL MSG_OOB MSG_PEEK MSG_PROXY MSG_RST
	MSG_SYN MSG_TRUNC MSG_URG MSG_WAITALL MSG_WIRE

	SHUT_RD SHUT_RDWR SHUT_WR

	INADDR_ANY INADDR_BROADCAST INADDR_LOOPBACK INADDR_NONE

	SCM_CONNECT SCM_CREDENTIALS SCM_CREDS SCM_RIGHTS SCM_TIMESTAMP

	SOMAXCONN

	IOV_MAX
	UIO_MAXIOV

	sockaddr_family
	pack_sockaddr_in  unpack_sockaddr_in  sockaddr_in
	pack_sockaddr_in6 unpack_sockaddr_in6 sockaddr_in6
	pack_sockaddr_un  unpack_sockaddr_un  sockaddr_un 

	inet_aton inet_ntoa
);

# List re-ordered to match documentation above. Try to keep the ordering
# consistent so it's easier to see which ones are or aren't documented.
our @EXPORT_OK = qw(
	CR LF CRLF $CR $LF $CRLF

	SOCK_NONBLOCK SOCK_CLOEXEC

	IP_ADD_MEMBERSHIP IP_ADD_SOURCE_MEMBERSHIP IP_BIND_ADDRESS_NO_PORT
	IP_DROP_MEMBERSHIP IP_DROP_SOURCE_MEMBERSHIP IP_FREEBIND
	IP_MULTICAST_ALL IP_MULTICAST_IF IP_MULTICAST_LOOP IP_MULTICAST_TTL
	IP_MTU IP_MTU_DISCOVER IP_NODEFRAG IP_RECVERR IP_TRANSPARENT

	IPPROTO_IP IPPROTO_IPV6 IPPROTO_RAW IPPROTO_ICMP IPPROTO_IGMP
	IPPROTO_TCP IPPROTO_UDP IPPROTO_GRE IPPROTO_ESP IPPROTO_AH
	IPPROTO_ICMPV6 IPPROTO_SCTP

	IP_PMTUDISC_DO IP_PMTUDISC_DONT IP_PMTUDISC_PROBE IP_PMTUDISC_WANT

	IPTOS_LOWDELAY IPTOS_THROUGHPUT IPTOS_RELIABILITY IPTOS_MINCOST

	TCP_CONGESTION TCP_CONNECTIONTIMEOUT TCP_CORK TCP_DEFER_ACCEPT
	TCP_FASTOPEN TCP_INFO TCP_INIT_CWND TCP_KEEPALIVE TCP_KEEPCNT
	TCP_KEEPIDLE TCP_KEEPINTVL TCP_LINGER2 TCP_MAXRT TCP_MAXSEG
	TCP_MD5SIG TCP_NODELAY TCP_NOOPT TCP_NOPUSH TCP_QUICKACK
	TCP_SACK_ENABLE TCP_STDURG TCP_SYNCNT TCP_USER_TIMEOUT
	TCP_WINDOW_CLAMP

	IN6ADDR_ANY IN6ADDR_LOOPBACK

	IPV6_ADDRFROM IPV6_ADD_MEMBERSHIP IPV6_DROP_MEMBERSHIP IPV6_JOIN_GROUP
	IPV6_LEAVE_GROUP IPV6_MTU IPV6_MTU_DISCOVER IPV6_MULTICAST_HOPS
	IPV6_MULTICAST_IF IPV6_MULTICAST_LOOP IPV6_RECVERR IPV6_ROUTER_ALERT
	IPV6_UNICAST_HOPS IPV6_V6ONLY

	SO_LOCK_FILTER SO_RCVBUFFORCE SO_SNDBUFFORCE

	pack_ip_mreq unpack_ip_mreq pack_ip_mreq_source unpack_ip_mreq_source

	pack_ipv6_mreq unpack_ipv6_mreq

	inet_pton inet_ntop

	getaddrinfo getnameinfo

	AI_ADDRCONFIG AI_ALL AI_CANONIDN AI_CANONNAME AI_IDN
	AI_IDN_ALLOW_UNASSIGNED AI_IDN_USE_STD3_ASCII_RULES AI_NUMERICHOST
	AI_NUMERICSERV AI_PASSIVE AI_V4MAPPED

	NI_DGRAM NI_IDN NI_IDN_ALLOW_UNASSIGNED NI_IDN_USE_STD3_ASCII_RULES
	NI_NAMEREQD NI_NOFQDN NI_NUMERICHOST NI_NUMERICSERV

	NIx_NOHOST NIx_NOSERV

	EAI_ADDRFAMILY EAI_AGAIN EAI_BADFLAGS EAI_BADHINTS EAI_FAIL EAI_FAMILY
	EAI_NODATA EAI_NONAME EAI_PROTOCOL EAI_SERVICE EAI_SOCKTYPE EAI_SYSTEM
);

our %EXPORT_TAGS = (
    crlf     => [qw(CR LF CRLF $CR $LF $CRLF)],
    addrinfo => [qw(getaddrinfo getnameinfo), grep m/^(?:AI|NI|NIx|EAI)_/, @EXPORT_OK],
    all      => [@EXPORT, @EXPORT_OK],
);

BEGIN {
    sub CR   () {"\015"}
    sub LF   () {"\012"}
    sub CRLF () {"\015\012"}

    # These are not gni() constants; they're extensions for the perl API
    # The definitions in Socket.pm and Socket.xs must match
    sub NIx_NOHOST() {1 << 0}
    sub NIx_NOSERV() {1 << 1}
}

*CR   = \CR();
*LF   = \LF();
*CRLF = \CRLF();

# The four deprecated addrinfo constants
foreach my $name (qw( AI_IDN_ALLOW_UNASSIGNED AI_IDN_USE_STD3_ASCII_RULES NI_IDN_ALLOW_UNASSIGNED NI_IDN_USE_STD3_ASCII_RULES )) {
    no strict 'refs';
    *$name = sub {
	croak "The addrinfo constant $name is deprecated";
    };
}

sub sockaddr_in {
    if (@_ == 6 && !wantarray) { # perl5.001m compat; use this && die
	my($af, $port, @quad) = @_;
	warnings::warn "6-ARG sockaddr_in call is deprecated" 
	    if warnings::enabled();
	pack_sockaddr_in($port, inet_aton(join('.', @quad)));
    } elsif (wantarray) {
	croak "usage:   (port,iaddr) = sockaddr_in(sin_sv)" unless @_ == 1;
        unpack_sockaddr_in(@_);
    } else {
	croak "usage:   sin_sv = sockaddr_in(port,iaddr))" unless @_ == 2;
        pack_sockaddr_in(@_);
    }
}

sub sockaddr_in6 {
    if (wantarray) {
	croak "usage:   (port,in6addr,scope_id,flowinfo) = sockaddr_in6(sin6_sv)" unless @_ == 1;
	unpack_sockaddr_in6(@_);
    }
    else {
	croak "usage:   sin6_sv = sockaddr_in6(port,in6addr,[scope_id,[flowinfo]])" unless @_ >= 2 and @_ <= 4;
	pack_sockaddr_in6(@_);
    }
}

sub sockaddr_un {
    if (wantarray) {
	croak "usage:   (filename) = sockaddr_un(sun_sv)" unless @_ == 1;
        unpack_sockaddr_un(@_);
    } else {
	croak "usage:   sun_sv = sockaddr_un(filename)" unless @_ == 1;
        pack_sockaddr_un(@_);
    }
}

XSLoader::load(__PACKAGE__, $VERSION);

my %errstr;

if( defined &getaddrinfo ) {
    # These are not part of the API, nothing uses them, and deleting them
    # reduces the size of %Socket:: by about 12K
    delete $Socket::{fake_getaddrinfo};
    delete $Socket::{fake_getnameinfo};
} else {
    require Scalar::Util;

    *getaddrinfo = \&fake_getaddrinfo;
    *getnameinfo = \&fake_getnameinfo;

    # These numbers borrowed from GNU libc's implementation, but since
    # they're only used by our emulation, it doesn't matter if the real
    # platform's values differ
    my %constants = (
	AI_PASSIVE     => 1,
	AI_CANONNAME   => 2,
	AI_NUMERICHOST => 4,
	AI_V4MAPPED    => 8,
	AI_ALL         => 16,
	AI_ADDRCONFIG  => 32,
	# RFC 2553 doesn't define this but Linux does - lets be nice and
	# provide it since we can
	AI_NUMERICSERV => 1024,

	EAI_BADFLAGS   => -1,
	EAI_NONAME     => -2,
	EAI_NODATA     => -5,
	EAI_FAMILY     => -6,
	EAI_SERVICE    => -8,

	NI_NUMERICHOST => 1,
	NI_NUMERICSERV => 2,
	NI_NOFQDN      => 4,
	NI_NAMEREQD    => 8,
	NI_DGRAM       => 16,

	# Constants we don't support. Export them, but croak if anyone tries to
	# use them
	AI_IDN      => 64,
	AI_CANONIDN => 128,
	NI_IDN      => 32,

	# Error constants we'll never return, so it doesn't matter what value
	# these have, nor that we don't provide strings for them
	EAI_SYSTEM   => -11,
	EAI_BADHINTS => -1000,
	EAI_PROTOCOL => -1001
    );

    foreach my $name ( keys %constants ) {
	my $value = $constants{$name};

	no strict 'refs';
	defined &$name or *$name = sub () { $value };
    }

    %errstr = (
	# These strings from RFC 2553
	EAI_BADFLAGS()   => "invalid value for ai_flags",
	EAI_NONAME()     => "nodename nor servname provided, or not known",
	EAI_NODATA()     => "no address associated with nodename",
	EAI_FAMILY()     => "ai_family not supported",
	EAI_SERVICE()    => "servname not supported for ai_socktype",
    );
}

# The following functions are used if the system does not have a
# getaddrinfo(3) function in libc; and are used to emulate it for the AF_INET
# family

# Borrowed from Regexp::Common::net
my $REGEXP_IPv4_DECIMAL = qr/25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}/;
my $REGEXP_IPv4_DOTTEDQUAD = qr/$REGEXP_IPv4_DECIMAL\.$REGEXP_IPv4_DECIMAL\.$REGEXP_IPv4_DECIMAL\.$REGEXP_IPv4_DECIMAL/;

sub fake_makeerr
{
    my ( $errno ) = @_;
    my $errstr = $errno == 0 ? "" : ( $errstr{$errno} || $errno );
    return Scalar::Util::dualvar( $errno, $errstr );
}

sub fake_getaddrinfo
{
    my ( $node, $service, $hints ) = @_;

    $node = "" unless defined $node;

    $service = "" unless defined $service;

    my ( $family, $socktype, $protocol, $flags ) = @$hints{qw( family socktype protocol flags )};

    $family ||= Socket::AF_INET(); # 0 == AF_UNSPEC, which we want too
    $family == Socket::AF_INET() or return fake_makeerr( EAI_FAMILY() );

    $socktype ||= 0;

    $protocol ||= 0;

    $flags ||= 0;

    my $flag_passive     = $flags & AI_PASSIVE();     $flags &= ~AI_PASSIVE();
    my $flag_canonname   = $flags & AI_CANONNAME();   $flags &= ~AI_CANONNAME();
    my $flag_numerichost = $flags & AI_NUMERICHOST(); $flags &= ~AI_NUMERICHOST();
    my $flag_numericserv = $flags & AI_NUMERICSERV(); $flags &= ~AI_NUMERICSERV();

    # These constants don't apply to AF_INET-only lookups, so we might as well
    # just ignore them. For AI_ADDRCONFIG we just presume the host has ability
    # to talk AF_INET. If not we'd have to return no addresses at all. :)
    $flags &= ~(AI_V4MAPPED()|AI_ALL()|AI_ADDRCONFIG());

    $flags & (AI_IDN()|AI_CANONIDN()) and
	croak "Socket::getaddrinfo() does not support IDN";

    $flags == 0 or return fake_makeerr( EAI_BADFLAGS() );

    $node eq "" and $service eq "" and return fake_makeerr( EAI_NONAME() );

    my $canonname;
    my @addrs;
    if( $node ne "" ) {
	return fake_makeerr( EAI_NONAME() ) if( $flag_numerichost and $node !~ m/^$REGEXP_IPv4_DOTTEDQUAD$/ );
	( $canonname, undef, undef, undef, @addrs ) = gethostbyname( $node );
	defined $canonname or return fake_makeerr( EAI_NONAME() );

	undef $canonname unless $flag_canonname;
    }
    else {
	$addrs[0] = $flag_passive ? Socket::inet_aton( "0.0.0.0" )
				  : Socket::inet_aton( "127.0.0.1" );
    }

    my @ports; # Actually ARRAYrefs of [ socktype, protocol, port ]
    my $protname = "";
    if( $protocol ) {
	$protname = eval { getprotobynumber( $protocol ) };
    }

    if( $service ne "" and $service !~ m/^\d+$/ ) {
	return fake_makeerr( EAI_NONAME() ) if( $flag_numericserv );
	getservbyname( $service, $protname ) or return fake_makeerr( EAI_SERVICE() );
    }

    foreach my $this_socktype ( Socket::SOCK_STREAM(), Socket::SOCK_DGRAM(), Socket::SOCK_RAW() ) {
	next if $socktype and $this_socktype != $socktype;

	my $this_protname = "raw";
	$this_socktype == Socket::SOCK_STREAM() and $this_protname = "tcp";
	$this_socktype == Socket::SOCK_DGRAM()  and $this_protname = "udp";

	next if $protname and $this_protname ne $protname;

	my $port;
	if( $service ne "" ) {
	    if( $service =~ m/^\d+$/ ) {
		$port = "$service";
	    }
	    else {
		( undef, undef, $port, $this_protname ) = getservbyname( $service, $this_protname );
		next unless defined $port;
	    }
	}
	else {
	    $port = 0;
	}

	push @ports, [ $this_socktype, eval { scalar getprotobyname( $this_protname ) } || 0, $port ];
    }

    my @ret;
    foreach my $addr ( @addrs ) {
	foreach my $portspec ( @ports ) {
	    my ( $socktype, $protocol, $port ) = @$portspec;
	    push @ret, {
		family    => $family,
		socktype  => $socktype,
		protocol  => $protocol,
		addr      => Socket::pack_sockaddr_in( $port, $addr ),
		canonname => undef,
	    };
	}
    }

    # Only supply canonname for the first result
    if( defined $canonname ) {
	$ret[0]->{canonname} = $canonname;
    }

    return ( fake_makeerr( 0 ), @ret );
}

sub fake_getnameinfo
{
    my ( $addr, $flags, $xflags ) = @_;

    my ( $port, $inetaddr );
    eval { ( $port, $inetaddr ) = Socket::unpack_sockaddr_in( $addr ) }
	or return fake_makeerr( EAI_FAMILY() );

    my $family = Socket::AF_INET();

    $flags ||= 0;

    my $flag_numerichost = $flags & NI_NUMERICHOST(); $flags &= ~NI_NUMERICHOST();
    my $flag_numericserv = $flags & NI_NUMERICSERV(); $flags &= ~NI_NUMERICSERV();
    my $flag_nofqdn      = $flags & NI_NOFQDN();      $flags &= ~NI_NOFQDN();
    my $flag_namereqd    = $flags & NI_NAMEREQD();    $flags &= ~NI_NAMEREQD();
    my $flag_dgram       = $flags & NI_DGRAM()   ;    $flags &= ~NI_DGRAM();

    $flags & NI_IDN() and
	croak "Socket::getnameinfo() does not support IDN";

    $flags == 0 or return fake_makeerr( EAI_BADFLAGS() );

    $xflags ||= 0;

    my $node;
    if( $xflags & NIx_NOHOST ) {
	$node = undef;
    }
    elsif( $flag_numerichost ) {
	$node = Socket::inet_ntoa( $inetaddr );
    }
    else {
	$node = gethostbyaddr( $inetaddr, $family );
	if( !defined $node ) {
	    return fake_makeerr( EAI_NONAME() ) if $flag_namereqd;
	    $node = Socket::inet_ntoa( $inetaddr );
	}
	elsif( $flag_nofqdn ) {
	    my ( $shortname ) = split m/\./, $node;
	    my ( $fqdn ) = gethostbyname $shortname;
	    $node = $shortname if defined $fqdn and $fqdn eq $node;
	}
    }

    my $service;
    if( $xflags & NIx_NOSERV ) {
	$service = undef;
    }
    elsif( $flag_numericserv ) {
	$service = "$port";
    }
    else {
	my $protname = $flag_dgram ? "udp" : "";
	$service = getservbyport( $port, $protname );
	if( !defined $service ) {
	    $service = "$port";
	}
    }

    return ( fake_makeerr( 0 ), $node, $service );
}

1;

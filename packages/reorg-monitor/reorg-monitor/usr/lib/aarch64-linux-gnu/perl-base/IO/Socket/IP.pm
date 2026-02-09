#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2010-2020 -- leonerd@leonerd.org.uk

package IO::Socket::IP;

use v5;
use strict;
use warnings;

# $VERSION needs to be set before  use base 'IO::Socket'
#  - https://rt.cpan.org/Ticket/Display.html?id=92107
BEGIN {
   our $VERSION = '0.41';
}

use base qw( IO::Socket );

use Carp;

use Socket 1.97 qw(
   getaddrinfo getnameinfo
   sockaddr_family
   AF_INET
   AI_PASSIVE
   IPPROTO_TCP IPPROTO_UDP
   IPPROTO_IPV6 IPV6_V6ONLY
   NI_DGRAM NI_NUMERICHOST NI_NUMERICSERV NIx_NOHOST NIx_NOSERV
   SO_REUSEADDR SO_REUSEPORT SO_BROADCAST SO_ERROR
   SOCK_DGRAM SOCK_STREAM
   SOL_SOCKET
);
my $AF_INET6 = eval { Socket::AF_INET6() }; # may not be defined
my $AI_ADDRCONFIG = eval { Socket::AI_ADDRCONFIG() } || 0;
my $AI_NUMERICHOST = eval { Socket::AI_NUMERICHOST() } || 0;
use POSIX qw( dup2 );
use Errno qw( EINVAL EINPROGRESS EISCONN ENOTCONN ETIMEDOUT EWOULDBLOCK EOPNOTSUPP );

use constant HAVE_MSWIN32 => ( $^O eq "MSWin32" );

# At least one OS (Android) is known not to have getprotobyname()
use constant HAVE_GETPROTOBYNAME => defined eval { getprotobyname( "tcp" ) };

my $IPv6_re = do {
   # translation of RFC 3986 3.2.2 ABNF to re
   my $IPv4address = do {
      my $dec_octet = q<(?:[0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])>;
      qq<$dec_octet(?: \\. $dec_octet){3}>;
   };
   my $IPv6address = do {
      my $h16  = qq<[0-9A-Fa-f]{1,4}>;
      my $ls32 = qq<(?: $h16 : $h16 | $IPv4address)>;
      qq<(?:
                                            (?: $h16 : ){6} $ls32
         |                               :: (?: $h16 : ){5} $ls32
         | (?:                   $h16 )? :: (?: $h16 : ){4} $ls32
         | (?: (?: $h16 : ){0,1} $h16 )? :: (?: $h16 : ){3} $ls32
         | (?: (?: $h16 : ){0,2} $h16 )? :: (?: $h16 : ){2} $ls32
         | (?: (?: $h16 : ){0,3} $h16 )? ::     $h16 :      $ls32
         | (?: (?: $h16 : ){0,4} $h16 )? ::                 $ls32
         | (?: (?: $h16 : ){0,5} $h16 )? ::                 $h16
         | (?: (?: $h16 : ){0,6} $h16 )? ::
      )>
   };
   qr<$IPv6address>xo;
};

sub import
{
   my $pkg = shift;
   my @symbols;

   foreach ( @_ ) {
      if( $_ eq "-register" ) {
         IO::Socket::IP::_ForINET->register_domain( AF_INET );
         IO::Socket::IP::_ForINET6->register_domain( $AF_INET6 ) if defined $AF_INET6;
      }
      else {
         push @symbols, $_;
      }
   }

   @_ = ( $pkg, @symbols );
   goto &IO::Socket::import;
}

# Convenient capability test function
{
   my $can_disable_v6only;
   sub CAN_DISABLE_V6ONLY
   {
      return $can_disable_v6only if defined $can_disable_v6only;

      socket my $testsock, Socket::PF_INET6(), SOCK_STREAM, 0 or
         die "Cannot socket(PF_INET6) - $!";

      if( setsockopt $testsock, IPPROTO_IPV6, IPV6_V6ONLY, 0 ) {
         return $can_disable_v6only = 1;
      }
      elsif( $! == EINVAL || $! == EOPNOTSUPP ) {
         return $can_disable_v6only = 0;
      }
      else {
         die "Cannot setsockopt() - $!";
      }
   }
}

sub new
{
   my $class = shift;
   my %arg = (@_ == 1) ? (PeerHost => $_[0]) : @_;
   return $class->SUPER::new(%arg);
}

# IO::Socket may call this one; neaten up the arguments from IO::Socket::INET
# before calling our real _configure method
sub configure
{
   my $self = shift;
   my ( $arg ) = @_;

   $arg->{PeerHost} = delete $arg->{PeerAddr}
      if exists $arg->{PeerAddr} && !exists $arg->{PeerHost};

   $arg->{PeerService} = delete $arg->{PeerPort}
      if exists $arg->{PeerPort} && !exists $arg->{PeerService};

   $arg->{LocalHost} = delete $arg->{LocalAddr}
      if exists $arg->{LocalAddr} && !exists $arg->{LocalHost};

   $arg->{LocalService} = delete $arg->{LocalPort}
      if exists $arg->{LocalPort} && !exists $arg->{LocalService};

   for my $type (qw(Peer Local)) {
      my $host    = $type . 'Host';
      my $service = $type . 'Service';

      if( defined $arg->{$host} ) {
         ( $arg->{$host}, my $s ) = $self->split_addr( $arg->{$host} );
         # IO::Socket::INET compat - *Host parsed port always takes precedence
         $arg->{$service} = $s if defined $s;
      }
   }

   $self->_io_socket_ip__configure( $arg );
}

# Avoid simply calling it _configure, as some subclasses of IO::Socket::INET on CPAN already take that
sub _io_socket_ip__configure
{
   my $self = shift;
   my ( $arg ) = @_;

   my %hints;
   my $localflags;
   my $peerflags;
   my @localinfos;
   my @peerinfos;

   my $listenqueue = $arg->{Listen};
   if( defined $listenqueue and
       ( defined $arg->{PeerHost} || defined $arg->{PeerService} || defined $arg->{PeerAddrInfo} ) ) {
      croak "Cannot Listen with a peer address";
   }

   if( defined $arg->{GetAddrInfoFlags} ) {
      $hints{flags} = $arg->{GetAddrInfoFlags};
      $localflags  = $arg->{GetAddrInfoFlags};
      $peerflags  = $arg->{GetAddrInfoFlags};
   }
   else {
      if (defined $arg->{LocalHost} and $arg->{LocalHost} =~ /^\d+\.\d+\.\d+\.\d+$/) {
              $localflags = $AI_NUMERICHOST;
      } else {
              $localflags = $AI_ADDRCONFIG;
      }
      if (defined $arg->{PeerHost} and $arg->{PeerHost} =~ /^\d+\.\d+\.\d+\.\d+$/) {
              $peerflags = $AI_NUMERICHOST;
      } elsif (defined $arg->{PeerHost} and $arg->{PeerHost} ne 'localhost') {
              $peerflags = $AI_ADDRCONFIG;
      }
   }

   if( defined( my $family = $arg->{Family} ) ) {
      $hints{family} = $family;
   }

   if( defined( my $type = $arg->{Type} ) ) {
      $hints{socktype} = $type;
   }

   if( defined( my $proto = $arg->{Proto} ) ) {
      unless( $proto =~ m/^\d+$/ ) {
         my $protonum = HAVE_GETPROTOBYNAME
            ? getprotobyname( $proto )
            : eval { Socket->${\"IPPROTO_\U$proto"}() };
         defined $protonum or croak "Unrecognised protocol $proto";
         $proto = $protonum;
      }

      $hints{protocol} = $proto;
   }

   # To maintain compatibility with IO::Socket::INET, imply a default of
   # SOCK_STREAM + IPPROTO_TCP if neither hint is given
   if( !defined $hints{socktype} and !defined $hints{protocol} ) {
      $hints{socktype} = SOCK_STREAM;
      $hints{protocol} = IPPROTO_TCP;
   }

   # Some OSes (NetBSD) don't seem to like just a protocol hint without a
   # socktype hint as well. We'll set a couple of common ones
   if( !defined $hints{socktype} and defined $hints{protocol} ) {
      $hints{socktype} = SOCK_STREAM if $hints{protocol} == IPPROTO_TCP;
      $hints{socktype} = SOCK_DGRAM  if $hints{protocol} == IPPROTO_UDP;
   }

   if( my $info = $arg->{LocalAddrInfo} ) {
      ref $info eq "ARRAY" or croak "Expected 'LocalAddrInfo' to be an ARRAY ref";
      @localinfos = @$info;
   }
   elsif( defined $arg->{LocalHost} or
          defined $arg->{LocalService} or
          HAVE_MSWIN32 and $arg->{Listen} ) {
      # Either may be undef
      my $host = $arg->{LocalHost};
      my $service = $arg->{LocalService};

      unless ( defined $host or defined $service ) {
         $service = 0;
      }

      local $1; # Placate a taint-related bug; [perl #67962]
      defined $service and $service =~ s/\((\d+)\)$// and
         my $fallback_port = $1;

      my %localhints = %hints;
      $localhints{flags} = $localflags;
      $localhints{flags} |= AI_PASSIVE;
      ( my $err, @localinfos ) = getaddrinfo( $host, $service, \%localhints );

      if( $err and defined $fallback_port ) {
         ( $err, @localinfos ) = getaddrinfo( $host, $fallback_port, \%localhints );
      }

      if( $err ) {
         $@ = "$err";
         $! = EINVAL;
         return;
      }
   }

   if( my $info = $arg->{PeerAddrInfo} ) {
      ref $info eq "ARRAY" or croak "Expected 'PeerAddrInfo' to be an ARRAY ref";
      @peerinfos = @$info;
   }
   elsif( defined $arg->{PeerHost} or defined $arg->{PeerService} ) {
      defined( my $host = $arg->{PeerHost} ) or
         croak "Expected 'PeerHost'";
      defined( my $service = $arg->{PeerService} ) or
         croak "Expected 'PeerService'";

      local $1; # Placate a taint-related bug; [perl #67962]
      defined $service and $service =~ s/\((\d+)\)$// and
         my $fallback_port = $1;

      my %peerhints = %hints;
      $peerhints{flags} = $peerflags;
      ( my $err, @peerinfos ) = getaddrinfo( $host, $service, \%peerhints );

      if( $err and defined $fallback_port ) {
         ( $err, @peerinfos ) = getaddrinfo( $host, $fallback_port, \%peerhints );
      }

      if( $err ) {
         $@ = "$err";
         $! = EINVAL;
         return;
      }
   }

   my $INT_1 = pack "i", 1;

   my @sockopts_enabled;
   push @sockopts_enabled, [ SOL_SOCKET, SO_REUSEADDR, $INT_1 ] if $arg->{ReuseAddr};
   push @sockopts_enabled, [ SOL_SOCKET, SO_REUSEPORT, $INT_1 ] if $arg->{ReusePort};
   push @sockopts_enabled, [ SOL_SOCKET, SO_BROADCAST, $INT_1 ] if $arg->{Broadcast};

   if( my $sockopts = $arg->{Sockopts} ) {
      ref $sockopts eq "ARRAY" or croak "Expected 'Sockopts' to be an ARRAY ref";
      foreach ( @$sockopts ) {
         ref $_ eq "ARRAY" or croak "Bad Sockopts item - expected ARRAYref";
         @$_ >= 2 and @$_ <= 3 or
            croak "Bad Sockopts item - expected 2 or 3 elements";

         my ( $level, $optname, $value ) = @$_;
         # TODO: consider more sanity checking on argument values

         defined $value or $value = $INT_1;
         push @sockopts_enabled, [ $level, $optname, $value ];
      }
   }

   my $blocking = $arg->{Blocking};
   defined $blocking or $blocking = 1;

   my $v6only = $arg->{V6Only};

   # IO::Socket::INET defines this key. IO::Socket::IP always implements the
   # behaviour it requests, so we can ignore it, unless the caller is for some
   # reason asking to disable it.
   if( defined $arg->{MultiHomed} and !$arg->{MultiHomed} ) {
      croak "Cannot disable the MultiHomed parameter";
   }

   my @infos;
   foreach my $local ( @localinfos ? @localinfos : {} ) {
      foreach my $peer ( @peerinfos ? @peerinfos : {} ) {
         next if defined $local->{family}   and defined $peer->{family}   and
            $local->{family} != $peer->{family};
         next if defined $local->{socktype} and defined $peer->{socktype} and
            $local->{socktype} != $peer->{socktype};
         next if defined $local->{protocol} and defined $peer->{protocol} and
            $local->{protocol} != $peer->{protocol};

         my $family   = $local->{family}   || $peer->{family}   or next;
         my $socktype = $local->{socktype} || $peer->{socktype} or next;
         my $protocol = $local->{protocol} || $peer->{protocol} || 0;

         push @infos, {
            family    => $family,
            socktype  => $socktype,
            protocol  => $protocol,
            localaddr => $local->{addr},
            peeraddr  => $peer->{addr},
         };
      }
   }

   if( !@infos ) {
      # If there was a Family hint then create a plain unbound, unconnected socket
      if( defined $hints{family} ) {
         @infos = ( {
            family   => $hints{family},
            socktype => $hints{socktype},
            protocol => $hints{protocol},
         } );
      }
      # If there wasn't, use getaddrinfo()'s AI_ADDRCONFIG side-effect to guess a
      # suitable family first.
      else {
         $hints{flags} |= $AI_ADDRCONFIG;
         ( my $err, @infos ) = getaddrinfo( "", "0", \%hints );
         if( $err ) {
            $@ = "$err";
            $! = EINVAL;
            return;
         }

         # We'll take all the @infos anyway, because some OSes (HPUX) are known to
         # ignore the AI_ADDRCONFIG hint and return AF_INET6 even if they don't
         # support them
      }
   }

   # In the nonblocking case, caller will be calling ->setup multiple times.
   # Store configuration in the object for the ->setup method
   # Yes, these are messy. Sorry, I can't help that...

   ${*$self}{io_socket_ip_infos} = \@infos;

   ${*$self}{io_socket_ip_idx} = -1;

   ${*$self}{io_socket_ip_sockopts} = \@sockopts_enabled;
   ${*$self}{io_socket_ip_v6only} = $v6only;
   ${*$self}{io_socket_ip_listenqueue} = $listenqueue;
   ${*$self}{io_socket_ip_blocking} = $blocking;

   ${*$self}{io_socket_ip_errors} = [ undef, undef, undef ];

   # ->setup is allowed to return false in nonblocking mode
   $self->setup or !$blocking or return undef;

   return $self;
}

sub setup
{
   my $self = shift;

   while(1) {
      ${*$self}{io_socket_ip_idx}++;
      last if ${*$self}{io_socket_ip_idx} >= @{ ${*$self}{io_socket_ip_infos} };

      my $info = ${*$self}{io_socket_ip_infos}->[${*$self}{io_socket_ip_idx}];

      $self->socket( @{$info}{qw( family socktype protocol )} ) or
         ( ${*$self}{io_socket_ip_errors}[2] = $!, next );

      $self->blocking( 0 ) unless ${*$self}{io_socket_ip_blocking};

      foreach my $sockopt ( @{ ${*$self}{io_socket_ip_sockopts} } ) {
         my ( $level, $optname, $value ) = @$sockopt;
         $self->setsockopt( $level, $optname, $value ) or ( $@ = "$!", return undef );
      }

      if( defined ${*$self}{io_socket_ip_v6only} and defined $AF_INET6 and $info->{family} == $AF_INET6 ) {
         my $v6only = ${*$self}{io_socket_ip_v6only};
         $self->setsockopt( IPPROTO_IPV6, IPV6_V6ONLY, pack "i", $v6only ) or ( $@ = "$!", return undef );
      }

      if( defined( my $addr = $info->{localaddr} ) ) {
         $self->bind( $addr ) or
            ( ${*$self}{io_socket_ip_errors}[1] = $!, next );
      }

      if( defined( my $listenqueue = ${*$self}{io_socket_ip_listenqueue} ) ) {
         $self->listen( $listenqueue ) or ( $@ = "$!", return undef );
      }

      if( defined( my $addr = $info->{peeraddr} ) ) {
         if( $self->connect( $addr ) ) {
            $! = 0;
            return 1;
         }

         if( $! == EINPROGRESS or $! == EWOULDBLOCK ) {
            ${*$self}{io_socket_ip_connect_in_progress} = 1;
            return 0;
         }

         # If connect failed but we have no system error there must be an error
         # at the application layer, like a bad certificate with
         # IO::Socket::SSL.
         # In this case don't continue IP based multi-homing because the problem
         # cannot be solved at the IP layer.
         return 0 if ! $!;

         ${*$self}{io_socket_ip_errors}[0] = $!;
         next;
      }

      return 1;
   }

   # Pick the most appropriate error, stringified
   $! = ( grep defined, @{ ${*$self}{io_socket_ip_errors}} )[0];
   $@ = "$!";
   return undef;
}

sub connect :method
{
   my $self = shift;

   # It seems that IO::Socket hides EINPROGRESS errors, making them look like
   # a success. This is annoying here.
   # Instead of putting up with its frankly-irritating intentional breakage of
   # useful APIs I'm just going to end-run around it and call core's connect()
   # directly

   if( @_ ) {
      my ( $addr ) = @_;

      # Annoyingly IO::Socket's connect() is where the timeout logic is
      # implemented, so we'll have to reinvent it here
      my $timeout = ${*$self}{'io_socket_timeout'};

      return connect( $self, $addr ) unless defined $timeout;

      my $was_blocking = $self->blocking( 0 );

      my $err = defined connect( $self, $addr ) ? 0 : $!+0;

      if( !$err ) {
         # All happy
         $self->blocking( $was_blocking );
         return 1;
      }
      elsif( not( $err == EINPROGRESS or $err == EWOULDBLOCK ) ) {
         # Failed for some other reason
         $self->blocking( $was_blocking );
         return undef;
      }
      elsif( !$was_blocking ) {
         # We shouldn't block anyway
         return undef;
      }

      my $vec = ''; vec( $vec, $self->fileno, 1 ) = 1;
      if( !select( undef, $vec, $vec, $timeout ) ) {
         $self->blocking( $was_blocking );
         $! = ETIMEDOUT;
         return undef;
      }

      # Hoist the error by connect()ing a second time
      $err = $self->getsockopt( SOL_SOCKET, SO_ERROR );
      $err = 0 if $err == EISCONN; # Some OSes give EISCONN

      $self->blocking( $was_blocking );

      $! = $err, return undef if $err;
      return 1;
   }

   return 1 if !${*$self}{io_socket_ip_connect_in_progress};

   # See if a connect attempt has just failed with an error
   if( my $errno = $self->getsockopt( SOL_SOCKET, SO_ERROR ) ) {
      delete ${*$self}{io_socket_ip_connect_in_progress};
      ${*$self}{io_socket_ip_errors}[0] = $! = $errno;
      return $self->setup;
   }

   # No error, so either connect is still in progress, or has completed
   # successfully. We can tell by trying to connect() again; either it will
   # succeed or we'll get EISCONN (connected successfully), or EALREADY
   # (still in progress). This even works on MSWin32.
   my $addr = ${*$self}{io_socket_ip_infos}[${*$self}{io_socket_ip_idx}]{peeraddr};

   if( connect( $self, $addr ) or $! == EISCONN ) {
      delete ${*$self}{io_socket_ip_connect_in_progress};
      $! = 0;
      return 1;
   }
   else {
      $! = EINPROGRESS;
      return 0;
   }
}

sub connected
{
   my $self = shift;
   return defined $self->fileno &&
          !${*$self}{io_socket_ip_connect_in_progress} &&
          defined getpeername( $self ); # ->peername caches, we need to detect disconnection
}

sub _get_host_service
{
   my $self = shift;
   my ( $addr, $flags, $xflags ) = @_;

   defined $addr or
      $! = ENOTCONN, return;

   $flags |= NI_DGRAM if $self->socktype == SOCK_DGRAM;

   my ( $err, $host, $service ) = getnameinfo( $addr, $flags, $xflags || 0 );
   croak "getnameinfo - $err" if $err;

   return ( $host, $service );
}

sub _unpack_sockaddr
{
   my ( $addr ) = @_;
   my $family = sockaddr_family $addr;

   if( $family == AF_INET ) {
      return ( Socket::unpack_sockaddr_in( $addr ) )[1];
   }
   elsif( defined $AF_INET6 and $family == $AF_INET6 ) {
      return ( Socket::unpack_sockaddr_in6( $addr ) )[1];
   }
   else {
      croak "Unrecognised address family $family";
   }
}

sub sockhost_service
{
   my $self = shift;
   my ( $numeric ) = @_;

   $self->_get_host_service( $self->sockname, $numeric ? NI_NUMERICHOST|NI_NUMERICSERV : 0 );
}

sub sockhost { my $self = shift; scalar +( $self->_get_host_service( $self->sockname, NI_NUMERICHOST, NIx_NOSERV ) )[0] }
sub sockport { my $self = shift; scalar +( $self->_get_host_service( $self->sockname, NI_NUMERICSERV, NIx_NOHOST ) )[1] }

sub sockhostname { my $self = shift; scalar +( $self->_get_host_service( $self->sockname, 0, NIx_NOSERV ) )[0] }
sub sockservice  { my $self = shift; scalar +( $self->_get_host_service( $self->sockname, 0, NIx_NOHOST ) )[1] }

sub sockaddr { my $self = shift; _unpack_sockaddr $self->sockname }

sub peerhost_service
{
   my $self = shift;
   my ( $numeric ) = @_;

   $self->_get_host_service( $self->peername, $numeric ? NI_NUMERICHOST|NI_NUMERICSERV : 0 );
}

sub peerhost { my $self = shift; scalar +( $self->_get_host_service( $self->peername, NI_NUMERICHOST, NIx_NOSERV ) )[0] }
sub peerport { my $self = shift; scalar +( $self->_get_host_service( $self->peername, NI_NUMERICSERV, NIx_NOHOST ) )[1] }

sub peerhostname { my $self = shift; scalar +( $self->_get_host_service( $self->peername, 0, NIx_NOSERV ) )[0] }
sub peerservice  { my $self = shift; scalar +( $self->_get_host_service( $self->peername, 0, NIx_NOHOST ) )[1] }

sub peeraddr { my $self = shift; _unpack_sockaddr $self->peername }

# This unbelievably dodgy hack works around the bug that IO::Socket doesn't do
# it
#    https://rt.cpan.org/Ticket/Display.html?id=61577
sub accept
{
   my $self = shift;
   my ( $new, $peer ) = $self->SUPER::accept( @_ ) or return;

   ${*$new}{$_} = ${*$self}{$_} for qw( io_socket_domain io_socket_type io_socket_proto );

   return wantarray ? ( $new, $peer )
                    : $new;
}

# This second unbelievably dodgy hack guarantees that $self->fileno doesn't
# change, which is useful during nonblocking connect
sub socket :method
{
   my $self = shift;
   return $self->SUPER::socket(@_) if not defined $self->fileno;

   # I hate core prototypes sometimes...
   socket( my $tmph, $_[0], $_[1], $_[2] ) or return undef;

   dup2( $tmph->fileno, $self->fileno ) or die "Unable to dup2 $tmph onto $self - $!";
}

# Versions of IO::Socket before 1.35 may leave socktype undef if from, say, an
#   ->fdopen call. In this case we'll apply a fix
BEGIN {
   if( eval($IO::Socket::VERSION) < 1.35 ) {
      *socktype = sub {
         my $self = shift;
         my $type = $self->SUPER::socktype;
         if( !defined $type ) {
            $type = $self->sockopt( Socket::SO_TYPE() );
         }
         return $type;
      };
   }
}

sub as_inet
{
   my $self = shift;
   croak "Cannot downgrade a non-PF_INET socket to IO::Socket::INET" unless $self->sockdomain == AF_INET;
   return IO::Socket::INET->new_from_fd( $self->fileno, "r+" );
}

sub split_addr
{
   shift;
   my ( $addr ) = @_;

   local ( $1, $2 ); # Placate a taint-related bug; [perl #67962]
   if( $addr =~ m/\A\[($IPv6_re)\](?::([^\s:]*))?\z/ or
       $addr =~ m/\A([^\s:]*):([^\s:]*)\z/ ) {
      return ( $1, $2 ) if defined $2 and length $2;
      return ( $1, undef );
   }

   return ( $addr, undef );
}

sub join_addr
{
   shift;
   my ( $host, $port ) = @_;

   $host = "[$host]" if $host =~ m/:/;

   return join ":", $host, $port if defined $port;
   return $host;
}

# Since IO::Socket->new( Domain => ... ) will delete the Domain parameter
# before calling ->configure, we need to keep track of which it was

package # hide from indexer
   IO::Socket::IP::_ForINET;
use base qw( IO::Socket::IP );

sub configure
{
   # This is evil
   my $self = shift;
   my ( $arg ) = @_;

   bless $self, "IO::Socket::IP";
   $self->configure( { %$arg, Family => Socket::AF_INET() } );
}

package # hide from indexer
   IO::Socket::IP::_ForINET6;
use base qw( IO::Socket::IP );

sub configure
{
   # This is evil
   my $self = shift;
   my ( $arg ) = @_;

   bless $self, "IO::Socket::IP";
   $self->configure( { %$arg, Family => Socket::AF_INET6() } );
}

0x55AA;

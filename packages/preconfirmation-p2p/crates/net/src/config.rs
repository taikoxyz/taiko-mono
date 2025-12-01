use std::{
    net::{IpAddr, Ipv4Addr, SocketAddr},
    time::Duration,
};

/// Network configuration (libp2p + discv5) with conservative defaults used by the preconfirmation
/// P2P stack.
///
/// This struct consolidates all network-related settings, from listen addresses
/// and bootnodes to various protocol tunings and reputation parameters.
#[derive(Debug, Clone)]
pub struct NetworkConfig {
    /// Chain ID used to derive gossip topics and protocol IDs.
    pub chain_id: u64,
    /// Libp2p listen address (TCP/QUIC as enabled).
    pub listen_addr: SocketAddr,
    /// discv5 listen address (UDP).
    pub discv5_listen: SocketAddr,
    /// Bootnodes as ENR or multiaddr strings. These are used for initial peer discovery.
    pub bootnodes: Vec<String>,
    /// Enable QUIC transport. If true, the network will attempt to use QUIC.
    pub enable_quic: bool,
    /// Enable TCP transport. If true, the network will attempt to use TCP.
    pub enable_tcp: bool,
    /// Gossipsub heartbeat interval. Determines how often gossipsub peers exchange keep-alive
    /// messages.
    pub gossipsub_heartbeat: Duration,
    /// Request/response request timeout. How long to wait for a response to a request.
    pub request_timeout: Duration,
    /// Toggle discv5 discovery. If true, discv5 will be used for peer discovery.
    pub enable_discovery: bool,
    /// Greylist threshold applied by the reputation engine. Peers with scores below this will be
    /// greylisted.
    pub reputation_greylist: f64,
    /// Ban threshold applied by the reputation engine. Peers with scores below this will be
    /// banned.
    pub reputation_ban: f64,
    /// Exponential-decay halflife for scores. Determines how quickly peer scores decay over time.
    pub reputation_halflife: Duration,
    /// Fixed (tumbling) window size for req/resp rate limiting.
    pub request_window: Duration,
    /// Maximum number of requests allowed per peer within the `request_window`.
    pub max_requests_per_window: u32,
    /// Maximum concurrent inbound+outbound req/resp streams (libp2p request-response config).
    pub max_reqresp_concurrent_streams: usize,
    /// Maximum pending inbound connections (None = unlimited).
    pub max_pending_incoming: Option<u32>,
    /// Maximum pending outbound connections (None = unlimited).
    pub max_pending_outgoing: Option<u32>,
    /// Maximum established inbound connections (None = unlimited).
    pub max_established_incoming: Option<u32>,
    /// Maximum established outbound connections (None = unlimited).
    pub max_established_outgoing: Option<u32>,
    /// Maximum total established connections (None = unlimited).
    pub max_established_total: Option<u32>,
    /// Maximum established connections per peer (None = unlimited).
    pub max_established_per_peer: Option<u32>,
    /// Kona gater: blocked CIDR subnets (strings parsed as IpNet) applied before dialing.
    /// Connections to peers within these subnets will be rejected.
    pub gater_blocked_subnets: Vec<String>,
    /// Kona gater: maximum redials per peer within a dial period.
    /// `None` implies Kona's default unlimited redials.
    pub gater_peer_redialing: Option<u64>,
    /// Kona gater: dial period window for redial limiting.
    pub gater_dial_period: Duration,
}

impl Default for NetworkConfig {
    /// Provides a default, conservative configuration for the network.
    ///
    /// These defaults can be overridden by user-provided configurations.
    fn default() -> Self {
        Self {
            chain_id: 167_000, // placeholder, override via CLI/config
            listen_addr: SocketAddr::new(IpAddr::V4(Ipv4Addr::UNSPECIFIED), 9000),
            discv5_listen: SocketAddr::new(IpAddr::V4(Ipv4Addr::UNSPECIFIED), 9001),
            bootnodes: Vec::new(),
            enable_quic: true,
            enable_tcp: true,
            gossipsub_heartbeat: *kona_gossip::GOSSIP_HEARTBEAT,
            request_timeout: Duration::from_secs(10),
            enable_discovery: true,
            reputation_greylist: -5.0,
            reputation_ban: -10.0,
            reputation_halflife: Duration::from_secs(600),
            request_window: Duration::from_secs(10),
            max_requests_per_window: 8,
            max_reqresp_concurrent_streams: 100,
            max_pending_incoming: Some(64),
            max_pending_outgoing: Some(64),
            max_established_incoming: Some(128),
            max_established_outgoing: Some(128),
            max_established_total: Some(256),
            max_established_per_peer: Some(4),
            gater_blocked_subnets: Vec::new(),
            gater_peer_redialing: None,
            gater_dial_period: Duration::from_secs(60 * 60),
        }
    }
}

impl NetworkConfig {
    /// Convenience constructor that sets `chain_id` and keeps all other defaults.
    pub fn for_chain(chain_id: u64) -> Self {
        Self { chain_id, ..Default::default() }
    }

    /// Ensure rate-limit parameters are sane before constructing a limiter.
    pub(crate) fn validate_request_rate_limits(&self) {
        debug_assert!(self.request_window > Duration::ZERO, "request_window must be > 0");
        debug_assert!(self.max_requests_per_window > 0, "max_requests_per_window must be > 0");
    }
}

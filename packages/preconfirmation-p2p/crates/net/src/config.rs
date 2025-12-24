use std::{
    net::{IpAddr, Ipv4Addr, SocketAddr},
    time::Duration,
};

use crate::reputation::ReputationConfig;

/// Minimal configuration for the simplified API.
#[derive(Debug, Clone)]
pub struct P2pConfig {
    pub chain_id: u64,
    pub listen_addr: SocketAddr,
    pub enable_discovery: bool,
    pub discovery_listen: SocketAddr,
    pub bootnodes: Vec<String>,
    pub request_timeout: Duration,
    pub max_reqresp_concurrent_streams: usize,
    pub rate_limit: RateLimitConfig,
    pub reputation: ReputationConfig,
}

/// Network configuration (libp2p + discv5) with conservative defaults used by the preconfirmation
/// P2P stack.
///
/// This struct consolidates all network-related settings, from listen addresses
/// and bootnodes to various protocol tunings and reputation parameters.
#[derive(Debug, Clone)]
pub(crate) struct NetworkConfig {
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
    /// Dial concurrency factor for libp2p swarm.
    pub dial_concurrency_factor: u8,
    /// Kona gater: blocked CIDR subnets (strings parsed as IpNet) applied before dialing.
    /// Connections to peers within these subnets will be rejected.
    pub gater_blocked_subnets: Vec<String>,
    /// Kona gater: maximum redials per peer within a dial period.
    /// `None` implies Kona's default unlimited redials.
    pub gater_peer_redialing: Option<u64>,
    /// Kona gater: dial period window for redial limiting.
    pub gater_dial_period: Duration,
}

impl Default for P2pConfig {
    fn default() -> Self {
        let base = NetworkConfig::default();
        Self {
            chain_id: base.chain_id,
            listen_addr: base.listen_addr,
            enable_discovery: base.enable_discovery,
            discovery_listen: base.discv5_listen,
            bootnodes: base.bootnodes,
            request_timeout: base.request_timeout,
            max_reqresp_concurrent_streams: base.max_reqresp_concurrent_streams,
            rate_limit: RateLimitConfig {
                window: base.request_window,
                max_requests: base.max_requests_per_window,
            },
            reputation: ReputationConfig {
                greylist_threshold: base.reputation_greylist,
                ban_threshold: base.reputation_ban,
                halflife: base.reputation_halflife,
            },
        }
    }
}

impl From<P2pConfig> for NetworkConfig {
    fn from(cfg: P2pConfig) -> Self {
        Self {
            chain_id: cfg.chain_id,
            listen_addr: cfg.listen_addr,
            discv5_listen: cfg.discovery_listen,
            enable_discovery: cfg.enable_discovery,
            bootnodes: cfg.bootnodes,
            request_timeout: cfg.request_timeout,
            max_reqresp_concurrent_streams: cfg.max_reqresp_concurrent_streams,
            request_window: cfg.rate_limit.window,
            max_requests_per_window: cfg.rate_limit.max_requests,
            reputation_greylist: cfg.reputation.greylist_threshold,
            reputation_ban: cfg.reputation.ban_threshold,
            reputation_halflife: cfg.reputation.halflife,
            ..Default::default()
        }
    }
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
            max_pending_incoming: Some(40),
            max_pending_outgoing: Some(40),
            max_established_incoming: Some(110),
            max_established_outgoing: Some(110),
            max_established_total: Some(220),
            max_established_per_peer: Some(4),
            dial_concurrency_factor: 16,
            gater_blocked_subnets: Vec::new(),
            gater_peer_redialing: None,
            gater_dial_period: Duration::from_secs(60 * 60),
        }
    }
}

/// Logical grouping for the resolved connection caps and dial factor returned by
/// `NetworkConfig::resolve_connection_caps`.
pub(crate) type ConnectionCaps = (
    Option<u32>, // pending inbound cap
    Option<u32>, // pending outbound cap
    Option<u32>, // established inbound cap
    Option<u32>, // established outbound cap
    Option<u32>, // total established cap
    Option<u32>, // established per peer cap
    u8,          // dial concurrency factor
);

impl NetworkConfig {
    /// Resolve connection caps and dial factor.
    pub(crate) fn resolve_connection_caps(&self) -> ConnectionCaps {
        (
            self.max_pending_incoming,
            self.max_pending_outgoing,
            self.max_established_incoming,
            self.max_established_outgoing,
            self.max_established_total,
            self.max_established_per_peer,
            self.dial_concurrency_factor,
        )
    }

    /// Ensure rate-limit parameters are sane before constructing a limiter.
    pub(crate) fn validate_request_rate_limits(&self) {
        debug_assert!(self.request_window > Duration::ZERO, "request_window must be > 0");
        debug_assert!(self.max_requests_per_window > 0, "max_requests_per_window must be > 0");
    }
}

/// Rate limit configuration for req/resp protocols.
#[derive(Debug, Clone, Copy)]
pub struct RateLimitConfig {
    pub window: Duration,
    pub max_requests: u32,
}

impl Default for RateLimitConfig {
    fn default() -> Self {
        Self { window: Duration::from_secs(10), max_requests: 8 }
    }
}

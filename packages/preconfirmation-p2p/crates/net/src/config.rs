use std::{
    net::{IpAddr, Ipv4Addr, SocketAddr},
    time::Duration,
};

/// Network configuration (libp2p + discv5) with conservative defaults used by the preconfirmation
/// P2P stack.
#[derive(Debug, Clone)]
pub struct NetworkConfig {
    /// Chain ID used to derive gossip topics and protocol IDs.
    pub chain_id: u64,
    /// Libp2p listen address (TCP/QUIC as enabled).
    pub listen_addr: SocketAddr,
    /// discv5 listen address (UDP).
    pub discv5_listen: SocketAddr,
    /// Bootnodes as ENR or multiaddr strings.
    pub bootnodes: Vec<String>, // ENR or multiaddr strings
    /// Enable QUIC transport.
    pub enable_quic: bool,
    /// Enable TCP transport.
    pub enable_tcp: bool,
    /// Gossipsub heartbeat interval.
    pub gossipsub_heartbeat: Duration,
    /// Req/resp request timeout.
    pub request_timeout: Duration,
    /// Toggle discv5 discovery.
    pub enable_discovery: bool,
    // Reputation/DoS tuning
    /// Greylist threshold applied by the reputation engine.
    pub reputation_greylist: f64,
    /// Ban threshold applied by the reputation engine.
    pub reputation_ban: f64,
    /// Exponential-decay halflife for scores.
    pub reputation_halflife: Duration,
    /// Sliding window size for req/resp rate limiting.
    pub request_window: Duration,
    /// Max requests per peer per window.
    pub max_requests_per_window: u32,
}

impl Default for NetworkConfig {
    fn default() -> Self {
        Self {
            chain_id: 167_000, // placeholder, override via CLI/config
            listen_addr: SocketAddr::new(IpAddr::V4(Ipv4Addr::UNSPECIFIED), 9000),
            discv5_listen: SocketAddr::new(IpAddr::V4(Ipv4Addr::UNSPECIFIED), 9001),
            bootnodes: Vec::new(),
            enable_quic: true,
            enable_tcp: true,
            gossipsub_heartbeat: Duration::from_millis(700),
            request_timeout: Duration::from_secs(10),
            enable_discovery: true,
            reputation_greylist: -5.0,
            reputation_ban: -10.0,
            reputation_halflife: Duration::from_secs(600),
            request_window: Duration::from_secs(10),
            max_requests_per_window: 8,
        }
    }
}

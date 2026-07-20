//! Preconfirmation-specific CLI flags.

use std::net::SocketAddr;

use clap::Parser;

/// Preconfirmation-specific CLI arguments.
#[derive(Parser, Clone, Debug, PartialEq, Eq)]
pub struct PreconfirmationArgs {
    /// TCP listen address for P2P connections.
    #[clap(long = "p2p.listen", env = "P2P_LISTEN", default_value = "0.0.0.0:9000")]
    pub p2p_listen: SocketAddr,

    /// UDP listen address for discv5 peer discovery.
    #[clap(
        long = "p2p.discovery.addr",
        env = "P2P_DISCOVERY_ADDR",
        default_value = "0.0.0.0:9001"
    )]
    pub p2p_discovery_addr: SocketAddr,

    /// Comma-separated list of bootnodes (ENR, enode URL, or multiaddr), dialed directly.
    #[clap(long = "p2p.bootnodes", env = "P2P_BOOTNODES", value_delimiter = ',')]
    pub p2p_bootnodes: Vec<String>,

    /// Comma-separated list of static peers to dial on startup (multiaddr).
    #[clap(long = "p2p.static-peers", env = "P2P_STATIC_PEERS", value_delimiter = ',')]
    pub p2p_static_peers: Vec<String>,

    /// Disable discv5 peer discovery; only configured bootnodes and static peers are
    /// dialed.
    #[clap(long = "p2p.disable-discovery", env = "P2P_DISABLE_DISCOVERY", default_value = "false")]
    pub p2p_disable_discovery: bool,

    /// Externally dialable TCP address advertised in the local P2P node record. Also
    /// required for discv5 discovery: it is the address published in the local ENR.
    #[clap(long = "p2p.advertise.addr", env = "P2P_ADVERTISE_ADDR")]
    pub p2p_advertise_addr: Option<SocketAddr>,

    /// Low-tide peer count: discovered peers are dialed while the connection count is
    /// below this target.
    #[clap(long = "p2p.peers.lo", env = "P2P_PEERS_LO", default_value = "20")]
    pub p2p_peers_lo: usize,

    /// High-tide peer count: established connections are capped at this bound.
    #[clap(long = "p2p.peers.hi", env = "P2P_PEERS_HI", default_value = "30")]
    pub p2p_peers_hi: usize,
}

#[cfg(test)]
mod tests {
    use std::net::SocketAddr;

    use clap::Parser;

    use super::PreconfirmationArgs;

    #[test]
    fn parses_p2p_advertise_addr() {
        let args = PreconfirmationArgs::try_parse_from([
            "test",
            "--p2p.advertise.addr",
            "127.0.0.1:30303",
        ])
        .expect("p2p advertise addr should parse");

        assert_eq!(
            args.p2p_advertise_addr,
            Some("127.0.0.1:30303".parse::<SocketAddr>().expect("socket addr"))
        );
    }
}

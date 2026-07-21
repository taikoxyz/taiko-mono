//! Preconfirmation-specific CLI flags.

use std::net::SocketAddr;

use clap::Parser;

/// Preconfirmation-specific CLI arguments.
#[derive(Parser, Clone, Debug, PartialEq, Eq)]
pub struct PreconfirmationArgs {
    /// TCP listen address for P2P connections.
    #[clap(long = "p2p.listen", env = "P2P_LISTEN", default_value = "0.0.0.0:9000")]
    pub p2p_listen: SocketAddr,

    /// Deprecated and ignored: discv5 discovery has been removed. Bootnodes are
    /// dialed directly instead. Kept so existing deployment manifests keep parsing.
    #[clap(
        long = "p2p.discovery.addr",
        env = "P2P_DISCOVERY_ADDR",
        default_value = "0.0.0.0:9001",
        hide = true
    )]
    pub p2p_discovery_addr: SocketAddr,

    /// Comma-separated list of bootnodes (ENR, enode URL, or multiaddr), dialed directly.
    #[clap(long = "p2p.bootnodes", env = "P2P_BOOTNODES", value_delimiter = ',')]
    pub p2p_bootnodes: Vec<String>,

    /// Comma-separated list of static peers to dial on startup (multiaddr).
    #[clap(long = "p2p.static-peers", env = "P2P_STATIC_PEERS", value_delimiter = ',')]
    pub p2p_static_peers: Vec<String>,

    /// Deprecated and ignored: discv5 discovery has been removed. Kept so existing
    /// deployment manifests keep parsing.
    #[clap(
        long = "p2p.disable-discovery",
        env = "P2P_DISABLE_DISCOVERY",
        default_value = "false",
        hide = true
    )]
    pub p2p_disable_discovery: bool,

    /// Externally dialable TCP address advertised in the local P2P node record.
    #[clap(long = "p2p.advertise.addr", env = "P2P_ADVERTISE_ADDR")]
    pub p2p_advertise_addr: Option<SocketAddr>,
}

#[cfg(test)]
mod tests {
    use std::net::SocketAddr;

    use clap::Parser;

    use super::PreconfirmationArgs;
    use crate::flags::test_env::{ENV_LOCK, EnvGuard};

    fn clear_p2p_env() -> [EnvGuard; 6] {
        [
            EnvGuard::unset("P2P_LISTEN"),
            EnvGuard::unset("P2P_DISCOVERY_ADDR"),
            EnvGuard::unset("P2P_BOOTNODES"),
            EnvGuard::unset("P2P_STATIC_PEERS"),
            EnvGuard::unset("P2P_DISABLE_DISCOVERY"),
            EnvGuard::unset("P2P_ADVERTISE_ADDR"),
        ]
    }

    #[test]
    fn parses_p2p_advertise_addr() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _clear = clear_p2p_env();
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

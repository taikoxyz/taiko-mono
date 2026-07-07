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

    /// Smallest valid arg set: this struct has no `required = true` flags, so the
    /// program name alone leaves every `default_value` to take effect.
    fn parse_minimal() -> PreconfirmationArgs {
        PreconfirmationArgs::try_parse_from(["test"]).expect("minimal preconf args should parse")
    }

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

    /// P2P defaults, including the deprecated no-op discovery flags kept for
    /// compat (removed in a later release — the no-op must not silently grow
    /// behavior back). One assert per `#[arg]` default in this file.
    #[test]
    fn preconfirmation_p2p_defaults_are_pinned() {
        let args = parse_minimal();
        assert_eq!(args.p2p_listen, "0.0.0.0:9000".parse::<SocketAddr>().expect("socket addr"));
        assert_eq!(
            args.p2p_discovery_addr,
            "0.0.0.0:9001".parse::<SocketAddr>().expect("socket addr")
        );
        assert!(!args.p2p_disable_discovery);
        assert_eq!(args.p2p_advertise_addr, None);
        // No `default_value`: unset list flags fall back to empty vectors.
        assert!(args.p2p_bootnodes.is_empty());
        assert!(args.p2p_static_peers.is_empty());
    }
}

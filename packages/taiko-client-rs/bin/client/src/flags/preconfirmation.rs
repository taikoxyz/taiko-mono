//! Preconfirmation-specific CLI flags.

use std::net::SocketAddr;

use clap::Parser;

/// Preconfirmation-specific CLI arguments.
#[derive(Parser, Clone, Debug, PartialEq, Eq)]
pub struct PreconfirmationArgs {
    /// TCP listen address for P2P connections.
    #[clap(long = "p2p.listen", env = "P2P_LISTEN", default_value = "0.0.0.0:9000")]
    pub p2p_listen: SocketAddr,

    /// UDP listen address for discv5 discovery.
    #[clap(
        long = "p2p.discovery.addr",
        env = "P2P_DISCOVERY_ADDR",
        default_value = "0.0.0.0:9001"
    )]
    pub p2p_discovery_addr: SocketAddr,

    /// Comma-separated list of bootnodes (ENR or multiaddr).
    #[clap(long = "p2p.bootnodes", env = "P2P_BOOTNODES", value_delimiter = ',')]
    pub p2p_bootnodes: Vec<String>,

    /// Comma-separated list of static peers to dial on startup (multiaddr).
    #[clap(long = "p2p.static-peers", env = "P2P_STATIC_PEERS", value_delimiter = ',')]
    pub p2p_static_peers: Vec<String>,

    /// Disable discv5 peer discovery.
    #[clap(long = "p2p.disable-discovery", env = "P2P_DISABLE_DISCOVERY", default_value = "false")]
    pub p2p_disable_discovery: bool,

    /// Externally dialable TCP address advertised in the local P2P node record.
    #[clap(long = "p2p.advertise.addr", env = "P2P_ADVERTISE_ADDR")]
    pub p2p_advertise_addr: Option<SocketAddr>,

    /// Optional address for user-facing preconfirmation RPC server.
    #[clap(long = "preconf.rpc.addr", env = "PRECONF_RPC_ADDR")]
    pub preconf_rpc_addr: Option<SocketAddr>,

    /// Chain-configured 32-byte preconfirmation signing domain as hex (64 hex chars,
    /// optional 0x prefix). Defaults to the protocol's built-in `DOMAIN_PRECONF`.
    #[clap(long = "preconf.signing-domain", env = "PRECONF_SIGNING_DOMAIN")]
    pub preconf_signing_domain: Option<String>,
}

impl PreconfirmationArgs {
    /// Parse the optional signing-domain flag into a 32-byte array.
    ///
    /// Returns `None` when the flag is unset and an error when the value is not exactly
    /// 32 bytes of hex.
    pub fn parse_signing_domain(&self) -> Result<Option<[u8; 32]>, String> {
        let Some(raw) = self.preconf_signing_domain.as_deref() else {
            return Ok(None);
        };
        let stripped = raw.strip_prefix("0x").unwrap_or(raw);
        let bytes = alloy_primitives::hex::decode(stripped)
            .map_err(|err| format!("invalid preconf.signing-domain hex: {err}"))?;
        let domain: [u8; 32] = bytes
            .try_into()
            .map_err(|_| "preconf.signing-domain must be exactly 32 bytes".to_string())?;
        Ok(Some(domain))
    }
}

#[cfg(test)]
mod tests {
    use std::net::SocketAddr;

    use clap::Parser;

    use super::PreconfirmationArgs;

    #[test]
    fn parses_signing_domain_hex() {
        let domain_hex = "0x".to_string() + &"ab".repeat(32);
        let args =
            PreconfirmationArgs::try_parse_from(["test", "--preconf.signing-domain", &domain_hex])
                .expect("signing domain should parse");
        let parsed = args.parse_signing_domain().expect("valid domain");
        assert_eq!(parsed, Some([0xab; 32]));
    }

    #[test]
    fn rejects_wrong_length_signing_domain() {
        let args =
            PreconfirmationArgs::try_parse_from(["test", "--preconf.signing-domain", "0xabcd"])
                .expect("flag parses as string");
        assert!(args.parse_signing_domain().is_err());
    }

    #[test]
    fn unset_signing_domain_is_none() {
        let args = PreconfirmationArgs::try_parse_from(["test"]).expect("no flags");
        assert_eq!(args.parse_signing_domain().expect("ok"), None);
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
}

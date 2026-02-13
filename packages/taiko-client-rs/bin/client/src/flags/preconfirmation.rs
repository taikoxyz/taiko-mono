//! Preconfirmation-specific CLI flags.

use std::net::SocketAddr;

use alloy_primitives::Address;
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

    /// Comma-separated list of allowed sequencer addresses for whitelist preconfirmation gossipsub.
    #[clap(
        long = "p2p.sequencer-addresses",
        env = "P2P_SEQUENCER_ADDRESSES",
        value_delimiter = ','
    )]
    pub p2p_sequencer_addresses: Vec<Address>,

    /// Single fallback sequencer address for legacy non-whitelist p2p signing checks.
    #[clap(long = "p2p.sequencer-address", env = "P2P_SEQUENCER_ADDRESS")]
    pub p2p_sequencer_address: Option<Address>,

    /// Disable discv5 peer discovery.
    #[clap(long = "p2p.disable-discovery", env = "P2P_DISABLE_DISCOVERY", default_value = "false")]
    pub p2p_disable_discovery: bool,

    /// Optional address for user-facing preconfirmation RPC server.
    #[clap(long = "preconf.rpc.addr", env = "PRECONF_RPC_ADDR")]
    pub preconf_rpc_addr: Option<SocketAddr>,
}

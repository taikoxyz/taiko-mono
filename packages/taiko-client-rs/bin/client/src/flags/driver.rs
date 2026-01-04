//! Driver-specific CLI flags.

use std::{net::SocketAddr, time::Duration};

use alloy_primitives::Address;
use clap::Parser;
use url::Url;

/// Driver-specific CLI arguments.
#[derive(Parser, Clone, Debug, PartialEq, Eq)]
pub struct DriverArgs {
    #[clap(
        long = "driver.retryInterval",
        env = "DRIVER_RETRY_INTERVAL",
        default_value = "12",
        help = "Interval in seconds between retry attempts when sync operations fail"
    )]
    retry_interval_seconds: u64,
    #[clap(
        long = "l1.beacon",
        env = "L1_BEACON",
        required = true,
        help = "HTTP endpoint of the L1 beacon node"
    )]
    pub l1_beacon_endpoint: Url,
    #[clap(
        long = "l2.checkpoint",
        env = "L2_CHECKPOINT",
        help = "Optional HTTP endpoint of a checkpointed L2 execution engine"
    )]
    pub l2_checkpoint_endpoint: Option<Url>,
    #[clap(
        long = "blob.server",
        env = "BLOB_SERVER",
        help = "Optional HTTP endpoint of a blob server to fallback when beacon sidecars are unavailable"
    )]
    pub blob_server_endpoint: Option<Url>,
    #[clap(
        long = "p2p.sidecar",
        env = "P2P_SIDECAR",
        default_value = "false",
        help = "Enable the in-process P2P preconfirmation sidecar"
    )]
    /// Enable the in-process P2P sidecar.
    pub p2p_sidecar_enabled: bool,
    #[clap(
        long = "p2p.chain_id",
        env = "P2P_CHAIN_ID",
        help = "Optional chain id override for the P2P sidecar"
    )]
    /// Optional chain id override for the P2P sidecar.
    pub p2p_chain_id: Option<u64>,
    #[clap(
        long = "p2p.listen_addr",
        env = "P2P_LISTEN_ADDR",
        help = "Optional listen socket address for the P2P sidecar"
    )]
    /// Optional listen socket address for the P2P sidecar.
    pub p2p_listen_addr: Option<SocketAddr>,
    #[clap(
        long = "p2p.bootnodes",
        env = "P2P_BOOTNODES",
        value_delimiter = ',',
        help = "Comma-separated bootnodes for the P2P sidecar"
    )]
    /// Bootnodes for the P2P sidecar.
    pub p2p_bootnodes: Vec<String>,
    #[clap(
        long = "p2p.enable_discovery",
        env = "P2P_ENABLE_DISCOVERY",
        help = "Toggle discovery for the P2P sidecar"
    )]
    /// Toggle discovery for the P2P sidecar.
    pub p2p_enable_discovery: Option<bool>,
    #[clap(
        long = "p2p.expected_slasher",
        env = "P2P_EXPECTED_SLASHER",
        help = "Expected slasher address for P2P commitment validation"
    )]
    /// Expected slasher address for P2P commitment validation.
    pub p2p_expected_slasher: Option<Address>,
    #[clap(
        long = "p2p.max_txlist_bytes",
        env = "P2P_MAX_TXLIST_BYTES",
        help = "Maximum txlist bytes accepted by the P2P sidecar"
    )]
    /// Maximum txlist bytes accepted by the P2P sidecar.
    pub p2p_max_txlist_bytes: Option<usize>,
}

impl DriverArgs {
    /// Retry interval as a [`Duration`].
    pub fn retry_interval(&self) -> Duration {
        Duration::from_secs(self.retry_interval_seconds)
    }
}

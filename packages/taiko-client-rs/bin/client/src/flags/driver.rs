//! Driver-specific CLI flags.

use clap::Parser;
use std::{net::SocketAddr, path::PathBuf, time::Duration};
use url::Url;

/// Driver-specific CLI arguments.
#[derive(Parser, Clone, Debug, PartialEq, Eq)]
pub struct DriverArgs {
    /// Interval in seconds between retry attempts when sync operations fail.
    #[clap(
        long = "driver.retryInterval",
        env = "DRIVER_RETRY_INTERVAL",
        default_value = "12",
        help = "Interval in seconds between retry attempts when sync operations fail"
    )]
    retry_interval_seconds: u64,
    /// HTTP endpoint of the L1 beacon node.
    #[clap(
        long = "l1.beacon",
        env = "L1_BEACON",
        required = true,
        help = "HTTP endpoint of the L1 beacon node"
    )]
    pub l1_beacon_endpoint: Url,
    /// Optional HTTP endpoint of a checkpointed L2 execution engine.
    #[clap(
        long = "l2.checkpoint",
        env = "L2_CHECKPOINT",
        help = "Optional HTTP endpoint of a checkpointed L2 execution engine"
    )]
    pub l2_checkpoint_endpoint: Option<Url>,
    /// Optional HTTP endpoint of a blob server to use as fallback.
    #[clap(
        long = "blob.server",
        env = "BLOB_SERVER",
        help = "Optional HTTP endpoint of a blob server to fallback when beacon sidecars are unavailable"
    )]
    pub blob_server_endpoint: Option<Url>,
    /// Optional socket address for the driver JSON-RPC server.
    #[clap(
        long = "driver.rpc.addr",
        env = "DRIVER_RPC_ADDR",
        help = "Optional address to bind the driver JSON-RPC server (JWT-protected)"
    )]
    pub rpc_listen_addr: Option<SocketAddr>,
    /// Path to the JWT secret used by the driver JSON-RPC server.
    #[clap(
        long = "driver.rpc.jwt.secret",
        env = "DRIVER_RPC_JWT_SECRET",
        help = "Path to the JWT secret used by the driver JSON-RPC server (HTTP only)"
    )]
    pub rpc_jwt_secret: Option<PathBuf>,
    /// Path for the IPC socket used by the driver JSON-RPC server.
    #[clap(
        long = "driver.rpc.ipc.path",
        env = "DRIVER_RPC_IPC_PATH",
        help = "Path for the IPC socket used by the driver JSON-RPC server (no JWT required)"
    )]
    pub rpc_ipc_path: Option<PathBuf>,
}

impl DriverArgs {
    /// Retry interval as a [`Duration`].
    pub fn retry_interval(&self) -> Duration {
        Duration::from_secs(self.retry_interval_seconds)
    }
}

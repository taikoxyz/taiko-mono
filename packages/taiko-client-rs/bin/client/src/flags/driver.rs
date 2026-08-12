//! Driver-specific CLI flags.

use clap::Parser;
use std::time::Duration;
use url::Url;

/// Driver-specific CLI arguments.
#[derive(Parser, Clone, Debug, PartialEq, Eq)]
pub struct DriverArgs {
    /// Maximum interval in seconds between retry attempts when sync operations fail; the
    /// event scanner reconnect backs off exponentially from one second up to this cap.
    #[clap(
        long = "driver.retryInterval",
        env = "DRIVER_RETRY_INTERVAL",
        default_value = "12",
        help = "Maximum interval in seconds between retry attempts when sync operations fail; \
                the event scanner reconnect backs off exponentially from one second up to this cap"
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
    /// Optional HTTP endpoint of an L2 execution engine used as an untrusted block-body source
    /// for checkpoint catch-up; the sync target itself is read from the L1 inbox.
    #[clap(
        long = "l2.checkpoint",
        env = "L2_CHECKPOINT",
        help = "Optional HTTP endpoint of an L2 execution engine used as an untrusted \
                block-body source for checkpoint catch-up"
    )]
    pub l2_checkpoint_endpoint: Option<Url>,
    /// Optional HTTP endpoint of a blob server to use as fallback.
    #[clap(
        long = "blob.server",
        env = "BLOB_SERVER",
        help = "Optional HTTP endpoint of a blob server to fallback when beacon sidecars are unavailable"
    )]
    pub blob_server_endpoint: Option<Url>,
    /// Timeout in seconds for blob fetches from the L1 beacon node or the blob server.
    #[clap(
        long = "blob.fetchTimeout",
        env = "BLOB_FETCH_TIMEOUT",
        default_value = "120",
        help = "Timeout in seconds for blob fetches from the L1 beacon node or the blob server; \
                PeerDAS beacon nodes may reconstruct blobs from data columns on request, which \
                takes multiple seconds per blob in the slot"
    )]
    blob_fetch_timeout_seconds: u64,
}

impl DriverArgs {
    /// Retry interval as a [`Duration`].
    pub fn retry_interval(&self) -> Duration {
        Duration::from_secs(self.retry_interval_seconds)
    }

    /// Blob fetch timeout as a [`Duration`].
    pub fn blob_fetch_timeout(&self) -> Duration {
        Duration::from_secs(self.blob_fetch_timeout_seconds)
    }
}

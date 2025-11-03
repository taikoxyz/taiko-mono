//! Driver-specific CLI flags.

use clap::Parser;
use std::time::Duration;
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
        long = "devnet.shastaTimestamp",
        env = "DEVNET_SHASTA_TIMESTAMP",
        default_value_t = 0u64,
        help = "Override the Shasta devnet fork activation timestamp (0 keeps the baked-in value)"
    )]
    pub devnet_shasta_timestamp: u64,
}

impl DriverArgs {
    /// Retry interval as a [`Duration`].
    pub fn retry_interval(&self) -> Duration {
        Duration::from_secs(self.retry_interval_seconds)
    }
}

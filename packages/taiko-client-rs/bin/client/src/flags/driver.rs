//! Driver-specific CLI flags.

use clap::Parser;
use std::time::Duration;
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
    /// Submit every missing block from the local L2 head to the checkpoint head.
    #[clap(
        long = "l2.checkpointBackfill",
        env = "L2_CHECKPOINT_BACKFILL",
        default_value_t = false,
        help = "Submit every missing block from the local L2 head to the checkpoint head"
    )]
    pub l2_checkpoint_backfill: bool,
    /// Optional HTTP endpoint of a blob server to use as fallback.
    #[clap(
        long = "blob.server",
        env = "BLOB_SERVER",
        help = "Optional HTTP endpoint of a blob server to fallback when beacon sidecars are unavailable"
    )]
    pub blob_server_endpoint: Option<Url>,
}

impl DriverArgs {
    /// Retry interval as a [`Duration`].
    pub fn retry_interval(&self) -> Duration {
        Duration::from_secs(self.retry_interval_seconds)
    }
}

#[cfg(test)]
mod tests {
    use clap::Parser;

    use super::DriverArgs;

    fn required_args() -> [&'static str; 3] {
        ["driver", "--l1.beacon", "http://localhost:5052"]
    }

    #[test]
    fn checkpoint_backfill_defaults_to_disabled() {
        let args = DriverArgs::try_parse_from(required_args()).expect("driver args should parse");

        assert!(!args.l2_checkpoint_backfill);
    }

    #[test]
    fn checkpoint_backfill_flag_enables_range_backfill() {
        let args = DriverArgs::try_parse_from([
            required_args()[0],
            required_args()[1],
            required_args()[2],
            "--l2.checkpointBackfill",
        ])
        .expect("driver args should parse");

        assert!(args.l2_checkpoint_backfill);
    }
}

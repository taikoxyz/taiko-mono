//! Driver-specific CLI flags.

use clap::Parser;
use std::{num::NonZeroUsize, time::Duration};
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
    /// Maximum number of retries for transient event-sync processing failures.
    #[clap(
        long = "driver.eventSyncMaxRetries",
        env = "DRIVER_EVENT_SYNC_MAX_RETRIES",
        default_value = "10",
        help = "Maximum number of retries for transient event-sync processing failures"
    )]
    event_sync_max_retries: NonZeroUsize,
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
}

impl DriverArgs {
    /// Retry interval as a [`Duration`].
    pub fn retry_interval(&self) -> Duration {
        Duration::from_secs(self.retry_interval_seconds)
    }

    /// Maximum number of retries for transient event-sync processing failures.
    pub fn event_sync_max_retries(&self) -> usize {
        self.event_sync_max_retries.get()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn required_args() -> [&'static str; 3] {
        ["driver", "--l1.beacon", "http://localhost:5052"]
    }

    #[test]
    fn uses_default_event_sync_retry_limit() {
        let args = DriverArgs::try_parse_from(required_args()).expect("driver args should parse");

        assert_eq!(args.event_sync_max_retries(), 10);
    }

    #[test]
    fn accepts_explicit_event_sync_retry_limit() {
        let args = DriverArgs::try_parse_from([
            required_args()[0],
            "--driver.eventSyncMaxRetries",
            "9",
            required_args()[1],
            required_args()[2],
        ])
        .expect("driver args should parse");

        assert_eq!(args.event_sync_max_retries(), 9);
    }

    #[test]
    fn rejects_zero_event_sync_retry_limit() {
        let err = DriverArgs::try_parse_from([
            required_args()[0],
            "--driver.eventSyncMaxRetries",
            "0",
            required_args()[1],
            required_args()[2],
        ])
        .expect_err("driver args should reject zero retries");

        let rendered = err.to_string();
        assert!(rendered.contains("driver.eventSyncMaxRetries"));
    }
}

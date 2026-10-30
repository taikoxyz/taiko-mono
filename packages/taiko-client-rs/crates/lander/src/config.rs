//! Validated operator configuration shared by the CLI and landing components.

use std::{path::PathBuf, time::Duration};

use abci::GRID_INTERVAL;
use url::Url;

use crate::{
    Limits, SidecarMode,
    blob::MAX_LANDING_BLOBS,
    error::{LanderError, Result},
};

/// Upper bound on configurable call deadlines, in seconds.
pub const MAX_TIMEOUT_SECS: u64 = 3600;

/// CometBFT `block.max_bytes` in every Etna genesis, bounding one block's protobuf and so each
/// published header and execution block.
pub const COMET_BLOCK_MAX_BYTES: usize = 22_020_096;

/// Explicit transaction fee ceilings supplied by the operator, in wei.
pub use crate::tx::FeeCaps;

/// Deadlines applied to network calls and the pluggable proof provider.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Timeouts {
    /// Deadline of one read-only RPC operation.
    pub rpc: Duration,
    /// Deadline of the authenticated engine singleton check.
    pub engine: Duration,
    /// Deadline of one proof request.
    pub proof: Duration,
    /// Deadline of one raw-transaction broadcast.
    pub broadcast: Duration,
    /// Deadline of one transaction/receipt reconciliation operation.
    pub receipt: Duration,
}

impl Timeouts {
    /// Reject zero or excessive deadlines.
    pub fn validate(&self) -> Result<()> {
        for (name, deadline) in [
            ("RPC", self.rpc),
            ("engine", self.engine),
            ("proof", self.proof),
            ("broadcast", self.broadcast),
            ("receipt", self.receipt),
        ] {
            if deadline.is_zero() || deadline > Duration::from_secs(MAX_TIMEOUT_SECS) {
                return Err(LanderError::Configuration(format!(
                    "{name} deadline must be positive and at most {MAX_TIMEOUT_SECS} seconds"
                )));
            }
        }
        Ok(())
    }
}

impl Default for Timeouts {
    /// Conservative independent deadlines; all may be overridden explicitly.
    fn default() -> Self {
        Self {
            rpc: Duration::from_secs(30),
            engine: Duration::from_secs(30),
            proof: Duration::from_secs(300),
            broadcast: Duration::from_secs(30),
            receipt: Duration::from_secs(30),
        }
    }
}

/// Collection threshold and bounded wait for a complete authenticated batch.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct BatchPolicy {
    /// Minimum complete blocks before submission, unless wait expires or consensus requires
    /// earlier landing.
    pub min_blocks: usize,
    /// Maximum collection wait for a below-threshold batch, measured by the runner's clock.
    pub max_wait: Duration,
}

impl BatchPolicy {
    /// Reject a zero threshold or a collection wait outside the positive one-hour bound.
    pub fn validate(&self) -> Result<()> {
        if self.min_blocks == 0 {
            return Err(LanderError::Configuration("minimum batch blocks must be positive".into()));
        }
        if self.max_wait.is_zero() || self.max_wait > Duration::from_secs(MAX_TIMEOUT_SECS) {
            return Err(LanderError::Configuration(format!(
                "maximum batch wait must be positive and at most {MAX_TIMEOUT_SECS} seconds"
            )));
        }
        Ok(())
    }
}

impl Default for BatchPolicy {
    /// Preserve immediate submission of any complete block with a bounded collection wait.
    fn default() -> Self {
        Self { min_blocks: 1, max_wait: Duration::from_secs(30) }
    }
}

/// Complete operator input, containing paths to secrets rather than their contents.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct LanderConfig {
    /// Public HTTP(S) endpoint of the operator's L1 node.
    pub l1_http: Url,
    /// Public HTTP(S) endpoint of the operator's L2 execution node.
    pub l2_http: Url,
    /// Authenticated HTTP(S) Engine API endpoint.
    pub l2_auth: Url,
    /// File containing the Engine API JWT secret.
    pub jwt_secret: PathBuf,
    /// HTTP(S) RPC endpoint of its CometBFT node.
    pub comet_http: Url,
    /// File containing a hex-encoded signing key.
    pub signing_key: PathBuf,
    /// Exclusive durable state directory, independent of the ABCI directory.
    pub data_dir: PathBuf,
    /// Optional existing chain-parameter TOML override.
    pub chain_config: Option<PathBuf>,
    /// Explicit batch, blob and codec limits.
    pub limits: Limits,
    /// Collection threshold and maximum wait before a batch becomes eligible.
    pub batch_policy: BatchPolicy,
    /// Operator-supplied transaction fee ceilings, in wei.
    pub fee_caps: FeeCaps,
    /// Network sidecar representation matching the operator's L1 fork.
    pub sidecar_mode: SidecarMode,
    /// Independent RPC and proof deadlines.
    pub timeouts: Timeouts,
    /// Idle polling and minimum retry delay.
    pub poll_interval: Duration,
    /// Number of canonical confirmations, counting the receipt's own block.
    pub confirmations: u64,
}

impl LanderConfig {
    /// Validate every local invariant before opening RPCs or reading a signing key.
    pub fn validate(&self) -> Result<()> {
        self.limits.validate()?;
        if self.limits.max_blocks < GRID_INTERVAL as usize {
            return Err(LanderError::Configuration(format!(
                "maximum batch blocks must fit a {GRID_INTERVAL}-block grid segment"
            )));
        }
        self.batch_policy.validate()?;
        if self.batch_policy.min_blocks > self.limits.max_blocks {
            return Err(LanderError::Configuration(
                "minimum batch blocks cannot exceed maximum batch blocks".into(),
            ));
        }
        self.fee_caps.validate()?;
        self.timeouts.validate()?;
        for (name, endpoint) in [
            ("L1", &self.l1_http),
            ("L2", &self.l2_http),
            ("Engine", &self.l2_auth),
            ("CometBFT", &self.comet_http),
        ] {
            if !matches!(endpoint.scheme(), "http" | "https") || endpoint.host_str().is_none() {
                return Err(LanderError::Configuration(format!(
                    "{name} endpoint requires HTTP(S) and a host"
                )));
            }
        }
        if self.signing_key.as_os_str().is_empty() ||
            self.data_dir.as_os_str().is_empty() ||
            self.jwt_secret.as_os_str().is_empty()
        {
            return Err(LanderError::Configuration(
                "signing-key and data-dir paths must be nonempty".into(),
            ));
        }
        if self.poll_interval.is_zero() ||
            self.poll_interval > Duration::from_secs(MAX_TIMEOUT_SECS) ||
            self.confirmations == 0
        {
            return Err(LanderError::Configuration("poll interval must be positive and at most one hour; confirmations must be nonzero".into()));
        }
        // Batches are sized for the six blobs Fusaka permits per transaction; the 124,000-byte
        // block rule keeps every decided block within one blob.
        if self.limits.max_blobs != MAX_LANDING_BLOBS {
            return Err(LanderError::Configuration(format!(
                "maximum blobs must equal {MAX_LANDING_BLOBS}, the blobs Fusaka permits per \
                 transaction"
            )));
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn valid() -> LanderConfig {
        LanderConfig {
            l1_http: Url::parse("http://l1:8545").unwrap(),
            l2_http: Url::parse("https://l2.example/rpc").unwrap(),
            l2_auth: Url::parse("http://l2:8551").unwrap(),
            jwt_secret: "jwt.hex".into(),
            comet_http: Url::parse("http://comet:26657").unwrap(),
            signing_key: PathBuf::from("/keys/lander.hex"),
            data_dir: PathBuf::from("/data/lander"),
            chain_config: None,
            limits: Limits {
                max_blocks: 16,
                max_blobs: 6,
                max_payload_bytes: 700_000,
                max_message_bytes: 22_020_096,
                max_decompressed_bytes: 16 * 22_020_096,
            },
            batch_policy: BatchPolicy::default(),
            fee_caps: FeeCaps {
                max_fee_per_gas: 10,
                max_priority_fee_per_gas: 1,
                max_fee_per_blob_gas: 10,
            },
            sidecar_mode: SidecarMode::Eip4844,
            timeouts: Timeouts::default(),
            poll_interval: Duration::from_secs(1),
            confirmations: 1,
        }
    }

    #[test]
    fn v1_operator_limit_must_fit_one_grid_segment() {
        for max_blocks in 1..6 {
            let mut config = valid();
            config.limits.max_blocks = max_blocks;
            assert!(config.validate().is_err(), "limit {max_blocks} cannot publish a grid segment");
        }
        let mut config = valid();
        config.limits.max_blocks = 6;
        config.validate().unwrap();
    }

    #[test]
    fn default_policy_keeps_single_complete_blocks_eligible() {
        let config = valid();
        assert_eq!(config.batch_policy.min_blocks, 1);
        assert_eq!(config.batch_policy.max_wait, Duration::from_secs(30));
        config.validate().unwrap();
    }

    #[test]
    fn rejects_zero_minimum_batch_blocks() {
        let policy = BatchPolicy { min_blocks: 0, ..BatchPolicy::default() };
        assert!(matches!(policy.validate(), Err(LanderError::Configuration(_))));
        assert!(LanderConfig { batch_policy: policy, ..valid() }.validate().is_err());
    }

    #[test]
    fn rejects_zero_and_excessive_collection_waits() {
        for max_wait in [Duration::ZERO, Duration::from_secs(3600) + Duration::from_nanos(1)] {
            let policy = BatchPolicy { max_wait, ..BatchPolicy::default() };
            assert!(matches!(policy.validate(), Err(LanderError::Configuration(_))));
            assert!(LanderConfig { batch_policy: policy, ..valid() }.validate().is_err());
        }
    }

    #[test]
    fn validates_minimum_against_maximum_blocks_with_inclusive_boundaries() {
        let mut config = valid();
        config.batch_policy = BatchPolicy { min_blocks: 16, max_wait: Duration::from_secs(3600) };
        config.validate().unwrap();
        config.batch_policy.min_blocks = 17;
        assert!(matches!(config.validate(), Err(LanderError::Configuration(_))));
    }

    #[test]
    fn accepts_both_explicit_sidecar_modes() {
        for sidecar_mode in [SidecarMode::Eip4844, SidecarMode::Eip7594] {
            LanderConfig { sidecar_mode, ..valid() }.validate().unwrap();
        }
    }

    #[test]
    fn rejects_zero_limits_and_fee_caps() {
        let mut configs = Vec::new();
        let mut c = valid();
        c.limits.max_blocks = 0;
        configs.push(c);
        let mut c = valid();
        c.limits.max_blobs = 0;
        configs.push(c);
        let mut c = valid();
        c.limits.max_payload_bytes = 0;
        configs.push(c);
        let mut c = valid();
        c.limits.max_message_bytes = 0;
        configs.push(c);
        let mut c = valid();
        c.limits.max_decompressed_bytes = 0;
        configs.push(c);
        let mut c = valid();
        c.fee_caps.max_fee_per_gas = 0;
        configs.push(c);
        let mut c = valid();
        c.fee_caps.max_fee_per_blob_gas = 0;
        configs.push(c);
        let mut c = valid();
        c.fee_caps.max_priority_fee_per_gas = 0;
        configs.push(c);
        for c in configs {
            assert!(c.validate().is_err(), "configuration accepted: {c:?}");
        }
    }

    /// The lander takes exactly `MAX_LANDING_BLOBS` blobs; fewer are refused.
    #[test]
    fn rejects_fewer_blobs_than_one_transaction_permits() {
        let mut c = valid();
        c.limits.max_blobs = MAX_LANDING_BLOBS;
        c.validate().unwrap();
        c.limits.max_blobs = MAX_LANDING_BLOBS - 1;
        assert!(matches!(c.validate(), Err(LanderError::Configuration(_))));
    }

    /// Fusaka permits at most six blobs in a single transaction.
    #[test]
    fn rejects_more_blobs_than_one_transaction_permits() {
        let mut c = valid();
        c.limits.max_blobs = MAX_LANDING_BLOBS + 1;
        assert!(matches!(c.validate(), Err(LanderError::Configuration(_))));
    }

    /// Payload V3 compresses, so one envelope may exceed the compressed payload bound.
    #[test]
    fn accepts_messages_larger_than_the_compressed_payload() {
        let c = valid();
        assert!(c.limits.max_message_bytes > c.limits.max_payload_bytes);
        c.validate().unwrap();
    }

    #[test]
    fn rejects_priority_fee_above_execution_cap() {
        let mut c = valid();
        c.fee_caps.max_priority_fee_per_gas = c.fee_caps.max_fee_per_gas + 1;
        assert!(c.validate().is_err());
    }

    #[test]
    fn rejects_zero_deadlines_polling_and_confirmations() {
        let mut configs = Vec::new();
        let mut c = valid();
        c.timeouts.rpc = Duration::ZERO;
        configs.push(c);
        let mut c = valid();
        c.timeouts.proof = Duration::ZERO;
        configs.push(c);
        let mut c = valid();
        c.timeouts.broadcast = Duration::ZERO;
        configs.push(c);
        let mut c = valid();
        c.timeouts.receipt = Duration::ZERO;
        configs.push(c);
        let mut c = valid();
        c.poll_interval = Duration::ZERO;
        configs.push(c);
        let mut c = valid();
        c.confirmations = 0;
        configs.push(c);
        let mut c = valid();
        c.timeouts.rpc = Duration::from_secs(MAX_TIMEOUT_SECS + 1);
        configs.push(c);
        for c in configs {
            assert!(c.validate().is_err(), "configuration accepted: {c:?}");
        }
    }

    #[test]
    fn rejects_unsupported_urls_and_empty_paths() {
        let mut configs = Vec::new();
        let mut c = valid();
        c.l1_http = Url::parse("ws://l1/rpc").unwrap();
        configs.push(c);
        let mut c = valid();
        c.l2_http = Url::parse("file:///tmp/socket").unwrap();
        configs.push(c);
        let mut c = valid();
        c.comet_http = Url::parse("ftp://comet/rpc").unwrap();
        configs.push(c);
        let mut c = valid();
        c.data_dir = PathBuf::new();
        configs.push(c);
        let mut c = valid();
        c.signing_key = PathBuf::new();
        configs.push(c);
        for c in configs {
            assert!(c.validate().is_err(), "configuration accepted: {c:?}");
        }
    }
}

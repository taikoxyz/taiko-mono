//! Validated operator configuration shared by the CLI and landing components.

use std::{path::PathBuf, time::Duration};

use url::Url;

use crate::{
    Limits, SidecarMode,
    error::{LanderError, Result},
};

/// Upper bound on configurable call deadlines, in seconds.
pub const MAX_TIMEOUT_SECS: u64 = 3600;

/// Explicit transaction fee ceilings supplied by the operator, in wei.
pub use crate::tx::FeeCaps;

/// Deadlines applied to network calls and the pluggable proof provider.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Timeouts {
    /// Deadline of one read-only RPC operation.
    pub rpc: Duration,
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
            proof: Duration::from_secs(300),
            broadcast: Duration::from_secs(30),
            receipt: Duration::from_secs(30),
        }
    }
}

/// Complete operator input, containing paths to secrets rather than their contents.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct LanderConfig {
    /// Public HTTP(S) endpoint of the operator's L1 node.
    pub l1_http: Url,
    /// Public HTTP(S) endpoint of the operator's L2 execution node.
    pub l2_http: Url,
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
        self.fee_caps.validate()?;
        self.timeouts.validate()?;
        for (name, endpoint) in
            [("L1", &self.l1_http), ("L2", &self.l2_http), ("CometBFT", &self.comet_http)]
        {
            if !matches!(endpoint.scheme(), "http" | "https") || endpoint.host_str().is_none() {
                return Err(LanderError::Configuration(format!(
                    "{name} endpoint requires HTTP(S) and a host"
                )));
            }
        }
        if self.signing_key.as_os_str().is_empty() || self.data_dir.as_os_str().is_empty() {
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
        if self.limits.max_message_bytes > self.limits.max_payload_bytes {
            return Err(LanderError::Configuration(
                "single-message bound cannot exceed total batch payload bound".into(),
            ));
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
            comet_http: Url::parse("http://comet:26657").unwrap(),
            signing_key: PathBuf::from("/keys/lander.hex"),
            data_dir: PathBuf::from("/data/lander"),
            chain_config: None,
            limits: Limits {
                max_blocks: 16,
                max_blobs: 6,
                max_payload_bytes: 700_000,
                max_message_bytes: 700_000,
            },
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

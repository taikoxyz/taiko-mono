//! Operator flags for the independent permissionless Etna lander.

use std::{path::PathBuf, time::Duration};

use clap::Parser;
use lander::{
    Limits, SidecarMode,
    blob::PAYLOAD_BYTES_PER_BLOB,
    config::{
        BatchPolicy, COMET_BLOCK_MAX_BYTES, FeeCaps, LanderConfig, MAX_TIMEOUT_SECS, Timeouts,
    },
};
use url::Url;

use crate::flags::common::http_url;

/// Public RPC, transaction budget and journal arguments for `taiko-client lander`.
#[derive(Parser, Clone, Debug)]
pub struct LanderArgs {
    /// Public HTTP(S) L1 JSON-RPC endpoint, serving the required historical state.
    #[clap(long = "l1.http", env = "L1_HTTP", required = true, value_parser = http_url)]
    pub l1_http_endpoint: Url,
    /// Public HTTP(S) L2 execution JSON-RPC endpoint.
    #[clap(long = "l2.http", env = "L2_HTTP", required = true, value_parser = http_url)]
    pub l2_http_endpoint: Url,
    /// Authenticated Engine API endpoint used to verify forced transaction skips.
    #[clap(long="l2.auth",env="L2_AUTH",required=true,value_parser=http_url)]
    pub l2_auth_endpoint: Url,
    /// File containing the Engine API JWT secret.
    #[clap(long = "jwt.secret", env = "JWT_SECRET", required = true)]
    pub jwt_secret: PathBuf,
    /// Deadline of a forced singleton check, in seconds.
    #[clap(long="engine.timeout",env="LANDER_ENGINE_TIMEOUT",default_value_t=30,value_parser=clap::value_parser!(u64).range(1..=MAX_TIMEOUT_SECS))]
    pub engine_timeout_secs: u64,
    /// HTTP(S) CometBFT RPC endpoint supplying blocks, commits and committee queries.
    #[clap(long = "comet.http", env = "LANDER_COMET_HTTP", required = true, value_parser = http_url)]
    pub comet_http_endpoint: Url,
    /// File containing the lander's hex-encoded signing key; never a CLI key value.
    #[clap(long = "signing-key", env = "LANDER_SIGNING_KEY", required = true)]
    pub signing_key: PathBuf,
    /// Dedicated durable journal directory, separate from the ABCI data directory.
    #[clap(long = "data-dir", env = "LANDER_DATA_DIR", required = true)]
    pub data_dir: PathBuf,
    /// Existing chain-parameter TOML override, used for the same chain as the L2 RPC.
    #[clap(long = "chain-config", env = "LANDER_CHAIN_CONFIG")]
    pub chain_config: Option<PathBuf>,
    /// Maximum complete blocks per batch; must respect the deployed Inbox limit.
    #[clap(long = "max-blocks", env = "LANDER_MAX_BLOCKS", required = true, value_parser = positive_usize)]
    pub max_blocks: usize,
    /// Minimum complete blocks before submission; wait expiry or consensus may require earlier
    /// landing.
    #[clap(long = "min-blocks", env = "LANDER_MIN_BLOCKS", default_value_t = 1, value_parser = positive_usize)]
    pub min_blocks: usize,
    /// Maximum wait for a below-threshold batch, in seconds; positive and at most one hour.
    #[clap(long = "max-batch-wait", env = "LANDER_MAX_BATCH_WAIT", default_value_t = 30, value_parser = clap::value_parser!(u64).range(1..=MAX_TIMEOUT_SECS))]
    pub max_batch_wait_secs: u64,
    /// Blobs per transaction: exactly 6, the capacity one decided block may need and the
    /// Fusaka per-transaction maximum.
    #[clap(long = "max-blobs", env = "LANDER_MAX_BLOBS", required = true, value_parser = positive_usize)]
    pub max_blobs: usize,
    /// Maximum execution fee per gas in wei, without an inferred budget.
    #[clap(long = "max-fee-per-gas", env = "LANDER_MAX_FEE_PER_GAS", required = true, value_parser = positive_u128)]
    pub max_fee_per_gas: u128,
    /// Maximum priority fee per execution gas in wei; cannot exceed the execution cap.
    #[clap(long = "max-priority-fee-per-gas", env = "LANDER_MAX_PRIORITY_FEE_PER_GAS", required = true, value_parser = positive_u128)]
    pub max_priority_fee_per_gas: u128,
    /// Maximum blob fee per blob gas in wei, without an inferred budget.
    #[clap(long = "max-fee-per-blob-gas", env = "LANDER_MAX_FEE_PER_BLOB_GAS", required = true, value_parser = positive_u128)]
    pub max_fee_per_blob_gas: u128,
    /// Explicit network sidecar format matching the L1 fork: eip4844 or eip7594.
    #[clap(long = "sidecar", env = "LANDER_SIDECAR", required = true, value_parser = sidecar_mode)]
    pub sidecar: SidecarMode,
    /// Deadline of each read-only RPC operation, in seconds.
    #[clap(long = "rpc.timeout", env = "LANDER_RPC_TIMEOUT", default_value_t = 30, value_parser = clap::value_parser!(u64).range(1..=MAX_TIMEOUT_SECS))]
    pub rpc_timeout_secs: u64,
    /// Deadline of a proof-provider request, in seconds; this version uses dummy proofs.
    #[clap(long = "proof.timeout", env = "LANDER_PROOF_TIMEOUT", default_value_t = 300, value_parser = clap::value_parser!(u64).range(1..=MAX_TIMEOUT_SECS))]
    pub proof_timeout_secs: u64,
    /// Deadline of one raw-transaction broadcast, in seconds.
    #[clap(long = "broadcast.timeout", env = "LANDER_BROADCAST_TIMEOUT", default_value_t = 30, value_parser = clap::value_parser!(u64).range(1..=MAX_TIMEOUT_SECS))]
    pub broadcast_timeout_secs: u64,
    /// Deadline of one receipt/nonce reconciliation operation, in seconds.
    #[clap(long = "receipt.timeout", env = "LANDER_RECEIPT_TIMEOUT", default_value_t = 30, value_parser = clap::value_parser!(u64).range(1..=MAX_TIMEOUT_SECS))]
    pub receipt_timeout_secs: u64,
    /// Idle polling and minimum retry interval, in milliseconds.
    #[clap(long = "poll.interval", env = "LANDER_POLL_INTERVAL", default_value_t = 1000, value_parser = clap::value_parser!(u64).range(1..=3_600_000))]
    pub poll_interval_ms: u64,
    /// Required canonical confirmations, counting the receipt's own block.
    #[clap(long = "confirmations", env = "LANDER_CONFIRMATIONS", default_value_t = 1, value_parser = clap::value_parser!(u64).range(1..))]
    pub confirmations: u64,
}

impl LanderArgs {
    /// Build and validate the shared runtime configuration before accessing any endpoint.
    ///
    /// The compressed payload fills at most `--max-blobs` blobs; each message is bounded by the
    /// CometBFT block size, and the decompressed list by the lesser of the fixed 64 MiB protocol
    /// ceiling and that size times `--max-blocks`.
    pub fn config(&self) -> lander::Result<LanderConfig> {
        let max_payload_bytes =
            self.max_blobs.checked_mul(PAYLOAD_BYTES_PER_BLOB).ok_or_else(|| {
                lander::LanderError::Configuration("blob payload capacity overflows usize".into())
            })?;
        let max_decompressed_bytes = COMET_BLOCK_MAX_BYTES
            .checked_mul(self.max_blocks)
            .ok_or_else(|| {
                lander::LanderError::Configuration(
                    "decompressed batch capacity overflows usize".into(),
                )
            })?
            .min(lander::codec::MAX_DECOMPRESSED_BYTES);
        let config = LanderConfig {
            l1_http: self.l1_http_endpoint.clone(),
            l2_http: self.l2_http_endpoint.clone(),
            l2_auth: self.l2_auth_endpoint.clone(),
            jwt_secret: self.jwt_secret.clone(),
            comet_http: self.comet_http_endpoint.clone(),
            signing_key: self.signing_key.clone(),
            data_dir: self.data_dir.clone(),
            chain_config: self.chain_config.clone(),
            limits: Limits {
                max_blocks: self.max_blocks,
                max_blobs: self.max_blobs,
                max_payload_bytes,
                max_message_bytes: COMET_BLOCK_MAX_BYTES,
                max_decompressed_bytes,
            },
            batch_policy: BatchPolicy {
                min_blocks: self.min_blocks,
                max_wait: Duration::from_secs(self.max_batch_wait_secs),
            },
            fee_caps: FeeCaps {
                max_fee_per_gas: self.max_fee_per_gas,
                max_priority_fee_per_gas: self.max_priority_fee_per_gas,
                max_fee_per_blob_gas: self.max_fee_per_blob_gas,
            },
            sidecar_mode: self.sidecar,
            timeouts: Timeouts {
                rpc: Duration::from_secs(self.rpc_timeout_secs),
                engine: Duration::from_secs(self.engine_timeout_secs),
                proof: Duration::from_secs(self.proof_timeout_secs),
                broadcast: Duration::from_secs(self.broadcast_timeout_secs),
                receipt: Duration::from_secs(self.receipt_timeout_secs),
            },
            poll_interval: Duration::from_millis(self.poll_interval_ms),
            confirmations: self.confirmations,
        };
        config.validate()?;
        Ok(config)
    }
}

/// Parse a nonzero batch/blob allocation limit.
fn positive_usize(value: &str) -> Result<usize, String> {
    value
        .parse::<usize>()
        .ok()
        .filter(|v| *v > 0)
        .ok_or_else(|| "value must be a positive usize".into())
}

/// Parse a nonzero fee budget in base-unit wei.
fn positive_u128(value: &str) -> Result<u128, String> {
    value
        .parse::<u128>()
        .ok()
        .filter(|v| *v > 0)
        .ok_or_else(|| "fee cap must be positive wei fitting u128".into())
}

/// Parse only explicit supported sidecar modes.
fn sidecar_mode(value: &str) -> Result<SidecarMode, String> {
    match value {
        "eip4844" => Ok(SidecarMode::Eip4844),
        "eip7594" => Ok(SidecarMode::Eip7594),
        _ => Err("sidecar must be eip4844 or eip7594".into()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        cli::{Cli, Commands},
        commands::lander::LanderSubCommand,
        flags::test_env::{ENV_LOCK, EnvGuard},
    };
    use clap::{Parser, error::ErrorKind};

    fn clear_env() -> Vec<EnvGuard> {
        [
            "L1_HTTP",
            "L2_HTTP",
            "LANDER_COMET_HTTP",
            "LANDER_SIGNING_KEY",
            "LANDER_DATA_DIR",
            "LANDER_CHAIN_CONFIG",
            "LANDER_MAX_BLOCKS",
            "LANDER_MIN_BLOCKS",
            "LANDER_MAX_BATCH_WAIT",
            "LANDER_MAX_BLOBS",
            "LANDER_MAX_FEE_PER_GAS",
            "LANDER_MAX_PRIORITY_FEE_PER_GAS",
            "LANDER_MAX_FEE_PER_BLOB_GAS",
            "LANDER_SIDECAR",
            "LANDER_RPC_TIMEOUT",
            "LANDER_PROOF_TIMEOUT",
            "LANDER_BROADCAST_TIMEOUT",
            "LANDER_RECEIPT_TIMEOUT",
            "LANDER_POLL_INTERVAL",
            "LANDER_CONFIRMATIONS",
            "L2_AUTH",
            "JWT_SECRET",
        ]
        .into_iter()
        .map(EnvGuard::unset)
        .collect()
    }

    fn argv() -> Vec<&'static str> {
        vec![
            "taiko-client",
            "lander",
            "--l1.http",
            "http://l1:8545",
            "--l2.http",
            "http://l2:8545",
            "--l2.auth",
            "http://l2:8551",
            "--jwt.secret",
            "/jwt.hex",
            "--comet.http",
            "http://comet:26657",
            "--signing-key",
            "/key.hex",
            "--data-dir",
            "/data/lander",
            "--max-blocks",
            "16",
            "--max-blobs",
            "6",
            "--max-fee-per-gas",
            "100",
            "--max-priority-fee-per-gas",
            "1",
            "--max-fee-per-blob-gas",
            "100",
            "--sidecar",
            "eip4844",
        ]
    }

    fn parse(argv: Vec<&str>) -> Result<LanderSubCommand, clap::Error> {
        match Cli::try_parse_from(argv)?.subcommand {
            Commands::Lander(cmd) => Ok(*cmd),
            other => panic!("expected lander, got {other:?}"),
        }
    }

    #[test]
    fn rejects_unknown_flags() {
        let _lock = ENV_LOCK.lock().unwrap();
        let _clear = clear_env();
        let mut args = argv();
        args.extend(["--no-such-flag", "1"]);
        assert_eq!(parse(args).unwrap_err().kind(), ErrorKind::UnknownArgument);
    }

    #[test]
    fn accepts_required_public_and_authenticated_engine_endpoints() {
        let _lock = ENV_LOCK.lock().unwrap();
        let _clear = clear_env();
        let cmd = parse(argv()).unwrap();
        let c = cmd.lander_flags.config().unwrap();
        assert_eq!(c.limits.max_blocks, 16);
        assert_eq!(c.limits.max_blobs, 6);
        assert_eq!(c.timeouts, Timeouts::default());
        assert_eq!(c.batch_policy.min_blocks, 1);
        assert_eq!(c.batch_policy.max_wait, Duration::from_secs(30));
        assert_eq!(c.sidecar_mode, SidecarMode::Eip4844);
        let mut args = argv();
        *args.last_mut().unwrap() = "eip7594";
        assert_eq!(
            parse(args).unwrap().lander_flags.config().unwrap().sidecar_mode,
            SidecarMode::Eip7594
        );
    }

    #[test]
    fn requires_engine_and_jwt_and_bounds_engine_timeout() {
        let _lock = ENV_LOCK.lock().unwrap();
        let _clear = clear_env();
        for flag in ["--l2.auth", "--jwt.secret"] {
            let mut args = argv();
            let i = args.iter().position(|arg| *arg == flag).unwrap();
            args.drain(i..i + 2);
            assert!(parse(args).is_err());
        }
        for value in ["0", "3601"] {
            let mut args = argv();
            args.extend(["--engine.timeout", value]);
            assert!(parse(args).is_err());
        }
    }

    #[test]
    fn derives_codec_limits_from_blobs_and_the_comet_block_size() {
        let _lock = ENV_LOCK.lock().unwrap();
        let _clear = clear_env();
        let c = parse(argv()).unwrap().lander_flags.config().unwrap();
        assert_eq!(c.limits.max_payload_bytes, 6 * 130_044);
        assert_eq!(c.limits.max_message_bytes, 22_020_096);
        assert_eq!(c.limits.max_decompressed_bytes, lander::codec::MAX_DECOMPRESSED_BYTES);
        let mut args = argv();
        let i = args.iter().position(|v| *v == "--max-blocks").unwrap();
        args[i + 1] = "1";
        assert!(parse(args).unwrap().lander_flags.config().is_err(), "a batch must fit K=6");
    }

    #[test]
    fn rejects_fewer_blobs_than_one_landing_needs() {
        let _lock = ENV_LOCK.lock().unwrap();
        let _clear = clear_env();
        let mut args = argv();
        let i = args.iter().position(|v| *v == "--max-blobs").unwrap();
        args[i + 1] = "5";
        assert!(parse(args).unwrap().lander_flags.config().is_err());
    }

    #[test]
    fn rejects_decompressed_capacity_overflow() {
        let _lock = ENV_LOCK.lock().unwrap();
        let _clear = clear_env();
        let mut args = argv();
        let i = args.iter().position(|v| *v == "--max-blocks").unwrap();
        let max = usize::MAX.to_string();
        args[i + 1] = &max;
        assert!(parse(args).unwrap().lander_flags.config().is_err());
    }

    #[test]
    fn accepts_batching_threshold_and_wait_options() {
        let _lock = ENV_LOCK.lock().unwrap();
        let _clear = clear_env();
        let mut args = argv();
        args.extend(["--min-blocks", "8", "--max-batch-wait", "60"]);
        let command = parse(args).unwrap();
        let config = command.lander_flags.config().unwrap();
        assert_eq!(config.batch_policy.min_blocks, 8);
        assert_eq!(config.batch_policy.max_wait, Duration::from_secs(60));
    }

    #[test]
    fn reads_batch_policy_from_environment_and_allows_cli_overrides() {
        let _lock = ENV_LOCK.lock().unwrap();
        let _clear = clear_env();
        let _minimum = EnvGuard::set("LANDER_MIN_BLOCKS", "6");
        let _wait = EnvGuard::set("LANDER_MAX_BATCH_WAIT", "120");
        let config = parse(argv()).unwrap().lander_flags.config().unwrap();
        assert_eq!(config.batch_policy.min_blocks, 6);
        assert_eq!(config.batch_policy.max_wait, Duration::from_secs(120));
        let mut args = argv();
        args.extend(["--min-blocks", "16", "--max-batch-wait", "3600"]);
        let config = parse(args).unwrap().lander_flags.config().unwrap();
        assert_eq!(config.batch_policy.min_blocks, 16);
        assert_eq!(config.batch_policy.max_wait, Duration::from_secs(3600));
    }

    #[test]
    fn rejects_invalid_batch_policy_environment_values() {
        let _lock = ENV_LOCK.lock().unwrap();
        let _clear = clear_env();
        for (name, value) in [
            ("LANDER_MIN_BLOCKS", "0"),
            ("LANDER_MAX_BATCH_WAIT", "0"),
            ("LANDER_MAX_BATCH_WAIT", "3601"),
        ] {
            let _value = EnvGuard::set(name, value);
            let error = parse(argv()).unwrap_err();
            assert_eq!(error.kind(), ErrorKind::ValueValidation, "{name}={value}: {error}");
        }
    }

    #[test]
    fn rejects_invalid_batching_option_values() {
        let _lock = ENV_LOCK.lock().unwrap();
        let _clear = clear_env();
        for (flag, value) in [
            ("--min-blocks", "0"),
            ("--min-blocks", "-1"),
            ("--min-blocks", "1.5"),
            ("--min-blocks", "18446744073709551616"),
            ("--max-batch-wait", "0"),
            ("--max-batch-wait", "-1"),
            ("--max-batch-wait", "3601"),
            ("--max-batch-wait", "1.5"),
        ] {
            let mut args = argv();
            let option = format!("{flag}={value}");
            args.push(&option);
            let error = parse(args).unwrap_err();
            assert_eq!(error.kind(), ErrorKind::ValueValidation, "{flag}={value}: {error}");
        }
    }

    #[test]
    fn rejects_batching_threshold_above_maximum_blocks() {
        let _lock = ENV_LOCK.lock().unwrap();
        let _clear = clear_env();
        let mut args = argv();
        args.extend(["--min-blocks", "17"]);
        let command = parse(args).unwrap();
        assert!(command.lander_flags.config().is_err());
    }

    #[test]
    fn requires_every_endpoint_budget_and_journal_argument() {
        let _lock = ENV_LOCK.lock().unwrap();
        let _clear = clear_env();
        for flag in [
            "--l1.http",
            "--l2.http",
            "--comet.http",
            "--signing-key",
            "--data-dir",
            "--max-blocks",
            "--max-blobs",
            "--max-fee-per-gas",
            "--max-priority-fee-per-gas",
            "--max-fee-per-blob-gas",
            "--sidecar",
        ] {
            let mut args = argv();
            let i = args.iter().position(|v| *v == flag).unwrap();
            args.drain(i..i + 2);
            let e = parse(args).unwrap_err();
            assert_eq!(e.kind(), ErrorKind::MissingRequiredArgument, "{flag}: {e}");
            assert!(e.to_string().contains(flag));
        }
    }

    #[test]
    fn rejects_bad_limits_fees_deadlines_confirmations_and_sidecars() {
        let _lock = ENV_LOCK.lock().unwrap();
        let _clear = clear_env();
        for (flag, value) in [
            ("--max-blocks", "0"),
            ("--max-blobs", "0"),
            ("--max-fee-per-gas", "0"),
            ("--max-priority-fee-per-gas", "0"),
            ("--max-fee-per-blob-gas", "0"),
            ("--rpc.timeout", "0"),
            ("--proof.timeout", "0"),
            ("--broadcast.timeout", "0"),
            ("--receipt.timeout", "0"),
            ("--poll.interval", "0"),
            ("--confirmations", "0"),
            ("--rpc.timeout", "3601"),
            ("--sidecar", "auto"),
        ] {
            let mut args = argv();
            if let Some(i) = args.iter().position(|v| *v == flag) {
                args[i + 1] = value;
            } else {
                args.extend([flag, value]);
            }
            let e = parse(args).unwrap_err();
            assert_eq!(e.kind(), ErrorKind::ValueValidation, "{flag}: {e}");
        }
    }

    #[test]
    fn rejects_unsupported_endpoint_schemes() {
        let _lock = ENV_LOCK.lock().unwrap();
        let _clear = clear_env();
        for flag in ["--l1.http", "--l2.http", "--comet.http"] {
            let mut args = argv();
            let i = args.iter().position(|v| *v == flag).unwrap();
            args[i + 1] = "ws://example/rpc";
            assert_eq!(parse(args).unwrap_err().kind(), ErrorKind::ValueValidation);
        }
    }

    #[test]
    fn rejects_priority_fee_above_total_before_network_access() {
        let _lock = ENV_LOCK.lock().unwrap();
        let _clear = clear_env();
        let mut args = argv();
        let i = args.iter().position(|v| *v == "--max-priority-fee-per-gas").unwrap();
        args[i + 1] = "101";
        assert!(parse(args).unwrap().lander_flags.config().is_err());
    }

    #[test]
    fn abci_still_requires_engine_and_jwt_arguments() {
        let _lock = ENV_LOCK.lock().unwrap();
        let _clear = clear_env();
        let e = Cli::try_parse_from([
            "taiko-client",
            "abci",
            "--l1.http",
            "http://l1",
            "--l2.http",
            "http://l2",
            "--data-dir",
            "/abci",
        ])
        .unwrap_err();
        assert_eq!(e.kind(), ErrorKind::MissingRequiredArgument);
        assert!(e.to_string().contains("--l2.auth"));
        assert!(e.to_string().contains("--jwt.secret"));
    }
}

//! CLI command parser and runner.
//!
//! This module provides the main CLI structure and command dispatch logic.
//! It parses command-line arguments using `clap` and routes to the appropriate
//! subcommand handler (proposer, driver, or preconfirmation driver).

use std::future::Future;

use crate::error::Result;
use clap::{Parser, Subcommand};
use tokio::runtime::{Builder, Runtime};

use crate::commands::{
    driver::DriverSubCommand, preconfirmation_driver::PreconfirmationDriverSubCommand,
    proposer::ProposerSubCommand,
    whitelist_preconfirmation_driver::WhitelistPreconfirmationDriverSubCommand,
};

/// Subcommands for the CLI.
#[derive(Debug, Clone, Subcommand)]
pub enum Commands {
    /// Run the proposer.
    Proposer(Box<ProposerSubCommand>),
    /// Run the driver.
    Driver(Box<DriverSubCommand>),
    /// Run the preconfirmation driver with P2P client.
    PreconfirmationDriver(Box<PreconfirmationDriverSubCommand>),
    /// Run the whitelist preconfirmation driver with whitelist P2P protocol.
    WhitelistPreconfirmationDriver(Box<WhitelistPreconfirmationDriverSubCommand>),
}

#[derive(Parser, Clone, Debug)]
#[command(author)]
/// Top-level CLI parser containing the selected subcommand.
pub struct Cli {
    /// The subcommand to run.
    #[command(subcommand)]
    pub subcommand: Commands,
}

impl Cli {
    /// Run the subcommand.
    pub fn run(self) -> Result<()> {
        match self.subcommand {
            Commands::Proposer(proposer_cmd) => Self::run_until_ctrl_c(proposer_cmd.run()),
            Commands::Driver(driver_cmd) => Self::run_until_ctrl_c(driver_cmd.run()),
            Commands::PreconfirmationDriver(cmd) => Self::run_until_ctrl_c(cmd.run()),
            Commands::WhitelistPreconfirmationDriver(cmd) => Self::run_until_ctrl_c(cmd.run()),
        }
    }

    /// Run until ctrl-c is pressed.
    pub fn run_until_ctrl_c<F>(fut: F) -> Result<()>
    where
        F: Future<Output = Result<()>>,
    {
        Self::tokio_runtime()?.block_on(fut)
    }

    /// Create a new default tokio multi-thread runtime.
    ///
    /// This creates a multi-threaded runtime with all features enabled,
    /// suitable for running async subcommands.
    pub fn tokio_runtime() -> Result<Runtime> {
        Ok(Builder::new_multi_thread().enable_all().build()?)
    }
}

#[cfg(test)]
mod tests {
    use std::{env, sync::Mutex};

    use super::*;

    static ENV_LOCK: Mutex<()> = Mutex::new(());

    struct EnvGuard {
        keys: Vec<&'static str>,
        previous: Vec<Option<String>>,
    }

    impl EnvGuard {
        fn clear(keys: &[&'static str]) -> Self {
            let previous = keys.iter().map(|k| env::var(k).ok()).collect();
            for k in keys {
                // SAFETY: ENV_LOCK serializes these test-only mutations.
                unsafe { env::remove_var(k) };
            }
            Self { keys: keys.to_vec(), previous }
        }
    }

    impl Drop for EnvGuard {
        fn drop(&mut self) {
            for (k, prev) in self.keys.iter().zip(self.previous.iter()) {
                // SAFETY: ENV_LOCK serializes these test-only mutations.
                unsafe {
                    match prev {
                        Some(v) => env::set_var(k, v),
                        None => env::remove_var(k),
                    }
                }
            }
        }
    }

    // Env vars that clap may pick up; clear them so CLI-only args control parsing.
    const ENV_KEYS: &[&str] = &[
        "L1_HTTP",
        "L1_WS",
        "L2_HTTP",
        "L2_AUTH",
        "JWT_SECRET",
        "SHASTA_INBOX",
        "L1_BEACON",
        "L1_PROPOSER_PRIV_KEY",
        "L2_SUGGESTED_FEE_RECIPIENT",
        "SHASTA_PRECONF_WHITELIST",
    ];

    // Shared required args for common + driver flags.
    fn common_args() -> Vec<&'static str> {
        vec![
            "--l1.http",
            "http://localhost:8545",
            "--l2.http",
            "http://localhost:28545",
            "--l2.auth",
            "http://localhost:28551",
            "--jwt.secret",
            "/tmp/jwt.hex",
            "--shasta.inbox",
            "0x0000000000000000000000000000000000000000",
        ]
    }

    fn driver_args() -> Vec<&'static str> {
        vec!["--l1.beacon", "http://localhost:4000"]
    }

    fn proposer_args() -> Vec<&'static str> {
        vec![
            "--l1.proposerPrivKey",
            "0x0000000000000000000000000000000000000000000000000000000000000001",
            "--l2.suggestedFeeRecipient",
            "0x0000000000000000000000000000000000000001",
        ]
    }

    fn whitelist_extra_args() -> Vec<&'static str> {
        vec!["--shasta.preconf-whitelist", "0x0000000000000000000000000000000000000002"]
    }

    fn build_args(subcommand: &str, groups: &[&[&str]]) -> Vec<String> {
        let mut args = vec!["taiko-client".to_string(), subcommand.to_string()];
        for group in groups {
            args.extend(group.iter().map(|s| s.to_string()));
        }
        args
    }

    #[test]
    fn parse_proposer_subcommand() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _guard = EnvGuard::clear(ENV_KEYS);
        let args = build_args("proposer", &[&common_args(), &proposer_args()]);
        let cli = Cli::try_parse_from(&args).expect("proposer should parse");
        assert!(matches!(cli.subcommand, Commands::Proposer(_)));
    }

    #[test]
    fn parse_driver_subcommand() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _guard = EnvGuard::clear(ENV_KEYS);
        let args = build_args("driver", &[&common_args(), &driver_args()]);
        let cli = Cli::try_parse_from(&args).expect("driver should parse");
        assert!(matches!(cli.subcommand, Commands::Driver(_)));
    }

    #[test]
    fn parse_preconfirmation_driver_subcommand() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _guard = EnvGuard::clear(ENV_KEYS);
        let args = build_args("preconfirmation-driver", &[&common_args(), &driver_args()]);
        let cli = Cli::try_parse_from(&args).expect("preconfirmation-driver should parse");
        assert!(matches!(cli.subcommand, Commands::PreconfirmationDriver(_)));
    }

    #[test]
    fn parse_whitelist_preconfirmation_driver_subcommand() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _guard = EnvGuard::clear(ENV_KEYS);
        let args = build_args(
            "whitelist-preconfirmation-driver",
            &[&common_args(), &driver_args(), &whitelist_extra_args()],
        );
        let cli =
            Cli::try_parse_from(&args).expect("whitelist-preconfirmation-driver should parse");
        assert!(matches!(cli.subcommand, Commands::WhitelistPreconfirmationDriver(_)));
    }

    #[test]
    fn rejects_unknown_subcommand() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _guard = EnvGuard::clear(ENV_KEYS);
        let args = ["taiko-client", "unknown"];
        assert!(Cli::try_parse_from(args).is_err());
    }

    #[test]
    fn rejects_no_subcommand() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _guard = EnvGuard::clear(ENV_KEYS);
        let args = ["taiko-client"];
        assert!(Cli::try_parse_from(args).is_err());
    }

    #[test]
    fn rejects_driver_missing_required_beacon() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _guard = EnvGuard::clear(ENV_KEYS);
        // driver requires --l1.beacon; omit it
        let args = build_args("driver", &[&common_args()]);
        assert!(Cli::try_parse_from(&args).is_err());
    }

    #[test]
    fn rejects_proposer_missing_required_privkey() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _guard = EnvGuard::clear(ENV_KEYS);
        // proposer requires --l1.proposerPrivKey; omit it
        let args = build_args(
            "proposer",
            &[
                &common_args(),
                &["--l2.suggestedFeeRecipient", "0x0000000000000000000000000000000000000001"],
            ],
        );
        assert!(Cli::try_parse_from(&args).is_err());
    }

    #[test]
    fn rejects_whitelist_driver_missing_whitelist_address() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _guard = EnvGuard::clear(ENV_KEYS);
        // whitelist driver requires --shasta.preconf-whitelist; omit it
        let args =
            build_args("whitelist-preconfirmation-driver", &[&common_args(), &driver_args()]);
        assert!(Cli::try_parse_from(&args).is_err());
    }

    #[test]
    fn proposer_default_values() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _guard = EnvGuard::clear(ENV_KEYS);
        let args = build_args("proposer", &[&common_args(), &proposer_args()]);
        let cli = Cli::try_parse_from(&args).expect("proposer should parse");
        if let Commands::Proposer(cmd) = cli.subcommand {
            assert_eq!(cmd.proposer_flags.propose_interval, 12);
            assert_eq!(cmd.proposer_flags.gas_limit, None);
            assert!(!cmd.proposer_flags.use_engine_mode);
            assert_eq!(cmd.common_flags.verbosity, 2);
            assert!(!cmd.common_flags.metrics_enabled);
            assert_eq!(cmd.common_flags.metrics_port, 9090);
        } else {
            panic!("expected Proposer variant");
        }
    }

    #[test]
    fn driver_default_values() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _guard = EnvGuard::clear(ENV_KEYS);
        let args = build_args("driver", &[&common_args(), &driver_args()]);
        let cli = Cli::try_parse_from(&args).expect("driver should parse");
        if let Commands::Driver(cmd) = cli.subcommand {
            assert_eq!(cmd.driver_flags.retry_interval(), std::time::Duration::from_secs(12));
            assert_eq!(cmd.driver_flags.l2_checkpoint_endpoint, None);
            assert_eq!(cmd.driver_flags.blob_server_endpoint, None);
        } else {
            panic!("expected Driver variant");
        }
    }
}

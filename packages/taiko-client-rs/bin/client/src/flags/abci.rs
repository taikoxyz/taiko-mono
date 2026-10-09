//! `abci` subcommand flags.

use std::{path::PathBuf, time::Duration};

use abci::{AppOptions, ListenAddr, server::DEFAULT_ADDR};
use clap::Parser;

/// Flags of the `abci` subcommand (besides the common ones).
#[derive(Parser, Clone, Debug, PartialEq, Eq)]
pub struct AbciArgs {
    /// The ABCI socket CometBFT's `proxy_app` connects to: `tcp://<host>:<port>` or
    /// `unix://<path>`.
    #[clap(
        long = "abci.addr",
        env = "ABCI_ADDR",
        default_value = DEFAULT_ADDR,
        value_parser = parse_abci_addr,
        help = "ABCI socket CometBFT's proxy_app connects to: tcp://<host>:<port> or unix://<path>"
    )]
    pub addr: String,
    /// Directory of the persisted app state (`abci-state.json`); created when missing.
    #[clap(
        long = "data-dir",
        env = "ABCI_DATA_DIR",
        required = true,
        help = "Directory of the persisted app state (abci-state.json); created when missing"
    )]
    pub data_dir: PathBuf,
    /// Optional TOML file overriding the built-in chain parameters (devnet only).
    #[clap(
        long = "chain-config",
        env = "ABCI_CHAIN_CONFIG",
        help = "Optional TOML file overriding the built-in chain parameters (devnet only)"
    )]
    pub chain_config: Option<PathBuf>,
    /// Deadline of one L1 read, in seconds.
    #[clap(
        long = "l1.timeout",
        env = "ABCI_L1_TIMEOUT",
        value_name = "SECONDS",
        default_value_t = AppOptions::default().l1_timeout.as_secs(),
        value_parser = clap::value_parser!(u64).range(1..),
        help = "Deadline of one L1 read (finality check, header or proof), in seconds"
    )]
    pub l1_timeout_secs: u64,
    /// Deadline of one Engine API or EL RPC call, in seconds.
    #[clap(
        long = "engine.timeout",
        env = "ABCI_ENGINE_TIMEOUT",
        value_name = "SECONDS",
        default_value_t = AppOptions::default().engine_timeout.as_secs(),
        value_parser = clap::value_parser!(u64).range(1..),
        help = "Deadline of one Engine API or EL RPC call, in seconds"
    )]
    pub engine_timeout_secs: u64,
    /// Deadline of an EL sync to a trusted head, in seconds.
    #[clap(
        long = "elsync.timeout",
        env = "ABCI_ELSYNC_TIMEOUT",
        value_name = "SECONDS",
        default_value_t = AppOptions::default().elsync_timeout.as_secs(),
        value_parser = clap::value_parser!(u64).range(1..),
        help = "Deadline of an execution-layer sync to a trusted head (devp2p download \
                included), in seconds"
    )]
    pub elsync_timeout_secs: u64,
    /// Overall deadline of one `PrepareProposal`, in seconds; must stay below CometBFT's
    /// `timeout_propose`.
    #[clap(
        long = "prepare.timeout",
        env = "ABCI_PREPARE_TIMEOUT",
        value_name = "SECONDS",
        default_value_t = AppOptions::default().prepare_timeout.as_secs(),
        value_parser = clap::value_parser!(u64).range(1..),
        help = "Overall deadline of one PrepareProposal (L1 reads and the block build), in \
                seconds; must stay below CometBFT's timeout_propose"
    )]
    pub prepare_timeout_secs: u64,
}

impl AbciArgs {
    /// The app's call deadlines.
    pub fn app_options(&self) -> AppOptions {
        AppOptions {
            l1_timeout: Duration::from_secs(self.l1_timeout_secs),
            engine_timeout: Duration::from_secs(self.engine_timeout_secs),
            elsync_timeout: Duration::from_secs(self.elsync_timeout_secs),
            prepare_timeout: Duration::from_secs(self.prepare_timeout_secs),
        }
    }
}

/// Accepts `addr` iff it is a valid [`ListenAddr`].
fn parse_abci_addr(addr: &str) -> Result<String, String> {
    ListenAddr::parse(addr).map(|_| addr.to_string()).map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use clap::{Parser, error::ErrorKind};

    use super::*;
    use crate::{
        cli::{Cli, Commands},
        commands::abci::AbciSubCommand,
        flags::test_env::{ENV_LOCK, EnvGuard},
    };

    /// Every environment variable the `abci` subcommand reads, unset.
    fn clear_env() -> Vec<EnvGuard> {
        [
            "ABCI_ADDR",
            "ABCI_DATA_DIR",
            "ABCI_CHAIN_CONFIG",
            "ABCI_L1_TIMEOUT",
            "ABCI_ENGINE_TIMEOUT",
            "ABCI_ELSYNC_TIMEOUT",
            "ABCI_PREPARE_TIMEOUT",
            "L1_HTTP",
            "L2_HTTP",
            "L2_AUTH",
            "JWT_SECRET",
        ]
        .into_iter()
        .map(EnvGuard::unset)
        .collect()
    }

    /// `taiko-client abci` with the common endpoints and `extra`.
    fn argv(extra: &[&'static str]) -> Vec<&'static str> {
        let mut argv = vec![
            "taiko-client",
            "abci",
            "--l1.http",
            "http://localhost:8545",
            "--l2.http",
            "http://localhost:28545",
            "--l2.auth",
            "http://localhost:28551",
            "--jwt.secret",
            "/tmp/jwt.hex",
        ];
        argv.extend_from_slice(extra);
        argv
    }

    /// Parses `argv` and returns the `abci` subcommand.
    fn parse(argv: Vec<&'static str>) -> Result<AbciSubCommand, clap::Error> {
        match Cli::try_parse_from(argv)?.subcommand {
            Commands::Abci(cmd) => Ok(*cmd),
            other => panic!("expected abci, got {other:?}"),
        }
    }

    #[test]
    fn parses_required_flags_with_defaults() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _clear = clear_env();
        let cmd = parse(argv(&["--data-dir", "/var/lib/abci"])).expect("abci parses");

        let flags = &cmd.abci_flags;
        assert_eq!(flags.addr, DEFAULT_ADDR);
        assert_eq!(flags.data_dir, PathBuf::from("/var/lib/abci"));
        assert_eq!(flags.chain_config, None);
        assert_eq!(flags.app_options(), AppOptions::default());
        assert_eq!(cmd.common_flags.l2_http_endpoint.as_str(), "http://localhost:28545/");
    }

    #[test]
    fn parses_every_flag() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _clear = clear_env();
        let cmd = parse(argv(&[
            "--data-dir",
            "/data",
            "--abci.addr",
            "unix:///run/abci.sock",
            "--chain-config",
            "/etc/chain.toml",
            "--l1.timeout",
            "4",
            "--engine.timeout",
            "6",
            "--elsync.timeout",
            "60",
            "--prepare.timeout",
            "1",
        ]))
        .expect("abci parses");

        let flags = &cmd.abci_flags;
        assert_eq!(flags.addr, "unix:///run/abci.sock");
        assert_eq!(flags.chain_config, Some(PathBuf::from("/etc/chain.toml")));
        assert_eq!(
            flags.app_options(),
            AppOptions {
                l1_timeout: Duration::from_secs(4),
                engine_timeout: Duration::from_secs(6),
                elsync_timeout: Duration::from_secs(60),
                prepare_timeout: Duration::from_secs(1),
            }
        );
    }

    #[test]
    fn parses_flags_from_env() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _clear = clear_env();
        let _env = [
            EnvGuard::set("ABCI_ADDR", "tcp://0.0.0.0:36658"),
            EnvGuard::set("ABCI_DATA_DIR", "/env/data"),
            EnvGuard::set("ABCI_CHAIN_CONFIG", "/env/chain.toml"),
            EnvGuard::set("ABCI_L1_TIMEOUT", "7"),
            EnvGuard::set("ABCI_ENGINE_TIMEOUT", "8"),
            EnvGuard::set("ABCI_ELSYNC_TIMEOUT", "9"),
            EnvGuard::set("ABCI_PREPARE_TIMEOUT", "1"),
            EnvGuard::set("L1_HTTP", "http://localhost:8545"),
            EnvGuard::set("L2_HTTP", "http://localhost:28545"),
            EnvGuard::set("L2_AUTH", "http://localhost:28551"),
            EnvGuard::set("JWT_SECRET", "/tmp/jwt.hex"),
        ];
        let cmd = parse(vec!["taiko-client", "abci"]).expect("env-backed abci parses");

        let flags = &cmd.abci_flags;
        assert_eq!(flags.addr, "tcp://0.0.0.0:36658");
        assert_eq!(flags.data_dir, PathBuf::from("/env/data"));
        assert_eq!(flags.chain_config, Some(PathBuf::from("/env/chain.toml")));
        assert_eq!(
            flags.app_options(),
            AppOptions {
                l1_timeout: Duration::from_secs(7),
                engine_timeout: Duration::from_secs(8),
                elsync_timeout: Duration::from_secs(9),
                prepare_timeout: Duration::from_secs(1),
            }
        );
        assert_eq!(cmd.common_flags.l1_http_endpoint.as_str(), "http://localhost:8545/");
    }

    #[test]
    fn missing_data_dir_fails() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _clear = clear_env();
        let err = parse(argv(&[])).expect_err("--data-dir is required");
        assert_eq!(err.kind(), ErrorKind::MissingRequiredArgument);
        assert!(err.to_string().contains("--data-dir"), "{err}");
    }

    #[test]
    fn rejects_invalid_addresses_and_zero_timeouts() {
        let _lock = ENV_LOCK.lock().expect("env lock poisoned");
        let _clear = clear_env();
        for extra in [
            ["--abci.addr", "127.0.0.1:26658"],
            ["--abci.addr", "http://127.0.0.1:26658"],
            ["--l1.timeout", "0"],
            ["--engine.timeout", "0"],
            ["--elsync.timeout", "0"],
            ["--prepare.timeout", "0"],
        ] {
            let mut args = vec!["--data-dir", "/data"];
            args.extend(extra);
            let err = parse(argv(&args)).expect_err("invalid value");
            assert_eq!(err.kind(), ErrorKind::ValueValidation, "{extra:?}: {err}");
        }
    }
}

//! `abci-genesis` subcommand: writes the Etna PoS chain's CometBFT `genesis.json` from the
//! Ethereum-final activation record on L1.

use std::{io::Write, path::PathBuf};

use abci::{RpcL1Source, build_genesis};
use clap::Parser;
use rpc::client::{DEFAULT_HTTP_TIMEOUT, connect_http_with_timeout};
use tracing::info;
use tracing_subscriber::EnvFilter;
use url::Url;

use crate::{
    commands::load_chain_params,
    error::{CliError, Result},
    flags::common::http_url,
};

/// Command-line interface of the genesis builder.
#[derive(Parser, Clone, Debug, PartialEq, Eq)]
#[command(
    about = "Writes the CometBFT genesis.json of the Etna PoS chain from the L1 activation record"
)]
pub struct AbciGenesisSubCommand {
    /// HTTP RPC endpoint of the L1 node; it must serve `eth_getProof` and `eth_getStorageAt`
    /// at the activation block and back to the Inbox's `genesisCutoff` (the registry entries are
    /// read at the newest block that still holds the genesis snapshot, which can be as old as
    /// `genesisCutoff`). The cutoff is fixed when the activating DAO proposal is written, well
    /// before the activation block, so in practice this is an archive node.
    #[clap(
        long = "l1.http",
        required = true,
        value_parser = http_url,
        help = "HTTP RPC endpoint of an L1 node serving eth_getProof and eth_getStorageAt from \
                the activation block back to the Inbox's genesisCutoff, which the activating DAO \
                proposal fixed well before it (in practice an archive node)"
    )]
    pub l1_http: Url,
    /// The L2 chain id whose built-in chain parameters apply; no L2 node is contacted.
    #[clap(
        long = "l2.chain-id",
        required = true,
        help = "L2 chain id selecting the built-in chain parameters (no L2 node is contacted)"
    )]
    pub l2_chain_id: u64,
    /// Optional TOML file overriding the built-in chain parameters (devnet only).
    #[clap(
        long = "chain-config",
        help = "Optional TOML file overriding the built-in chain parameters (devnet only)"
    )]
    pub chain_config: Option<PathBuf>,
    /// Where to write `genesis.json`; standard output when absent.
    #[clap(long = "out", help = "Path of the genesis.json to write (default: standard output)")]
    pub out: Option<PathBuf>,
}

impl AbciGenesisSubCommand {
    /// Builds the genesis from L1 and writes it as pretty JSON with a trailing newline.
    ///
    /// Logs go to standard error, so the JSON on standard output stays clean.
    pub async fn run(&self) -> Result<()> {
        let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
        let _ = tracing_subscriber::fmt()
            .with_env_filter(filter)
            .with_writer(std::io::stderr)
            .try_init();

        let params = load_chain_params(self.l2_chain_id, self.chain_config.as_deref())?;
        let l1 =
            RpcL1Source::new(connect_http_with_timeout(self.l1_http.clone(), DEFAULT_HTTP_TIMEOUT));
        let doc = build_genesis(&l1, &params).await?;
        let mut json = doc.to_json_pretty();
        json.push('\n');
        match &self.out {
            Some(path) => std::fs::write(path, json)
                .map_err(|source| CliError::GenesisWrite { path: path.clone(), source })?,
            None => std::io::stdout().lock().write_all(json.as_bytes())?,
        }
        info!(
            chain_id = %doc.chain_id,
            initial_height = %doc.initial_height,
            genesis_time = %doc.genesis_time,
            validators = doc.validators.len(),
            "genesis built"
        );
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use clap::{Parser, error::ErrorKind};

    use super::*;
    use crate::cli::{Cli, Commands};

    /// Parses `argv` and returns the `abci-genesis` subcommand.
    fn parse(argv: &[&str]) -> std::result::Result<AbciGenesisSubCommand, clap::Error> {
        match Cli::try_parse_from(argv)?.subcommand {
            Commands::AbciGenesis(cmd) => Ok(*cmd),
            other => panic!("expected abci-genesis, got {other:?}"),
        }
    }

    #[test]
    fn parses_required_flags_with_defaults() {
        let cmd = parse(&[
            "taiko-client",
            "abci-genesis",
            "--l1.http",
            "http://localhost:8545",
            "--l2.chain-id",
            "167001",
        ])
        .expect("abci-genesis parses");
        assert_eq!(
            cmd,
            AbciGenesisSubCommand {
                l1_http: Url::parse("http://localhost:8545").unwrap(),
                l2_chain_id: 167_001,
                chain_config: None,
                out: None,
            }
        );
    }

    #[test]
    fn parses_every_flag() {
        let cmd = parse(&[
            "taiko-client",
            "abci-genesis",
            "--l1.http",
            "http://l1:8545",
            "--l2.chain-id",
            "7",
            "--chain-config",
            "/etc/chain.toml",
            "--out",
            "/cometbft/config/genesis.json",
        ])
        .expect("abci-genesis parses");
        assert_eq!(cmd.chain_config, Some(PathBuf::from("/etc/chain.toml")));
        assert_eq!(cmd.out, Some(PathBuf::from("/cometbft/config/genesis.json")));
        assert_eq!(cmd.l2_chain_id, 7);
    }

    #[test]
    fn missing_or_malformed_flags_fail() {
        let missing_chain_id = parse(&["taiko-client", "abci-genesis", "--l1.http", "http://l1"]);
        let err = missing_chain_id.expect_err("--l2.chain-id is required");
        assert_eq!(err.kind(), ErrorKind::MissingRequiredArgument);
        assert!(err.to_string().contains("--l2.chain-id"), "{err}");

        let missing_l1 = parse(&["taiko-client", "abci-genesis", "--l2.chain-id", "7"]);
        let err = missing_l1.expect_err("--l1.http is required");
        assert_eq!(err.kind(), ErrorKind::MissingRequiredArgument);
        assert!(err.to_string().contains("--l1.http"), "{err}");

        for (l1, chain_id) in [
            ("http://l1", "-1"),
            ("http://l1", "devnet"),
            ("not a url", "7"),
            ("ws://l1:8546", "7"),
        ] {
            let argv = ["taiko-client", "abci-genesis", "--l1.http", l1, "--l2.chain-id", chain_id];
            let err = parse(&argv).expect_err("invalid value");
            assert!(
                matches!(err.kind(), ErrorKind::ValueValidation | ErrorKind::UnknownArgument),
                "{argv:?}: {err}"
            );
        }
    }
}

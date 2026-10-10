//! `abci-committee-record` subcommand: computes the `committeeRecordHash` an Etna activation
//! takes for a chosen `genesisCutoff`, from the staking registry on L1, before the activating DAO
//! proposal is written.

use std::{fmt::Write as _, io::Write as _, path::PathBuf};

use abci::{GenesisCommitteeRecord, RpcL1Source, build_committee_record};
use clap::Parser;
use rpc::client::{DEFAULT_HTTP_TIMEOUT, connect_http_with_timeout};
use tracing::info;
use tracing_subscriber::EnvFilter;
use url::Url;

use crate::{commands::load_chain_params, error::Result, flags::common::http_url};

/// Command-line interface of the activation committee record tool.
#[derive(Parser, Clone, Debug, PartialEq, Eq)]
#[command(
    about = "Computes the committeeRecordHash an Etna activation takes for a genesis cutoff, from \
             the staking registry on L1"
)]
pub struct AbciCommitteeRecordSubCommand {
    /// HTTP RPC endpoint of the L1 node; it must serve `eth_getProof` and `eth_getStorageAt` at
    /// the proving block and back to the genesis cutoff (the registry entries are read at the
    /// newest block that still holds the snapshot, which can be as old as the cutoff).
    #[clap(
        long = "l1.http",
        required = true,
        value_parser = http_url,
        help = "HTTP RPC endpoint of an L1 node serving eth_getProof and eth_getStorageAt from \
                the proving block back to the genesis cutoff (an archive node for an old cutoff)"
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
    /// The `genesisCutoff` the activation will pass: the L1 block whose registry snapshot defines
    /// the genesis committee. It must be at or before the L1 `finalized` block, as the activation
    /// fixes it irreversibly.
    #[clap(
        long = "genesis-cutoff",
        required = true,
        help = "L1 block of the genesis committee's registry snapshot (activateEtna's \
                genesisCutoff), at or before the L1 finalized block"
    )]
    pub genesis_cutoff: u64,
    /// The L1 block the snapshot is read and proven at; must be after the cutoff. The L1
    /// `finalized` block when absent.
    #[clap(
        long = "at",
        help = "L1 block to read and prove the snapshot at, after the cutoff (default: the L1 \
                finalized block)"
    )]
    pub at: Option<u64>,
    /// Print the report as JSON instead of plain text.
    #[clap(long = "json", help = "Print the report as JSON instead of plain text")]
    pub json: bool,
}

impl AbciCommitteeRecordSubCommand {
    /// Computes the record from L1 and prints the report (plain text, or JSON with `--json`)
    /// with a trailing newline.
    ///
    /// Logs go to standard error, so the report on standard output stays clean.
    pub async fn run(&self) -> Result<()> {
        let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
        let _ = tracing_subscriber::fmt()
            .with_env_filter(filter)
            .with_writer(std::io::stderr)
            .try_init();

        let params = load_chain_params(self.l2_chain_id, self.chain_config.as_deref())?;
        let l1 =
            RpcL1Source::new(connect_http_with_timeout(self.l1_http.clone(), DEFAULT_HTTP_TIMEOUT));
        let report = build_committee_record(&l1, &params, self.genesis_cutoff, self.at).await?;
        let mut out = if self.json { report.to_json_pretty() } else { render_text(&report) };
        out.push('\n');
        std::io::stdout().lock().write_all(out.as_bytes())?;
        info!(
            record_hash = %report.record_hash,
            genesis_cutoff = self.genesis_cutoff,
            proving_block = report.proving_block,
            members = report.members.len(),
            "committee record computed"
        );
        Ok(())
    }
}

/// The plain-text report: the record hash, the snapshot, each member and the totals, one fact
/// per line (no trailing newline).
fn render_text(report: &GenesisCommitteeRecord) -> String {
    let record = &report.record;
    let mut out = String::new();
    // Writing to a `String` cannot fail.
    let _ = writeln!(out, "committeeRecordHash: {}", report.record_hash);
    let _ = writeln!(out, "genesisCutoff:       {}", record.cutoff_l1_block);
    let _ = writeln!(out, "checkpointIndex:     {}", record.checkpoint_index);
    let _ = writeln!(out, "provingBlock:        {}", report.proving_block);
    let _ = writeln!(out, "members:             {}", report.members.len());
    for member in &report.members {
        let _ = writeln!(out, "  {} power {}", member.pubkey, member.power);
    }
    let _ = writeln!(out, "totalPower:          {}", record.total_power);
    let _ = writeln!(out, "totalStake:          {}", record.total_stake);
    let _ = write!(
        out,
        "minL1_0:             {} (first activation block whose lagged cutoff reaches the genesis \
         cutoff; informational, the node floors later cutoffs at the genesis cutoff)",
        report.min_l1_0.map_or_else(|| "overflows u64".to_string(), |n| n.to_string())
    );
    out
}

#[cfg(test)]
mod tests {
    use abci::{CommitteeRecord, Member};
    use clap::{Parser, error::ErrorKind};

    use super::*;
    use crate::cli::{Cli, Commands};

    /// Parses `argv` and returns the `abci-committee-record` subcommand.
    fn parse(argv: &[&str]) -> std::result::Result<AbciCommitteeRecordSubCommand, clap::Error> {
        match Cli::try_parse_from(argv)?.subcommand {
            Commands::AbciCommitteeRecord(cmd) => Ok(*cmd),
            other => panic!("expected abci-committee-record, got {other:?}"),
        }
    }

    #[test]
    fn parses_required_flags_with_defaults() {
        let cmd = parse(&[
            "taiko-client",
            "abci-committee-record",
            "--l1.http",
            "http://localhost:8545",
            "--l2.chain-id",
            "167001",
            "--genesis-cutoff",
            "63",
        ])
        .expect("abci-committee-record parses");
        assert_eq!(
            cmd,
            AbciCommitteeRecordSubCommand {
                l1_http: Url::parse("http://localhost:8545").unwrap(),
                l2_chain_id: 167_001,
                chain_config: None,
                genesis_cutoff: 63,
                at: None,
                json: false,
            }
        );
    }

    #[test]
    fn parses_every_flag() {
        let cmd = parse(&[
            "taiko-client",
            "abci-committee-record",
            "--l1.http",
            "https://l1:8545",
            "--l2.chain-id",
            "7",
            "--chain-config",
            "/etc/chain.toml",
            "--genesis-cutoff",
            "100",
            "--at",
            "120",
            "--json",
        ])
        .expect("abci-committee-record parses");
        assert_eq!(cmd.chain_config, Some(PathBuf::from("/etc/chain.toml")));
        assert_eq!((cmd.genesis_cutoff, cmd.at, cmd.json), (100, Some(120), true));
    }

    #[test]
    fn missing_or_malformed_flags_fail() {
        let base = ["taiko-client", "abci-committee-record"];
        for missing in ["--l1.http", "--l2.chain-id", "--genesis-cutoff"] {
            let mut argv = base.to_vec();
            for (flag, value) in
                [("--l1.http", "http://l1"), ("--l2.chain-id", "7"), ("--genesis-cutoff", "63")]
            {
                if flag != missing {
                    argv.extend([flag, value]);
                }
            }
            let err = parse(&argv).expect_err("a required flag is missing");
            assert_eq!(err.kind(), ErrorKind::MissingRequiredArgument, "{missing}");
            assert!(err.to_string().contains(missing), "{err}");
        }

        for (l1, cutoff, at) in [
            ("ws://l1:8546", "63", "64"),
            ("http://l1", "-1", "64"),
            ("http://l1", "latest", "64"),
            ("http://l1", "63", "finalized"),
        ] {
            let argv = [
                "taiko-client",
                "abci-committee-record",
                "--l1.http",
                l1,
                "--l2.chain-id",
                "7",
                "--genesis-cutoff",
                cutoff,
                "--at",
                at,
            ];
            let err = parse(&argv).expect_err("invalid value");
            assert!(
                matches!(err.kind(), ErrorKind::ValueValidation | ErrorKind::UnknownArgument),
                "{argv:?}: {err}"
            );
        }
    }

    /// A 32-byte hex word of `byte` repeated, `0x`-prefixed.
    fn word(byte: &str) -> String {
        format!("0x{}", byte.repeat(32))
    }

    #[test]
    fn renders_the_report_one_fact_per_line() {
        let member = |byte: &str, stake: &str, power| Member {
            pubkey: word(byte).parse().unwrap(),
            eff_stake: stake.parse().unwrap(),
            power,
        };
        let report = GenesisCommitteeRecord {
            record_hash: word("ab").parse().unwrap(),
            record: CommitteeRecord {
                target_epoch: 0,
                cutoff_l1_block: 63,
                checkpoint_index: 2,
                set_root: word("5e").parse().unwrap(),
                total_stake: "3000000000000000000".parse().unwrap(),
                total_power: 3_000_000_000,
                encoding_version: 1,
            },
            members: vec![
                member("11", "1000000000000000000", 1_000_000_000),
                member("22", "2000000000000000000", 2_000_000_000),
            ],
            proving_block: 64,
            min_l1_0: Some(64),
        };
        let text = render_text(&report);
        let lines: Vec<&str> = text.lines().collect();
        assert_eq!(lines[0], format!("committeeRecordHash: {}", word("ab")));
        assert_eq!(lines[1], "genesisCutoff:       63");
        assert_eq!(lines[2], "checkpointIndex:     2");
        assert_eq!(lines[3], "provingBlock:        64");
        assert_eq!(lines[4], "members:             2");
        assert_eq!(lines[5], format!("  {} power 1000000000", word("11")));
        assert_eq!(lines[6], format!("  {} power 2000000000", word("22")));
        assert_eq!(lines[7], "totalPower:          3000000000");
        assert_eq!(lines[8], "totalStake:          3000000000000000000");
        assert!(lines[9].starts_with("minL1_0:             64 ("), "{}", lines[9]);
        assert_eq!(lines.len(), 10);
        assert!(!text.ends_with('\n'));

        let none = render_text(&GenesisCommitteeRecord { min_l1_0: None, ..report });
        assert!(none.contains("minL1_0:             overflows u64"), "{none}");
    }
}

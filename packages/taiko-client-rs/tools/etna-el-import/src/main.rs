#![deny(missing_docs, clippy::missing_docs_in_private_items)]
//! Internal offline EL operations over caller-authenticated roots; no service is started.

use alloy_genesis::Genesis;
use alloy_primitives::B256;
use clap::{Args, Parser, Subcommand};
use etna_el_import::{
    DatasetReport, ElTrust, HeaderManifest, ImportError, install_dataset,
    install_dataset_with_scratch,
};
use std::{
    fs::File,
    io::{Read, Write},
    path::{Path, PathBuf},
    process::ExitCode,
};

/// Local JSON capacity, independent of a publisher's claimed file length.
const JSON_LIMIT: u64 = 256 * 1024 * 1024;

/// Command parser for the private helper process.
#[derive(Parser)]
#[command(version, about)]
struct Cli {
    /// One installation from a stopped source into a fresh datadir.
    #[command(subcommand)]
    operation: Operation,
}

/// A successful install still leaves chain trust and signing to the parent application.
#[derive(Subcommand)]
enum Operation {
    /// Copy a stopped EL datadir, verify its state against the trusted root and build a pruned
    /// normal-provider-compatible datadir, without adopting old histories.
    Install(Inputs),
}

/// Separate trusted roots are mandatory and cannot default to publisher metadata.
#[derive(Args)]
struct Inputs {
    /// Stopped EL datadir whose `db/{mdbx.dat,database.version}` are copied; never written.
    #[arg(long)]
    source: PathBuf,
    /// Absent absolute directory that the install creates.
    #[arg(long)]
    datadir: PathBuf,
    /// Existing directory outside the source for private offline work, cleaned on success or
    /// failure; defaults to the new datadir.
    #[arg(long)]
    scratch_parent: Option<PathBuf>,
    /// Operator's original EL runtime Genesis JSON, distinct from Comet genesis.
    #[arg(long)]
    chain: PathBuf,
    /// Strict authenticated ascending header context issued by the Rust verifier.
    #[arg(long)]
    manifest: PathBuf,
    /// L2 chain identity already checked by the caller's RPC/configuration binding.
    #[arg(long)]
    chain_id: u64,
    /// Selected EL hash authenticated against own finalized L1.
    #[arg(long)]
    trusted_el_hash: B256,
    /// Terminal header state root authenticated by the caller.
    #[arg(long)]
    trusted_state_root: B256,
    /// Original EL genesis hash from authenticated deployment facts.
    #[arg(long)]
    trusted_genesis_hash: B256,
}

/// Read bounded JSON without echoing input contents into diagnostics.
fn load<T: serde::de::DeserializeOwned>(path: &Path) -> Result<T, ImportError> {
    let file = File::open(path)?;
    let metadata = file.metadata()?;
    if !metadata.is_file() || metadata.len() > JSON_LIMIT {
        return Err(ImportError::Invalid("unsupported or oversized local JSON input"));
    }
    let mut bytes = Vec::new();
    file.take(JSON_LIMIT + 1).read_to_end(&mut bytes)?;
    if bytes.len() as u64 > JSON_LIMIT {
        return Err(ImportError::Invalid("local JSON input exceeded its capacity"));
    }
    serde_json::from_slice(&bytes).map_err(|_| ImportError::Invalid("invalid local JSON input"))
}

/// Run one complete offline install with independently supplied expected identities.
fn execute(operation: Operation) -> Result<DatasetReport, ImportError> {
    let Operation::Install(inputs) = operation;
    let genesis: Genesis = load(&inputs.chain)?;
    let manifest: HeaderManifest = load(&inputs.manifest)?;
    let trust = ElTrust {
        chain_id: inputs.chain_id,
        genesis_hash: inputs.trusted_genesis_hash,
        terminal_hash: inputs.trusted_el_hash,
        state_root: inputs.trusted_state_root,
    };
    let (source, datadir) = (&inputs.source, &inputs.datadir);
    match inputs.scratch_parent.as_deref() {
        Some(parent) => {
            install_dataset_with_scratch(source, datadir, &genesis, &manifest, &trust, parent)
        }
        None => install_dataset(source, datadir, &genesis, &manifest, &trust),
    }
}

/// Emit exactly one receipt on success; every failure keeps parent publication closed.
fn main() -> ExitCode {
    let outcome = execute(Cli::parse().operation).and_then(|receipt| {
        let mut output = std::io::stdout().lock();
        serde_json::to_writer(&mut output, &receipt)?;
        output.write_all(b"\n")?;
        Ok(())
    });
    match outcome {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("{error}");
            match error {
                ImportError::Incomplete(_) | ImportError::Io(_) | ImportError::Database(_) => {
                    ExitCode::from(3)
                }
                ImportError::Json(e) if e.is_io() => ExitCode::from(3),
                ImportError::Invalid(_) | ImportError::StateRoot { .. } | ImportError::Json(_) => {
                    ExitCode::FAILURE
                }
            }
        }
    }
}

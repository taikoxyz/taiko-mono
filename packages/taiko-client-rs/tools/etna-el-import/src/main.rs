#![deny(missing_docs, clippy::missing_docs_in_private_items)]
//! Internal offline EL operations over caller-authenticated roots; no service is started.

use alloy_genesis::Genesis;
use alloy_primitives::B256;
use clap::{Args, Parser, Subcommand};
use etna_el_import::{
    DatasetReport, ElTrust, HeaderManifest, ImportError, install_dataset,
    install_dataset_with_scratch, verify_dataset, verify_dataset_with_scratch,
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
    /// Read-only verification or installation into privately claimed unpublished staging.
    #[command(subcommand)]
    operation: Operation,
}

/// Every successful operation still leaves chain trust and signing to the parent application.
#[derive(Subcommand)]
enum Operation {
    /// Recompute actual account/storage/code state without adopting old histories.
    Verify(Inputs),
    /// Build a pruned normal-provider-compatible component in owned offline staging.
    Install(Inputs),
}

/// Separate trusted roots are mandatory and cannot default to publisher metadata.
#[derive(Args)]
struct Inputs {
    /// Canonical effective EL directory, with a private lifecycle claim for install.
    #[arg(long)]
    datadir: PathBuf,
    /// Existing external directory for private offline work, cleaned on success or failure.
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

/// Dispatch one complete offline operation with independently supplied expected identities.
fn execute(operation: Operation) -> Result<DatasetReport, ImportError> {
    let (inputs, install) = match operation {
        Operation::Verify(inputs) => (inputs, false),
        Operation::Install(inputs) => (inputs, true),
    };
    let genesis: Genesis = load(&inputs.chain)?;
    let manifest: HeaderManifest = load(&inputs.manifest)?;
    let trust = ElTrust {
        chain_id: inputs.chain_id,
        genesis_hash: inputs.trusted_genesis_hash,
        terminal_hash: inputs.trusted_el_hash,
        state_root: inputs.trusted_state_root,
    };
    match (install, inputs.scratch_parent.as_deref()) {
        (true, Some(parent)) => {
            install_dataset_with_scratch(&inputs.datadir, &genesis, &manifest, &trust, parent)
        }
        (false, Some(parent)) => {
            verify_dataset_with_scratch(&inputs.datadir, &genesis, &manifest, &trust, parent)
        }
        (true, None) => install_dataset(&inputs.datadir, &genesis, &manifest, &trust),
        (false, None) => verify_dataset(&inputs.datadir, &genesis, &manifest, &trust),
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
            ExitCode::FAILURE
        }
    }
}

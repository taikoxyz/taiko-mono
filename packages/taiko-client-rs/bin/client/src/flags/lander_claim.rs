//! Explicit public endpoints and the independent L2 gas-payer key.
use super::common::http_url;
use alloy_primitives::B256;
use clap::Parser;
use std::path::PathBuf;
use url::Url;

/// Claim options deliberately have no payout-recipient override.
#[derive(Parser, Clone, Debug)]
pub struct LanderClaimArgs {
    /// Own finalized L1 RPC.
    #[arg(long = "l1.http", value_parser = http_url)]
    pub l1_http: Url,
    /// Own canonical executed L2 RPC.
    #[arg(long = "l2.http", value_parser = http_url)]
    pub l2_http: Url,
    /// Successful L1 transaction containing BatchRewardRecorded.
    #[arg(long)]
    pub landing_tx: B256,
    /// Exact immutable reward batch identifier.
    #[arg(long)]
    pub batch_id: B256,
    /// Explicit L2 gas-payer private-key file; never journaled.
    #[arg(long)]
    pub key_file: PathBuf,
    /// Dedicated claim directory, distinct from any landing directory.
    #[arg(long)]
    pub data_dir: PathBuf,
    /// Deadline for each RPC and ordinary reconciliation, in seconds.
    #[arg(long = "rpc.timeout", default_value = "30", value_parser = clap::value_parser!(u64).range(1..=3600))]
    pub rpc_timeout: u64,
    /// Independent total historical discovery and EL ancestry deadline, in seconds.
    #[arg(long = "finality.timeout", default_value = "300", value_parser = clap::value_parser!(u64).range(1..=3600))]
    pub finality_timeout: u64,
}

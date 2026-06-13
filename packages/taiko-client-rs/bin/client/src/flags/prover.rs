//! Prover-specific CLI flags.
//!
//! Every flag keeps the Go prover's env var name so existing operator configs
//! port over unchanged.

use alloy_primitives::{Address, B256};
use clap::Parser;

#[derive(Parser, Clone, Debug, PartialEq, Eq)]
/// CLI flags specific to prover operation.
pub struct ProverArgs {
    /// Private key of the L1 prover, who signs and sends `Inbox.prove` txs.
    #[clap(
        long = "l1.proverPrivKey",
        env = "L1_PROVER_PRIV_KEY",
        required = true,
        help = "Private key of the L1 prover, who will send transactions to prove proposals on the inbox"
    )]
    pub l1_prover_private_key: B256,
    /// raiko base host endpoint (the SGX compose path).
    #[clap(
        long = "raiko.host",
        env = "RAIKO_HOST",
        required = true,
        help = "raiko host endpoint for the SGX compose proof path"
    )]
    pub raiko_host: url::Url,
    /// Optional raiko ZKVM host endpoint; enables the zk_any-first path.
    #[clap(
        long = "raiko.host.zkvm",
        env = "RAIKO_HOST_ZKVM",
        help = "Optional raiko ZKVM host endpoint; enables the zk_any proof path"
    )]
    pub raiko_zkvm_host: Option<url::Url>,
    /// Path to a file holding the raiko API key (sent as X-API-KEY).
    #[clap(
        long = "raiko.apiKeyPath",
        env = "RAIKO_API_KEY_PATH",
        help = "Path to a file holding the raiko API key"
    )]
    pub raiko_api_key_path: Option<std::path::PathBuf>,
    /// raiko per-request timeout in seconds.
    #[clap(
        long = "raiko.requestTimeout",
        env = "RAIKO_REQUEST_TIMEOUT",
        default_value = "600",
        help = "raiko per-request timeout in seconds"
    )]
    pub raiko_request_timeout_secs: u64,
    /// Optional first proposal id to start proving from.
    #[clap(
        long = "prover.startingProposalID",
        env = "STARTING_PROPOSAL_ID",
        help = "Optional first proposal id to start proving from"
    )]
    pub starting_proposal_id: Option<u64>,
    /// Prove proposals whose designated prover is someone else, after expiry.
    #[clap(
        long = "prover.proveUnassignedProposals",
        env = "PROVE_UNASSIGNED_PROPOSALS",
        default_value = "false",
        help = "Prove proposals whose designated prover is someone else, after the proving window expires"
    )]
    pub prove_unassigned_proposals: bool,
    /// Allowed proving range above the last finalized proposal (0 = unlimited).
    #[clap(
        long = "prover.proposal.window.size",
        env = "PROVER_PROPOSAL_WINDOW_SIZE",
        default_value = "0",
        help = "Allowed proving range above last finalized (0 = unlimited)"
    )]
    pub proposal_window_size: u64,
    /// Maximum proposal distance above last finalized for requesting ZK proofs.
    #[clap(
        long = "prover.maxZKProofProposalDistance",
        env = "PROVER_MAX_ZK_PROOF_PROPOSAL_DISTANCE",
        default_value = "30",
        help = "Maximum proposal distance above lastFinalizedProposalID for requesting ZK proofs; beyond it the prover requests the base proof instead"
    )]
    pub max_zk_proof_proposal_distance: u64,
    /// Produce filler proofs instead of calling raiko (tests/devnet).
    #[clap(
        long = "prover.dummy",
        env = "PROVER_DUMMY",
        default_value = "false",
        help = "Produce filler proofs instead of calling raiko"
    )]
    pub dummy: bool,
    /// raiko polling interval in seconds.
    #[clap(
        long = "prover.proofPollingInterval",
        env = "PROVER_PROOF_POLLING_INTERVAL",
        default_value = "10",
        help = "raiko polling interval in seconds"
    )]
    pub proof_polling_interval_secs: u64,
    /// Extra proposer addresses this prover proves for.
    #[clap(
        long = "prover.localProposerAddresses",
        env = "PROVER_LOCAL_PROPOSER_ADDRESSES",
        value_delimiter = ',',
        help = "Comma-separated proposer addresses this prover also proves for"
    )]
    pub local_proposer_addresses: Vec<Address>,
    /// L1 confirmations before handling a `Proposed` event.
    #[clap(
        long = "prover.blockConfirmations",
        env = "PROVER_BLOCK_CONFIRMATIONS",
        default_value = "6",
        help = "L1 confirmations before handling a Proposed event"
    )]
    pub block_confirmations: u64,
    /// Force aggregation of a non-empty buffer after this many seconds.
    #[clap(
        long = "prover.forceBatchProvingInterval",
        env = "PROVER_FORCE_BATCH_PROVING_INTERVAL",
        default_value = "1800",
        help = "Force aggregation of a non-empty buffer after this many seconds"
    )]
    pub force_batch_proving_interval_secs: u64,
    /// SGX proof buffer size.
    #[clap(
        long = "prover.sgx.batchSize",
        env = "PROVER_SGX_BATCH_SIZE",
        default_value = "1",
        help = "SGX proof buffer size before aggregation"
    )]
    pub sgx_batch_size: u64,
    /// ZK proof buffer size.
    #[clap(
        long = "prover.zkvm.batchSize",
        env = "PROVER_ZKVM_BATCH_SIZE",
        default_value = "1",
        help = "ZK proof buffer size before aggregation"
    )]
    pub zkvm_batch_size: u64,
    /// Run the full pipeline but skip L1 submission (rollout shadow gate).
    #[clap(
        long = "prover.shadowMode",
        env = "PROVER_SHADOW_MODE",
        default_value = "false",
        help = "Run the full pipeline (incl. raiko proof generation) but skip L1 submission"
    )]
    pub shadow_mode: bool,
    /// Interval in seconds between tx-manager resubmissions for an unconfirmed
    /// prove transaction.
    #[clap(
        long = "prove.retryInterval",
        env = "PROVE_RETRY_INTERVAL",
        default_value = "48",
        help = "Interval in seconds between tx-manager resubmissions for an unconfirmed prove transaction"
    )]
    pub retry_interval_secs: u64,
    /// Maximum seconds to wait for a prove transaction before giving up.
    #[clap(
        long = "prove.confirmationTimeout",
        env = "PROVE_CONFIRMATION_TIMEOUT",
        default_value = "180",
        help = "Maximum seconds to wait for a prove transaction before giving up"
    )]
    pub confirmation_timeout_secs: u64,
    /// Minimum priority fee floor in gwei for prove transactions.
    #[clap(
        long = "prove.minTipCap",
        env = "PROVE_MIN_TIP_CAP",
        default_value = "1",
        help = "Minimum priority fee floor in gwei for prove transactions"
    )]
    pub min_tip_cap_gwei: u64,
    /// Minimum base fee floor in gwei for prove transactions.
    #[clap(
        long = "prove.minBaseFee",
        env = "PROVE_MIN_BASE_FEE",
        default_value = "1",
        help = "Minimum base fee floor in gwei for prove transactions"
    )]
    pub min_base_fee_gwei: u64,
}

#[cfg(test)]
mod tests {
    use clap::{CommandFactory, Parser};

    use super::ProverArgs;

    #[test]
    fn prover_help_lists_raiko_and_shadow_flags() {
        let mut command = ProverArgs::command();
        let mut help = Vec::new();
        command.write_long_help(&mut help).expect("help rendering should succeed");
        let help = String::from_utf8(help).expect("clap help should be utf-8");

        assert!(help.contains("--raiko.host"));
        assert!(help.contains("--prover.dummy"));
        assert!(help.contains("--prover.shadowMode"));
        assert!(help.contains("--l1.proverPrivKey"));
        assert!(help.contains("--prover.maxZKProofProposalDistance"));
    }

    #[test]
    fn max_zk_proof_proposal_distance_defaults_to_30() {
        let args = ProverArgs::try_parse_from([
            "prover",
            "--l1.proverPrivKey",
            "0x0000000000000000000000000000000000000000000000000000000000000001",
            "--raiko.host",
            "http://localhost:8080",
        ])
        .expect("minimal prover args should parse");
        assert_eq!(args.max_zk_proof_proposal_distance, 30);
    }
}

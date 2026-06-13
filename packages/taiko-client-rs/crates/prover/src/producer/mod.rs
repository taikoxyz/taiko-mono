//! Proof pipeline types and producers.

use alloy_primitives::{Address, B256, Bytes};

use crate::raiko::ProofType;

/// On-chain verifier id for sgxgeth proofs (Go `prover/init.go:29`).
pub const SGX_GETH_VERIFIER_ID: u8 = 1;

/// On-chain verifier id for sgx (reth) proofs (Go `prover/init.go:30`).
pub const SGX_RETH_VERIFIER_ID: u8 = 4;

/// On-chain verifier id for risc0 proofs (Go `prover/init.go:31`).
pub const RISC0_VERIFIER_ID: u8 = 5;

/// On-chain verifier id for sp1 proofs (Go `prover/init.go:32`).
pub const SP1_VERIFIER_ID: u8 = 6;

/// Everything a proof request needs to know about one proposal, captured from
/// the `Proposed` event plus pre-request RPC enrichment. Mirrors Go's
/// `ProposalProofRequestOptions` (`proof_producer/interface.go:44-57`).
#[derive(Debug, Clone)]
pub struct ProofRequest {
    /// Shasta proposal id.
    pub proposal_id: u64,
    /// Proposer address (the designated prover under Shasta).
    pub proposer: Address,
    /// Timestamp of the L1 block containing the `Proposed` event.
    pub proposal_timestamp: u64,
    /// L1 block number containing the `Proposed` event.
    pub event_l1_block_number: u64,
    /// L1 block hash containing the `Proposed` event (reorg sentinel).
    pub event_l1_block_hash: B256,
    /// Address of this prover (the `prover` field in raiko requests).
    pub prover_address: Address,
    /// All L2 block numbers covered by the proposal, ascending.
    pub l2_block_numbers: Vec<u64>,
    /// Number of the proposal's last L2 block.
    pub end_block_number: u64,
    /// Hash of the proposal's last L2 block.
    pub end_block_hash: B256,
    /// State root of the proposal's last L2 block.
    pub end_state_root: B256,
    /// Anchor block number observed at the previous proposal's last block.
    pub last_anchor_block_number: u64,
    /// Whether the sgxgeth single proof already completed (metrics dedup
    /// across raiko polls).
    pub geth_proof_generated: bool,
    /// Whether the reth/zk single proof already completed.
    pub reth_proof_generated: bool,
    /// Whether the sgxgeth aggregation already completed.
    pub geth_aggregation_generated: bool,
    /// Whether the reth/zk aggregation already completed.
    pub reth_aggregation_generated: bool,
}

/// A completed single proof for one proposal.
#[derive(Debug, Clone)]
pub struct ProofResponse {
    /// The originating request (carried through aggregation and tx building).
    pub request: ProofRequest,
    /// Raw proof bytes; empty for single sp1 proofs (their payload is null).
    pub proof: Bytes,
    /// Proof type raiko actually produced.
    pub proof_type: ProofType,
}

impl ProofResponse {
    /// Proposal id shorthand.
    #[must_use]
    pub fn proposal_id(&self) -> u64 {
        self.request.proposal_id
    }
}

/// An aggregated batch ready for one `Inbox.prove` call: the base/zk
/// aggregation plus the always-present sgxgeth aggregation (compose model).
#[derive(Debug, Clone)]
pub struct BatchProofs {
    /// The single proofs that were aggregated, ascending by proposal id.
    pub responses: Vec<ProofResponse>,
    /// Aggregated base/zk proof bytes.
    pub batch_proof: Bytes,
    /// Aggregated sgxgeth proof bytes.
    pub sgx_geth_batch_proof: Bytes,
    /// Proposal ids covered, ascending.
    pub batch_ids: Vec<u64>,
    /// Base/zk proof type of the aggregation.
    pub proof_type: ProofType,
    /// Verifier id for the base/zk sub-proof.
    pub verifier_id: u8,
    /// Verifier id for the sgxgeth sub-proof.
    pub sgx_geth_verifier_id: u8,
}

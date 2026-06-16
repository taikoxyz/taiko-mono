//! Proof pipeline types and producers.

mod compose;
mod dummy;
mod sgx_geth;
mod zk_backlog;

use std::time::Instant;

use alloy_primitives::{Address, B256, Bytes, hex};
pub use compose::ComposeProofProducer;
pub use dummy::DummyProofProducer;
pub use sgx_geth::SgxGethProofProducer;
pub use zk_backlog::ZkBacklogController;

use crate::{
    error::{ProverError, Result},
    metrics::ProverMetrics,
    raiko::{
        ProofType, RaikoClient, RaikoError,
        types::{RaikoCheckpoint, RaikoProofResponse, RaikoProposal},
    },
};

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

/// A proof backend: generates one proof per proposal and aggregates batches
/// (Go `ProofProducer`, `proof_producer/interface.go`). Producers are
/// single-shot: in-progress raiko statuses surface as [`RaikoError`] values and
/// the caller owns the polling loop.
#[async_trait::async_trait]
pub trait ProofProducer: Send + Sync {
    /// Request a single proof for one proposal. On success the producer flips
    /// the request's `*_generated` flags so repeated polls don't re-record
    /// metrics or logs. `request_at` is when proving for this proposal began
    /// (captured once before the poll loop) and bounds the recorded generation
    /// time.
    async fn request_proof(
        &self,
        request: &mut ProofRequest,
        request_at: Instant,
    ) -> Result<ProofResponse>;

    /// Request the aggregation over already-generated single proofs. Flips the
    /// `*_aggregation_generated` flags on the first item's request. `request_at`
    /// is when this aggregation began and bounds the recorded generation time.
    async fn aggregate(
        &self,
        items: &mut [ProofResponse],
        request_at: Instant,
    ) -> Result<BatchProofs>;
}

/// Build raiko proposal entries from proof requests (Go
/// `compose_proof_producer.go:246-258`). Hashes are lowercase hex without the
/// `0x` prefix, matching Go's `Hash.Hex()[2:]`.
pub(crate) fn raiko_proposals(requests: &[&ProofRequest]) -> Vec<RaikoProposal> {
    requests
        .iter()
        .map(|request| RaikoProposal {
            proposal_id: request.proposal_id,
            l1_inclusion_block_number: request.event_l1_block_number,
            l2_block_numbers: request.l2_block_numbers.clone(),
            checkpoint: RaikoCheckpoint {
                block_number: request.end_block_number,
                block_hash: hex::encode(request.end_block_hash),
                state_root: hex::encode(request.end_state_root),
            },
            last_anchor_block_number: request.last_anchor_block_number,
        })
        .collect()
}

/// EIP-55 checksummed address without the `0x` prefix, matching Go's
/// `Address.Hex()[2:]` used for the raiko `prover` field.
pub(crate) fn prover_hex(address: Address) -> String {
    address.to_checksum(None)[2..].to_owned()
}

/// POST a raiko batch request and validate the response (Go's shared
/// `requestBatchProof` tail, `sgx_geth_proof_producer.go:154-192`). On the first
/// successful generation (`already_generated == false`) it logs the "generated"
/// line and records the per-proof-type generation latency/count metrics, exactly
/// where Go calls `updateProvingMetrics` (`common.go:139-189`). The recorded
/// type is the drawn type raiko returned, falling back to the requested type
/// (e.g. for sgxgeth, where requested == drawn) when the response omits it.
pub(crate) async fn request_validated(
    raiko: &RaikoClient,
    request: &crate::raiko::types::RaikoBatchProofRequest,
    already_generated: bool,
    request_at: Instant,
) -> std::result::Result<RaikoProofResponse, RaikoError> {
    let response = raiko.request_batch_proof(request).await?;
    response.validate()?;
    if !already_generated {
        let drawn_type = response.proof_type.unwrap_or(request.proof_type);
        tracing::info!(
            requested_type = ?request.proof_type,
            drawn_type = ?drawn_type,
            aggregate = request.aggregate,
            start = request.proposals.first().map(|p| p.proposal_id),
            end = request.proposals.last().map(|p| p.proposal_id),
            elapsed_secs = request_at.elapsed().as_secs_f64(),
            "batch proof generated"
        );
        ProverMetrics::record_proof_generation(drawn_type, request.aggregate, request_at.elapsed());
    }
    Ok(response)
}

/// Decode the hex proof payload out of a validated raiko response.
pub(crate) fn decode_proof_payload(response: &RaikoProofResponse) -> Result<Bytes> {
    let hex_str = response
        .data
        .as_ref()
        .and_then(|data| data.proof.as_ref())
        .and_then(|payload| payload.proof.as_deref())
        .unwrap_or_default();
    let bytes = hex::decode(hex_str).map_err(|err| {
        ProverError::Other(anyhow::anyhow!("invalid proof hex from raiko: {err}"))
    })?;
    Ok(bytes.into())
}

//! Filler proof producer for tests and `--prover.dummy` mode.

use alloy_primitives::Bytes;

use super::{ProofRequest, ProofResponse};
use crate::raiko::ProofType;

/// Number of filler bytes in dummy proofs (Go `dummy_producer.go`).
const DUMMY_PROOF_LEN: usize = 100;

/// Always returns filler proofs without touching raiko (Go
/// `DummyProofProducer`). The proof type is supplied by the caller, mirroring
/// how the Go compose/sgxgeth producers stamp their own type onto dummy
/// results. Go's standalone `Aggregate` (returning the dead `op` type) is
/// deliberately not ported.
#[derive(Debug, Clone, Copy, Default)]
pub struct DummyProofProducer;

impl DummyProofProducer {
    /// Filler single proof: `0xff` repeated 100 times (Go `dummy_producer.go:23`).
    #[must_use]
    pub fn request_proof(&self, request: &ProofRequest, proof_type: ProofType) -> ProofResponse {
        ProofResponse {
            request: request.clone(),
            proof: Bytes::from(vec![0xff; DUMMY_PROOF_LEN]),
            proof_type,
        }
    }

    /// Filler batch proof: `0xbb` repeated 100 times (Go `dummy_producer.go:37`).
    #[must_use]
    pub fn request_batch_proofs(&self) -> Bytes {
        Bytes::from(vec![0xbb; DUMMY_PROOF_LEN])
    }
}

#[cfg(test)]
mod tests {
    use alloy_primitives::{Address, B256};

    use super::{DUMMY_PROOF_LEN, DummyProofProducer};
    use crate::{producer::ProofRequest, raiko::ProofType};

    fn test_request(proposal_id: u64) -> ProofRequest {
        ProofRequest {
            proposal_id,
            proposer: Address::repeat_byte(0x11),
            proposal_timestamp: 1_000,
            event_l1_block_number: 42,
            event_l1_block_hash: B256::repeat_byte(0x22),
            prover_address: Address::repeat_byte(0x33),
            l2_block_numbers: vec![100],
            end_block_number: 100,
            end_block_hash: B256::repeat_byte(0x44),
            end_state_root: B256::repeat_byte(0x55),
            last_anchor_block_number: 40,
            geth_proof_generated: false,
            reth_proof_generated: false,
            geth_aggregation_generated: false,
            reth_aggregation_generated: false,
        }
    }

    #[test]
    fn dummy_single_proof_is_ff_filler_with_caller_type() {
        let response = DummyProofProducer.request_proof(&test_request(9), ProofType::Sgx);
        assert_eq!(response.proposal_id(), 9);
        assert_eq!(response.proof_type, ProofType::Sgx);
        assert_eq!(response.proof.len(), DUMMY_PROOF_LEN);
        assert!(response.proof.iter().all(|b| *b == 0xff));
    }

    #[test]
    fn dummy_batch_proof_is_bb_filler() {
        let batch = DummyProofProducer.request_batch_proofs();
        assert_eq!(batch.len(), DUMMY_PROOF_LEN);
        assert!(batch.iter().all(|b| *b == 0xbb));
    }
}

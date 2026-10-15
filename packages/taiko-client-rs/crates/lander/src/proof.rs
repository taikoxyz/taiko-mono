//! The external proof boundary. The initial implementation deliberately supplies a dummy proof.

use crate::types::PreparedBatch;
use alloy_primitives::Bytes;
use async_trait::async_trait;
use serde::{Deserialize, Serialize};

/// Immutable prepared inputs passed to a proof backend.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProofRequest {
    /// Batch and statement bound before any provider invocation.
    pub batch: PreparedBatch,
}

/// A proof backend's failure, separate from consensus or transport errors.
#[derive(Clone, Debug, PartialEq, Eq, thiserror::Error)]
pub enum ProofError {
    /// Backend was temporarily unable to produce the proof.
    #[error("proof backend temporarily unavailable: {0}")]
    Temporary(String),
    /// Backend permanently rejected the immutable request.
    #[error("proof backend rejected request: {0}")]
    Rejected(String),
}

/// Asynchronous boundary that a real prover can implement without changing landing public inputs.
#[async_trait]
pub trait ProofProvider: Send + Sync {
    /// Produce bytes for this exact request; the provider cannot modify its statement or blobs.
    async fn prove(&self, request: &ProofRequest) -> std::result::Result<Bytes, ProofError>;
}

/// Explicit dummy mode: always emits one zero byte, with no cryptographic proof computation.
#[derive(Clone, Copy, Debug, Default)]
pub struct DummyProofProvider;

#[async_trait]
impl ProofProvider for DummyProofProvider {
    async fn prove(&self, _request: &ProofRequest) -> std::result::Result<Bytes, ProofError> {
        Ok(Bytes::from_static(&[0]))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::protocol::request;

    #[tokio::test]
    async fn dummy_proof_is_exactly_one_zero_byte_through_trait() {
        let provider: &dyn ProofProvider = &DummyProofProvider;
        let proof = provider.prove(&request()).await.unwrap();
        assert_eq!(proof.as_ref(), &[0]);
        assert_eq!(format!("{proof}"), "0x00");
    }

    struct Reject;
    #[async_trait]
    impl ProofProvider for Reject {
        async fn prove(&self, _request: &ProofRequest) -> Result<Bytes, ProofError> {
            Err(ProofError::Rejected("bad witness".into()))
        }
    }

    #[tokio::test]
    async fn alternative_backend_error_survives_trait_boundary() {
        let provider: &dyn ProofProvider = &Reject;
        assert_eq!(
            provider.prove(&request()).await,
            Err(ProofError::Rejected("bad witness".into()))
        );
    }
}

#[cfg(test)]
mod journal_tests {
    use super::*;
    use crate::test_utils::protocol::request;
    use alloy::sol_types::SolValue;

    /// The input, the participation parts and the settlement committees are journaled as their
    /// exact Solidity `abi.encode` bytes; truncated, extended or noncanonical bytes are refused.
    #[test]
    fn immutable_request_round_trip_uses_canonical_abi_inputs() {
        let request = request();
        assert!(!request.batch.participation.is_empty() && !request.batch.settlements.is_empty());
        let json = serde_json::to_value(&request).unwrap();
        let restored: ProofRequest = serde_json::from_value(json.clone()).unwrap();
        assert_eq!(restored, request);
        for (field, bytes) in [
            ("input", request.batch.input.abi_encode()),
            ("participation", request.batch.participation.abi_encode()),
            ("settlements", request.batch.settlements.abi_encode()),
        ] {
            assert_eq!(
                json["batch"][field],
                serde_json::to_value(Bytes::from(bytes.clone())).unwrap(),
                "{field}"
            );
            let mut noncanonical = bytes.clone();
            if field != "input" {
                // A second offset word pointing past the first: same values, other bytes.
                noncanonical[31] = 0x40;
                noncanonical.splice(32..32, [0; 32]);
            }
            for bad_bytes in [
                vec![],
                bytes[..bytes.len() - 1].to_vec(),
                [bytes.as_slice(), &[0]].concat(),
                noncanonical,
            ] {
                if bad_bytes == bytes {
                    continue;
                }
                let mut bad = json.clone();
                bad["batch"][field] = serde_json::to_value(Bytes::from(bad_bytes)).unwrap();
                assert!(serde_json::from_value::<ProofRequest>(bad).is_err(), "{field}");
            }
        }
    }
}

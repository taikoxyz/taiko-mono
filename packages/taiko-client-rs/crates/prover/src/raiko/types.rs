//! Wire types for the raiko proving service (`/v3/proof/batch/shasta`).

use serde::{Deserialize, Serialize};
use thiserror::Error;

/// Proof type identifiers shared with raiko and the on-chain verifier wiring.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProofType {
    /// SGX execution proof produced against geth (always the first sub-proof).
    #[serde(rename = "sgxgeth")]
    SgxGeth,
    /// SGX proof produced against reth (the default base proof).
    Sgx,
    /// risc0 ZK proof.
    Risc0,
    /// sp1 ZK proof.
    Sp1,
    /// Request marker letting raiko pick risc0 or sp1.
    ZkAny,
}

/// Checkpoint of the proposal's last L2 block (hex strings WITHOUT `0x` prefix,
/// per Go `compose_proof_producer.go:251-255`).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RaikoCheckpoint {
    /// Last L2 block number of the proposal.
    pub block_number: u64,
    /// Last L2 block hash, hex without `0x` prefix.
    pub block_hash: String,
    /// Last L2 block state root, hex without `0x` prefix.
    pub state_root: String,
}

/// One proposal entry in a raiko batch proof request.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RaikoProposal {
    /// Shasta proposal id.
    pub proposal_id: u64,
    /// L1 block number containing the `Proposed` event.
    pub l1_inclusion_block_number: u64,
    /// All L2 block numbers covered by the proposal.
    pub l2_block_numbers: Vec<u64>,
    /// Checkpoint of the proposal's last L2 block.
    pub checkpoint: RaikoCheckpoint,
    /// Anchor block number observed at the previous proposal's last block.
    pub last_anchor_block_number: u64,
}

/// JSON body POSTed to `/v3/proof/batch/shasta` (Go `RaikoRequestProofBodyV3Shasta`).
#[derive(Debug, Clone, Serialize)]
pub struct RaikoBatchProofRequest {
    /// Proposals to prove (single entry) or aggregate (many).
    pub proposals: Vec<RaikoProposal>,
    /// Prover address, hex without `0x` prefix.
    pub prover: String,
    /// True for the aggregation pass over already-generated single proofs.
    pub aggregate: bool,
    /// Requested proof type.
    pub proof_type: ProofType,
}

/// Response envelope (Go `RaikoRequestProofBodyResponseV2`).
#[derive(Debug, Clone, Deserialize)]
pub struct RaikoProofResponse {
    /// Proof payload and generation status.
    pub data: Option<RaikoProofData>,
    /// Human-readable error message, if any.
    pub message: Option<String>,
    /// Machine error string, if any.
    pub error: Option<String>,
    /// Proof type raiko actually produced (relevant for `zk_any` draws).
    pub proof_type: Option<ProofType>,
}

/// Proof payload and status (Go `RaikoProofDataV2`).
#[derive(Debug, Clone, Deserialize)]
pub struct RaikoProofData {
    /// The proof, when generation has completed.
    pub proof: Option<RaikoProofPayload>,
    /// Generation status string (`work_in_progress`, `registered`, ...).
    pub status: String,
}

/// Inner proof bytes (Go `ProofDataV2`).
#[derive(Debug, Clone, Deserialize)]
pub struct RaikoProofPayload {
    /// Hex proof bytes (`0x`-prefixed), null for single sp1 proofs.
    pub proof: Option<String>,
    /// KZG proof, unused by the client.
    pub kzg_proof: Option<String>,
    /// SGX quote, unused by the client.
    pub quote: Option<String>,
}

/// Errors surfaced by raiko requests and response validation.
#[derive(Debug, Error)]
pub enum RaikoError {
    /// Proof generation is still running; poll again.
    #[error("work_in_progress")]
    ProofInProgress,

    /// Request registered; poll again.
    #[error("registered")]
    Retry,

    /// raiko chose not to draw a ZK proof for this batch; fall back to SGX.
    #[error("zk_any_not_drawn")]
    ZkAnyNotDrawn,

    /// Completed response carried no proof bytes for a non-sp1 type.
    #[error("empty proof from raiko")]
    EmptyProof,

    /// raiko returned an error payload.
    #[error("raiko error: {error:?}, message: {message:?}")]
    Failed {
        /// Machine error string.
        error: Option<String>,
        /// Human-readable message.
        message: Option<String>,
    },

    /// Transport-level failure.
    #[error("raiko http error: {0}")]
    Http(#[from] reqwest::Error),

    /// Non-200 HTTP status.
    #[error("raiko returned http status {0}")]
    Status(u16),
}

impl RaikoProofResponse {
    /// Validate the response exactly like Go `common.go:26-55`: error payloads
    /// first, then status strings, then the sp1-null-proof exemption.
    ///
    /// A missing `data` field (Go's "unexpected structure error") maps to
    /// [`RaikoError::EmptyProof`]. Empty-string `error`/`message` payloads are
    /// treated as absent, matching Go's `len(..) > 0` checks.
    pub fn validate(&self) -> Result<(), RaikoError> {
        if self.error.as_deref().is_some_and(|e| !e.is_empty()) ||
            self.message.as_deref().is_some_and(|m| !m.is_empty())
        {
            return Err(RaikoError::Failed {
                error: self.error.clone(),
                message: self.message.clone(),
            });
        }
        let data = self.data.as_ref().ok_or(RaikoError::EmptyProof)?;
        match data.status.as_str() {
            "work_in_progress" => return Err(RaikoError::ProofInProgress),
            "registered" => return Err(RaikoError::Retry),
            "zk_any_not_drawn" => return Err(RaikoError::ZkAnyNotDrawn),
            _ => {}
        }
        let has_proof =
            data.proof.as_ref().is_some_and(|p| p.proof.as_deref().is_some_and(|s| !s.is_empty()));
        if self.proof_type != Some(ProofType::Sp1) && !has_proof {
            return Err(RaikoError::EmptyProof);
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn proof_type_serializes_to_raiko_wire_names() {
        for (ty, wire) in [
            (ProofType::SgxGeth, "\"sgxgeth\""),
            (ProofType::Sgx, "\"sgx\""),
            (ProofType::Risc0, "\"risc0\""),
            (ProofType::Sp1, "\"sp1\""),
            (ProofType::ZkAny, "\"zk_any\""),
        ] {
            assert_eq!(serde_json::to_string(&ty).unwrap(), wire);
            assert_eq!(serde_json::from_str::<ProofType>(wire).unwrap(), ty);
        }
    }

    #[test]
    fn response_status_maps_to_typed_errors() {
        let resp = |status: &str| RaikoProofResponse {
            data: Some(RaikoProofData { proof: None, status: status.to_owned() }),
            message: None,
            error: None,
            proof_type: Some(ProofType::Sgx),
        };
        assert!(matches!(resp("work_in_progress").validate(), Err(RaikoError::ProofInProgress)));
        assert!(matches!(resp("registered").validate(), Err(RaikoError::Retry)));
        assert!(matches!(resp("zk_any_not_drawn").validate(), Err(RaikoError::ZkAnyNotDrawn)));
        // Non-sp1 with empty proof payload is an error (Go common.go:48-52).
        assert!(matches!(resp("ok").validate(), Err(RaikoError::EmptyProof)));
    }

    #[test]
    fn sp1_single_proof_with_null_payload_is_valid() {
        let resp = RaikoProofResponse {
            data: Some(RaikoProofData { proof: None, status: "ok".to_owned() }),
            message: None,
            error: None,
            proof_type: Some(ProofType::Sp1),
        };
        assert!(resp.validate().is_ok());
    }

    #[test]
    fn success_response_round_trips_through_serde() {
        let body = r#"{"data":{"proof":{"proof":"0xabcd","kzg_proof":null,"quote":"0x11"},"status":"ok"},"proof_type":"risc0"}"#;
        let resp: RaikoProofResponse = serde_json::from_str(body).unwrap();

        let data = resp.data.as_ref().expect("data present");
        assert_eq!(data.status, "ok");
        let payload = data.proof.as_ref().expect("proof payload present");
        assert_eq!(payload.proof.as_deref(), Some("0xabcd"));
        assert_eq!(payload.kzg_proof, None);
        assert_eq!(payload.quote.as_deref(), Some("0x11"));
        assert_eq!(resp.message, None);
        assert_eq!(resp.error, None);
        assert_eq!(resp.proof_type, Some(ProofType::Risc0));

        assert!(resp.validate().is_ok());
    }

    #[test]
    fn error_response_validates_to_failed() {
        let body = r#"{"error":"err","message":"boom","proof_type":"sgx"}"#;
        let resp: RaikoProofResponse = serde_json::from_str(body).unwrap();
        match resp.validate() {
            Err(RaikoError::Failed { error, message }) => {
                assert_eq!(error.as_deref(), Some("err"));
                assert_eq!(message.as_deref(), Some("boom"));
            }
            other => panic!("expected RaikoError::Failed, got {other:?}"),
        }
    }

    #[test]
    fn batch_request_serializes_with_go_json_tags() {
        let request = RaikoBatchProofRequest {
            proposals: vec![RaikoProposal {
                proposal_id: 7,
                l1_inclusion_block_number: 42,
                l2_block_numbers: vec![100, 101],
                checkpoint: RaikoCheckpoint {
                    block_number: 101,
                    block_hash: "ab".repeat(32),
                    state_root: "cd".repeat(32),
                },
                last_anchor_block_number: 40,
            }],
            prover: "ef".repeat(20),
            aggregate: false,
            proof_type: ProofType::ZkAny,
        };
        // JSON tags per Go compose_proof_producer.go:18-39.
        assert_eq!(
            serde_json::to_value(&request).unwrap(),
            serde_json::json!({
                "proposals": [{
                    "proposal_id": 7,
                    "l1_inclusion_block_number": 42,
                    "l2_block_numbers": [100, 101],
                    "checkpoint": {
                        "block_number": 101,
                        "block_hash": "ab".repeat(32),
                        "state_root": "cd".repeat(32),
                    },
                    "last_anchor_block_number": 40,
                }],
                "prover": "ef".repeat(20),
                "aggregate": false,
                "proof_type": "zk_any",
            })
        );
    }
}

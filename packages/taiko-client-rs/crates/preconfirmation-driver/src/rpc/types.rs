//! User-facing RPC API types for the preconfirmation node.

use alloy_primitives::{Address, B256, Bytes, U256};
use serde::{Deserialize, Serialize};

/// Request to publish a signed preconfirmation commitment.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PublishCommitmentRequest {
    /// The RLP-encoded preconfirmation commitment.
    pub commitment: Bytes,
    /// The 65-byte ECDSA signature over the commitment hash.
    pub signature: Bytes,
    /// Optional list of raw transaction bytes to include in this block.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub transactions: Option<Vec<Bytes>>,
}

/// Request to publish a raw transaction list separately from the commitment.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PublishTxListRequest {
    /// The keccak256 hash of the compressed transaction list.
    pub tx_list_hash: B256,
    /// The list of raw transaction bytes to publish.
    pub transactions: Vec<Bytes>,
}

/// Response for a successful commitment publication.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PublishCommitmentResponse {
    /// The keccak256 hash of the published commitment.
    pub commitment_hash: B256,
    /// The keccak256 hash of the associated transaction list.
    pub tx_list_hash: B256,
}

/// Response for a successful transaction list publication.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PublishTxListResponse {
    /// The keccak256 hash of the published transaction list.
    pub tx_list_hash: B256,
    /// The number of transactions in the published list.
    pub transaction_count: u64,
}

/// Current status of the preconfirmation node.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NodeStatus {
    /// Whether the node has completed initial sync with L1 events.
    pub is_synced: bool,
    /// The highest preconfirmed block number known to this node.
    pub preconf_tip: U256,
    /// The last canonical proposal ID from L1 inbox events.
    pub canonical_proposal_id: u64,
    /// Number of connected P2P peers.
    pub peer_count: u64,
    /// This node's libp2p peer ID.
    pub peer_id: String,
}

/// Information about the current lookahead.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LookaheadInfo {
    /// The Ethereum address of the current preconfirmer for this slot.
    pub current_preconfirmer: Address,
    /// Unix timestamp when the current submission window ends.
    pub submission_window_end: U256,
    /// The current beacon chain slot number, if available.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub current_slot: Option<u64>,
}

/// Current preconfirmation head information.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PreconfHead {
    /// The latest preconfirmed block number.
    pub block_number: U256,
    /// Unix timestamp when the current submission window ends.
    pub submission_window_end: U256,
}

/// RPC error codes for preconfirmation operations (JSON-RPC -32000 to -32099 range).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(i32)]
pub enum PreconfRpcErrorCode {
    /// Internal server error occurred.
    InternalError = -32000,
    /// The commitment format or signature is invalid.
    InvalidCommitment = -32001,
    /// The transaction list format is invalid.
    InvalidTxList = -32002,
    /// The node has not completed initial sync.
    NotSynced = -32003,
    /// The submission window has expired for this slot.
    SubmissionWindowExpired = -32004,
    /// The signer is not the expected preconfirmer for this slot.
    InvalidSigner = -32005,
}

impl PreconfRpcErrorCode {
    /// Get the integer code for this error.
    pub const fn code(self) -> i32 {
        self as i32
    }

    /// Get a human-readable message for this error.
    pub const fn message(self) -> &'static str {
        match self {
            Self::InternalError => "Internal error",
            Self::InvalidCommitment => "Invalid commitment format or signature",
            Self::InvalidTxList => "Invalid transaction list format",
            Self::NotSynced => "Node is not synced",
            Self::SubmissionWindowExpired => "Submission window has expired",
            Self::InvalidSigner => "Signer is not the expected preconfirmer",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_publish_commitment_request_serde() {
        let request = PublishCommitmentRequest {
            commitment: Bytes::from(vec![1, 2, 3]),
            signature: Bytes::from(vec![4, 5, 6]),
            transactions: Some(vec![Bytes::from(vec![7, 8, 9])]),
        };

        let json = serde_json::to_string(&request).unwrap();
        let parsed: PublishCommitmentRequest = serde_json::from_str(&json).unwrap();

        assert_eq!(parsed.commitment, request.commitment);
        assert_eq!(parsed.signature, request.signature);
        assert_eq!(parsed.transactions, request.transactions);
    }

    #[test]
    fn test_node_status_camel_case() {
        let status = NodeStatus {
            is_synced: true,
            preconf_tip: U256::from(100),
            canonical_proposal_id: 42,
            peer_count: 5,
            peer_id: "test-peer-id".to_string(),
        };

        let json = serde_json::to_string(&status).unwrap();
        assert!(json.contains("isSynced"));
        assert!(json.contains("preconfTip"));
        assert!(json.contains("canonicalProposalId"));
    }

    #[test]
    fn test_error_codes() {
        assert_eq!(PreconfRpcErrorCode::InvalidCommitment.code(), -32001);
        assert_eq!(PreconfRpcErrorCode::NotSynced.code(), -32003);
        assert_eq!(PreconfRpcErrorCode::InternalError.code(), -32000);
    }
}

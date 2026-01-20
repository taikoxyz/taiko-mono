//! RPC request and response types.

use alloy_primitives::{B256, U256};
use serde::{Deserialize, Serialize};

/// Request to get commitments within a block range.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GetCommitmentsRequest {
    /// Starting block number (inclusive).
    pub from_block: U256,
    /// Ending block number (inclusive).
    pub to_block: U256,
}

/// SSZ-encoded signed commitment payload.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SszSignedCommitment {
    /// SSZ-serialized SignedCommitment bytes.
    pub bytes: Vec<u8>,
}

/// SSZ-encoded transaction list gossip payload.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SszRawTxList {
    /// SSZ-serialized RawTxListGossip bytes.
    pub bytes: Vec<u8>,
}

/// Response containing commitments.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GetCommitmentsResponse {
    /// List of signed commitments in the range.
    pub commitments: Vec<SszSignedCommitment>,
}

/// Request to get a transaction list by commitment hash.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GetTxListRequest {
    /// Hash of the commitment.
    pub commitment_hash: B256,
}

/// Response containing a transaction list.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GetTxListResponse {
    /// The transaction list bytes, or None if not found.
    pub txlist: Option<SszRawTxList>,
}

/// Response for publish operations.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PublishResponse {
    /// Whether the publish was successful.
    pub success: bool,
}

/// Current node status.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NodeStatus {
    /// Current preconfirmation tip block number.
    pub preconf_tip: U256,
    /// Current event sync tip (safe block number).
    pub event_sync_tip: U256,
    /// Number of connected peers.
    pub peer_count: u32,
    /// Whether the node is synced.
    pub synced: bool,
}

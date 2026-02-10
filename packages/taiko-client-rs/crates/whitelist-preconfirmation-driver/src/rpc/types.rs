//! Whitelist preconfirmation JSON-RPC request and response types.

use alloy_primitives::{Address, B256, Bytes};
use serde::{Deserialize, Serialize};

/// Request body for `whitelist_buildPreconfBlock`.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BuildPreconfBlockRequest {
    /// Parent block hash.
    pub parent_hash: B256,
    /// Fee recipient address.
    pub fee_recipient: Address,
    /// Block number.
    pub block_number: u64,
    /// Gas limit.
    pub gas_limit: u64,
    /// Block timestamp.
    pub timestamp: u64,
    /// RLP-encoded then zlib-compressed transaction list.
    pub transactions: Bytes,
    /// Extra data for the block header.
    pub extra_data: Bytes,
    /// Base fee per gas.
    pub base_fee_per_gas: u64,
    /// Whether this is the last preconfirmation block in the epoch.
    pub end_of_sequencing: Option<bool>,
    /// Whether this is a forced inclusion block.
    pub is_forced_inclusion: Option<bool>,
}

/// Response body for `whitelist_buildPreconfBlock`.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BuildPreconfBlockResponse {
    /// Hash of the built block.
    pub block_hash: B256,
    /// Number of the built block.
    pub block_number: u64,
}

/// Response body for `whitelist_getStatus`.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct WhitelistStatus {
    /// Head L1 origin block ID, if available.
    pub head_l1_origin_block_id: Option<u64>,
    /// Highest unsafe block number on L2.
    pub highest_unsafe_block_number: Option<u64>,
    /// Local libp2p peer ID.
    pub peer_id: String,
    /// Whether event sync has established a head L1 origin.
    pub sync_ready: bool,
}

/// Response body for `whitelist_healthz`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HealthResponse {
    /// Whether the server is healthy.
    pub ok: bool,
}

/// Custom JSON-RPC error codes for whitelist preconfirmation operations.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(i32)]
pub enum WhitelistRpcErrorCode {
    /// Internal server error.
    InternalError = -32000,
    /// Invalid payload format.
    InvalidPayload = -32001,
    /// Node is not synced.
    NotSynced = -32002,
    /// Signing failed.
    SigningFailed = -32003,
    /// P2P publish failed.
    PublishFailed = -32004,
}

impl WhitelistRpcErrorCode {
    /// Get the integer code for this error.
    pub const fn code(self) -> i32 {
        self as i32
    }

    /// Get a human-readable message for this error.
    #[allow(dead_code)]
    pub const fn message(self) -> &'static str {
        match self {
            Self::InternalError => "Internal error",
            Self::InvalidPayload => "Invalid payload format",
            Self::NotSynced => "Node is not synced",
            Self::SigningFailed => "Signing failed",
            Self::PublishFailed => "Publish to P2P network failed",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn build_preconf_block_request_camel_case() {
        let request = BuildPreconfBlockRequest {
            parent_hash: B256::ZERO,
            fee_recipient: Address::ZERO,
            block_number: 1,
            gas_limit: 30_000_000,
            timestamp: 1_735_000_000,
            transactions: Bytes::from(vec![0x01]),
            extra_data: Bytes::default(),
            base_fee_per_gas: 1_000_000_000,
            end_of_sequencing: Some(true),
            is_forced_inclusion: None,
        };

        let json = serde_json::to_string(&request).unwrap();
        assert!(json.contains("parentHash"));
        assert!(json.contains("feeRecipient"));
        assert!(json.contains("blockNumber"));
        assert!(json.contains("gasLimit"));
        assert!(json.contains("baseFeePerGas"));
        assert!(json.contains("endOfSequencing"));
    }

    #[test]
    fn whitelist_status_camel_case() {
        let status = WhitelistStatus {
            head_l1_origin_block_id: Some(42),
            highest_unsafe_block_number: Some(100),
            peer_id: "test-peer".to_string(),
            sync_ready: true,
        };

        let json = serde_json::to_string(&status).unwrap();
        assert!(json.contains("headL1OriginBlockId"));
        assert!(json.contains("highestUnsafeBlockNumber"));
        assert!(json.contains("syncReady"));
    }

    #[test]
    fn error_codes() {
        assert_eq!(WhitelistRpcErrorCode::InternalError.code(), -32000);
        assert_eq!(WhitelistRpcErrorCode::InvalidPayload.code(), -32001);
        assert_eq!(WhitelistRpcErrorCode::NotSynced.code(), -32002);
        assert_eq!(WhitelistRpcErrorCode::SigningFailed.code(), -32003);
        assert_eq!(WhitelistRpcErrorCode::PublishFailed.code(), -32004);
    }
}

//! Whitelist preconfirmation REST/WS request and response types.

use alloy_primitives::{Address, B256, Bytes};
use alloy_rpc_types::Header as RpcHeader;
use serde::{Deserialize, Serialize};

/// Internal request body used by `POST /preconfBlocks`.
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

/// Internal response body returned by the build-preconf flow.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BuildPreconfBlockResponse {
    /// Hash of the built block.
    pub block_hash: B256,
    /// Number of the built block.
    pub block_number: u64,
    /// Full block header of the built preconfirmation block.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub block_header: Option<RpcHeader>,
}

/// REST-compatible request body for `POST /preconfBlocks`.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BuildPreconfBlockRestRequest {
    /// Nested executable payload fields.
    pub executable_data: Option<ExecutableData>,
    /// Whether this is the last preconfirmation block in the epoch.
    pub end_of_sequencing: Option<bool>,
    /// Whether this is a forced inclusion block.
    pub is_forced_inclusion: Option<bool>,
}

/// REST-compatible nested executable data.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ExecutableData {
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
}

impl BuildPreconfBlockRestRequest {
    /// Convert REST request format into internal RPC request format.
    pub fn into_rpc_request(self) -> std::result::Result<BuildPreconfBlockRequest, String> {
        let executable_data =
            self.executable_data.ok_or_else(|| "executable data is required".to_string())?;
        Ok(BuildPreconfBlockRequest {
            parent_hash: executable_data.parent_hash,
            fee_recipient: executable_data.fee_recipient,
            block_number: executable_data.block_number,
            gas_limit: executable_data.gas_limit,
            timestamp: executable_data.timestamp,
            transactions: executable_data.transactions,
            extra_data: executable_data.extra_data,
            base_fee_per_gas: executable_data.base_fee_per_gas,
            end_of_sequencing: self.end_of_sequencing,
            is_forced_inclusion: self.is_forced_inclusion,
        })
    }
}

/// Go-compatible slot range.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct SlotRange {
    /// Inclusive start slot.
    pub start: u64,
    /// Exclusive end slot.
    pub end: u64,
}

/// Go-compatible lookahead status shape.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LookaheadStatus {
    /// Current operator address.
    pub curr_operator: Address,
    /// Next operator address.
    pub next_operator: Address,
    /// Current operator allowed slot ranges.
    pub curr_ranges: Vec<SlotRange>,
    /// Next operator allowed slot ranges.
    pub next_ranges: Vec<SlotRange>,
    /// Last update timestamp (unix seconds).
    pub updated_at: u64,
    /// Last epoch used for update.
    pub last_updated_epoch: u64,
}

/// Go-compatible REST status response for `GET /status`.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RestStatus {
    /// Sequencing lookahead information.
    pub lookahead: Option<LookaheadStatus>,
    /// Total cached envelopes (best-effort).
    pub total_cached: u64,
    /// Highest unsafe payload block ID tracked by this node.
    pub highest_unsafe_l2_payload_block_id: u64,
    /// End-of-sequencing block hash for current epoch (if any).
    pub end_of_sequencing_block_hash: String,
}

/// Go-compatible `/ws` push notification payload.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EndOfSequencingNotification {
    /// Current beacon epoch at notification time.
    pub current_epoch: u64,
    /// Marker indicating this is an end-of-sequencing notification.
    pub end_of_sequencing: bool,
}

/// Internal status model used by `GET /status`.
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
    /// Sequencing lookahead information.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub lookahead: Option<LookaheadStatus>,
    /// Total cached envelopes (best-effort).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub total_cached: Option<u64>,
    /// Highest unsafe payload block ID tracked by this node.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub highest_unsafe_l2_payload_block_id: Option<u64>,
    /// End-of-sequencing block hash for current epoch.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub end_of_sequencing_block_hash: Option<String>,
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
            lookahead: None,
            total_cached: Some(0),
            highest_unsafe_l2_payload_block_id: Some(100),
            end_of_sequencing_block_hash: Some(B256::ZERO.to_string()),
        };

        let json = serde_json::to_string(&status).unwrap();
        assert!(json.contains("headL1OriginBlockId"));
        assert!(json.contains("highestUnsafeBlockNumber"));
        assert!(json.contains("syncReady"));
        assert!(json.contains("highestUnsafeL2PayloadBlockId"));
        assert!(json.contains("endOfSequencingBlockHash"));
    }
}

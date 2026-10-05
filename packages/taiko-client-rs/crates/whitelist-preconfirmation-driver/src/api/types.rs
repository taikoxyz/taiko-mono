//! Whitelist preconfirmation REST/WS request and response types.

use alloy_primitives::{Address, B256, Bytes};
use alloy_rpc_types::Header as RpcHeader;
use serde::{Deserialize, Serialize};

/// Request body for `POST /preconfBlocks`.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BuildPreconfBlockRequest {
    /// Nested executable payload fields.
    pub executable_data: Option<ExecutableData>,
    /// Whether this is the last preconfirmation block in the epoch.
    pub end_of_sequencing: Option<bool>,
    /// Whether this is a forced inclusion block.
    pub is_forced_inclusion: Option<bool>,
}

/// Executable payload fields nested in [`BuildPreconfBlockRequest`].
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
    /// Parent beacon block root of the block. Etna blocks require the nonzero L1 state root of
    /// their anchor block; pre-Etna blocks omit it or send zero.
    #[serde(default)]
    pub parent_beacon_block_root: Option<B256>,
}

/// Response body returned by `POST /preconfBlocks`.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BuildPreconfBlockResponse {
    /// Full block header of the built preconfirmation block.
    pub block_header: RpcHeader,
}

/// Status response for `GET /status`.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ApiStatus {
    /// Highest unsafe payload block ID tracked by this node.
    #[serde(rename = "highestUnsafeL2PayloadBlockID")]
    pub highest_unsafe_l2_payload_block_id: u64,
    /// End-of-sequencing block hash for current epoch (zero hash when unknown).
    pub end_of_sequencing_block_hash: String,
    /// True when SIGTERM is safe — no `build_preconf_block` request has been
    /// received within the last shutdown-block window.
    pub can_shutdown: bool,
}

/// `/ws` push notification payload.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EndOfSequencingNotification {
    /// Current beacon epoch at notification time.
    pub current_epoch: u64,
    /// Marker indicating this is an end-of-sequencing notification.
    pub end_of_sequencing: bool,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn build_preconf_block_request_camel_case() {
        let request = BuildPreconfBlockRequest {
            executable_data: Some(ExecutableData {
                parent_hash: B256::ZERO,
                fee_recipient: Address::ZERO,
                block_number: 1,
                gas_limit: 30_000_000,
                timestamp: 1_735_000_000,
                transactions: Bytes::from(vec![0x01]),
                extra_data: Bytes::default(),
                base_fee_per_gas: 1_000_000_000,
                parent_beacon_block_root: Some(B256::repeat_byte(0x5a)),
            }),
            end_of_sequencing: Some(true),
            is_forced_inclusion: None,
        };

        let json = serde_json::to_string(&request).unwrap();
        assert!(json.contains("executableData"));
        assert!(json.contains("parentHash"));
        assert!(json.contains("feeRecipient"));
        assert!(json.contains("blockNumber"));
        assert!(json.contains("gasLimit"));
        assert!(json.contains("baseFeePerGas"));
        assert!(json.contains("parentBeaconBlockRoot"));
        assert!(json.contains("endOfSequencing"));
    }

    /// Build the JSON `executableData` a sequencer sends, with `root` as its
    /// `parentBeaconBlockRoot` value (`None` omits the key, as pre-Etna requests do today).
    fn executable_data_json(root: Option<&str>) -> serde_json::Value {
        let mut data = serde_json::json!({
            "parentHash": B256::ZERO,
            "feeRecipient": Address::ZERO,
            "blockNumber": 1,
            "gasLimit": 30_000_000,
            "timestamp": 1_735_000_000,
            "transactions": "0x01",
            "extraData": "0x",
            "baseFeePerGas": 1_000_000_000,
        });
        if let Some(root) = root {
            data["parentBeaconBlockRoot"] = serde_json::Value::from(root);
        }
        data
    }

    #[test]
    fn executable_data_root_is_none_when_the_field_is_absent() {
        let data: ExecutableData =
            serde_json::from_value(executable_data_json(None)).expect("pre-Etna request parses");
        assert_eq!(data.parent_beacon_block_root, None);
    }

    #[test]
    fn executable_data_root_parses_a_zero_root() {
        let zero = B256::ZERO.to_string();
        let data: ExecutableData =
            serde_json::from_value(executable_data_json(Some(&zero))).expect("zero root parses");
        assert_eq!(data.parent_beacon_block_root, Some(B256::ZERO));
    }

    #[test]
    fn executable_data_root_parses_a_nonzero_root() {
        let root = B256::repeat_byte(0x5a);
        let data: ExecutableData =
            serde_json::from_value(executable_data_json(Some(&root.to_string())))
                .expect("Etna root parses");
        assert_eq!(data.parent_beacon_block_root, Some(root));
    }

    #[test]
    fn status_serializes_fields_in_camel_case() {
        let status = ApiStatus {
            highest_unsafe_l2_payload_block_id: 1,
            end_of_sequencing_block_hash: B256::ZERO.to_string(),
            can_shutdown: true,
        };

        let json =
            serde_json::from_str::<serde_json::Value>(&serde_json::to_string(&status).unwrap())
                .expect("status should serialize as JSON");
        assert_eq!(
            json["highestUnsafeL2PayloadBlockID"]
                .as_u64()
                .expect("missing highest unsafe block ID"),
            1
        );
        assert!(json.get("highestUnsafeL2PayloadBlockId").is_none());
        assert!(
            json["endOfSequencingBlockHash"].as_str().expect("missing EOS hash").starts_with("0x")
        );
        assert!(json["canShutdown"].as_bool().expect("missing canShutdown"));
    }
}

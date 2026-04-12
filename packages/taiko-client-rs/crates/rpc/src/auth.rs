//! Authenticated RPC extensions for Taiko execution engine.

use std::borrow::Cow;

use alethia_reth_primitives::{
    engine::types::TaikoExecutionDataSidecar,
    payload::attributes::{RpcL1Origin, TaikoPayloadAttributes},
};
use alethia_reth_rpc_types::PreBuiltTxList as TaikoPreBuiltTxList;
use alloy_primitives::{Address, FixedBytes, U256};
use alloy_provider::Provider;
use alloy_rpc_types_engine::{
    ExecutionPayloadEnvelopeV2, ExecutionPayloadInputV2, ForkchoiceState, ForkchoiceUpdated,
    PayloadId, PayloadStatus,
};
use anyhow::anyhow;
use serde_json::Value;

use super::client::Client;
use crate::{
    error::{Result, RpcClientError},
    l1_origin::EngineRpcL1Origin,
};

/// Re-export of Taiko's pre-built transaction list type using untyped transactions.
pub type PreBuiltTxList = TaikoPreBuiltTxList<Value>;

/// Taiko authenticated RPC method names.
#[derive(Debug, Clone, Copy)]
pub enum TaikoAuthMethod {
    /// Fetch pre-built transaction lists with minimum tip.
    TxPoolContentWithMinTip,
    /// Update L1 origin metadata.
    UpdateL1Origin,
    /// Set L1 origin signature.
    SetL1OriginSignature,
    /// Set head L1 origin pointer.
    SetHeadL1Origin,
    /// Set batch to last block mapping.
    SetBatchToLastBlock,
    /// Fetch the last L1 origin for a batch id.
    LastL1OriginByBatchId,
    /// Fetch the last block id for a batch id.
    LastBlockIdByBatchId,
}

impl TaikoAuthMethod {
    /// Get the RPC method name as a string.
    pub const fn as_str(&self) -> &'static str {
        match self {
            Self::TxPoolContentWithMinTip => "taikoAuth_txPoolContentWithMinTip",
            Self::UpdateL1Origin => "taikoAuth_updateL1Origin",
            Self::SetL1OriginSignature => "taikoAuth_setL1OriginSignature",
            Self::SetHeadL1Origin => "taikoAuth_setHeadL1Origin",
            Self::SetBatchToLastBlock => "taikoAuth_setBatchToLastBlock",
            Self::LastL1OriginByBatchId => "taikoAuth_lastL1OriginByBatchID",
            Self::LastBlockIdByBatchId => "taikoAuth_lastBlockIDByBatchID",
        }
    }
}

/// Taiko engine API method names.
#[derive(Debug, Clone, Copy)]
pub enum TaikoEngineMethod {
    /// Submit a new execution payload.
    NewPayloadV2,
    /// Update forkchoice state and optionally request payload building.
    ForkchoiceUpdatedV2,
    /// Retrieve a built payload by id.
    GetPayloadV2,
}

impl TaikoEngineMethod {
    /// Get the RPC method name as a string.
    pub const fn as_str(&self) -> &'static str {
        match self {
            Self::NewPayloadV2 => "engine_newPayloadV2",
            Self::ForkchoiceUpdatedV2 => "engine_forkchoiceUpdatedV2",
            Self::GetPayloadV2 => "engine_getPayloadV2",
        }
    }
}

/// Parameters for fetching pre-built transaction lists with minimum tip.
pub struct TxPoolContentParams {
    /// Beneficiary used for txpool list filtering on the engine side.
    pub beneficiary: Address,
    /// Optional base fee hint used by the txpool prebuild endpoint.
    pub base_fee: Option<u64>,
    /// Block gas limit used when building candidate tx lists.
    pub block_max_gas_limit: u64,
    /// Maximum encoded bytes permitted per returned tx list.
    pub max_bytes_per_tx_list: u64,
    /// Local addresses to prioritize in txpool prebuild.
    pub locals: Vec<String>,
    /// Maximum number of tx lists requested from the engine.
    pub max_transactions_lists: u64,
    /// Minimum tip (wei) required for transactions in returned lists.
    pub min_tip: u64,
}

/// JSON payload submitted to Taiko's `engine_newPayloadV2` endpoint.
#[derive(serde::Serialize)]
#[serde(rename_all = "camelCase")]
struct EngineNewPayloadV2Request<'a> {
    /// Standard execution payload fields, including optional withdrawals.
    #[serde(flatten)]
    payload: &'a ExecutionPayloadInputV2,
    /// Transactions root hash tracked by the Taiko sidecar.
    tx_hash: alloy_primitives::B256,
    /// Withdrawals root hash tracked by the Taiko sidecar.
    withdrawals_hash: alloy_primitives::B256,
    /// Optional hash-relevant header difficulty restored for Uzen blocks.
    #[serde(skip_serializing_if = "Option::is_none")]
    header_difficulty: Option<U256>,
    /// Optional marker flag indicating that the payload is Taiko-specific.
    #[serde(skip_serializing_if = "Option::is_none")]
    taiko_block: Option<bool>,
}

/// Serialize a Taiko execution payload and sidecar into the `engine_newPayloadV2` JSON shape.
fn engine_new_payload_v2_value(
    payload: &ExecutionPayloadInputV2,
    sidecar: &TaikoExecutionDataSidecar,
) -> Result<Value> {
    serde_json::to_value(EngineNewPayloadV2Request {
        payload,
        tx_hash: sidecar.tx_hash,
        withdrawals_hash: sidecar.withdrawals_hash.unwrap_or_default(),
        header_difficulty: sidecar.header_difficulty,
        taiko_block: sidecar.taiko_block,
    })
    .map_err(|err| RpcClientError::Other(anyhow!(err)))
}

impl<P: Provider + Clone> Client<P> {
    /// Fetch pre-built transaction lists from the authenticated L2 execution engine.
    pub async fn tx_pool_content_with_min_tip(
        &self,
        params: TxPoolContentParams,
    ) -> Result<Vec<PreBuiltTxList>> {
        self.l2_auth_provider
            .raw_request(
                Cow::Borrowed(TaikoAuthMethod::TxPoolContentWithMinTip.as_str()),
                (
                    params.beneficiary,
                    params.base_fee,
                    params.block_max_gas_limit,
                    params.max_bytes_per_tx_list,
                    params.locals,
                    params.max_transactions_lists,
                    params.min_tip,
                ),
            )
            .await
            .map_err(Into::into)
    }

    /// Update the execution engine's L1 origin metadata for a given block.
    pub async fn update_l1_origin(&self, origin: &RpcL1Origin) -> Result<Option<RpcL1Origin>> {
        let origin = EngineRpcL1Origin::from(origin.clone());
        self.l2_auth_provider
            .raw_request::<_, Option<EngineRpcL1Origin>>(
                Cow::Borrowed(TaikoAuthMethod::UpdateL1Origin.as_str()),
                (origin,),
            )
            .await
            .map(|origin| origin.map(Into::into))
            .map_err(Into::into)
    }

    /// Store the signature associated with a block's L1 origin envelope.
    pub async fn set_l1_origin_signature(
        &self,
        block_id: U256,
        signature: FixedBytes<65>,
    ) -> Result<Option<RpcL1Origin>> {
        self.l2_auth_provider
            .raw_request::<_, Option<EngineRpcL1Origin>>(
                Cow::Borrowed(TaikoAuthMethod::SetL1OriginSignature.as_str()),
                (block_id, signature),
            )
            .await
            .map(|origin| origin.map(Into::into))
            .map_err(Into::into)
    }

    /// Update the head L1 origin pointer in the execution engine.
    pub async fn set_head_l1_origin(&self, block_id: U256) -> Result<Option<U256>> {
        self.l2_auth_provider
            .raw_request(Cow::Borrowed(TaikoAuthMethod::SetHeadL1Origin.as_str()), (block_id,))
            .await
            .map_err(Into::into)
    }

    /// Record the last block associated with a batch in the execution engine.
    pub async fn set_batch_to_last_block(
        &self,
        batch_id: U256,
        block_id: U256,
    ) -> Result<Option<U256>> {
        self.l2_auth_provider
            .raw_request(
                Cow::Borrowed(TaikoAuthMethod::SetBatchToLastBlock.as_str()),
                (batch_id, block_id),
            )
            .await
            .map_err(Into::into)
    }

    /// Fetch the last L1 origin associated with the given batch id via the authenticated engine
    /// API.
    pub async fn last_l1_origin_by_batch_id(
        &self,
        proposal_id: U256,
    ) -> Result<Option<RpcL1Origin>> {
        self.l2_auth_provider
            .raw_request::<_, Option<EngineRpcL1Origin>>(
                Cow::Borrowed(TaikoAuthMethod::LastL1OriginByBatchId.as_str()),
                (proposal_id,),
            )
            .await
            .or_else(handle_ignorable_origin_error)
            .map(|origin| origin.map(Into::into))
    }

    /// Fetch the last block id that corresponds to the provided batch id via the authenticated
    /// engine API.
    pub async fn last_block_id_by_batch_id(&self, proposal_id: U256) -> Result<Option<U256>> {
        self.l2_auth_provider
            .raw_request(
                Cow::Borrowed(TaikoAuthMethod::LastBlockIdByBatchId.as_str()),
                (proposal_id,),
            )
            .await
            .or_else(handle_ignorable_origin_error)
    }

    /// Submit a new payload via the execution engine API.
    pub async fn engine_new_payload_v2(
        &self,
        payload: &ExecutionPayloadInputV2,
        sidecar: &TaikoExecutionDataSidecar,
    ) -> Result<PayloadStatus> {
        let payload_value = engine_new_payload_v2_value(payload, sidecar)?;

        self.l2_auth_provider
            .raw_request(Cow::Borrowed(TaikoEngineMethod::NewPayloadV2.as_str()), (payload_value,))
            .await
            .map_err(Into::into)
    }

    /// Update the forkchoice state and optionally request a new payload build.
    pub async fn engine_forkchoice_updated_v2(
        &self,
        forkchoice_state: ForkchoiceState,
        payload_attributes: Option<TaikoPayloadAttributes>,
    ) -> Result<ForkchoiceUpdated> {
        let forkchoice_state = serde_json::to_value(forkchoice_state)
            .map_err(|err| RpcClientError::Other(anyhow!(err)))?;

        let payload_attributes = match payload_attributes {
            Some(payload_attributes) => Some(
                serde_json::to_value(&payload_attributes)
                    .map_err(|err| RpcClientError::Other(anyhow!(err)))?,
            ),
            None => None,
        };

        self.l2_auth_provider
            .raw_request(
                Cow::Borrowed(TaikoEngineMethod::ForkchoiceUpdatedV2.as_str()),
                (forkchoice_state, payload_attributes),
            )
            .await
            .map_err(Into::into)
    }

    /// Retrieve a built payload from the execution engine.
    pub async fn engine_get_payload_v2(
        &self,
        payload_id: PayloadId,
    ) -> Result<ExecutionPayloadEnvelopeV2> {
        self.l2_auth_provider
            .raw_request(Cow::Borrowed(TaikoEngineMethod::GetPayloadV2.as_str()), (payload_id,))
            .await
            .map_err(Into::into)
    }
}

/// Checks whether the underlying RPC error message represents a "not found" or ignorable response.
fn is_ignorable_origin_error(message: &str) -> bool {
    message.contains("not found") || message.contains("proposal last block uncertain")
}

/// Converts an RPC error into an optional origin, mapping ignorable errors to `Ok(None)`.
pub(crate) fn handle_ignorable_origin_error<T, E>(err: E) -> Result<Option<T>>
where
    E: Into<RpcClientError> + std::fmt::Display,
{
    let message = err.to_string();
    if is_ignorable_origin_error(&message) { Ok(None) } else { Err(err.into()) }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alethia_reth_primitives::engine::types::TaikoExecutionDataSidecar;
    use alloy_primitives::{Address, B256, Bytes, U256};
    use alloy_rpc_types_engine::ExecutionPayloadV1;

    #[test]
    fn engine_new_payload_v2_value_preserves_header_difficulty() {
        let payload = ExecutionPayloadInputV2 {
            execution_payload: ExecutionPayloadV1 {
                parent_hash: B256::from(U256::from(10u64)),
                fee_recipient: Address::from([1u8; 20]),
                state_root: B256::from(U256::from(2u64)),
                receipts_root: B256::from(U256::from(3u64)),
                logs_bloom: Default::default(),
                prev_randao: B256::from(U256::from(4u64)),
                block_number: 7,
                gas_limit: 30_000_000,
                gas_used: 0,
                timestamp: 123,
                extra_data: Bytes::new(),
                base_fee_per_gas: U256::from(1u64),
                block_hash: B256::from(U256::from(42u64)),
                transactions: vec![],
            },
            withdrawals: None,
        };

        let sidecar = TaikoExecutionDataSidecar {
            tx_hash: B256::from([0x11; 32]),
            withdrawals_hash: Some(B256::from([0x22; 32])),
            header_difficulty: Some(U256::from(7u64)),
            taiko_block: Some(true),
        };

        let value = engine_new_payload_v2_value(&payload, &sidecar).unwrap();
        let obj = value.as_object().expect("payload should serialize to a JSON object");

        assert_eq!(obj.get("headerDifficulty"), Some(&serde_json::json!("0x7")));
        assert_eq!(
            obj.get("txHash"),
            Some(&serde_json::json!(format!("{:#066x}", sidecar.tx_hash)))
        );
        assert_eq!(
            obj.get("withdrawalsHash"),
            Some(&serde_json::json!(format!("{:#066x}", sidecar.withdrawals_hash.unwrap())))
        );
        assert_eq!(obj.get("taikoBlock"), Some(&serde_json::json!(true)));
        assert!(!obj.contains_key("withdrawals"));
    }

    #[test]
    fn engine_new_payload_v2_value_omits_header_difficulty_when_absent() {
        let payload = ExecutionPayloadInputV2 {
            execution_payload: ExecutionPayloadV1 {
                parent_hash: B256::from(U256::from(10u64)),
                fee_recipient: Address::from([1u8; 20]),
                state_root: B256::from(U256::from(2u64)),
                receipts_root: B256::from(U256::from(3u64)),
                logs_bloom: Default::default(),
                prev_randao: B256::from(U256::from(4u64)),
                block_number: 7,
                gas_limit: 30_000_000,
                gas_used: 0,
                timestamp: 123,
                extra_data: Bytes::new(),
                base_fee_per_gas: U256::from(1u64),
                block_hash: B256::from(U256::from(42u64)),
                transactions: vec![],
            },
            withdrawals: None,
        };

        let sidecar = TaikoExecutionDataSidecar {
            tx_hash: B256::ZERO,
            withdrawals_hash: None,
            header_difficulty: None,
            taiko_block: Some(true),
        };

        let value = engine_new_payload_v2_value(&payload, &sidecar).unwrap();
        let obj = value.as_object().expect("payload should serialize to a JSON object");

        assert!(!obj.contains_key("headerDifficulty"));
    }

    #[test]
    fn engine_new_payload_v2_value_preserves_withdrawals_when_present() {
        let payload = ExecutionPayloadInputV2 {
            execution_payload: ExecutionPayloadV1 {
                parent_hash: B256::from(U256::from(10u64)),
                fee_recipient: Address::from([1u8; 20]),
                state_root: B256::from(U256::from(2u64)),
                receipts_root: B256::from(U256::from(3u64)),
                logs_bloom: Default::default(),
                prev_randao: B256::from(U256::from(4u64)),
                block_number: 7,
                gas_limit: 30_000_000,
                gas_used: 0,
                timestamp: 123,
                extra_data: Bytes::new(),
                base_fee_per_gas: U256::from(1u64),
                block_hash: B256::from(U256::from(42u64)),
                transactions: vec![],
            },
            withdrawals: Some(vec![]),
        };

        let sidecar = TaikoExecutionDataSidecar {
            tx_hash: B256::ZERO,
            withdrawals_hash: None,
            header_difficulty: None,
            taiko_block: Some(true),
        };

        let value = engine_new_payload_v2_value(&payload, &sidecar).unwrap();
        let obj = value.as_object().expect("payload should serialize to a JSON object");

        assert_eq!(obj.get("withdrawals"), Some(&serde_json::json!([])));
    }
}

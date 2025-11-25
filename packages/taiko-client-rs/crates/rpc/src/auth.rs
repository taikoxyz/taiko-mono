//! Authenticated RPC extensions for Taiko execution engine.

use std::borrow::Cow;

use alethia_reth_primitives::{
    engine::types::TaikoExecutionDataSidecar,
    payload::attributes::{RpcL1Origin, TaikoPayloadAttributes},
};
use alethia_reth_rpc::eth::auth::PreBuiltTxList as TaikoPreBuiltTxList;
use alloy_primitives::{Address, FixedBytes, U256};
use alloy_provider::Provider;
use alloy_rpc_types_engine::{
    ExecutionPayloadEnvelopeV2, ExecutionPayloadInputV2, ForkchoiceState, ForkchoiceUpdated,
    PayloadId, PayloadStatus,
};
use anyhow::anyhow;
use serde_json::Value;

use super::client::Client;
use crate::error::{Result, RpcClientError};

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
    pub beneficiary: Address,
    pub base_fee: Option<u64>,
    pub block_max_gas_limit: u64,
    pub max_bytes_per_tx_list: u64,
    pub locals: Vec<String>,
    pub max_transactions_lists: u64,
    pub min_tip: u64,
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
        self.l2_auth_provider
            .raw_request(Cow::Borrowed(TaikoAuthMethod::UpdateL1Origin.as_str()), (origin,))
            .await
            .map_err(Into::into)
    }

    /// Store the signature associated with a block's L1 origin envelope.
    pub async fn set_l1_origin_signature(
        &self,
        block_id: U256,
        signature: FixedBytes<65>,
    ) -> Result<Option<RpcL1Origin>> {
        self.l2_auth_provider
            .raw_request(
                Cow::Borrowed(TaikoAuthMethod::SetL1OriginSignature.as_str()),
                (block_id, signature),
            )
            .await
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

    /// Submit a new payload via the execution engine API.
    pub async fn engine_new_payload_v2(
        &self,
        payload: &ExecutionPayloadInputV2,
        sidecar: &TaikoExecutionDataSidecar,
    ) -> Result<PayloadStatus> {
        let mut payload_value = serde_json::to_value(&payload.execution_payload)
            .map_err(|err| RpcClientError::Other(anyhow!(err)))?;
        if let serde_json::Value::Object(ref mut obj) = payload_value {
            obj.insert(
                "txHash".to_string(),
                serde_json::Value::String(format!("{:#066x}", sidecar.tx_hash)),
            );
            let withdrawals_hex = format!("{:#066x}", sidecar.withdrawals_hash.unwrap_or_default());
            obj.insert("withdrawalsHash".to_string(), serde_json::Value::String(withdrawals_hex));
            if let Some(flag) = sidecar.taiko_block {
                obj.insert("taikoBlock".to_string(), serde_json::Value::Bool(flag));
            }
        }

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

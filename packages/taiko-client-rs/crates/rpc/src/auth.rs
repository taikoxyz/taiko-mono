use std::borrow::Cow;

use alethia_reth::{
    payload::attributes::RpcL1Origin, rpc::eth::auth::PreBuiltTxList as TaikoPreBuiltTxList,
};
use alloy_primitives::{Address, FixedBytes, U256};
use alloy_provider::Provider;
use anyhow::Result;
use serde_json::Value;

use super::client::Client;

/// Re-export of Taiko's pre-built transaction list type using untyped transactions.
pub type PreBuiltTxList = TaikoPreBuiltTxList<Value>;

/// Re-export of Taiko's L1 origin payload type.
pub type L1Origin = RpcL1Origin;

impl Client {
    /// Fetch pre-built transaction lists from the authenticated L2 execution engine.
    pub async fn tx_pool_content_with_min_tip(
        &self,
        beneficiary: Address,
        base_fee: Option<U256>,
        block_max_gas_limit: u64,
        max_bytes_per_tx_list: u64,
        locals: Vec<String>,
        max_transactions_lists: u64,
        min_tip: u64,
    ) -> Result<Vec<PreBuiltTxList>> {
        self.l2_provider
            .raw_request(
                Cow::Borrowed("taikoAuth_txPoolContentWithMinTip"),
                (
                    beneficiary,
                    base_fee,
                    block_max_gas_limit,
                    max_bytes_per_tx_list,
                    locals,
                    max_transactions_lists,
                    min_tip,
                ),
            )
            .await
            .map_err(Into::into)
    }

    /// Update the execution engine's L1 origin metadata for a given block.
    pub async fn update_l1_origin(&self, origin: &L1Origin) -> Result<Option<L1Origin>> {
        self.l2_provider
            .raw_request(Cow::Borrowed("taikoAuth_updateL1Origin"), (origin,))
            .await
            .map_err(Into::into)
    }

    /// Store the signature associated with a block's L1 origin envelope.
    pub async fn set_l1_origin_signature(
        &self,
        block_id: U256,
        signature: FixedBytes<65>,
    ) -> Result<Option<L1Origin>> {
        self.l2_provider
            .raw_request(Cow::Borrowed("taikoAuth_setL1OriginSignature"), (block_id, signature))
            .await
            .map_err(Into::into)
    }

    /// Update the head L1 origin pointer in the execution engine.
    pub async fn set_head_l1_origin(&self, block_id: U256) -> Result<Option<U256>> {
        self.l2_provider
            .raw_request(Cow::Borrowed("taikoAuth_setHeadL1Origin"), (block_id,))
            .await
            .map_err(Into::into)
    }

    /// Record the last block associated with a batch in the execution engine.
    pub async fn set_batch_to_last_block(
        &self,
        batch_id: U256,
        block_id: U256,
    ) -> Result<Option<U256>> {
        self.l2_provider
            .raw_request(Cow::Borrowed("taikoAuth_setBatchToLastBlock"), (batch_id, block_id))
            .await
            .map_err(Into::into)
    }
}

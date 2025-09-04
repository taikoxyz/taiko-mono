use std::time::Duration;

use alloy_consensus::{BlockHeader, Header as ConsensusHeader};
use alloy_primitives::{Address, Bytes, U256, hex::FromHex};
use alloy_provider::Provider;
use alloy_rpc_types_eth::BlockNumberOrTag;
use anyhow::{Context, Result};
use serde::Deserialize;
use taiko_reth::consensus::eip4396::{
    SHASTA_INITIAL_BASE_FEE, calculate_next_block_eip4396_base_fee,
};
use tokio::time::timeout;
use tracing::debug;

use crate::client::RpcClient;

/// Default timeout for RPC operations
const DEFAULT_TIMEOUT: Duration = Duration::from_secs(30);

/// Parameters for fetching transaction pool content
#[derive(Debug)]
pub struct FetchTxPoolParams {
    beneficiary: Address,
    base_fee: U256,
    block_max_gas_limit: u64,
    max_bytes_per_tx_list: u64,
    locals: Vec<String>,
    max_transactions_lists: u64,
    min_tip: u64,
}

/// Configuration for base fee calculation
#[derive(Debug, Clone)]
pub struct BaseFeeConfig {
    pub adjustment_quotient: u64,
    pub gas_issuance_per_second: u64,
}

/// Pre-built transaction list from the transaction pool
#[derive(Debug, Clone, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PreBuiltTxList {
    #[serde(deserialize_with = "deserialize_hex_bytes_vec")]
    pub transactions: Vec<Bytes>,
    pub estimated_gas_used: u64,
    pub bytes_size: u64,
}

/// Custom deserializer for Vec<Bytes> from hex strings
fn deserialize_hex_bytes_vec<'de, D>(deserializer: D) -> Result<Vec<Bytes>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    let hex_strings: Vec<String> = Vec::deserialize(deserializer)?;
    hex_strings.into_iter().map(|s| Bytes::from_hex(&s).map_err(serde::de::Error::custom)).collect()
}

/// Parameters for fetching pool content
#[derive(Debug, Clone)]
pub struct GetPoolContentParams {
    pub beneficiary: Address,
    pub block_max_gas_limit: u32,
    pub max_bytes_per_tx_list: u64,
    pub locals: Vec<Address>,
    pub max_transactions_lists: u64,
    pub min_tip: u64,
    pub base_fee_config: BaseFeeConfig,
}

impl RpcClient {
    /// Fetches transaction pool content with the specified parameters.
    ///
    /// This method:
    /// 1. Gets the latest L2 head
    /// 2. Calculates the base fee
    /// 3. Fetches transactions from the pool that meet the criteria
    ///
    /// # Arguments
    /// * `params` - Parameters for fetching pool content
    ///
    /// # Returns
    /// A list of pre-built transaction lists ready for proposing
    pub async fn get_pool_content(
        &self,
        params: GetPoolContentParams,
    ) -> Result<Vec<PreBuiltTxList>> {
        // Get the latest L2 head with timeout
        let l2_head = timeout(
            DEFAULT_TIMEOUT,
            self.l2_provider().get_block_by_number(BlockNumberOrTag::Latest),
        )
        .await
        .context("Timeout while fetching L2 head")?
        .context("Failed to fetch L2 head")?
        .context("L2 head block not found")?;

        debug!("Latest L2 head: block #{}", l2_head.header.number);

        let base_fee = self
            .calculate_base_fee(&l2_head.header)
            .await
            .context("Failed to calculate base fee")?;

        debug!("Calculated base fee: {}", base_fee);

        // Convert local addresses to strings for the RPC call
        let locals_arg: Vec<String> =
            params.locals.iter().map(|addr| format!("{:#x}", addr)).collect();

        // Fetch transaction pool content from L2 engine
        let tx_lists = self
            .fetch_tx_pool_content(FetchTxPoolParams {
                beneficiary: params.beneficiary,
                base_fee,
                block_max_gas_limit: params.block_max_gas_limit as u64,
                max_bytes_per_tx_list: params.max_bytes_per_tx_list,
                locals: locals_arg,
                max_transactions_lists: params.max_transactions_lists,
                min_tip: params.min_tip,
            })
            .await
            .context("Failed to fetch transaction pool content")?;

        Ok(tx_lists)
    }

    /// Calculates the base fee for the next block.
    async fn calculate_base_fee(&self, l2_head: &alloy_rpc_types_eth::Header) -> Result<U256> {
        if l2_head.number < 1 {
            return Ok(U256::from(SHASTA_INITIAL_BASE_FEE));
        }

        // Convert RPC header to consensus header by accessing inner fields
        let consensus_header = ConsensusHeader {
            parent_hash: l2_head.parent_hash,
            ommers_hash: l2_head.ommers_hash,
            beneficiary: l2_head.beneficiary,
            state_root: l2_head.state_root,
            transactions_root: l2_head.transactions_root,
            receipts_root: l2_head.receipts_root,
            logs_bloom: l2_head.logs_bloom,
            difficulty: l2_head.difficulty,
            number: l2_head.number,
            gas_limit: l2_head.gas_limit,
            gas_used: l2_head.gas_used,
            timestamp: l2_head.timestamp,
            extra_data: l2_head.extra_data.clone(),
            mix_hash: l2_head.mix_hash,
            nonce: l2_head.nonce,
            base_fee_per_gas: l2_head.base_fee_per_gas,
            withdrawals_root: l2_head.withdrawals_root,
            blob_gas_used: l2_head.blob_gas_used,
            excess_blob_gas: l2_head.excess_blob_gas,
            parent_beacon_block_root: l2_head.parent_beacon_block_root,
            requests_hash: None,
        };

        let l2_head_parent = self
            .l1_provider()
            .get_block_by_hash(l2_head.parent_hash)
            .await?
            .context("L2 head parent block not found")?;

        Ok(U256::from(calculate_next_block_eip4396_base_fee(
            &consensus_header,
            l2_head.timestamp() - l2_head_parent.header.timestamp(),
        )))
    }

    /// Fetches transaction pool content from the L2 engine.
    ///
    /// This calls the `taikoAuth_txPoolContentWithMinTip` RPC method on the L2 engine.
    pub async fn fetch_tx_pool_content(
        &self,
        params: FetchTxPoolParams,
    ) -> Result<Vec<PreBuiltTxList>> {
        let engine_client = self
            .l2_engine_client()
            .ok_or_else(|| anyhow::anyhow!("L2 engine client not configured"))?;

        debug!(
            "Fetching L2 pending transactions with baseFee: {}, blockMaxGasLimit: {}, maxBytesPerTxList: {}, maxTransactions: {}, locals: {:?}, minTip: {}",
            params.base_fee,
            params.block_max_gas_limit,
            params.max_bytes_per_tx_list,
            params.max_transactions_lists,
            params.locals,
            params.min_tip
        );

        // Build RPC parameters
        let rpc_params = serde_json::json!([
            params.beneficiary,
            format!("0x{:x}", params.base_fee), // Convert U256 to hex string
            params.block_max_gas_limit,
            params.max_bytes_per_tx_list,
            params.locals,
            params.max_transactions_lists,
            params.min_tip,
        ]);

        let response: serde_json::Value = engine_client
            .request("taikoAuth_txPoolContentWithMinTip", rpc_params)
            .await
            .context("Failed to call taikoAuth_txPoolContentWithMinTip")?;

        // Parse the response into PreBuiltTxList
        let tx_lists = parse_tx_pool_response(response)
            .context("Failed to parse transaction pool response")?;

        debug!("Fetched {} transaction lists from L2 engine", tx_lists.len());

        Ok(tx_lists)
    }
}

/// Parses the JSON response from the txPoolContentWithMinTip RPC call.
fn parse_tx_pool_response(response: serde_json::Value) -> Result<Vec<PreBuiltTxList>> {
    serde_json::from_value(response).context("Failed to deserialize transaction pool response")
}

//! Core proposer implementation for submitting block proposals.

use alethia_reth_consensus::{
    eip4396::{SHASTA_INITIAL_BASE_FEE, calculate_next_block_eip4396_base_fee},
    validation::ANCHOR_V3_V4_GAS_LIMIT,
};
use alethia_reth_primitives::{
    decode_shasta_proposal_id,
    payload::attributes::{RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes},
};
use alloy::{
    eips::BlockNumberOrTag,
    primitives::{B256, Bytes, U256},
    providers::Provider,
    rpc::types::{Block, Transaction},
};
use alloy_consensus::TxEnvelope;
use alloy_eips::eip2718::{Decodable2718, Encodable2718};
use alloy_network::TransactionBuilder;
use alloy_rpc_types_engine::{
    ExecutionPayloadFieldV2, ForkchoiceState, PayloadAttributes as EthPayloadAttributes,
};
use metrics::{counter, gauge, histogram};
use protocol::shasta::{
    AnchorTxConstructor, AnchorV4Input, calculate_shasta_difficulty,
    constants::{MIN_BLOCK_GAS_LIMIT, PROPOSAL_MAX_BLOB_BYTES},
    encode_extra_data,
};
use rpc::client::{Client, ClientConfig, ClientWithWallet};
use serde_json::from_value;
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::time::interval;
use tracing::{error, info, instrument};

use crate::{
    config::ProposerConfigs,
    error::{ProposerError, Result},
    metrics::ProposerMetrics,
    transaction_builder::ShastaProposalTransactionBuilder,
};

use alloy_provider::RootProvider;

// Type alias for a list of transactions lists.
pub type TransactionsLists = Vec<Vec<Transaction>>;

/// Parameters captured from engine mode payload building.
/// These ensure consistency between the anchor transaction and the block manifest.
#[derive(Debug, Clone, Copy)]
pub struct EnginePayloadParams {
    /// The L1 block number used for the anchor transaction.
    pub anchor_block_number: u64,
    /// The timestamp used for the payload.
    pub timestamp: u64,
    /// The gas limit for the block.
    pub gas_limit: u64,
}

// Proposer keeps proposing new transactions from L2 execution engine's tx pool at a fixed interval.
pub struct Proposer {
    rpc_provider: ClientWithWallet,
    transaction_builder: ShastaProposalTransactionBuilder,
    anchor_constructor: AnchorTxConstructor<RootProvider<alloy_network::Ethereum>>,
    cfg: ProposerConfigs,
}

impl Proposer {
    /// Creates a new proposer instance.
    #[instrument(skip(cfg), fields(inbox_address = ?cfg.inbox_address))]
    pub async fn new(cfg: ProposerConfigs) -> Result<Self> {
        info!(
            inbox_address = ?cfg.inbox_address,
            l2_suggested_fee_recipient = ?cfg.l2_suggested_fee_recipient,
            propose_interval = ?cfg.propose_interval,
            "initializing proposer"
        );

        let rpc_provider = Client::new_with_wallet(
            ClientConfig {
                l1_provider_source: cfg.l1_provider_source.clone(),
                l2_provider_url: cfg.l2_provider_url.clone(),
                l2_auth_provider_url: cfg.l2_auth_provider_url.clone(),
                jwt_secret: cfg.jwt_secret.clone(),
                inbox_address: cfg.inbox_address,
            },
            cfg.l1_proposer_private_key,
        )
        .await?;

        let transaction_builder = ShastaProposalTransactionBuilder::new(
            rpc_provider.clone(),
            cfg.l2_suggested_fee_recipient,
        );

        // Initialize anchor transaction constructor for engine mode.
        let anchor_constructor = AnchorTxConstructor::new(
            rpc_provider.l2_provider.clone(),
            *rpc_provider.shasta.anchor.address(),
        )
        .await?;

        Ok(Self { rpc_provider, cfg, transaction_builder, anchor_constructor })
    }

    /// Start the proposer main loop.
    pub async fn start(&self) -> Result<()> {
        let mut interval = interval(self.cfg.propose_interval);
        let mut epoch = 0;

        loop {
            interval.tick().await;
            info!(epoch, "proposer epoch");

            self.fetch_and_propose().await?;

            epoch += 1;
        }
    }

    /// Fetch L2 EE mempool and propose a new proposal to protocol inbox.
    /// Fetch transactions and submit a proposal once.
    pub async fn fetch_and_propose(&self) -> Result<()> {
        // Fetch transactions based on mode.
        // Engine mode also returns the parameters used for the anchor transaction.
        let (pool_content, engine_params) = if self.cfg.use_engine_mode {
            let (txs, params) = self.fetch_payload_transactions().await?;
            (txs, Some(params))
        } else {
            (self.fetch_pool_content().await?, None)
        };

        // Record number of transactions in the pool
        let tx_count: usize = pool_content.iter().map(|list| list.len()).sum();
        gauge!(ProposerMetrics::TX_POOL_SIZE).set(tx_count as f64);
        info!(
            txs_lists = pool_content.len(),
            tx_count,
            engine_mode = self.cfg.use_engine_mode,
            ?engine_params,
            "fetched transaction pool content"
        );

        let mut transaction_request =
            self.transaction_builder.build(pool_content, engine_params).await?;

        // Set gas limit if configured, otherwise let the provider estimate it.
        if let Some(gas_limit) = self.cfg.gas_limit {
            transaction_request = transaction_request.with_gas_limit(gas_limit);
        }

        // Send transaction using provider with wallet filler.
        // The wallet filler will automatically fill nonce, gas_limit, fees, and sign the
        // transaction.
        let pending_tx =
            self.rpc_provider.l1_provider.send_transaction(transaction_request).await?;

        info!(tx_hash = %pending_tx.tx_hash(), "proposal transaction sent");
        counter!(ProposerMetrics::PROPOSALS_SENT).increment(1);

        let receipt = pending_tx.get_receipt().await?;

        if receipt.status() {
            info!(
                tx_hash = %receipt.transaction_hash,
                gas_used = receipt.gas_used,
                "proposal transaction mined successfully"
            );
            counter!(ProposerMetrics::PROPOSALS_SUCCESS).increment(1);

            // Record gas used
            histogram!(ProposerMetrics::GAS_USED).record(receipt.gas_used as f64);
        } else {
            error!(tx_hash = %receipt.transaction_hash, "proposal transaction failed");
            counter!(ProposerMetrics::PROPOSALS_FAILED).increment(1);
        }

        Ok(())
    }

    /// Return a clone of the RPC client bundle used by the proposer.
    pub fn rpc_client(&self) -> ClientWithWallet {
        self.rpc_provider.clone()
    }

    /// Fetch transaction pool content from the L2 execution engine.
    async fn fetch_pool_content(&self) -> Result<TransactionsLists> {
        let base_fee_u64 = u64::try_from(self.calculate_next_shasta_block_base_fee().await?)
            .map_err(|_| ProposerError::BaseFeeOverflow)?;

        let pool_content = self
            .rpc_provider
            .tx_pool_content_with_min_tip(rpc::TxPoolContentParams {
                beneficiary: self.cfg.l2_suggested_fee_recipient,
                base_fee: Some(base_fee_u64),
                block_max_gas_limit: MIN_BLOCK_GAS_LIMIT,
                max_bytes_per_tx_list: PROPOSAL_MAX_BLOB_BYTES as u64,
                locals: vec![],
                max_transactions_lists: 1,
                min_tip: 0,
            })
            .await?;

        info!(
            txs_lists_count = pool_content.len(),
            "fetched transactions lists from L2 execution engine"
        );

        let txs_lists = pool_content
            .into_iter()
            .map(|content| {
                content
                    .tx_list
                    .into_iter()
                    .map(|tx| from_value::<Transaction>(tx).map_err(ProposerError::from))
                    .collect::<Result<Vec<_>>>()
            })
            .collect::<Result<Vec<Vec<_>>>>()?;

        Ok(txs_lists)
    }

    /// Calculate the base fee for the next L2 block using EIP-4396 rules.
    async fn calculate_next_shasta_block_base_fee(&self) -> Result<U256> {
        // Get the latest block to calculate the next base fee.
        let parent = self
            .rpc_provider
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await?
            .ok_or(ProposerError::LatestBlockNotFound)?;

        // If the parent is genesis, return the initial base fee.
        if parent.number() == 0 {
            return Ok(U256::from(SHASTA_INITIAL_BASE_FEE));
        }

        // Calculate the parent block time by subtracting its timestamp from its parent's timestamp.
        let parent_block_time = parent.header.timestamp -
            self.rpc_provider
                .l2_provider
                .get_block_by_number(BlockNumberOrTag::Number(parent.number() - 1))
                .await?
                .ok_or_else(|| ProposerError::ParentBlockNotFound(parent.number() - 1))?
                .header
                .timestamp;

        Ok(U256::from(calculate_next_block_eip4396_base_fee(
            &parent.header.inner,
            parent_block_time,
        )))
    }

    /// Build forkchoice state from L2 chain.
    /// Returns the forkchoice state and the head block used.
    async fn build_forkchoice_state(&self) -> Result<(ForkchoiceState, Block)> {
        let head = self
            .rpc_provider
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await?
            .ok_or(ProposerError::LatestBlockNotFound)?;

        let safe = self
            .rpc_provider
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Safe)
            .await?
            .map(|b| b.header.hash)
            .unwrap_or(head.header.hash);

        let finalized = self
            .rpc_provider
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Finalized)
            .await?
            .map(|b| b.header.hash)
            .unwrap_or(head.header.hash);

        Ok((
            ForkchoiceState {
                head_block_hash: head.header.hash,
                safe_block_hash: safe,
                finalized_block_hash: finalized,
            },
            head,
        ))
    }

    /// Build Taiko payload attributes for engine mode.
    /// Constructs the payload attributes with anchor transaction and block metadata.
    /// Returns the payload attributes and the engine payload parameters used.
    async fn build_payload_attributes(
        &self,
        parent: &Block,
    ) -> Result<(TaikoPayloadAttributes, EnginePayloadParams)> {
        let block_number = parent.number() + 1;
        let timestamp = current_unix_timestamp();

        // Get basefee sharing percentage from inbox config.
        let inbox_config = self.rpc_provider.shasta.inbox.getConfig().call().await?;
        let basefee_sharing_pctg = inbox_config.basefeeSharingPctg;

        // Get proposal ID from parent's extra data and increment.
        let proposal_id = decode_shasta_proposal_id(&parent.header.extra_data)
            .ok_or(ProposerError::InvalidExtraData)? +
            1;

        // Calculate base fee for the new block.
        let base_fee = self.calculate_next_shasta_block_base_fee().await?;

        // Get latest L1 block for anchor transaction.
        let l1_block = self
            .rpc_provider
            .l1_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await?
            .ok_or(ProposerError::LatestBlockNotFound)?;
        let anchor_block_number = l1_block.header.number;

        // Build anchor transaction.
        let anchor_tx = self
            .anchor_constructor
            .assemble_anchor_v4_tx(
                parent.header.hash,
                AnchorV4Input {
                    anchor_block_number,
                    anchor_block_hash: l1_block.header.hash,
                    anchor_state_root: l1_block.header.inner.state_root,
                    l2_height: block_number,
                    base_fee,
                },
            )
            .await?;

        // Calculate mix hash (difficulty).
        let mix_hash = calculate_shasta_difficulty(parent.header.inner.mix_hash, block_number);

        let payload_attributes = TaikoPayloadAttributes {
            payload_attributes: EthPayloadAttributes {
                timestamp,
                prev_randao: mix_hash,
                suggested_fee_recipient: self.cfg.l2_suggested_fee_recipient,
                withdrawals: Some(vec![]),
                parent_beacon_block_root: None,
            },
            base_fee_per_gas: base_fee,
            block_metadata: TaikoBlockMetadata {
                beneficiary: self.cfg.l2_suggested_fee_recipient,
                gas_limit: parent.header.gas_limit,
                timestamp: U256::from(timestamp),
                mix_hash,
                tx_list: None, // Engine mode: let node select from mempool
                extra_data: encode_extra_data(basefee_sharing_pctg, proposal_id),
            },
            l1_origin: RpcL1Origin {
                block_id: U256::from(block_number),
                l2_block_hash: B256::ZERO,
                l1_block_height: Some(U256::from(anchor_block_number)),
                l1_block_hash: Some(l1_block.header.hash),
                build_payload_args_id: [0; 8],
                is_forced_inclusion: false,
                signature: [0; 65],
            },
            anchor_transaction: Some(Bytes::from(anchor_tx.encoded_2718())),
        };

        let engine_params = EnginePayloadParams {
            anchor_block_number,
            timestamp,
            gas_limit: parent.header.gas_limit,
        };

        Ok((payload_attributes, engine_params))
    }

    /// Fetch transactions using Engine API (FCU + get_payload).
    /// In engine mode, we use forkchoice_updated to trigger payload building
    /// with tx_list: None, then retrieve the built payload to extract transactions.
    /// Returns the transactions and the engine payload parameters used.
    async fn fetch_payload_transactions(&self) -> Result<(TransactionsLists, EnginePayloadParams)> {
        // Build forkchoice state and get the head block to use as parent.
        let (forkchoice_state, parent) = self.build_forkchoice_state().await?;

        // Build payload attributes and capture the engine parameters used.
        let (payload_attributes, engine_params) = self.build_payload_attributes(&parent).await?;

        info!(
            parent_number = parent.number(),
            parent_hash = %parent.header.hash,
            anchor_block_number = engine_params.anchor_block_number,
            timestamp = engine_params.timestamp,
            gas_limit = engine_params.gas_limit,
            "sending forkchoice_updated with payload attributes"
        );

        // Send forkchoice_updated to trigger payload building.
        let fcu_response = self
            .rpc_provider
            .engine_forkchoice_updated_v2(forkchoice_state, Some(payload_attributes))
            .await
            .map_err(|e| ProposerError::FcuFailed(e.to_string()))?;

        // Check FCU response status.
        if !fcu_response.payload_status.is_valid() {
            return Err(ProposerError::FcuFailed(format!(
                "invalid payload status: {:?}",
                fcu_response.payload_status
            )));
        }

        // Get payload ID from FCU response.
        let payload_id = fcu_response.payload_id.ok_or(ProposerError::NoPayloadId)?;

        info!(payload_id = ?payload_id, "received payload ID, fetching payload");

        // Fetch the built payload.
        let payload_envelope = self
            .rpc_provider
            .engine_get_payload_v2(payload_id)
            .await
            .map_err(|e| ProposerError::Rpc(e.to_string()))?;

        // Extract transactions from payload based on version.
        let transactions = match &payload_envelope.execution_payload {
            ExecutionPayloadFieldV2::V1(payload) => &payload.transactions,
            ExecutionPayloadFieldV2::V2(payload) => &payload.payload_inner.transactions,
        };

        // If no transactions, return empty list with engine parameters.
        if transactions.is_empty() {
            info!("payload contains no transactions");
            return Ok((vec![vec![]], engine_params));
        }

        // Skip the first transaction (anchor) and parse the rest.
        let txs: Vec<Transaction> = transactions
            .iter()
            .skip(1) // Skip anchor transaction
            .filter_map(|tx_bytes: &Bytes| {
                // Decode the transaction from RLP bytes.
                TxEnvelope::decode_2718(&mut tx_bytes.as_ref()).ok().and_then(|tx| {
                    // Convert TxEnvelope to rpc Transaction.
                    serde_json::to_value(&tx).ok().and_then(|v| from_value::<Transaction>(v).ok())
                })
            })
            .collect();

        info!(
            tx_count = txs.len(),
            total_payload_txs = transactions.len(),
            anchor_block_number = engine_params.anchor_block_number,
            "extracted user transactions from engine payload"
        );

        Ok((vec![txs], engine_params))
    }
}

/// Returns the current UNIX timestamp in seconds.
pub(crate) fn current_unix_timestamp() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs()
}

#[cfg(test)]
mod tests {
    use std::time::{SystemTime, UNIX_EPOCH};

    use super::current_unix_timestamp;

    #[test]
    fn current_unix_timestamp_tracks_system_time() {
        let before = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs();
        let timestamp = current_unix_timestamp();
        let after = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs();

        assert!(timestamp >= before);
        assert!(timestamp <= after);
    }
}

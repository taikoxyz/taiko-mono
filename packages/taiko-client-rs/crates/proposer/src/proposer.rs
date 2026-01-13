//! Core proposer implementation for submitting block proposals.

use alethia_reth_consensus::eip4396::{
    SHASTA_INITIAL_BASE_FEE, calculate_next_block_eip4396_base_fee,
};
use alloy::{
    eips::BlockNumberOrTag, primitives::U256, providers::Provider, rpc::types::Transaction,
};
use alloy_network::TransactionBuilder;
use metrics::{counter, gauge, histogram};
use protocol::shasta::constants::{MIN_BLOCK_GAS_LIMIT, PROPOSAL_MAX_BLOB_BYTES};
use rpc::client::{Client, ClientConfig, ClientWithWallet};
use serde_json::from_value;
use tokio::time::interval;
use tracing::{error, info, instrument};

use crate::{
    config::ProposerConfigs,
    error::{ProposerError, Result},
    metrics::ProposerMetrics,
    transaction_builder::ShastaProposalTransactionBuilder,
};

// Type alias for a list of transactions lists.
pub type TransactionsLists = Vec<Vec<Transaction>>;

// Proposer keeps proposing new transactions from L2 execution engine's tx pool at a fixed interval.
pub struct Proposer {
    rpc_provider: ClientWithWallet,
    transaction_builder: ShastaProposalTransactionBuilder,
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

        Ok(Self { rpc_provider, cfg, transaction_builder })
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
        // Fetch mempool content from L2 execution engine.
        let pool_content = self.fetch_pool_content().await?;

        // Record number of transactions in the pool
        let tx_count: usize = pool_content.iter().map(|list| list.len()).sum();
        gauge!(ProposerMetrics::TX_POOL_SIZE).set(tx_count as f64);
        info!(txs_lists = pool_content.len(), tx_count, "fetched transaction pool content");

        let mut transaction_request = self.transaction_builder.build(pool_content).await?;

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
}

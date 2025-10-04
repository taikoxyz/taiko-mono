//! Core proposer implementation for submitting block proposals.

use alethia_reth::consensus::eip4396::{
    SHASTA_INITIAL_BASE_FEE, calculate_next_block_eip4396_base_fee,
};
use alloy::{
    eips::BlockNumberOrTag, primitives::U256, providers::Provider, rpc::types::Transaction,
};
use alloy_network::TransactionBuilder;
use event_indexer::indexer::{ShastaEventIndexer, ShastaEventIndexerConfig};
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

        // Initialize RPC client.
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

        // Initialize event indexer.
        let indexer = ShastaEventIndexer::new(ShastaEventIndexerConfig {
            l1_subscription_source: cfg.l1_provider_source.clone(),
            inbox_address: cfg.inbox_address,
        })
        .await?;
        indexer.clone().spawn();
        indexer.wait_historical_indexing_finished().await;

        let l2_suggested_fee_recipient = cfg.l2_suggested_fee_recipient;

        Ok(Self {
            rpc_provider: rpc_provider.clone(),
            cfg,
            transaction_builder: ShastaProposalTransactionBuilder::new(
                rpc_provider,
                indexer,
                l2_suggested_fee_recipient,
            ),
        })
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
    async fn fetch_and_propose(&self) -> Result<()> {
        // Fetch mempool content from L2 execution engine.
        let pool_content = self.fetch_pool_content().await?;

        // Record number of transactions in the pool
        gauge!(ProposerMetrics::TX_POOL_SIZE).set(pool_content.len() as f64);
        info!(tx_count = pool_content.len(), "fetched tx pool content");

        let mut transaction_request =
            self.transaction_builder.build(pool_content).await?.with_to(self.cfg.inbox_address);

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

    /// Fetch transaction pool content from the L2 execution engine.
    async fn fetch_pool_content(&self) -> Result<Vec<Transaction>> {
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

        info!(tx_lists_count = pool_content.len(), "fetched tx lists from L2 execution engine");

        let transactions = pool_content
            .into_iter()
            .flat_map(|tx_list| tx_list.tx_list.into_iter())
            .map(|tx| from_value::<Transaction>(tx).map_err(ProposerError::from))
            .collect::<Result<Vec<_>>>()?;

        Ok(transactions)
    }

    /// Calculate the base fee for the next L2 block using EIP-4396 rules.
    async fn calculate_next_shasta_block_base_fee(&self) -> Result<U256> {
        let parent = self
            .rpc_provider
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await?
            .ok_or(ProposerError::LatestBlockNotFound)?;

        // For the first two Shasta blocks, return the initial base fee.
        if parent.number() <= 2 {
            return Ok(U256::from(SHASTA_INITIAL_BASE_FEE));
        }

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

#[cfg(test)]
mod tests {
    use std::{borrow::Cow, env, path::PathBuf, str::FromStr, sync::OnceLock, time::Duration};

    use super::*;
    use alloy::{
        primitives::{Address, B256, aliases::U48},
        rpc::client::NoParams,
        transports::http::reqwest::Url,
    };
    use rpc::SubscriptionSource;

    fn init_tracing() {
        static INIT: OnceLock<()> = OnceLock::new();

        INIT.get_or_init(|| {
            let env_filter = tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("debug"));
            let _ = tracing_subscriber::fmt().with_env_filter(env_filter).try_init();
        });
    }

    #[tokio::test]
    async fn propose_shasta_batches() -> anyhow::Result<()> {
        init_tracing();

        let cfg = ProposerConfigs {
            l1_provider_source: SubscriptionSource::Ws(Url::from_str(&env::var("L1_WS")?)?),
            l2_provider_url: Url::from_str(&env::var("L2_HTTP")?)?,
            l2_auth_provider_url: Url::from_str(&env::var("L2_AUTH")?)?,
            jwt_secret: PathBuf::from_str(&env::var("JWT_SECRET")?)?,
            inbox_address: Address::from_str(&env::var("SHASTA_INBOX")?)?,
            l2_suggested_fee_recipient: Address::from_str(&env::var(
                "L2_SUGGESTED_FEE_RECIPIENT",
            )?)?,
            propose_interval: Duration::from_secs(0),
            l1_proposer_private_key: env::var("L1_PROPOSER_PRIVATE_KEY")?.parse()?,
            gas_limit: None,
        };

        let proposer = Proposer::new(cfg.clone()).await?;
        let provider = proposer.rpc_provider.clone();

        for i in 0..3 {
            assert_eq!(B256::ZERO, get_proposal_hash(provider.clone(), U48::from(i + 1)).await?);

            evm_mine(provider.clone()).await?;
            proposer.fetch_and_propose().await?;

            assert_ne!(B256::ZERO, get_proposal_hash(provider.clone(), U48::from(i + 1)).await?);
        }

        Ok(())
    }

    async fn evm_mine(client: ClientWithWallet) -> anyhow::Result<()> {
        client
            .l1_provider
            .raw_request::<_, String>(Cow::Borrowed("evm_mine"), NoParams::default())
            .await?;
        Ok(())
    }

    async fn get_proposal_hash(client: ClientWithWallet, proposal_id: U48) -> anyhow::Result<B256> {
        let hash = client.shasta.inbox.getProposalHash(proposal_id).call().await?;
        Ok(hash)
    }
}

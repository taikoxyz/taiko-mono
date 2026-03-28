//! Core proposer implementation for submitting block proposals.

use alethia_reth_consensus::eip4396::{
    SHASTA_INITIAL_BASE_FEE, calculate_next_block_eip4396_base_fee,
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
use alloy_consensus::{
    TxEnvelope,
    transaction::{Recovered, SignerRecoverable, TransactionInfo},
};
use alloy_eips::eip2718::{Decodable2718, Encodable2718};
use alloy_provider::RootProvider;
use alloy_rpc_types::{Transaction as RpcTransaction, TransactionReceipt};
use alloy_rpc_types_engine::{
    ExecutionPayloadFieldV2, ForkchoiceState, PayloadAttributes as EthPayloadAttributes,
};
use metrics::{counter, gauge, histogram};
use protocol::shasta::{
    AnchorTxConstructor, AnchorV4Input, calculate_shasta_difficulty,
    constants::{MIN_BLOCK_GAS_LIMIT, PROPOSAL_MAX_BLOB_BYTES, min_base_fee_for_chain},
    encode_extra_data,
};
use rpc::client::{Client, ClientConfig, ClientWithWallet};
use serde_json::from_value;
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::time::interval;
use tracing::{error, info, instrument, warn};

use crate::{
    config::ProposerConfigs,
    error::{ProposerError, Result},
    metrics::ProposerMetrics,
    transaction_builder::ShastaProposalTransactionBuilder,
    tx_manager_adapter::ProposalTxManager,
};

/// Type alias for batches of transaction lists fetched from the txpool.
pub type TransactionLists = Vec<Vec<Transaction>>;

/// Parameters captured from engine mode payload building.
/// These ensure consistency between the anchor transaction and the block manifest.
#[derive(Debug, Clone, Copy)]
pub struct EngineBuildContext {
    /// The L1 block number used for the anchor transaction.
    pub anchor_block_number: u64,
    /// The L2 parent block number used to derive the proposal payload.
    pub parent_block_number: u64,
    /// The timestamp used for the payload.
    pub timestamp: u64,
    /// The gas limit for the block.
    pub gas_limit: u64,
}

/// Outcome returned by the proposer after one submission attempt.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ProposalSendOutcome {
    /// The proposal reached a confirmed receipt through the tx-manager.
    ///
    /// Callers must inspect `receipt.status()` to distinguish success from an on-chain revert.
    ConfirmedReceipt {
        /// Confirmed receipt returned by the tx-manager-backed submission path.
        receipt: Box<TransactionReceipt>,
    },
    /// The tx-manager exhausted its bounded retry budget and the proposer loop should continue.
    RetryExhausted,
}

/// Proposer loop that builds and submits Shasta proposals at a fixed interval.
pub struct Proposer {
    /// RPC client bundle with signing wallet for L1 submission.
    rpc_provider: ClientWithWallet,
    /// Builder that converts txpool content into proposal transactions.
    transaction_builder: ShastaProposalTransactionBuilder,
    /// Tx-manager responsible for proposal submission and retry handling.
    tx_manager: ProposalTxManager,
    /// Optional anchor constructor used in engine mode.
    anchor_constructor: Option<AnchorTxConstructor<RootProvider<alloy_network::Ethereum>>>,
    /// Chain-specific minimum base fee used by EIP-4396 clamping.
    min_base_fee_to_clamp: u64,
    /// Runtime proposer configuration.
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
        // The RPC client wallet and tx-manager signer are both derived from the same
        // proposer key, so all L1 proposal submissions must continue to flow through
        // tx-manager to avoid splitting nonce management across two send paths.
        let tx_manager =
            ProposalTxManager::new(&cfg, rpc_provider.l1_provider.root().to_owned()).await?;
        // Match proposer-side base-fee clamping to chain policy used by derivation.
        let min_base_fee_to_clamp =
            min_base_fee_for_chain(rpc_provider.l2_provider.get_chain_id().await?);

        // Initialize anchor transaction constructor only for engine mode.
        let anchor_constructor = if cfg.use_engine_mode {
            Some(
                AnchorTxConstructor::new(
                    rpc_provider.l2_provider.clone(),
                    *rpc_provider.shasta.anchor.address(),
                )
                .await?,
            )
        } else {
            None
        };

        Ok(Self {
            rpc_provider,
            transaction_builder,
            tx_manager,
            anchor_constructor,
            min_base_fee_to_clamp,
            cfg,
        })
    }

    /// Start the proposer main loop.
    pub async fn start(&self) -> Result<()> {
        let mut interval = interval(self.cfg.propose_interval);
        let mut epoch = 0;

        loop {
            interval.tick().await;
            info!(epoch, "proposer epoch");

            if matches!(self.fetch_and_propose().await?, ProposalSendOutcome::RetryExhausted) {
                info!(epoch, "proposal retries exhausted; continuing proposer loop");
            }

            epoch += 1;
        }
    }

    /// Fetch L2 EE mempool and propose a new proposal to protocol inbox.
    /// Fetch transactions and submit a proposal once.
    pub async fn fetch_and_propose(&self) -> Result<ProposalSendOutcome> {
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

        let mut proposal_tx = self.transaction_builder.build(pool_content, engine_params).await?;

        // Set gas limit if configured, otherwise let the provider estimate it.
        if let Some(gas_limit) = self.cfg.gas_limit {
            proposal_tx = proposal_tx.with_gas_limit(gas_limit);
        }

        record_submission_attempt();
        Ok(record_submission_outcome(self.tx_manager.send_proposal(proposal_tx).await?))
    }

    /// Return a clone of the RPC client bundle used by the proposer.
    pub fn rpc_client(&self) -> ClientWithWallet {
        self.rpc_provider.clone()
    }

    /// Fetch transaction pool content from the L2 execution engine.
    async fn fetch_pool_content(&self) -> Result<TransactionLists> {
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
        let parent_number = parent.number();
        let grandparent_number = parent_number.saturating_sub(1);
        let grandparent = self
            .rpc_provider
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Number(grandparent_number))
            .await?
            .ok_or(ProposerError::ParentBlockNotFound(grandparent_number))?;
        let parent_block_time_delta_secs =
            parent.header.timestamp.saturating_sub(grandparent.header.timestamp);
        let parent_base_fee_per_gas =
            parent.header.inner.base_fee_per_gas.ok_or(ProposerError::MissingParentBaseFee {
                parent_block_number: parent_number,
            })?;

        // Pass explicit parent base fee + chain clamp to mirror current EIP-4396 API semantics.
        Ok(U256::from(calculate_next_block_eip4396_base_fee(
            &parent.header.inner,
            parent_block_time_delta_secs,
            parent_base_fee_per_gas,
            self.min_base_fee_to_clamp,
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
    ) -> Result<(TaikoPayloadAttributes, EngineBuildContext)> {
        let block_number = parent.number() + 1;
        let timestamp = current_unix_timestamp();

        // Get basefee sharing percentage from inbox config.
        let inbox_config = self.rpc_provider.shasta.inbox.getConfig().call().await?;
        let basefee_sharing_pctg = inbox_config.basefeeSharingPctg;

        // Get proposal ID from parent's extra data and increment.
        let proposal_id = next_shasta_proposal_id(parent.header.number, &parent.header.extra_data)?;

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
            .as_ref()
            .ok_or(ProposerError::AnchorConstructorNotInitialized)?
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

        Ok((
            payload_attributes,
            EngineBuildContext {
                anchor_block_number,
                parent_block_number: parent.header.number,
                timestamp,
                gas_limit: parent.header.gas_limit,
            },
        ))
    }

    /// Fetch transactions using Engine API (FCU + get_payload).
    /// In engine mode, we use forkchoice_updated to trigger payload building
    /// with tx_list: None, then retrieve the built payload to extract transactions.
    /// Returns the transactions and the engine payload parameters used.
    async fn fetch_payload_transactions(&self) -> Result<(TransactionLists, EngineBuildContext)> {
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
            .enumerate()
            .map(|(index, tx_bytes): (usize, &Bytes)| {
                // Decode the transaction from RLP bytes.
                let tx = TxEnvelope::decode_2718(&mut tx_bytes.as_ref())
                    .map_err(|source| ProposerError::TxDecode { index, source })?;

                // Recover the signer address from the transaction signature.
                let signer = tx
                    .recover_signer()
                    .map_err(|e| ProposerError::SignerRecovery { index, message: e.to_string() })?;

                Ok(RpcTransaction::from_transaction(
                    Recovered::new_unchecked(tx, signer),
                    TransactionInfo::default(),
                ))
            })
            .collect::<Result<Vec<_>>>()?;

        info!(
            tx_count = txs.len(),
            total_payload_txs = transactions.len(),
            anchor_block_number = engine_params.anchor_block_number,
            "extracted user transactions from engine payload"
        );

        Ok((vec![txs], engine_params))
    }
}

/// Record metrics and logs for a proposer submission outcome.
fn record_submission_outcome(outcome: ProposalSendOutcome) -> ProposalSendOutcome {
    match &outcome {
        ProposalSendOutcome::ConfirmedReceipt { receipt } => {
            if receipt.status() {
                info!(
                    tx_hash = %receipt.transaction_hash,
                    gas_used = receipt.gas_used,
                    "proposal transaction mined successfully"
                );
                counter!(ProposerMetrics::PROPOSALS_SUCCESS).increment(1);

                // Record gas used once the confirmed receipt shows successful execution.
                histogram!(ProposerMetrics::GAS_USED).record(receipt.gas_used as f64);
            } else {
                error!(tx_hash = %receipt.transaction_hash, "proposal transaction failed");
                counter!(ProposerMetrics::PROPOSALS_FAILED).increment(1);
            }
        }
        ProposalSendOutcome::RetryExhausted => {
            // `base-tx-manager` can exhaust retries before any publish succeeds
            // (for example on repeated pre-publish RPC failures), so this
            // outcome does not prove the proposal ever reached L1.
            warn!("proposal transaction retries exhausted before confirmation");
            counter!(ProposerMetrics::PROPOSALS_FAILED).increment(1);
        }
    }

    outcome
}

/// Record that the proposer started an L1 submission attempt for a built proposal.
fn record_submission_attempt() {
    counter!(ProposerMetrics::PROPOSALS_SENT).increment(1);
}

/// Returns the current UNIX timestamp in seconds.
pub(crate) fn current_unix_timestamp() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs()
}

/// Derive the next proposal id from the parent block header.
///
/// Shasta stores the previous proposal id in the parent block extra data. On a fresh chain the
/// genesis parent may still have empty extra data, so the first proposal starts at id `1`.
fn next_shasta_proposal_id(parent_block_number: u64, parent_extra_data: &Bytes) -> Result<u64> {
    if parent_block_number == 0 {
        return Ok(1);
    }

    decode_shasta_proposal_id(parent_extra_data)
        .map(|proposal_id| proposal_id + 1)
        .ok_or(ProposerError::InvalidExtraData)
}

#[cfg(test)]
mod tests {
    use alloy::{
        consensus::{Eip658Value, Receipt, ReceiptEnvelope, ReceiptWithBloom},
        primitives::{Address, B256, Bloom, Bytes},
    };
    use alloy_rpc_types::TransactionReceipt;
    use metrics_util::debugging::{DebugValue, DebuggingRecorder};

    use std::time::{SystemTime, UNIX_EPOCH};

    use super::{
        ProposalSendOutcome, current_unix_timestamp, next_shasta_proposal_id,
        record_submission_attempt, record_submission_outcome,
    };
    use crate::metrics::ProposerMetrics;
    use protocol::shasta::encode_extra_data;

    #[test]
    fn current_unix_timestamp_tracks_system_time() {
        let before = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs();
        let timestamp = current_unix_timestamp();
        let after = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs();

        assert!(timestamp >= before);
        assert!(timestamp <= after);
    }

    #[test]
    fn retry_exhausted_submission_outcome_stays_non_fatal() {
        assert_eq!(
            record_submission_outcome(ProposalSendOutcome::RetryExhausted),
            ProposalSendOutcome::RetryExhausted
        );
    }

    #[test]
    fn confirmed_receipt_submission_outcome_preserves_receipt_status() {
        let receipt = receipt_with_status(false, B256::repeat_byte(0x44));
        let outcome = record_submission_outcome(ProposalSendOutcome::ConfirmedReceipt {
            receipt: Box::new(receipt),
        });

        assert!(matches!(
            outcome,
            ProposalSendOutcome::ConfirmedReceipt { receipt } if !receipt.status()
        ));
    }

    #[test]
    fn submission_attempt_increments_sent_metric() {
        let recorder = DebuggingRecorder::new();
        let snapshotter = recorder.snapshotter();

        metrics::with_local_recorder(&recorder, || {
            record_submission_attempt();
        });

        assert_eq!(counter_value(&snapshotter, ProposerMetrics::PROPOSALS_SENT), Some(1));
    }

    #[test]
    fn next_shasta_proposal_id_starts_from_one_for_empty_genesis_extra_data() {
        assert_eq!(
            next_shasta_proposal_id(0, &Bytes::new()).expect("empty genesis extra data is valid"),
            1
        );
    }

    #[test]
    fn next_shasta_proposal_id_increments_encoded_parent_proposal_id() {
        assert_eq!(
            next_shasta_proposal_id(7, &encode_extra_data(15, 9))
                .expect("encoded proposal id should decode"),
            10
        );
    }

    #[test]
    fn next_shasta_proposal_id_rejects_non_genesis_invalid_extra_data() {
        assert!(matches!(
            next_shasta_proposal_id(1, &Bytes::from_static(&[0x12, 0x34])),
            Err(crate::error::ProposerError::InvalidExtraData)
        ));
    }

    /// Build a minimal receipt with the requested execution status.
    fn receipt_with_status(success: bool, tx_hash: B256) -> TransactionReceipt {
        let inner = ReceiptEnvelope::Legacy(ReceiptWithBloom {
            receipt: Receipt {
                status: Eip658Value::Eip658(success),
                cumulative_gas_used: 21_000,
                logs: vec![],
            },
            logs_bloom: Bloom::ZERO,
        });

        TransactionReceipt {
            inner,
            transaction_hash: tx_hash,
            transaction_index: Some(0),
            block_hash: Some(B256::ZERO),
            block_number: Some(1),
            gas_used: 21_000,
            effective_gas_price: 1_000_000_000,
            blob_gas_used: None,
            blob_gas_price: None,
            from: Address::ZERO,
            to: Some(Address::ZERO),
            contract_address: None,
        }
    }

    fn counter_value(
        snapshotter: &metrics_util::debugging::Snapshotter,
        metric_name: &str,
    ) -> Option<u64> {
        snapshotter.snapshot().into_vec().into_iter().find_map(|(key, _, _, value)| {
            (key.key().name() == metric_name).then(|| match value {
                DebugValue::Counter(value) => value,
                other => panic!("expected counter for {metric_name}, got {other:?}"),
            })
        })
    }
}

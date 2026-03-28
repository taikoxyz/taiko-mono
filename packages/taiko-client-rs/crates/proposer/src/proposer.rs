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
    providers::{Provider, WalletProvider},
    rpc::types::{Block, Transaction},
};
use alloy_consensus::{
    TxEnvelope,
    transaction::{Recovered, SignerRecoverable, TransactionInfo},
};
use alloy_eips::eip2718::{Decodable2718, Encodable2718};
use alloy_network::TransactionBuilder;
use alloy_rpc_types::Transaction as RpcTransaction;
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
};

use alloy_provider::RootProvider;

/// Type alias for batches of transaction lists fetched from the txpool.
pub type TransactionLists = Vec<Vec<Transaction>>;

/// Parameters captured from engine mode payload building.
/// These ensure consistency between the anchor transaction and the block manifest.
#[derive(Debug, Clone, Copy)]
pub struct EngineBuildContext {
    /// The L1 block number used for the anchor transaction.
    pub anchor_block_number: u64,
    /// The timestamp used for the payload.
    pub timestamp: u64,
    /// The gas limit for the block.
    pub gas_limit: u64,
}

/// Tracks the most recently submitted EIP-1559 fee caps for proposal transactions.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct ProposalFeeState {
    /// The current max fee per gas in wei.
    max_fee_per_gas: u128,
    /// The current max priority fee per gas in wei.
    max_priority_fee_per_gas: u128,
    /// The current max fee per blob gas in wei.
    max_fee_per_blob_gas: u128,
}

impl ProposalFeeState {
    /// Creates the initial fee state from a fresh fee estimate and configured minimum floors.
    fn from_estimate(
        estimated_max_fee_per_gas: u128,
        estimated_priority_fee_per_gas: u128,
        min_max_fee_per_gas: u128,
        min_priority_fee_per_gas: u128,
    ) -> Self {
        Self {
            max_fee_per_gas: estimated_max_fee_per_gas.max(min_max_fee_per_gas),
            max_priority_fee_per_gas: estimated_priority_fee_per_gas.max(min_priority_fee_per_gas),
            max_fee_per_blob_gas: min_max_fee_per_gas,
        }
    }

    /// Returns the next replacement fee state, ensuring retries never drop below the last sent tx.
    fn bumped_replacement_fees(
        self,
        estimated_max_fee_per_gas: u128,
        estimated_priority_fee_per_gas: u128,
        tip_bump_percentage: u64,
        min_max_fee_per_gas: u128,
        min_priority_fee_per_gas: u128,
    ) -> Self {
        Self {
            max_fee_per_gas: bumped_replacement_fee(
                self.max_fee_per_gas,
                estimated_max_fee_per_gas,
                tip_bump_percentage,
                min_max_fee_per_gas,
            ),
            max_priority_fee_per_gas: bumped_replacement_fee(
                self.max_priority_fee_per_gas,
                estimated_priority_fee_per_gas,
                tip_bump_percentage,
                min_priority_fee_per_gas,
            ),
            max_fee_per_blob_gas: self.max_fee_per_blob_gas.saturating_mul(2),
        }
    }
}

/// Returns a bumped replacement fee that stays above the last submitted value.
fn bumped_replacement_fee(
    previous_fee: u128,
    estimated_fee: u128,
    tip_bump_percentage: u64,
    minimum_fee: u128,
) -> u128 {
    let multiplier = 100u128 + u128::from(tip_bump_percentage);
    let estimate_floor = estimated_fee.max(minimum_fee);
    let previous_floor = previous_fee.max(minimum_fee);
    let strictly_above_previous =
        if tip_bump_percentage == 0 { previous_floor } else { previous_floor.saturating_add(1) };

    estimate_floor
        .saturating_mul(multiplier)
        .div_ceil(100)
        .max(previous_floor.saturating_mul(multiplier).div_ceil(100))
        .max(strictly_above_previous)
}

/// Returns true when an RPC error indicates that a replacement transaction fee bump was too low.
fn is_retryable_replacement_error(error: &str) -> bool {
    let error = error.to_ascii_lowercase();

    error.contains("replacement transaction underpriced") ||
        error.contains("underpriced") ||
        error.contains("replacementnotallowed")
}

/// Parameters for computing the next fee bump after a retry-trigger event.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
struct RetryBumpParams {
    /// Latest estimated max fee per gas from the provider, in wei.
    estimated_max_fee_per_gas: u128,
    /// Latest estimated max priority fee per gas from the provider, in wei.
    estimated_priority_fee_per_gas: u128,
    /// Percentage increase to apply for the next bump.
    tip_bump_percentage: u64,
    /// Minimum configured max fee per gas, in wei.
    min_max_fee_per_gas: u128,
    /// Minimum configured max priority fee per gas, in wei.
    min_priority_fee_per_gas: u128,
    /// Number of fee bumps already consumed by prior retry triggers.
    bumps_used: u32,
    /// Maximum number of fee bumps allowed for this proposal submission.
    max_bumps: u32,
}

/// Computes the next replacement fee state if retry budget remains.
fn try_bump_fees(
    current_fees: ProposalFeeState,
    params: RetryBumpParams,
) -> Option<(ProposalFeeState, u32)> {
    if params.bumps_used >= params.max_bumps {
        return None;
    }

    Some((
        current_fees.bumped_replacement_fees(
            params.estimated_max_fee_per_gas,
            params.estimated_priority_fee_per_gas,
            params.tip_bump_percentage,
            params.min_max_fee_per_gas,
            params.min_priority_fee_per_gas,
        ),
        params.bumps_used + 1,
    ))
}

/// Proposer loop that builds and submits Shasta proposals at a fixed interval.
pub struct Proposer {
    /// RPC client bundle with signing wallet for L1 submission.
    rpc_provider: ClientWithWallet,
    /// Builder that converts txpool content into proposal transactions.
    transaction_builder: ShastaProposalTransactionBuilder,
    /// Optional anchor constructor used in engine mode.
    anchor_constructor: Option<AnchorTxConstructor<RootProvider<alloy_network::Ethereum>>>,
    /// Chain-specific minimum base fee used by EIP-4396 clamping.
    min_base_fee_to_clamp: u64,
    /// Runtime proposer configuration.
    cfg: ProposerConfigs,
}

/// Outcome of a single proposal submission attempt.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProposalOutcome {
    /// A proposal transaction was mined and the receipt was observed.
    Mined,
    /// The proposer exhausted its configured retries without a receipt and will continue looping.
    RetryExhausted,
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

            match self.fetch_and_propose().await? {
                ProposalOutcome::Mined => {}
                ProposalOutcome::RetryExhausted => {
                    warn!(epoch, "proposal retries exhausted; continuing proposer loop");
                }
            }

            epoch += 1;
        }
    }

    /// Fetch L2 EE mempool and propose a new proposal to protocol inbox.
    /// Fetch transactions and submit a proposal once.
    pub async fn fetch_and_propose(&self) -> Result<ProposalOutcome> {
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

        // Send transaction with tip-bumping retry loop.
        // On each timeout, resubmit with the same nonce and a bumped priority fee.
        // Pin the nonce upfront so retries replace the original tx rather than queue behind it.
        let signer = self.rpc_provider.l1_provider.default_signer_address();
        let nonce = self
            .rpc_provider
            .l1_provider
            .get_transaction_count(signer)
            .block_id(BlockNumberOrTag::Latest.into())
            .await?;
        // Estimate fees and enforce a minimum floor to prevent near-zero fees on devnets.
        let fee_estimate = self.rpc_provider.l1_provider.estimate_eip1559_fees().await?;
        let min_max_fee = self.cfg.min_max_fee_per_gas_gwei as u128 * 1_000_000_000;
        let min_priority_fee = self.cfg.min_priority_fee_per_gas_gwei as u128 * 1_000_000_000;
        let mut current_fees = ProposalFeeState::from_estimate(
            fee_estimate.max_fee_per_gas,
            fee_estimate.max_priority_fee_per_gas,
            min_max_fee,
            min_priority_fee,
        );
        let mut current_request = transaction_request
            .nonce(nonce)
            .max_fee_per_gas(current_fees.max_fee_per_gas)
            .max_priority_fee_per_gas(current_fees.max_priority_fee_per_gas)
            .max_fee_per_blob_gas(current_fees.max_fee_per_blob_gas);
        let mut bumps_used = 0u32;
        let retry_exhausted = || {
            error!(
                max_retries = self.cfg.max_tip_bump_retries,
                "proposal transaction not mined after all tip bump retries"
            );
            counter!(ProposerMetrics::PROPOSALS_FAILED).increment(1);
            Ok(ProposalOutcome::RetryExhausted)
        };

        loop {
            let attempt = bumps_used;
            let pending_tx = match self
                .rpc_provider
                .l1_provider
                .send_transaction(current_request.clone())
                .await
            {
                Ok(tx) => tx,
                Err(err) => {
                    let err_str = err.to_string();
                    if is_retryable_replacement_error(&err_str) {
                        // Reactively bump fees and retry, like op-txmgr.
                        warn!(attempt, nonce, "transaction underpriced, bumping fees and retrying");
                        let fee_estimate =
                            self.rpc_provider.l1_provider.estimate_eip1559_fees().await?;
                        let Some((next_fees, next_bumps_used)) = try_bump_fees(
                            current_fees,
                            RetryBumpParams {
                                estimated_max_fee_per_gas: fee_estimate.max_fee_per_gas,
                                estimated_priority_fee_per_gas: fee_estimate
                                    .max_priority_fee_per_gas,
                                tip_bump_percentage: self.cfg.tip_bump_percentage,
                                min_max_fee_per_gas: min_max_fee,
                                min_priority_fee_per_gas: min_priority_fee,
                                bumps_used,
                                max_bumps: self.cfg.max_tip_bump_retries,
                            },
                        ) else {
                            return retry_exhausted();
                        };
                        current_fees = next_fees;
                        bumps_used = next_bumps_used;
                        current_request = current_request
                            .max_priority_fee_per_gas(current_fees.max_priority_fee_per_gas)
                            .max_fee_per_gas(current_fees.max_fee_per_gas)
                            .max_fee_per_blob_gas(current_fees.max_fee_per_blob_gas);
                        continue;
                    }
                    return Err(err.into());
                }
            };

            let tx_hash = *pending_tx.tx_hash();
            info!(%tx_hash, attempt, nonce, "proposal transaction sent");
            counter!(ProposerMetrics::PROPOSALS_SENT).increment(1);

            // Wait for receipt with timeout.
            let receipt_result =
                tokio::time::timeout(self.cfg.receipt_timeout, pending_tx.get_receipt()).await;

            match receipt_result {
                Ok(Ok(receipt)) => {
                    if receipt.status() {
                        info!(
                            tx_hash = %receipt.transaction_hash,
                            gas_used = receipt.gas_used,
                            attempt,
                            "proposal transaction mined successfully"
                        );
                        counter!(ProposerMetrics::PROPOSALS_SUCCESS).increment(1);
                        histogram!(ProposerMetrics::GAS_USED).record(receipt.gas_used as f64);
                    } else {
                        error!(
                            tx_hash = %receipt.transaction_hash,
                            attempt,
                            "proposal transaction failed"
                        );
                        counter!(ProposerMetrics::PROPOSALS_FAILED).increment(1);
                    }
                    return Ok(ProposalOutcome::Mined);
                }
                Ok(Err(e)) => {
                    // RPC error while polling receipt — don't retry, propagate.
                    return Err(e.into());
                }
                Err(_) => {
                    // Timeout — loop will retry with bumped tip if attempts remain.
                    warn!(
                        %tx_hash,
                        attempt,
                        timeout_secs = self.cfg.receipt_timeout.as_secs(),
                        "timed out waiting for proposal receipt"
                    );
                    let fee_estimate =
                        self.rpc_provider.l1_provider.estimate_eip1559_fees().await?;
                    let Some((next_fees, next_bumps_used)) = try_bump_fees(
                        current_fees,
                        RetryBumpParams {
                            estimated_max_fee_per_gas: fee_estimate.max_fee_per_gas,
                            estimated_priority_fee_per_gas: fee_estimate.max_priority_fee_per_gas,
                            tip_bump_percentage: self.cfg.tip_bump_percentage,
                            min_max_fee_per_gas: min_max_fee,
                            min_priority_fee_per_gas: min_priority_fee,
                            bumps_used,
                            max_bumps: self.cfg.max_tip_bump_retries,
                        },
                    ) else {
                        return retry_exhausted();
                    };
                    current_fees = next_fees;
                    bumps_used = next_bumps_used;
                    current_request = current_request
                        .max_priority_fee_per_gas(current_fees.max_priority_fee_per_gas)
                        .max_fee_per_gas(current_fees.max_fee_per_gas)
                        .max_fee_per_blob_gas(current_fees.max_fee_per_blob_gas);
                    warn!(
                        attempt = bumps_used,
                        tip_bump_percentage = self.cfg.tip_bump_percentage,
                        nonce,
                        "receipt timeout, resubmitting with bumped tip"
                    );
                }
            }
        }
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

/// Returns the current UNIX timestamp in seconds.
pub(crate) fn current_unix_timestamp() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs()
}

#[cfg(test)]
mod tests {
    use std::time::{SystemTime, UNIX_EPOCH};

    use super::{
        ProposalFeeState, RetryBumpParams, current_unix_timestamp, is_retryable_replacement_error,
        try_bump_fees,
    };

    #[test]
    fn current_unix_timestamp_tracks_system_time() {
        let before = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs();
        let timestamp = current_unix_timestamp();
        let after = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs();

        assert!(timestamp >= before);
        assert!(timestamp <= after);
    }

    #[test]
    fn replacement_bump_stays_above_previous_fees_when_estimate_drops() {
        let current = ProposalFeeState {
            max_fee_per_gas: 100,
            max_priority_fee_per_gas: 10,
            max_fee_per_blob_gas: 32,
        };

        let next = current.bumped_replacement_fees(70, 7, 20, 1, 1);

        assert_eq!(next.max_priority_fee_per_gas, 12);
        assert_eq!(next.max_fee_per_gas, 120);
        assert_eq!(next.max_fee_per_blob_gas, 64);
    }

    #[test]
    fn replacement_bump_uses_fresh_estimate_when_it_exceeds_previous_floor() {
        let current = ProposalFeeState {
            max_fee_per_gas: 100,
            max_priority_fee_per_gas: 10,
            max_fee_per_blob_gas: 32,
        };

        let next = current.bumped_replacement_fees(150, 15, 20, 1, 1);

        assert_eq!(next.max_priority_fee_per_gas, 18);
        assert_eq!(next.max_fee_per_gas, 180);
        assert_eq!(next.max_fee_per_blob_gas, 64);
    }

    #[test]
    fn replacement_error_matcher_accepts_known_provider_variants() {
        assert!(is_retryable_replacement_error("replacement transaction underpriced"));
        assert!(is_retryable_replacement_error("ReplacementNotAllowed"));
    }

    #[test]
    fn replacement_error_matcher_rejects_unrelated_errors() {
        assert!(!is_retryable_replacement_error("insufficient funds for gas * price + value"));
    }

    #[test]
    fn try_bump_fees_increments_budget_once_per_retry_trigger() {
        let current = ProposalFeeState {
            max_fee_per_gas: 100,
            max_priority_fee_per_gas: 10,
            max_fee_per_blob_gas: 32,
        };

        let (next, bumps_used) = try_bump_fees(
            current,
            RetryBumpParams {
                estimated_max_fee_per_gas: 70,
                estimated_priority_fee_per_gas: 7,
                tip_bump_percentage: 20,
                min_max_fee_per_gas: 1,
                min_priority_fee_per_gas: 1,
                bumps_used: 0,
                max_bumps: 2,
            },
        )
        .unwrap();

        assert_eq!(next.max_priority_fee_per_gas, 12);
        assert_eq!(next.max_fee_per_gas, 120);
        assert_eq!(next.max_fee_per_blob_gas, 64);
        assert_eq!(bumps_used, 1);
    }

    #[test]
    fn try_bump_fees_returns_none_when_retry_budget_is_exhausted() {
        let current = ProposalFeeState {
            max_fee_per_gas: 100,
            max_priority_fee_per_gas: 10,
            max_fee_per_blob_gas: 32,
        };

        assert!(
            try_bump_fees(
                current,
                RetryBumpParams {
                    estimated_max_fee_per_gas: 70,
                    estimated_priority_fee_per_gas: 7,
                    tip_bump_percentage: 20,
                    min_max_fee_per_gas: 1,
                    min_priority_fee_per_gas: 1,
                    bumps_used: 2,
                    max_bumps: 2,
                },
            )
            .is_none()
        );
    }
}

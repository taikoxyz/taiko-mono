//! Core proposer implementation for submitting block proposals.

use alethia_reth_consensus::eip4396::SHASTA_INITIAL_BASE_FEE;
use alethia_reth_primitives::{
    decode_shasta_proposal_id, payload::attributes::TaikoPayloadAttributes,
};
use alloy::{
    eips::BlockNumberOrTag,
    primitives::{Address, B256, Bytes, U256, aliases::U48},
    providers::Provider,
    rpc::types::{Block, Transaction},
    signers::local::PrivateKeySigner,
    transports::RpcError,
};
use alloy_consensus::{
    TxEnvelope,
    transaction::{Recovered, SignerRecoverable, TransactionInfo},
};
use alloy_eips::eip2718::{Decodable2718, Encodable2718};
use alloy_provider::RootProvider;
use alloy_rpc_types::{Transaction as RpcTransaction, TransactionReceipt};
use alloy_rpc_types_engine::{ExecutionPayloadFieldV2, ForkchoiceState};
use base_tx_manager::{SimpleTxManager, TxManager, TxManagerError};
use bindings::preconf_whitelist::PreconfWhitelist::PreconfWhitelistInstance;
use protocol::shasta::{
    AnchorTxConstructor, AnchorV4Input, PayloadAttributesInput, build_payload_attributes,
    calculate_shasta_mix_hash,
    constants::{
        MIN_BLOCK_GAS_LIMIT, PROPOSAL_MAX_BLOB_BYTES,
        calculate_next_block_eip4396_base_fee_for_parent, min_base_fee_for_chain,
    },
    encode_extra_data,
};
use rpc::{
    RpcClientError,
    client::{Client, ClientConfig, ClientWithWallet},
};
use serde_json::from_value;
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::time::interval;
use tracing::{error, info, instrument, warn};

use crate::{
    config::ProposerConfigs,
    error::{ProposerError, Result},
    metrics::ProposerMetrics,
    transaction_builder::ShastaProposalTransactionBuilder,
    tx_manager_adapter::{build_tx_manager, proposal_candidate},
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

/// Proposer loop that builds and submits Shasta proposals at a fixed interval.
pub struct Proposer {
    /// RPC client bundle with signing wallet for L1 submission.
    rpc_provider: ClientWithWallet,
    /// Builder that converts txpool content into proposal transactions.
    transaction_builder: ShastaProposalTransactionBuilder,
    /// Tx-manager responsible for proposal submission and retry handling.
    tx_manager: SimpleTxManager,
    /// L1 address derived from the configured proposer private key.
    l1_proposer_address: Address,
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
        let tx_manager = build_tx_manager(&cfg, rpc_provider.l1_provider.root().to_owned()).await?;
        let l1_proposer_address = proposer_address_from_key(&cfg.l1_proposer_private_key)?;
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
            l1_proposer_address,
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

            match self.precheck_current_preconf_operator().await {
                Ok(true) => {}
                Ok(false) => {
                    info!(
                        epoch,
                        proposer = ?self.l1_proposer_address,
                        "skipping proposal attempt because proposer is not current preconf whitelist operator"
                    );
                    epoch += 1;
                    continue;
                }
                Err(err) if is_operational_loop_error(&err) => {
                    if should_increment_loop_failure_metric(&err) {
                        ProposerMetrics::proposals_failed().inc();
                    }
                    warn!(
                        epoch,
                        error = %err,
                        "proposer precheck failed on a retryable error; continuing proposer loop"
                    );
                    epoch += 1;
                    continue;
                }
                Err(err) => return Err(err),
            }

            match self.fetch_and_propose().await {
                Ok(receipt) => {
                    info!(
                        epoch,
                        tx_hash = %receipt.transaction_hash,
                        execution_succeeded = receipt.status(),
                        "proposal attempt completed"
                    );
                }
                Err(err) if is_operational_loop_error(&err) => {
                    if should_increment_loop_failure_metric(&err) {
                        ProposerMetrics::proposals_failed().inc();
                    }
                    warn!(epoch, error = %err, "proposal attempt failed; continuing proposer loop");
                }
                Err(err) => return Err(err),
            }

            epoch += 1;
        }
    }

    /// Fetch L2 EE mempool and propose a new proposal to protocol inbox.
    pub async fn fetch_and_propose(&self) -> Result<TransactionReceipt> {
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
        ProposerMetrics::tx_pool_size().set(tx_count as f64);
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
        let receipt = self.tx_manager.send(proposal_candidate(proposal_tx)).await?;
        record_submission_receipt(receipt)
    }

    /// Return a clone of the RPC client bundle used by the proposer.
    pub fn rpc_client(&self) -> ClientWithWallet {
        self.rpc_provider.clone()
    }

    /// Return whether the configured proposer key is the current preconfirmation whitelist
    /// operator.
    async fn precheck_current_preconf_operator(&self) -> Result<bool> {
        let inbox_config = self.rpc_provider.shasta.inbox.getConfig().call().await?;
        if self.forced_inclusion_allows_permissionless(&inbox_config).await? {
            info!(
                "allowing proposal attempt because forced inclusion processing is permissionless"
            );
            return Ok(true);
        }

        let whitelist = PreconfWhitelistInstance::new(
            inbox_config.proposerChecker,
            self.rpc_provider.l1_provider.clone(),
        );
        let current_operator = whitelist.getOperatorForCurrentEpoch().call().await?;

        Ok(current_operator == self.l1_proposer_address)
    }

    /// Return whether the oldest queued forced inclusion makes proposing permissionless.
    async fn forced_inclusion_allows_permissionless(
        &self,
        inbox_config: &bindings::inbox::IInbox::Config,
    ) -> Result<bool> {
        let forced_inclusion_state =
            self.rpc_provider.shasta.inbox.getForcedInclusionState().call().await?;
        if forced_inclusion_state.head_ == forced_inclusion_state.tail_ {
            return Ok(false);
        }

        let inclusions = self
            .rpc_provider
            .shasta
            .inbox
            .getForcedInclusions(forced_inclusion_state.head_, U48::from(1))
            .call()
            .await?;
        let Some(oldest_inclusion) = inclusions.first() else {
            return Ok(false);
        };

        let latest_l1_block = self
            .rpc_provider
            .l1_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await?
            .ok_or(ProposerError::LatestBlockNotFound)?;

        Ok(forced_inclusion_is_permissionless(
            oldest_inclusion.blobSlice.timestamp.to::<u64>(),
            latest_l1_block.header.timestamp,
            inbox_config.forcedInclusionDelay,
            inbox_config.permissionlessInclusionMultiplier,
        ))
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

        self.calculate_next_shasta_block_base_fee_for_parent(&parent).await
    }

    /// Calculate the base fee for the next L2 block from a specific parent snapshot.
    async fn calculate_next_shasta_block_base_fee_for_parent(
        &self,
        parent: &Block,
    ) -> Result<U256> {
        let parent_number = parent.number();
        let grandparent = if parent_number == 0 {
            None
        } else {
            let grandparent_number = parent_number.saturating_sub(1);
            Some(
                self.rpc_provider
                    .l2_provider
                    .get_block_by_hash(parent.header.parent_hash)
                    .await?
                    .ok_or(ProposerError::ParentBlockNotFound(grandparent_number))?,
            )
        };

        calculate_next_shasta_block_base_fee_from_parent(
            parent,
            grandparent.as_ref(),
            self.min_base_fee_to_clamp,
        )
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
        let base_fee = self.calculate_next_shasta_block_base_fee_for_parent(parent).await?;

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

        // Calculate mix hash.
        let mix_hash = calculate_shasta_mix_hash(parent.header.inner.mix_hash, block_number);

        let payload_attributes = build_payload_attributes(PayloadAttributesInput {
            beneficiary: self.cfg.l2_suggested_fee_recipient,
            timestamp,
            mix_hash,
            gas_limit: parent.header.gas_limit,
            // Engine mode: let the node select transactions from its mempool.
            tx_list: None,
            extra_data: encode_extra_data(basefee_sharing_pctg, proposal_id),
            base_fee_per_gas: base_fee,
            block_number,
            l1_block_height: Some(U256::from(anchor_block_number)),
            l1_block_hash: Some(l1_block.header.hash),
            is_forced_inclusion: false,
            signature: [0; 65],
            parent_beacon_block_root: None,
            anchor_transaction: Some(Bytes::from(anchor_tx.encoded_2718())),
        });

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
        let payload_envelope = self.rpc_provider.engine_get_payload_v2(payload_id).await?;

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

/// Calculate the next Shasta base fee from a fixed parent snapshot and its grandparent.
fn calculate_next_shasta_block_base_fee_from_parent(
    parent: &Block,
    grandparent: Option<&Block>,
    min_base_fee_to_clamp: u64,
) -> Result<U256> {
    if parent.number() == 0 {
        return Ok(U256::from(SHASTA_INITIAL_BASE_FEE));
    }

    let grandparent =
        grandparent.ok_or(ProposerError::ParentBlockNotFound(parent.number().saturating_sub(1)))?;

    calculate_next_block_eip4396_base_fee_for_parent(
        parent.header.inner.number,
        parent.header.inner.gas_limit,
        parent.header.inner.gas_used,
        parent.header.timestamp,
        parent.header.inner.base_fee_per_gas,
        grandparent.header.timestamp,
        min_base_fee_to_clamp,
    )
    .map(U256::from)
    .ok_or(ProposerError::MissingParentBaseFee { parent_block_number: parent.number() })
}

/// Record metrics and logs for a proposer submission receipt.
fn record_submission_receipt(receipt: TransactionReceipt) -> Result<TransactionReceipt> {
    if receipt.status() {
        info!(
            tx_hash = %receipt.transaction_hash,
            gas_used = receipt.gas_used,
            "proposal transaction mined successfully"
        );
        ProposerMetrics::proposals_success().inc();

        // Record gas used once the confirmed receipt shows successful execution.
        ProposerMetrics::gas_used().observe(receipt.gas_used as f64);
        Ok(receipt)
    } else {
        let tx_hash = receipt.transaction_hash;
        error!(tx_hash = %tx_hash, "proposal transaction failed");
        ProposerMetrics::proposals_failed().inc();
        Err(ProposerError::ProposalTransactionReverted { tx_hash })
    }
}

/// Record that the proposer started an L1 submission attempt for a built proposal.
fn record_submission_attempt() {
    ProposerMetrics::proposals_sent().inc();
}

/// Return the L1 account address controlled by a proposer private key.
fn proposer_address_from_key(private_key: &B256) -> Result<Address> {
    PrivateKeySigner::from_bytes(private_key).map(|signer| signer.address()).map_err(|err| {
        ProposerError::from(TxManagerError::Sign(format!(
            "failed to build proposer signer from configured private key: {err}"
        )))
    })
}

/// Return whether a forced inclusion is old enough to bypass proposer authorization.
#[must_use]
fn forced_inclusion_is_permissionless(
    oldest_timestamp: u64,
    l1_timestamp: u64,
    forced_inclusion_delay: u16,
    permissionless_inclusion_multiplier: u8,
) -> bool {
    if oldest_timestamp == 0 {
        return false;
    }

    let permissionless_timestamp = u64::from(forced_inclusion_delay)
        .saturating_mul(u64::from(permissionless_inclusion_multiplier))
        .saturating_add(oldest_timestamp);
    l1_timestamp > permissionless_timestamp
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

/// Return `true` when a surfaced proposer loop error should be retried on the next epoch.
///
/// Transport failures (network blips, timeouts, backend-gone), tx-manager execution reverts,
/// and proposer-owned reverted receipt errors are operational.
/// RPC error responses (`ErrorResp`) and local errors (decoding, unsupported features, unknown
/// functions, fatal tx-manager errors) are fatal and exit the loop.
fn is_operational_loop_error(err: &ProposerError) -> bool {
    matches!(
        err,
        ProposerError::Rpc(RpcError::Transport(_)) |
            ProposerError::RpcClient(RpcClientError::Rpc(RpcError::Transport(_))) |
            ProposerError::Contract(alloy::contract::Error::TransportError(RpcError::Transport(
                _,
            ))) |
            ProposerError::TxManager(
                TxManagerError::Rpc(_) |
                    TxManagerError::SendTimeout |
                    TxManagerError::MempoolDeadlineExpired |
                    TxManagerError::ExecutionReverted,
            ) |
            ProposerError::ProposalTransactionReverted { .. }
    )
}

/// Return whether a retryable proposer loop error should increment the loop failure counter.
///
/// Receipt-level proposal reverts are already counted when the receipt is recorded, so counting
/// here would double-count the same failure.
#[must_use]
fn should_increment_loop_failure_metric(err: &ProposerError) -> bool {
    !matches!(err, ProposerError::ProposalTransactionReverted { .. })
}

#[cfg(test)]
mod tests {
    use alloy::{
        consensus::Header as ConsensusHeader,
        primitives::{Address, B256, Bytes, U256},
        transports::{RpcError, TransportErrorKind},
    };
    use alloy_consensus::{Eip658Value, Receipt, ReceiptEnvelope, ReceiptWithBloom};
    use alloy_json_rpc::ErrorPayload;
    use alloy_rpc_types::{
        TransactionReceipt,
        eth::{Block as RpcBlock, Header as RpcHeader},
    };
    use base_tx_manager::TxManagerError;

    use std::time::{SystemTime, UNIX_EPOCH};

    use super::{
        calculate_next_shasta_block_base_fee_from_parent, current_unix_timestamp,
        forced_inclusion_is_permissionless, is_operational_loop_error, next_shasta_proposal_id,
        record_submission_attempt, record_submission_receipt, should_increment_loop_failure_metric,
    };
    use crate::{error::ProposerError, metrics::ProposerMetrics};
    use protocol::shasta::{
        constants::calculate_next_block_eip4396_base_fee_from_parent_values, encode_extra_data,
    };
    use rpc::RpcClientError;

    #[test]
    fn current_unix_timestamp_tracks_system_time() {
        let before = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs();
        let timestamp = current_unix_timestamp();
        let after = SystemTime::now().duration_since(UNIX_EPOCH).unwrap_or_default().as_secs();

        assert!(timestamp >= before);
        assert!(timestamp <= after);
    }

    /// Sent/success/failed metric deltas across one success and one revert —
    /// sequential in one test to touch the process-global registry once.
    #[test]
    fn submission_metrics_track_success_and_revert() {
        // 1. snapshot the counters we assert deltas against.
        let sent_before = ProposerMetrics::proposals_sent().get();
        record_submission_attempt();
        assert_eq!(ProposerMetrics::proposals_sent().get(), sent_before + 1);

        // 2. a success receipt is returned unchanged and bumps the success counter.
        let success_receipt = receipt_with_status(true);
        let success_hash = success_receipt.transaction_hash;
        let success_before = ProposerMetrics::proposals_success().get();

        let recorded = record_submission_receipt(success_receipt)
            .expect("successful receipt should remain successful");

        assert_eq!(recorded.transaction_hash, success_hash);
        assert_eq!(ProposerMetrics::proposals_success().get(), success_before + 1);

        // 3. a reverted receipt surfaces the proposal error and bumps the failed counter.
        let reverted_receipt = receipt_with_status(false);
        let reverted_hash = reverted_receipt.transaction_hash;
        let failed_before = ProposerMetrics::proposals_failed().get();

        let err = record_submission_receipt(reverted_receipt)
            .expect_err("reverted receipt should be surfaced as a proposer error");

        assert!(matches!(
            err,
            ProposerError::ProposalTransactionReverted { tx_hash: observed } if observed == reverted_hash
        ));
        assert_eq!(ProposerMetrics::proposals_failed().get(), failed_before + 1);
    }

    fn receipt_with_status(status: bool) -> TransactionReceipt {
        TransactionReceipt {
            inner: ReceiptEnvelope::Eip1559(ReceiptWithBloom {
                receipt: Receipt {
                    status: Eip658Value::Eip658(status),
                    cumulative_gas_used: 21_000,
                    logs: vec![],
                },
                logs_bloom: Default::default(),
            }),
            transaction_hash: B256::repeat_byte(if status { 0x11 } else { 0x22 }),
            transaction_index: Some(0),
            block_hash: Some(B256::repeat_byte(0x33)),
            block_number: Some(1),
            gas_used: 21_000,
            effective_gas_price: 1,
            blob_gas_used: None,
            blob_gas_price: None,
            from: Address::repeat_byte(0x44),
            to: Some(Address::repeat_byte(0x55)),
            contract_address: None,
        }
    }

    #[test]
    fn forced_inclusion_precheck_accepts_permissionless_window() {
        assert!(forced_inclusion_is_permissionless(100, 151, 10, 5));
    }

    #[test]
    fn forced_inclusion_precheck_rejects_before_permissionless_window() {
        assert!(!forced_inclusion_is_permissionless(100, 150, 10, 5));
        assert!(!forced_inclusion_is_permissionless(100, 149, 10, 5));
    }

    #[test]
    fn forced_inclusion_precheck_rejects_missing_timestamp() {
        assert!(!forced_inclusion_is_permissionless(0, 1_000, 10, 5));
    }

    /// Retryable-vs-fatal classification for the proposer loop — the single
    /// decision that keeps the proposer alive through transient RPC failures.
    /// One row per (error construction, expected operational) pair, folded from
    /// the seven per-variant tests this replaces.
    #[test]
    fn operational_loop_error_classification_table() {
        // A JSON-RPC error response used by both the RPC and RpcClient fatal rows.
        // Verify once that alloy still surfaces it as revert data before classifying.
        let payload: ErrorPayload = serde_json::from_str(
            r#"{"code":3,"message":"execution reverted: ","data":"0x810f00230000000000000000000000000000000000000000000000000000000000000001"}"#,
        )
        .expect("valid JSON-RPC error payload");
        let error_resp_contract =
            alloy::contract::Error::TransportError(RpcError::ErrorResp(payload.clone()));
        assert!(error_resp_contract.as_revert_data().is_some());

        let cases: Vec<(ProposerError, bool)> = vec![
            // Operational tx-manager execution failures — retry next epoch.
            (ProposerError::TxManager(TxManagerError::Rpc("provider timed out".into())), true),
            (ProposerError::TxManager(TxManagerError::SendTimeout), true),
            (ProposerError::TxManager(TxManagerError::MempoolDeadlineExpired), true),
            (ProposerError::TxManager(TxManagerError::ExecutionReverted), true),
            (ProposerError::ProposalTransactionReverted { tx_hash: B256::repeat_byte(0x22) }, true),
            // Transport failures on precheck RPC / contract calls — retry.
            (ProposerError::Rpc(TransportErrorKind::backend_gone()), true),
            (
                ProposerError::Contract(alloy::contract::Error::TransportError(
                    TransportErrorKind::backend_gone(),
                )),
                true,
            ),
            // RPC error responses on precheck RPC / contract calls — fatal, exit.
            (ProposerError::Rpc(RpcError::ErrorResp(payload.clone())), false),
            (ProposerError::Contract(error_resp_contract), false),
            // RpcClient transport failure — retry; RpcClient error response — fatal.
            (ProposerError::from(RpcClientError::from(TransportErrorKind::backend_gone())), true),
            (ProposerError::from(RpcClientError::from(RpcError::ErrorResp(payload))), false),
            // Local contract errors (unknown function) — fatal, exit.
            (
                ProposerError::Contract(alloy::contract::Error::UnknownFunction(
                    "getOperatorForCurrentEpoch".into(),
                )),
                false,
            ),
            // Fatal tx-manager errors — exit the loop.
            (ProposerError::TxManager(TxManagerError::NonceTooLow), false),
            (
                ProposerError::TxManager(TxManagerError::FeeLimitExceeded { fee: 11, ceiling: 10 }),
                false,
            ),
            (
                ProposerError::TxManager(TxManagerError::Sign("wallet rejected signing".into())),
                false,
            ),
            (
                ProposerError::TxManager(TxManagerError::InvalidConfig("bad fee limit".into())),
                false,
            ),
        ];

        for (err, expected) in cases {
            assert_eq!(
                is_operational_loop_error(&err),
                expected,
                "classification changed for {err:?}"
            );
        }
    }

    #[test]
    fn loop_failure_metric_not_double_counted_for_reverted_receipts() {
        let before = ProposerMetrics::proposals_failed().get();

        let reverted_err =
            ProposerError::ProposalTransactionReverted { tx_hash: B256::repeat_byte(0x22) };
        if is_operational_loop_error(&reverted_err) &&
            should_increment_loop_failure_metric(&reverted_err)
        {
            ProposerMetrics::proposals_failed().inc();
        }
        assert_eq!(ProposerMetrics::proposals_failed().get(), before);

        let execution_reverted = ProposerError::TxManager(TxManagerError::ExecutionReverted);
        let before = ProposerMetrics::proposals_failed().get();
        if is_operational_loop_error(&execution_reverted) &&
            should_increment_loop_failure_metric(&execution_reverted)
        {
            ProposerMetrics::proposals_failed().inc();
        }
        assert_eq!(ProposerMetrics::proposals_failed().get(), before + 1);
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

    #[test]
    fn base_fee_calculation_uses_supplied_parent_snapshot() {
        let grandparent = RpcBlock {
            header: RpcHeader {
                hash: B256::repeat_byte(0x11),
                inner: ConsensusHeader { number: 1, timestamp: 100, ..Default::default() },
                total_difficulty: None,
                size: None,
            },
            ..Default::default()
        };
        let parent = RpcBlock {
            header: RpcHeader {
                hash: B256::repeat_byte(0x22),
                inner: ConsensusHeader {
                    number: 2,
                    parent_hash: grandparent.header.hash,
                    timestamp: 112,
                    gas_limit: 45_000_000,
                    base_fee_per_gas: Some(2_000_000_000),
                    ..Default::default()
                },
                total_difficulty: None,
                size: None,
            },
            ..Default::default()
        };

        let expected = U256::from(calculate_next_block_eip4396_base_fee_from_parent_values(
            parent.header.inner.number,
            parent.header.inner.gas_limit,
            parent.header.inner.gas_used,
            parent.header.timestamp.saturating_sub(grandparent.header.timestamp),
            parent.header.inner.base_fee_per_gas.expect("parent should define a base fee"),
            1_000_000_000,
        ));

        assert_eq!(
            calculate_next_shasta_block_base_fee_from_parent(
                &parent,
                Some(&grandparent),
                1_000_000_000
            )
            .expect("parent snapshot should determine the next base fee"),
            expected
        );
    }
}

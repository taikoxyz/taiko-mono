//! Core proposer implementation for submitting block proposals.

use alethia_reth_consensus::eip4396::SHASTA_INITIAL_BASE_FEE;
use alethia_reth_primitives::{
    decode_shasta_proposal_id,
    payload::attributes::{RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes},
};
use alloy::{
    eips::BlockNumberOrTag,
    primitives::{Address, B256, Bytes, U256, aliases::U48},
    providers::Provider,
    rpc::types::{Block, Transaction},
    signers::local::PrivateKeySigner,
    transports::{RpcError, TransportErrorKind},
};
use alloy_consensus::{
    TxEnvelope,
    transaction::{Recovered, SignerRecoverable, TransactionInfo},
};
use alloy_eips::eip2718::{Decodable2718, Encodable2718};
use alloy_provider::RootProvider;
use alloy_rpc_types::{Transaction as RpcTransaction, TransactionReceipt};
use alloy_rpc_types_engine::{ExecutionPayloadFieldV2, ForkchoiceState};
use alloy_rpc_types_engine_2::PayloadAttributes as EthPayloadAttributes;
use base_tx_manager::TxManagerError;
use bindings::preconf_whitelist::PreconfWhitelist::PreconfWhitelistInstance;
use metrics::{counter, gauge, histogram};
use protocol::shasta::{
    AnchorTxConstructor, AnchorV4Input, calculate_shasta_mix_hash,
    constants::{
        MIN_BLOCK_GAS_LIMIT, PROPOSAL_MAX_BLOB_BYTES,
        calculate_next_block_eip4396_base_fee_from_parent_values, min_base_fee_for_chain,
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

/// Proposer loop that builds and submits Shasta proposals at a fixed interval.
pub struct Proposer {
    /// RPC client bundle with signing wallet for L1 submission.
    rpc_provider: ClientWithWallet,
    /// Builder that converts txpool content into proposal transactions.
    transaction_builder: ShastaProposalTransactionBuilder,
    /// Tx-manager responsible for proposal submission and retry handling.
    tx_manager: ProposalTxManager,
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
        let tx_manager =
            ProposalTxManager::new(&cfg, rpc_provider.l1_provider.root().to_owned()).await?;
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
                    counter!(ProposerMetrics::PROPOSALS_FAILED).increment(1);
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
                    counter!(ProposerMetrics::PROPOSALS_FAILED).increment(1);
                    warn!(epoch, error = %err, "proposal attempt failed; continuing proposer loop");
                }
                Err(err) => return Err(err),
            }

            epoch += 1;
        }
    }

    /// Fetch L2 EE mempool and propose a new proposal to protocol inbox.
    /// Fetch transactions and submit a proposal once.
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
        Ok(record_submission_receipt(self.tx_manager.send_proposal(proposal_tx).await?))
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

        Ok(is_current_preconf_operator(current_operator, self.l1_proposer_address))
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

        let payload_attributes = TaikoPayloadAttributes {
            payload_attributes: EthPayloadAttributes {
                timestamp,
                prev_randao: mix_hash,
                suggested_fee_recipient: self.cfg.l2_suggested_fee_recipient,
                withdrawals: Some(vec![]),
                parent_beacon_block_root: None,
                slot_number: None,
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
    let parent_block_time_delta_secs =
        parent.header.timestamp.saturating_sub(grandparent.header.timestamp);
    let parent_base_fee_per_gas = parent
        .header
        .inner
        .base_fee_per_gas
        .ok_or(ProposerError::MissingParentBaseFee { parent_block_number: parent.number() })?;

    Ok(U256::from(calculate_next_block_eip4396_base_fee_from_parent_values(
        parent.header.inner.number,
        parent.header.inner.gas_limit,
        parent.header.inner.gas_used,
        parent_block_time_delta_secs,
        parent_base_fee_per_gas,
        min_base_fee_to_clamp,
    )))
}

/// Record metrics and logs for a proposer submission receipt.
fn record_submission_receipt(receipt: TransactionReceipt) -> TransactionReceipt {
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

    receipt
}

/// Record that the proposer started an L1 submission attempt for a built proposal.
fn record_submission_attempt() {
    counter!(ProposerMetrics::PROPOSALS_SENT).increment(1);
}

/// Return the L1 account address controlled by a proposer private key.
fn proposer_address_from_key(private_key: &B256) -> Result<Address> {
    PrivateKeySigner::from_bytes(private_key).map(|signer| signer.address()).map_err(|err| {
        ProposerError::from(TxManagerError::Sign(format!(
            "failed to build proposer signer from configured private key: {err}"
        )))
    })
}

/// Return whether the whitelist-selected operator matches the configured proposer account.
#[must_use]
fn is_current_preconf_operator(current_operator: Address, proposer_address: Address) -> bool {
    current_operator == proposer_address
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
fn is_operational_loop_error(err: &ProposerError) -> bool {
    match err {
        ProposerError::Rpc(err) => is_transport_rpc_error(err),
        ProposerError::RpcClient(err) => is_operational_rpc_client_error(err),
        ProposerError::Contract(err) => is_transport_contract_error(err),
        ProposerError::TxManager(
            TxManagerError::Rpc(_) |
            TxManagerError::SendTimeout |
            TxManagerError::MempoolDeadlineExpired,
        ) => true,
        _ => false,
    }
}

/// Return whether an RPC client error came from the transport layer.
#[must_use]
fn is_operational_rpc_client_error(err: &RpcClientError) -> bool {
    match err {
        RpcClientError::Rpc(err) => is_transport_rpc_error(err),
        _ => false,
    }
}

/// Return whether an RPC error came from the transport layer rather than an RPC error response.
#[must_use]
fn is_transport_rpc_error(err: &RpcError<TransportErrorKind>) -> bool {
    matches!(err, RpcError::Transport(_))
}

/// Return whether a contract call failed before the RPC server produced an error response.
#[must_use]
fn is_transport_contract_error(err: &alloy::contract::Error) -> bool {
    match err {
        alloy::contract::Error::TransportError(err) => is_transport_rpc_error(err),
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use alloy::{
        consensus::Header as ConsensusHeader,
        primitives::{B256, Bytes, U256},
        transports::{RpcError, TransportErrorKind},
    };
    use alloy_json_rpc::ErrorPayload;
    use alloy_rpc_types::eth::{Block as RpcBlock, Header as RpcHeader};
    use base_tx_manager::TxManagerError;
    use metrics_util::debugging::{DebugValue, DebuggingRecorder};

    use std::time::{SystemTime, UNIX_EPOCH};

    use super::{
        calculate_next_shasta_block_base_fee_from_parent, current_unix_timestamp,
        forced_inclusion_is_permissionless, is_current_preconf_operator, is_operational_loop_error,
        next_shasta_proposal_id, record_submission_attempt,
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
    fn preconf_whitelist_precheck_accepts_current_operator() {
        let proposer = alloy::primitives::Address::repeat_byte(0x11);

        assert!(is_current_preconf_operator(proposer, proposer));
    }

    #[test]
    fn preconf_whitelist_precheck_rejects_non_current_operator() {
        let proposer = alloy::primitives::Address::repeat_byte(0x11);
        let current_operator = alloy::primitives::Address::repeat_byte(0x22);

        assert!(!is_current_preconf_operator(current_operator, proposer));
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

    #[test]
    fn tx_manager_operational_errors_keep_the_proposer_loop_running() {
        assert!(is_operational_loop_error(&ProposerError::TxManager(TxManagerError::Rpc(
            "provider timed out".into(),
        ))));
        assert!(is_operational_loop_error(&ProposerError::TxManager(TxManagerError::SendTimeout,)));
        assert!(is_operational_loop_error(&ProposerError::TxManager(
            TxManagerError::MempoolDeadlineExpired,
        )));
    }

    #[test]
    fn precheck_transport_errors_keep_the_proposer_loop_running() {
        assert!(is_operational_loop_error(&ProposerError::Rpc(TransportErrorKind::backend_gone())));
        assert!(is_operational_loop_error(&ProposerError::Contract(
            alloy::contract::Error::TransportError(TransportErrorKind::backend_gone()),
        )));
    }

    #[test]
    fn precheck_error_responses_still_exit_the_proposer_loop() {
        let payload: ErrorPayload = serde_json::from_str(
            r#"{"code":3,"message":"execution reverted: ","data":"0x810f00230000000000000000000000000000000000000000000000000000000000000001"}"#,
        )
        .expect("valid JSON-RPC error payload");
        let contract_error =
            alloy::contract::Error::TransportError(RpcError::ErrorResp(payload.clone()));

        assert!(contract_error.as_revert_data().is_some());
        assert!(!is_operational_loop_error(&ProposerError::Rpc(RpcError::ErrorResp(payload))));
        assert!(!is_operational_loop_error(&ProposerError::Contract(contract_error)));
    }

    #[test]
    fn rpc_client_transport_errors_keep_the_proposer_loop_running() {
        let err = ProposerError::from(RpcClientError::from(TransportErrorKind::backend_gone()));

        assert!(is_operational_loop_error(&err));
    }

    #[test]
    fn rpc_client_error_responses_still_exit_the_proposer_loop() {
        let payload: ErrorPayload = serde_json::from_str(
            r#"{"code":3,"message":"execution reverted: ","data":"0x810f00230000000000000000000000000000000000000000000000000000000000000001"}"#,
        )
        .expect("valid JSON-RPC error payload");
        let err = ProposerError::from(RpcClientError::from(RpcError::ErrorResp(payload)));

        assert!(!is_operational_loop_error(&err));
    }

    #[test]
    fn precheck_local_contract_errors_still_exit_the_proposer_loop() {
        assert!(!is_operational_loop_error(&ProposerError::Contract(
            alloy::contract::Error::UnknownFunction("getOperatorForCurrentEpoch".into()),
        )));
    }

    #[test]
    fn fatal_tx_manager_errors_still_exit_the_proposer_loop() {
        assert!(!is_operational_loop_error(
            &ProposerError::TxManager(TxManagerError::NonceTooLow,)
        ));
        assert!(!is_operational_loop_error(&ProposerError::TxManager(
            TxManagerError::FeeLimitExceeded { fee: 11, ceiling: 10 },
        )));
        assert!(!is_operational_loop_error(&ProposerError::TxManager(TxManagerError::Sign(
            "wallet rejected signing".into(),
        ))));
        assert!(!is_operational_loop_error(&ProposerError::TxManager(
            TxManagerError::InvalidConfig("bad fee limit".into()),
        )));
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

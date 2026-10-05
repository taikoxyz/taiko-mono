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
use alloy_rpc_types_engine::{ExecutionPayloadV3, ForkchoiceState};
use base_tx_manager::{SimpleTxManager, TxManager, TxManagerError};
use bindings::preconf_whitelist::PreconfWhitelist::PreconfWhitelistInstance;
use protocol::shasta::{
    AnchorTxConstructor, AnchorV4Input, PayloadAttributesInput, anchor_gas_reserve,
    build_payload_attributes, calculate_shasta_mix_hash,
    constants::{
        PROPOSAL_MAX_BLOB_BYTES, calculate_next_block_eip4396_base_fee_for_parent,
        min_base_fee_for_chain,
    },
    encode_etna_extra_data, encode_extra_data, etna_fork_timestamp_for_chain, is_etna_at,
    parent_manifest_gas_limit,
};
use rpc::{RpcClientError, TxPoolContentParams, client::Client};
use serde_json::from_value;
use tokio::time::{MissedTickBehavior, interval};
use tracing::{error, info, instrument, warn};

use crate::{
    config::ProposerConfigs,
    error::{ProposerError, Result},
    metrics::ProposerMetrics,
    transaction_builder::{ShastaProposalTransactionBuilder, manifest_gas_limit},
    tx_manager_adapter::{build_tx_manager, proposal_candidate},
};

/// Type alias for batches of transaction lists fetched from the txpool.
pub type TransactionLists = Vec<Vec<Transaction>>;

/// Chain-state snapshot a proposal is built against.
/// Captured once per proposal attempt — from engine-mode payload building or from the
/// proposer's own L1/L2 reads in pool mode — so transaction selection, the anchor (the anchor
/// transaction before Etna, the anchor root and `extraData` of an Etna block), and the block
/// manifest all describe the same parent and L1 head.
#[derive(Debug, Clone, Copy)]
pub struct EngineBuildContext {
    /// The L1 block the proposal anchors to (the L1 head at capture time), declared as the
    /// manifest's anchor block number. Before Etna it is the anchor transaction's checkpoint; an
    /// Etna block carries it in its 13-byte `extraData` and commits to its state root as the
    /// `parentBeaconBlockRoot`.
    pub anchor_block_number: u64,
    /// The L2 parent block number used to derive the proposal payload.
    pub parent_block_number: u64,
    /// Whether the L2 parent is an Etna block (decided by the parent's own timestamp); an Etna
    /// parent's gas limit carries no anchor reserve.
    pub parent_is_etna: bool,
    /// The timestamp used for the payload.
    pub timestamp: u64,
    /// The L2 parent's header gas limit.
    pub gas_limit: u64,
}

impl EngineBuildContext {
    /// Capture a build context, together with the L2 parent block it derives from, off the
    /// current L1/L2 chain heads.
    ///
    /// The timestamp is taken from the L1 head rather than the local wall clock: driver
    /// validation rejects any manifest block stamped above the proposal's L1 inclusion
    /// timestamp, degrading the whole manifest to the default empty block.
    ///
    /// `etna_fork_timestamp` is the chain's resolved Etna activation time (`None` = never).
    pub async fn from_chain_heads(
        rpc: &Client,
        etna_fork_timestamp: Option<u64>,
    ) -> Result<(Self, Block)> {
        let parent = rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await?
            .ok_or(ProposerError::LatestBlockNotFound)?;

        let l1_head = rpc
            .l1_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await?
            .ok_or(ProposerError::LatestBlockNotFound)?;

        Ok((Self::from_snapshot(&parent, &l1_head, etna_fork_timestamp), parent))
    }

    /// Build a context from an L2 parent and the L1 head it is anchored to: the L1 head gives the
    /// anchor block number and the payload timestamp, the parent its number, gas limit and fork.
    pub(crate) fn from_snapshot(
        parent: &Block,
        l1_head: &Block,
        etna_fork_timestamp: Option<u64>,
    ) -> Self {
        Self {
            anchor_block_number: l1_head.header.number,
            parent_block_number: parent.header.number,
            parent_is_etna: is_etna_at(etna_fork_timestamp, parent.header.timestamp),
            timestamp: l1_head.header.timestamp,
            gas_limit: parent.header.gas_limit,
        }
    }
}

/// Proposer loop that builds and submits Shasta proposals at a fixed interval.
pub struct Proposer {
    /// RPC client bundle used for L1/L2 reads; L1 submission is signed by the tx-manager.
    rpc_provider: Client,
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
    /// The chain's Etna activation time, resolved once at startup (`None` = never).
    etna_fork_timestamp: Option<u64>,
    /// Runtime proposer configuration.
    cfg: ProposerConfigs,
}

impl Proposer {
    /// Creates a new proposer instance.
    #[instrument(skip(cfg), fields(inbox_address = ?cfg.client.inbox_address))]
    pub async fn new(cfg: ProposerConfigs) -> Result<Self> {
        info!(
            inbox_address = ?cfg.client.inbox_address,
            l2_suggested_fee_recipient = ?cfg.l2_suggested_fee_recipient,
            propose_interval = ?cfg.propose_interval,
            "initializing proposer"
        );

        let rpc_provider = Client::new(cfg.client.clone()).await?;

        let transaction_builder = ShastaProposalTransactionBuilder::new(
            rpc_provider.clone(),
            cfg.l2_suggested_fee_recipient,
        );
        // The RPC client carries no wallet; the tx-manager owns the proposer key, so all
        // L1 proposal submissions flow through tx-manager and nonce management stays on a
        // single send path.
        let tx_manager = build_tx_manager(&cfg, rpc_provider.l1_provider.root().to_owned()).await?;
        let l1_proposer_address = proposer_address_from_key(&cfg.l1_proposer_private_key)?;
        // Match proposer-side base-fee clamping to chain policy used by derivation.
        let min_base_fee_to_clamp =
            min_base_fee_for_chain(rpc_provider.l2_provider.get_chain_id().await?);
        let chain_id = rpc_provider.chain_id;
        let etna_fork_timestamp = etna_fork_timestamp_for_chain(chain_id)
            .map_err(|source| ProposerError::EtnaScheduleUnresolved { chain_id, source })?;

        // Initialize anchor transaction constructor only for engine mode.
        let anchor_constructor = if cfg.use_engine_mode {
            warn!(
                "engine mode is enabled: on execution clients without deferred L1-origin \
                 persistence (taikoxyz/alethia-reth#219), the build-only FCU preview persists \
                 l1_origin, head_l1_origin, and batch_to_last_block rows for blocks that never \
                 become canonical, leaving ghost rows every proposal cycle; verify the \
                 connected node includes that fix before using engine mode in production"
            );
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
            etna_fork_timestamp,
            cfg,
        })
    }

    /// Start the proposer main loop.
    pub async fn start(&self) -> Result<()> {
        let mut interval = interval(self.cfg.propose_interval);
        // A slow confirmation must not replay the missed ticks as an immediate burst afterwards:
        // the inbox accepts at most one proposal per L1 block, so burst ticks only revert.
        interval.set_missed_tick_behavior(MissedTickBehavior::Delay);
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
        // Fetch transactions based on mode. Both modes capture the chain-state snapshot the
        // transactions were selected against, so the manifest is built from the same snapshot.
        let (pool_content, build_ctx) = if self.cfg.use_engine_mode {
            self.fetch_payload_transactions().await?
        } else {
            self.fetch_pool_content().await?
        };

        // Record number of transactions in the pool
        let tx_count: usize = pool_content.iter().map(|list| list.len()).sum();
        ProposerMetrics::tx_pool_size().set(tx_count as f64);
        info!(
            txs_lists = pool_content.len(),
            tx_count,
            engine_mode = self.cfg.use_engine_mode,
            ?build_ctx,
            "fetched transaction pool content"
        );

        let mut proposal_tx = self.transaction_builder.build(pool_content, build_ctx).await?;

        // Set gas limit if configured, otherwise let the provider estimate it.
        if let Some(gas_limit) = self.cfg.gas_limit {
            proposal_tx = proposal_tx.with_gas_limit(gas_limit);
        }

        record_submission_attempt();
        let receipt = self.tx_manager.send(proposal_candidate(proposal_tx)).await?;
        record_submission_receipt(receipt)
    }

    /// Return a clone of the RPC client bundle used by the proposer.
    pub fn rpc_client(&self) -> Client {
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

    /// Fetch transaction pool content from the L2 execution engine, together with the
    /// chain-state snapshot the selection ran against.
    async fn fetch_pool_content(&self) -> Result<(TransactionLists, EngineBuildContext)> {
        let (build_ctx, parent) =
            EngineBuildContext::from_chain_heads(&self.rpc_provider, self.etna_fork_timestamp)
                .await?;

        let base_fee_u64 =
            u64::try_from(self.calculate_next_shasta_block_base_fee_for_parent(&parent).await?)
                .map_err(|_| ProposerError::BaseFeeOverflow)?;

        let pool_content = self
            .rpc_provider
            .tx_pool_content_with_min_tip(pool_content_params(
                self.cfg.l2_suggested_fee_recipient,
                base_fee_u64,
                &build_ctx,
            ))
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

        Ok((txs_lists, build_ctx))
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
    ///
    /// The target block is stamped with the L1 head timestamp, which also decides its fork. A
    /// pre-Etna target carries the anchor transaction, a zero root and 7-byte `extraData`; an
    /// Etna target carries no anchor transaction, the L1 head's state root and 13-byte
    /// `extraData` naming the L1 head as its anchor block (see [`engine_target_fork_fields`]).
    /// Returns the payload attributes, the build context, and the fork-dependent fields used.
    async fn build_payload_attributes(
        &self,
        parent: &Block,
    ) -> Result<(TaikoPayloadAttributes, EngineBuildContext, EngineTargetForkFields)> {
        let block_number = parent.number() + 1;

        // Get basefee sharing percentage from inbox config.
        let inbox_config = self.rpc_provider.shasta.inbox.getConfig().call().await?;
        let basefee_sharing_pctg = inbox_config.basefeeSharingPctg;

        // Get proposal ID from parent's extra data and increment.
        let proposal_id = next_shasta_proposal_id(parent.header.number, &parent.header.extra_data)?;

        // Calculate base fee for the new block.
        let base_fee = self.calculate_next_shasta_block_base_fee_for_parent(parent).await?;

        // Get latest L1 block for the anchor.
        let l1_block = self
            .rpc_provider
            .l1_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await?
            .ok_or(ProposerError::LatestBlockNotFound)?;
        // Stamp the payload with the L1 head timestamp instead of the local wall clock: the
        // manifest timestamp must not exceed the proposal's L1 inclusion timestamp, or driver
        // validation degrades the whole manifest to the default empty block.
        let ctx = EngineBuildContext::from_snapshot(parent, &l1_block, self.etna_fork_timestamp);
        let fork_fields = engine_target_fork_fields(
            &ctx,
            l1_block.header.inner.state_root,
            basefee_sharing_pctg,
            proposal_id,
            self.etna_fork_timestamp,
        )?;

        // Build the anchor transaction; an Etna target has none.
        let anchor_transaction = if fork_fields.has_anchor_transaction() {
            let anchor_tx = self
                .anchor_constructor
                .as_ref()
                .ok_or(ProposerError::AnchorConstructorNotInitialized)?
                .assemble_anchor_v4_tx(
                    parent.header.hash,
                    AnchorV4Input {
                        anchor_block_number: ctx.anchor_block_number,
                        anchor_block_hash: l1_block.header.hash,
                        anchor_state_root: l1_block.header.inner.state_root,
                        l2_height: block_number,
                        base_fee,
                    },
                )
                .await?;
            Some(Bytes::from(anchor_tx.encoded_2718()))
        } else {
            None
        };

        let payload_attributes = engine_payload_attributes(EngineAttributesParams {
            beneficiary: self.cfg.l2_suggested_fee_recipient,
            parent,
            ctx: &ctx,
            l1_head_hash: l1_block.header.hash,
            fork_fields: &fork_fields,
            base_fee,
            anchor_transaction,
        });

        Ok((payload_attributes, ctx, fork_fields))
    }

    /// Fetch transactions using Engine API (FCU + get_payload).
    /// In engine mode, we use forkchoice_updated to trigger payload building
    /// with tx_list: None, then retrieve the built payload to extract transactions.
    /// Returns the transactions and the engine payload parameters used.
    async fn fetch_payload_transactions(&self) -> Result<(TransactionLists, EngineBuildContext)> {
        // Build forkchoice state and get the head block to use as parent.
        let (forkchoice_state, parent) = self.build_forkchoice_state().await?;

        // Build payload attributes and capture the engine parameters used.
        let (payload_attributes, engine_params, fork_fields) =
            self.build_payload_attributes(&parent).await?;

        info!(
            parent_number = parent.number(),
            parent_hash = %parent.header.hash,
            anchor_block_number = engine_params.anchor_block_number,
            timestamp = engine_params.timestamp,
            target_is_etna = fork_fields.target_is_etna,
            gas_limit = fork_fields.gas_limit,
            "sending forkchoice_updated with payload attributes"
        );

        // Send forkchoice_updated to trigger payload building.
        let fcu_response = self
            .rpc_provider
            .engine_forkchoice_updated_v3(forkchoice_state, Some(payload_attributes))
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
        let payload_envelope = self.rpc_provider.engine_get_payload_v5(payload_id).await?;
        let execution_payload = &payload_envelope.execution_payload;
        let transactions = &execution_payload.payload_inner.payload_inner.transactions;

        // If no transactions, return empty list with engine parameters.
        if transactions.is_empty() {
            info!("payload contains no transactions");
            return Ok((vec![vec![]], engine_params));
        }

        let txs = engine_payload_user_transactions(execution_payload, &fork_fields)?;

        info!(
            tx_count = txs.len(),
            total_payload_txs = transactions.len(),
            anchor_block_number = engine_params.anchor_block_number,
            "extracted user transactions from engine payload"
        );

        Ok((vec![txs], engine_params))
    }
}

/// Build the `taikoAuth_txPoolContentWithMinTip` request for a pool-mode proposal.
///
/// The pool fills up to the gas limit the manifest will declare ([`manifest_gas_limit`]: the
/// parent's limit minus its anchor reserve, none for a genesis or Etna parent) instead of the
/// protocol minimum, which under-filled every list to 10M while blocks advertise ~45M. It is
/// derived from the same snapshot the manifest is built against. No block context is sent: on an
/// Etna parent the execution engine drops its own anchor zk-gas reserve.
fn pool_content_params(
    beneficiary: Address,
    base_fee: u64,
    ctx: &EngineBuildContext,
) -> TxPoolContentParams {
    TxPoolContentParams {
        beneficiary,
        base_fee: Some(base_fee),
        block_max_gas_limit: manifest_gas_limit(ctx),
        max_bytes_per_tx_list: PROPOSAL_MAX_BLOB_BYTES as u64,
        locals: vec![],
        max_transactions_lists: 1,
        min_tip: 0,
    }
}

/// Fork-dependent fields of an engine-mode build, decided by [`engine_target_fork_fields`].
#[derive(Debug, Clone, PartialEq, Eq)]
struct EngineTargetForkFields {
    /// Whether the target block (at the L1 head timestamp) is an Etna block.
    target_is_etna: bool,
    /// Header gas limit of the target: the parent's manifest gas limit plus the target's anchor
    /// reserve.
    gas_limit: u64,
    /// `parentBeaconBlockRoot` of the attributes: zero before Etna, the L1 head's state root for
    /// an Etna target.
    parent_beacon_block_root: B256,
    /// Header `extraData`: 7 bytes before Etna, 13 bytes naming the L1 head as the anchor block
    /// for an Etna target.
    extra_data: Bytes,
}

impl EngineTargetForkFields {
    /// Whether the attributes carry an anchor transaction, which the execution engine then
    /// places at index 0 of the built payload: every pre-Etna target, never an Etna one.
    const fn has_anchor_transaction(&self) -> bool {
        !self.target_is_etna
    }
}

/// Decide the fork-dependent fields of an engine-mode build over `ctx`, whose L1 head (number
/// `ctx.anchor_block_number`, time `ctx.timestamp`, state root `l1_head_state_root`) is the
/// anchor and whose L1 head time is the target timestamp.
///
/// The header gas limit is `parent_manifest_gas_limit(parent) + anchor_gas_reserve(target)` for
/// every target, as derivation computes it. For a non-genesis pre-Etna parent and a pre-Etna
/// target it equals the parent's header gas limit; for a genesis parent and a pre-Etna target it
/// is the genesis gas limit plus the 1,000,000 anchor gas reserve, as derivation does. Engine
/// mode only previews the block: the proposal's gas comes from the manifest. An Etna target names
/// the L1 head by its state root and in its 13-byte `extraData`; a pre-Etna target keeps a zero
/// root and the 7-byte `extraData`.
fn engine_target_fork_fields(
    ctx: &EngineBuildContext,
    l1_head_state_root: B256,
    basefee_sharing_pctg: u8,
    proposal_id: u64,
    etna_fork_timestamp: Option<u64>,
) -> Result<EngineTargetForkFields> {
    let target_is_etna = is_etna_at(etna_fork_timestamp, ctx.timestamp);
    let gas_limit =
        parent_manifest_gas_limit(ctx.parent_block_number, ctx.gas_limit, ctx.parent_is_etna)
            .saturating_add(anchor_gas_reserve(target_is_etna));

    let (parent_beacon_block_root, extra_data) = if target_is_etna {
        (
            l1_head_state_root,
            encode_etna_extra_data(basefee_sharing_pctg, proposal_id, ctx.anchor_block_number)?,
        )
    } else {
        (B256::ZERO, encode_extra_data(basefee_sharing_pctg, proposal_id))
    };

    Ok(EngineTargetForkFields { target_is_etna, gas_limit, parent_beacon_block_root, extra_data })
}

/// Inputs of [`engine_payload_attributes`] for one engine-mode build.
struct EngineAttributesParams<'a> {
    /// Fee recipient of the target block.
    beneficiary: Address,
    /// L2 parent the target block builds on.
    parent: &'a Block,
    /// Build context: the target timestamp and the L1 head the target anchors to.
    ctx: &'a EngineBuildContext,
    /// Hash of the L1 head (block `ctx.anchor_block_number`).
    l1_head_hash: B256,
    /// Fork-dependent fields of the target, from [`engine_target_fork_fields`].
    fork_fields: &'a EngineTargetForkFields,
    /// Base fee of the target block.
    base_fee: U256,
    /// Encoded anchor transaction of a pre-Etna target; `None` for an Etna target.
    anchor_transaction: Option<Bytes>,
}

/// Assemble the engine-mode payload attributes of the parent's child.
///
/// The fork-dependent gas limit, `extraData` and root come from `fork_fields`; the root is
/// always sent (zero before Etna). The transaction list is left to the node's mempool.
fn engine_payload_attributes(params: EngineAttributesParams<'_>) -> TaikoPayloadAttributes {
    let EngineAttributesParams {
        beneficiary,
        parent,
        ctx,
        l1_head_hash,
        fork_fields,
        base_fee,
        anchor_transaction,
    } = params;
    let block_number = parent.number() + 1;

    build_payload_attributes(PayloadAttributesInput {
        beneficiary,
        timestamp: ctx.timestamp,
        mix_hash: calculate_shasta_mix_hash(parent.header.inner.mix_hash, block_number),
        gas_limit: fork_fields.gas_limit,
        // Engine mode: let the node select transactions from its mempool.
        tx_list: None,
        extra_data: fork_fields.extra_data.clone(),
        base_fee_per_gas: base_fee,
        block_number,
        l1_block_height: Some(U256::from(ctx.anchor_block_number)),
        l1_block_hash: Some(l1_head_hash),
        is_forced_inclusion: false,
        signature: [0; 65],
        parent_beacon_block_root: Some(fork_fields.parent_beacon_block_root),
        anchor_transaction,
    })
}

/// Decode the user transactions of a payload built in engine mode for a target with
/// `fork_fields`.
///
/// A pre-Etna payload starts with the anchor transaction the execution engine inserted from the
/// attributes; it is not part of the proposal, so it is skipped. An Etna payload has no anchor
/// transaction, and its transaction 0 is a user transaction.
fn engine_payload_user_transactions(
    execution_payload: &ExecutionPayloadV3,
    fork_fields: &EngineTargetForkFields,
) -> Result<Vec<Transaction>> {
    execution_payload
        .payload_inner
        .payload_inner
        .transactions
        .iter()
        .skip(usize::from(fork_fields.has_anchor_transaction()))
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
        .collect()
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
    use alethia_reth_consensus::eip4396::SHASTA_INITIAL_BASE_FEE;
    use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
    use alloy::{
        consensus::Header as ConsensusHeader,
        primitives::{Address, B256, Bytes, U256},
        signers::{SignerSync, local::PrivateKeySigner},
        transports::{RpcError, TransportErrorKind},
    };
    use alloy_consensus::{
        Eip658Value, Receipt, ReceiptEnvelope, ReceiptWithBloom, SignableTransaction,
        Transaction as _, TxEnvelope, TxLegacy,
    };
    use alloy_eips::eip2718::Encodable2718;
    use alloy_json_rpc::ErrorPayload;
    use alloy_rpc_types::{
        TransactionReceipt,
        eth::{Block as RpcBlock, Header as RpcHeader},
    };
    use alloy_rpc_types_engine::{ExecutionPayloadV1, ExecutionPayloadV2, ExecutionPayloadV3};
    use base_tx_manager::TxManagerError;

    use super::{
        EngineAttributesParams, EngineBuildContext, EngineTargetForkFields,
        calculate_next_shasta_block_base_fee_from_parent, engine_payload_attributes,
        engine_payload_user_transactions, engine_target_fork_fields,
        forced_inclusion_is_permissionless, is_operational_loop_error, next_shasta_proposal_id,
        pool_content_params, record_submission_attempt, record_submission_receipt,
        should_increment_loop_failure_metric,
    };
    use crate::{
        error::ProposerError, metrics::ProposerMetrics, transaction_builder::manifest_gas_limit,
    };
    use protocol::shasta::{
        constants::calculate_next_block_eip4396_base_fee_from_parent_values,
        decode_etna_anchor_block_number, encode_etna_extra_data, encode_extra_data,
    };
    use rpc::RpcClientError;

    #[test]
    fn submission_attempt_increments_sent_metric() {
        let before = ProposerMetrics::proposals_sent().get();
        record_submission_attempt();
        assert_eq!(ProposerMetrics::proposals_sent().get(), before + 1);
    }

    #[test]
    fn successful_submission_receipt_is_returned_and_recorded() {
        let receipt = receipt_with_status(true);
        let tx_hash = receipt.transaction_hash;
        let before = ProposerMetrics::proposals_success().get();

        let recorded = record_submission_receipt(receipt)
            .expect("successful receipt should remain successful");

        assert_eq!(recorded.transaction_hash, tx_hash);
        assert_eq!(ProposerMetrics::proposals_success().get(), before + 1);
    }

    /// Serializes tests that snapshot and assert on the process-global proposal-failure
    /// counter, which would otherwise race each other under the parallel test runner.
    static PROPOSALS_FAILED_METRIC_GUARD: std::sync::Mutex<()> = std::sync::Mutex::new(());

    #[test]
    fn reverted_submission_receipt_becomes_failed_proposal_error() {
        let _metric_guard =
            PROPOSALS_FAILED_METRIC_GUARD.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
        let receipt = receipt_with_status(false);
        let tx_hash = receipt.transaction_hash;
        let before = ProposerMetrics::proposals_failed().get();

        let err = record_submission_receipt(receipt)
            .expect_err("reverted receipt should be surfaced as a proposer error");

        assert!(matches!(
            err,
            ProposerError::ProposalTransactionReverted { tx_hash: observed } if observed == tx_hash
        ));
        assert_eq!(ProposerMetrics::proposals_failed().get(), before + 1);
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
    fn forced_inclusion_precheck_classifies_permissionless_windows() {
        // (case, (oldest inclusion timestamp, l1 timestamp, delay, multiplier), expected).
        let cases = [
            ("l1 timestamp past the permissionless window", (100, 151, 10, 5), true),
            ("l1 timestamp at the window boundary", (100, 150, 10, 5), false),
            ("l1 timestamp before the window", (100, 149, 10, 5), false),
            ("missing oldest-inclusion timestamp", (0, 1_000, 10, 5), false),
        ];

        for (case, (oldest_timestamp, l1_timestamp, delay, multiplier), expected) in cases {
            assert_eq!(
                forced_inclusion_is_permissionless(
                    oldest_timestamp,
                    l1_timestamp,
                    delay,
                    multiplier
                ),
                expected,
                "{case}"
            );
        }
    }

    #[test]
    fn loop_failure_metric_not_double_counted_for_reverted_receipts() {
        let _metric_guard =
            PROPOSALS_FAILED_METRIC_GUARD.lock().unwrap_or_else(|poisoned| poisoned.into_inner());
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
    fn loop_error_classification_matches_expected_retry_behavior() {
        let error_payload = || -> ErrorPayload {
            serde_json::from_str(
                r#"{"code":3,"message":"execution reverted: ","data":"0x810f00230000000000000000000000000000000000000000000000000000000000000001"}"#,
            )
            .expect("valid JSON-RPC error payload")
        };
        let revert_contract_error =
            alloy::contract::Error::TransportError(RpcError::ErrorResp(error_payload()));
        assert!(revert_contract_error.as_revert_data().is_some());

        // (case, error, expected `is_operational_loop_error` verdict).
        let cases = [
            (
                "tx-manager rpc failure is retried",
                ProposerError::TxManager(TxManagerError::Rpc("provider timed out".into())),
                true,
            ),
            (
                "tx-manager send timeout is retried",
                ProposerError::TxManager(TxManagerError::SendTimeout),
                true,
            ),
            (
                "tx-manager mempool deadline expiry is retried",
                ProposerError::TxManager(TxManagerError::MempoolDeadlineExpired),
                true,
            ),
            (
                "tx-manager execution revert is retried",
                ProposerError::TxManager(TxManagerError::ExecutionReverted),
                true,
            ),
            (
                "reverted proposal receipt is retried",
                ProposerError::ProposalTransactionReverted { tx_hash: B256::repeat_byte(0x22) },
                true,
            ),
            (
                "precheck transport failure is retried",
                ProposerError::Rpc(TransportErrorKind::backend_gone()),
                true,
            ),
            (
                "precheck contract transport failure is retried",
                ProposerError::Contract(alloy::contract::Error::TransportError(
                    TransportErrorKind::backend_gone(),
                )),
                true,
            ),
            (
                "rpc-client transport failure is retried",
                ProposerError::from(RpcClientError::from(TransportErrorKind::backend_gone())),
                true,
            ),
            (
                "rpc error response exits the loop",
                ProposerError::Rpc(RpcError::ErrorResp(error_payload())),
                false,
            ),
            (
                "contract revert response exits the loop",
                ProposerError::Contract(revert_contract_error),
                false,
            ),
            (
                "rpc-client error response exits the loop",
                ProposerError::from(RpcClientError::from(RpcError::ErrorResp(error_payload()))),
                false,
            ),
            (
                "local contract error exits the loop",
                ProposerError::Contract(alloy::contract::Error::UnknownFunction(
                    "getOperatorForCurrentEpoch".into(),
                )),
                false,
            ),
            (
                "tx-manager nonce-too-low exits the loop",
                ProposerError::TxManager(TxManagerError::NonceTooLow),
                false,
            ),
            (
                "tx-manager fee-limit breach exits the loop",
                ProposerError::TxManager(TxManagerError::FeeLimitExceeded { fee: 11, ceiling: 10 }),
                false,
            ),
            (
                "tx-manager signing failure exits the loop",
                ProposerError::TxManager(TxManagerError::Sign("wallet rejected signing".into())),
                false,
            ),
            (
                "tx-manager invalid config exits the loop",
                ProposerError::TxManager(TxManagerError::InvalidConfig("bad fee limit".into())),
                false,
            ),
        ];

        for (case, err, expected) in cases {
            assert_eq!(is_operational_loop_error(&err), expected, "{case}");
        }
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

    /// Etna activation time used by the fork-aware tests.
    const SAMPLE_ETNA_TIMESTAMP: u64 = 1_000;

    /// RPC block with the given header number, timestamp and gas limit.
    fn header_block(number: u64, timestamp: u64, gas_limit: u64) -> RpcBlock {
        RpcBlock {
            header: RpcHeader {
                hash: B256::with_last_byte(number as u8),
                inner: ConsensusHeader { number, timestamp, gas_limit, ..Default::default() },
                total_difficulty: None,
                size: None,
            },
            ..Default::default()
        }
    }

    #[test]
    fn build_context_records_the_parent_fork_from_the_parent_timestamp() {
        let l1_head = header_block(77, SAMPLE_ETNA_TIMESTAMP + 12, 30_000_000);
        // (case, parent timestamp, Etna activation time, expected `parent_is_etna`).
        let cases = [
            ("Etna not scheduled", SAMPLE_ETNA_TIMESTAMP, None, false),
            ("parent before Etna", SAMPLE_ETNA_TIMESTAMP - 1, Some(SAMPLE_ETNA_TIMESTAMP), false),
            ("parent at Etna", SAMPLE_ETNA_TIMESTAMP, Some(SAMPLE_ETNA_TIMESTAMP), true),
        ];

        for (case, parent_timestamp, etna_fork_timestamp, expected) in cases {
            let parent = header_block(42, parent_timestamp, 45_000_000);
            let ctx = EngineBuildContext::from_snapshot(&parent, &l1_head, etna_fork_timestamp);

            assert_eq!(ctx.parent_is_etna, expected, "{case}");
            assert_eq!(ctx.parent_block_number, 42, "{case}");
            assert_eq!(ctx.gas_limit, 45_000_000, "{case}");
            assert_eq!(ctx.anchor_block_number, 77, "{case}");
            assert_eq!(ctx.timestamp, SAMPLE_ETNA_TIMESTAMP + 12, "{case}");
        }
    }

    #[test]
    fn pool_budget_equals_the_manifest_gas_limit() {
        // (case, parent number, parent is Etna, expected budget).
        let cases = [
            ("genesis parent", 0, false, 45_000_000),
            ("pre-Etna parent", 42, false, 44_000_000),
            ("Etna parent", 42, true, 45_000_000),
        ];

        for (case, parent_block_number, parent_is_etna, expected) in cases {
            let ctx = EngineBuildContext {
                anchor_block_number: 77,
                parent_block_number,
                parent_is_etna,
                timestamp: SAMPLE_ETNA_TIMESTAMP,
                gas_limit: 45_000_000,
            };

            let params = pool_content_params(Address::repeat_byte(0x11), 7, &ctx);

            assert_eq!(params.block_max_gas_limit, manifest_gas_limit(&ctx), "{case}");
            assert_eq!(params.block_max_gas_limit, expected, "{case}");
            assert_eq!(params.beneficiary, Address::repeat_byte(0x11), "{case}");
            assert_eq!(params.base_fee, Some(7), "{case}");
        }
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

    #[test]
    fn base_fee_calculation_returns_initial_base_fee_for_genesis_parent() {
        let genesis = RpcBlock {
            header: RpcHeader {
                hash: B256::repeat_byte(0x11),
                inner: ConsensusHeader { number: 0, ..Default::default() },
                total_difficulty: None,
                size: None,
            },
            ..Default::default()
        };

        assert_eq!(
            calculate_next_shasta_block_base_fee_from_parent(&genesis, None, 1_000_000_000)
                .expect("genesis parent should not require a grandparent"),
            U256::from(SHASTA_INITIAL_BASE_FEE)
        );
    }

    #[test]
    fn base_fee_calculation_errors_on_missing_grandparent() {
        let parent = RpcBlock {
            header: RpcHeader {
                hash: B256::repeat_byte(0x22),
                inner: ConsensusHeader {
                    number: 2,
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

        assert!(matches!(
            calculate_next_shasta_block_base_fee_from_parent(&parent, None, 1_000_000_000),
            Err(ProposerError::ParentBlockNotFound(1))
        ));
    }

    #[test]
    fn base_fee_calculation_errors_on_parent_missing_base_fee() {
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
                    base_fee_per_gas: None,
                    ..Default::default()
                },
                total_difficulty: None,
                size: None,
            },
            ..Default::default()
        };

        assert!(matches!(
            calculate_next_shasta_block_base_fee_from_parent(
                &parent,
                Some(&grandparent),
                1_000_000_000
            ),
            Err(ProposerError::MissingParentBaseFee { parent_block_number: 2 })
        ));
    }

    /// Encoded legacy transfer with the given nonce, signed by `signer`.
    fn signed_transfer(signer: &PrivateKeySigner, nonce: u64) -> Bytes {
        let tx = TxLegacy {
            chain_id: Some(167_001),
            nonce,
            gas_price: 1,
            gas_limit: 21_000,
            to: Address::with_last_byte(0x42).into(),
            ..Default::default()
        };
        let signature = signer.sign_hash_sync(&tx.signature_hash()).expect("sign transfer");
        Bytes::from(TxEnvelope::from(tx.into_signed(signature)).encoded_2718())
    }

    /// V3 execution payload, as carried by a `getPayloadV5` envelope, with the given
    /// transactions.
    fn engine_payload(transactions: Vec<Bytes>) -> ExecutionPayloadV3 {
        ExecutionPayloadV3 {
            payload_inner: ExecutionPayloadV2 {
                payload_inner: ExecutionPayloadV1 {
                    parent_hash: B256::ZERO,
                    fee_recipient: Address::ZERO,
                    state_root: B256::ZERO,
                    receipts_root: B256::ZERO,
                    logs_bloom: Default::default(),
                    prev_randao: B256::ZERO,
                    block_number: 1,
                    gas_limit: 30_000_000,
                    gas_used: 0,
                    timestamp: 1,
                    extra_data: Bytes::new(),
                    base_fee_per_gas: U256::from(1u64),
                    block_hash: B256::ZERO,
                    transactions,
                },
                withdrawals: vec![],
            },
            blob_gas_used: 0,
            excess_blob_gas: 0,
        }
    }

    /// Unzen engine-mode payloads still start with the anchor transaction, which is not part
    /// of the proposal.
    #[test]
    fn engine_payload_user_transactions_skip_the_unzen_anchor() {
        let signer = PrivateKeySigner::random();
        let payload =
            engine_payload(vec![signed_transfer(&signer, 0), signed_transfer(&signer, 1)]);

        let txs = engine_payload_user_transactions(&payload, &unzen_target().1)
            .expect("decode user transactions");

        assert_eq!(txs.len(), 1);
        assert_eq!(txs[0].nonce(), 1);
        assert_eq!(txs[0].inner.signer(), signer.address());
    }

    /// An Etna payload has no anchor transaction: transaction 0 is a user transaction and must
    /// stay in the proposal.
    #[test]
    fn engine_payload_user_transactions_keep_tx_zero_of_an_etna_payload() {
        let signer = PrivateKeySigner::random();
        let payload =
            engine_payload(vec![signed_transfer(&signer, 0), signed_transfer(&signer, 1)]);

        let txs = engine_payload_user_transactions(&payload, &etna_target().1)
            .expect("decode user transactions");

        assert_eq!(txs.len(), 2);
        assert_eq!(txs[0].nonce(), 0);
        assert_eq!(txs[1].nonce(), 1);
    }

    #[test]
    fn engine_payload_user_transactions_reject_undecodable_bytes() {
        let signer = PrivateKeySigner::random();
        let payload =
            engine_payload(vec![signed_transfer(&signer, 0), Bytes::from_static(&[0xff])]);

        assert!(matches!(
            engine_payload_user_transactions(&payload, &unzen_target().1),
            Err(ProposerError::TxDecode { index: 0, .. })
        ));
    }

    /// Basefee sharing percentage used by the engine-mode field tests.
    const SAMPLE_PCTG: u8 = 75;
    /// Proposal id used by the engine-mode field tests.
    const SAMPLE_PROPOSAL_ID: u64 = 10;
    /// L1 head number (the anchor block) used by the engine-mode field tests.
    const SAMPLE_L1_HEAD_NUMBER: u64 = 77;

    /// L1 head state root used by the engine-mode field tests.
    fn sample_l1_state_root() -> B256 {
        B256::repeat_byte(0x5a)
    }

    /// Engine-mode build context over a parent with the given number, fork and header gas
    /// limit, targeting the L1 head time `target_timestamp`.
    fn engine_ctx(
        parent_block_number: u64,
        parent_is_etna: bool,
        gas_limit: u64,
        target_timestamp: u64,
    ) -> EngineBuildContext {
        EngineBuildContext {
            anchor_block_number: SAMPLE_L1_HEAD_NUMBER,
            parent_block_number,
            parent_is_etna,
            timestamp: target_timestamp,
            gas_limit,
        }
    }

    /// Build context and fork fields of an Etna target on an Etna parent (block 42).
    fn etna_target() -> (EngineBuildContext, EngineTargetForkFields) {
        let ctx = engine_ctx(42, true, 45_000_000, SAMPLE_ETNA_TIMESTAMP + 12);
        let fields = engine_target_fork_fields(
            &ctx,
            sample_l1_state_root(),
            SAMPLE_PCTG,
            SAMPLE_PROPOSAL_ID,
            Some(SAMPLE_ETNA_TIMESTAMP),
        )
        .expect("Etna fields");
        (ctx, fields)
    }

    /// Build context and fork fields of an Unzen target on an Unzen parent (block 42).
    fn unzen_target() -> (EngineBuildContext, EngineTargetForkFields) {
        let ctx = engine_ctx(42, false, 45_000_000, SAMPLE_ETNA_TIMESTAMP - 1);
        let fields = engine_target_fork_fields(
            &ctx,
            sample_l1_state_root(),
            SAMPLE_PCTG,
            SAMPLE_PROPOSAL_ID,
            Some(SAMPLE_ETNA_TIMESTAMP),
        )
        .expect("Unzen fields");
        (ctx, fields)
    }

    /// Hash of the sample L1 head.
    fn sample_l1_head_hash() -> B256 {
        B256::repeat_byte(0x77)
    }

    /// Engine-mode attributes of block 43 over `ctx` and `fields`, carrying `anchor_transaction`.
    fn sample_engine_attributes(
        ctx: &EngineBuildContext,
        fields: &EngineTargetForkFields,
        anchor_transaction: Option<Bytes>,
    ) -> TaikoPayloadAttributes {
        let parent = header_block(42, ctx.timestamp - 12, ctx.gas_limit);
        engine_payload_attributes(EngineAttributesParams {
            beneficiary: Address::with_last_byte(0x11),
            parent: &parent,
            ctx,
            l1_head_hash: sample_l1_head_hash(),
            fork_fields: fields,
            base_fee: U256::from(7u64),
            anchor_transaction,
        })
    }

    /// An Etna target's attributes send the L1 head's state root as `parentBeaconBlockRoot`,
    /// the 13-byte `extraData` and no anchor transaction, leaving the list to the mempool.
    #[test]
    fn engine_attributes_for_an_etna_target_send_the_l1_state_root_and_no_anchor() {
        let (ctx, fields) = etna_target();

        let attributes = sample_engine_attributes(&ctx, &fields, None);

        assert_eq!(
            attributes.payload_attributes.parent_beacon_block_root,
            Some(sample_l1_state_root())
        );
        assert_eq!(attributes.payload_attributes.timestamp, ctx.timestamp);
        assert_eq!(attributes.block_metadata.extra_data, fields.extra_data);
        assert_eq!(attributes.block_metadata.extra_data.len(), 13);
        assert_eq!(attributes.block_metadata.gas_limit, fields.gas_limit);
        assert_eq!(attributes.block_metadata.tx_list, None);
        assert_eq!(attributes.anchor_transaction, None);
        assert_eq!(attributes.l1_origin.block_id, U256::from(43u64));
        assert_eq!(attributes.l1_origin.l1_block_height, Some(U256::from(SAMPLE_L1_HEAD_NUMBER)));
        assert_eq!(attributes.l1_origin.l1_block_hash, Some(sample_l1_head_hash()));
    }

    /// An Unzen target's attributes send the explicit zero root, the 7-byte `extraData` and the
    /// anchor transaction.
    #[test]
    fn engine_attributes_for_an_unzen_target_send_a_zero_root_and_the_anchor() {
        let (ctx, fields) = unzen_target();
        let anchor_transaction = Bytes::from_static(&[0x02, 0xaa]);

        let attributes = sample_engine_attributes(&ctx, &fields, Some(anchor_transaction.clone()));

        assert_eq!(attributes.payload_attributes.parent_beacon_block_root, Some(B256::ZERO));
        assert_eq!(attributes.block_metadata.extra_data, fields.extra_data);
        assert_eq!(attributes.block_metadata.extra_data.len(), 7);
        assert_eq!(attributes.block_metadata.gas_limit, fields.gas_limit);
        assert_eq!(attributes.anchor_transaction, Some(anchor_transaction));
    }

    #[test]
    fn engine_fields_for_an_etna_target_drop_the_anchor_and_carry_the_l1_state_root() {
        let ctx = engine_ctx(42, true, 45_000_000, SAMPLE_ETNA_TIMESTAMP + 12);

        let fields = engine_target_fork_fields(
            &ctx,
            sample_l1_state_root(),
            SAMPLE_PCTG,
            SAMPLE_PROPOSAL_ID,
            Some(SAMPLE_ETNA_TIMESTAMP),
        )
        .expect("Etna fields");

        assert!(fields.target_is_etna);
        assert!(!fields.has_anchor_transaction(), "an Etna target has no anchor transaction");
        assert_eq!(fields.parent_beacon_block_root, sample_l1_state_root());
        assert_eq!(fields.extra_data.len(), 13);
        assert_eq!(
            fields.extra_data,
            encode_etna_extra_data(SAMPLE_PCTG, SAMPLE_PROPOSAL_ID, SAMPLE_L1_HEAD_NUMBER)
                .expect("encode Etna extraData")
        );
        assert_eq!(
            decode_etna_anchor_block_number(43, &fields.extra_data).expect("decode anchor"),
            SAMPLE_L1_HEAD_NUMBER
        );
        // An Etna parent carries no reserve and an Etna target adds none.
        assert_eq!(fields.gas_limit, 45_000_000);
    }

    #[test]
    fn engine_fields_for_an_unzen_target_keep_the_anchor_and_a_zero_root() {
        for etna_fork_timestamp in [None, Some(SAMPLE_ETNA_TIMESTAMP)] {
            let ctx = engine_ctx(42, false, 45_000_000, SAMPLE_ETNA_TIMESTAMP - 1);

            let fields = engine_target_fork_fields(
                &ctx,
                sample_l1_state_root(),
                SAMPLE_PCTG,
                SAMPLE_PROPOSAL_ID,
                etna_fork_timestamp,
            )
            .expect("Unzen fields");

            assert!(!fields.target_is_etna, "{etna_fork_timestamp:?}");
            assert!(fields.has_anchor_transaction(), "{etna_fork_timestamp:?}");
            assert_eq!(fields.parent_beacon_block_root, B256::ZERO, "{etna_fork_timestamp:?}");
            assert_eq!(
                fields.extra_data,
                encode_extra_data(SAMPLE_PCTG, SAMPLE_PROPOSAL_ID),
                "{etna_fork_timestamp:?}"
            );
            assert_eq!(fields.extra_data.len(), 7, "{etna_fork_timestamp:?}");
            // The parent's manifest gas (45M - 1M) plus the target's 1M anchor reserve.
            assert_eq!(fields.gas_limit, 45_000_000, "{etna_fork_timestamp:?}");
        }
    }

    #[test]
    fn engine_fields_at_the_etna_boundary_drop_the_parent_reserve() {
        // Unzen parent, Etna target: the parent's reserve goes and no new one is added.
        let ctx = engine_ctx(42, false, 45_000_000, SAMPLE_ETNA_TIMESTAMP);

        let fields = engine_target_fork_fields(
            &ctx,
            sample_l1_state_root(),
            SAMPLE_PCTG,
            SAMPLE_PROPOSAL_ID,
            Some(SAMPLE_ETNA_TIMESTAMP),
        )
        .expect("boundary fields");

        assert!(fields.target_is_etna);
        assert_eq!(fields.gas_limit, 44_000_000);
    }

    #[test]
    fn engine_fields_for_a_genesis_parent_add_the_reserve_before_etna() {
        // Derivation gives block 1 the genesis gas limit as manifest gas plus the anchor reserve.
        let ctx = engine_ctx(0, false, 45_000_000, SAMPLE_ETNA_TIMESTAMP - 1);

        let fields = engine_target_fork_fields(
            &ctx,
            sample_l1_state_root(),
            SAMPLE_PCTG,
            1,
            Some(SAMPLE_ETNA_TIMESTAMP),
        )
        .expect("genesis-parent fields");

        assert_eq!(fields.gas_limit, 46_000_000);
    }
}

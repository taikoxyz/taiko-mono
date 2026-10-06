use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy::{
    eips::{BlockNumberOrTag, NumHash, eip7685::EMPTY_REQUESTS_HASH},
    primitives::{Address, B256, U256, keccak256},
    providers::Provider,
};
use alloy_consensus::{Header, TxEnvelope};
use alloy_rpc_types::Transaction as RpcTransaction;
use alloy_rpc_types_engine::{ForkchoiceState, PayloadId};
use protocol::shasta::{
    PayloadAttributesInput, anchor_gas_reserve, build_payload_attributes_with_id,
    calculate_shasta_mix_hash, encode_etna_extra_data, encode_extra_data, encode_transactions,
    is_etna_at,
    manifest::{BlockManifest, DerivationSourceManifest},
    unzen_active_for_chain_timestamp,
};

use crate::{
    derivation::DerivationError,
    metrics::DriverMetrics,
    sync::{
        engine::{EngineBlockOutcome, PayloadApplier, ensure_valid_forkchoice_status},
        is_finalized_block_not_found,
    },
};
use protocol::shasta::AnchorV4Input;

use tracing::{debug, info, instrument, warn};

use super::{
    super::validation::{ValidationError, validate_source_manifest},
    ShastaDerivationPipeline,
    bundle::{BundleMeta, SourceManifestSegment},
    state::ParentState,
};

/// Context describing a manifest segment during payload derivation.
#[derive(Debug)]
struct SegmentContext<'a> {
    /// Proposal metadata shared across all segments.
    meta: &'a BundleMeta,
    /// Index of the segment within the proposal bundle.
    segment_index: usize,
    /// Total number of segments in the proposal bundle.
    segments_total: usize,
}

/// Position metadata passed down to block-level processing.
#[derive(Debug, Clone, Copy)]
struct BlockPosition {
    /// Index of the segment containing the block.
    segment_index: usize,
    /// Total number of segments in the bundle.
    segments_total: usize,
    /// Index of the block within its segment.
    block_index: usize,
    /// Total number of blocks in the segment.
    blocks_len: usize,
    /// Whether the block originates from a forced inclusion segment.
    forced_inclusion: bool,
}

/// Shared inputs required when converting a manifest block into payload attributes.
#[derive(Debug, Clone, Copy)]
struct BlockContext<'a> {
    /// Immutable metadata describing the entire proposal bundle.
    meta: &'a BundleMeta,
    /// Positional data describing where the block sits within the proposal.
    position: BlockPosition,
}

/// Aggregate of per-block data forwarded to `create_payload_attributes`.
#[derive(Debug)]
struct PayloadContext<'a> {
    /// Manifest-provided block metadata.
    block: &'a BlockManifest,
    /// Proposal-level metadata reused for payload construction.
    meta: &'a BundleMeta,
    /// Base fee target for the upcoming block.
    block_base_fee: u64,
    /// Mix hash used when sealing the block.
    mix_hash: B256,
    /// Height of the block being built.
    block_number: u64,
    /// Hash of the parent block used for payload ID derivation.
    parent_hash: B256,
    /// Positional data describing where the block sits within the proposal.
    position: BlockPosition,
    /// Whether the block is an Etna block (decided by its final timestamp): no anchor
    /// transaction, no anchor gas reserve and the 13-byte `extraData`.
    is_etna: bool,
    /// Root sent as `parentBeaconBlockRoot`: zero before Etna; for an Etna block, the state root
    /// of the L1 block it anchors to (its `anchor_block_number`).
    parent_beacon_block_root: B256,
}

/// Aggregated parameters required to assemble the anchor transaction.
#[derive(Debug)]
struct AnchorTxInputs<'a> {
    /// Manifest-provided block metadata.
    block: &'a BlockManifest,
    /// Height of the block being built.
    block_number: u64,
    /// Base fee target for the upcoming block.
    block_base_fee: u64,
}

/// Return true when the manifest represents the protocol-defined default payload.
fn manifest_is_default(manifest: &DerivationSourceManifest) -> bool {
    if manifest.blocks.len() != 1 {
        return false;
    }

    let block = &manifest.blocks[0];
    block.timestamp == 0 &&
        block.coinbase == Address::ZERO &&
        block.anchor_block_number == 0 &&
        block.gas_limit == 0 &&
        block.transactions.is_empty()
}

impl BlockPosition {
    /// Return true if this is the last block of the last manifest segment.
    fn is_final(&self) -> bool {
        self.segment_index + 1 == self.segments_total && self.block_index + 1 == self.blocks_len
    }

    /// Return true if this block comes from a forced-inclusion source.
    fn is_forced_inclusion(&self) -> bool {
        self.forced_inclusion
    }
}

/// Prepared data required to either materialise or validate a manifest block.
///
/// By caching the payload attributes, anchor transaction, and derived metadata we can reuse the
/// same computation when probing the canonical chain.
#[derive(Debug)]
struct BlockDerivationContext {
    /// Payload attributes derived for this manifest block.
    payload: TaikoPayloadAttributes,
    /// Anchor transaction paired with `payload`; `None` for an Etna block, which has none.
    anchor_tx: Option<TxEnvelope>,
    /// Parent hash used to build the payload.
    parent_hash: B256,
    /// L2 block number expected from execution.
    block_number: u64,
    /// Final anchor block number of the block: encoded into the anchor transaction before Etna,
    /// and into the 13-byte `extraData` of an Etna block.
    anchor_block_number: u64,
    /// Whether this block finalizes the proposal's derivation output.
    is_final_block: bool,
}

/// Canonical block data captured when a proposal's blocks already exist on the execution chain.
#[derive(Debug)]
pub(super) struct KnownCanonicalBlock {
    /// Payload attributes validated against canonical chain data.
    pub(super) payload: TaikoPayloadAttributes,
    /// Execution outcome projected from canonical block data.
    pub(super) outcome: EngineBlockOutcome,
    /// Whether this block is the final block for the proposal.
    pub(super) is_final_block: bool,
}

/// Output of a successful canonical-chain verification.
///
/// Carries both the execution outcome (for L1 origin updates) and the consensus header so the
/// parent state can advance without talking to the engine again.
#[derive(Debug)]
struct VerifiedCanonicalBlock {
    /// Engine-like outcome reconstructed from canonical block data.
    outcome: EngineBlockOutcome,
    /// Consensus header used to advance parent state.
    header: Header,
}

impl ShastaDerivationPipeline {
    /// Resolve the last finalized proposal's canonical block height and hash if available.
    ///
    /// Missing checkpoint data returns `Ok(None)`. RPC errors propagate so finality refresh can
    /// retry instead of marking the proposal as successfully processed.
    async fn finalized_block_for(
        &self,
        maybe_last_finalized_proposal_id: Option<u64>,
    ) -> Result<Option<NumHash>, DerivationError> {
        let Some(last_finalized_proposal_id) = maybe_last_finalized_proposal_id else {
            return Ok(None);
        };

        let block_number = match self
            .rpc
            .last_block_id_by_batch_id(U256::from(last_finalized_proposal_id))
            .await
        {
            Ok(Some(block_id)) => block_id.to::<u64>(),
            Ok(None) => {
                debug!(
                    proposal_id = last_finalized_proposal_id,
                    "no batch-to-block mapping for finalized proposal id"
                );
                return Ok(None);
            }
            Err(err) => {
                warn!(
                    proposal_id = last_finalized_proposal_id,
                    error = %err,
                    "failed to query finalized proposal block id"
                );
                return Err(err.into());
            }
        };

        match self.rpc.l2_provider.get_block_by_number(BlockNumberOrTag::Number(block_number)).await
        {
            Ok(Some(block)) => {
                debug!(
                    proposal_id = last_finalized_proposal_id,
                    block_number,
                    block_hash = ?block.header.hash,
                    "resolved finalized block hash from proposal core state"
                );
                Ok(Some(NumHash::new(block.header.number, block.header.hash)))
            }
            Ok(None) => {
                warn!(
                    proposal_id = last_finalized_proposal_id,
                    block_number, "missing block for finalized proposal id"
                );
                Ok(None)
            }
            Err(err) => {
                warn!(
                    proposal_id = last_finalized_proposal_id,
                    block_number,
                    error = %err,
                    "failed to fetch finalized block by number"
                );
                Err(err.into())
            }
        }
    }

    /// Resolve a finalized hash without blocking payload building on checkpoint RPC failures.
    ///
    /// The checkpoint lookup logs errors before they are discarded here. Canonical finality
    /// refresh uses the fallible lookup directly so its failures remain retryable.
    async fn finalized_block_hash_for(
        &self,
        maybe_last_finalized_proposal_id: Option<u64>,
    ) -> Option<B256> {
        self.finalized_block_for(maybe_last_finalized_proposal_id)
            .await
            .ok()
            .flatten()
            .map(|block| block.hash)
    }

    /// Process all manifest segments in order, materialising blocks via the execution engine.
    #[instrument(
        skip(self, sources, state, applier),
        fields(proposal_id = meta.proposal_id, segment_count = sources.len())
    )]
    pub(super) async fn build_payloads_from_sources(
        &self,
        sources: Vec<SourceManifestSegment>,
        meta: &BundleMeta,
        state: &mut ParentState,
        applier: &(dyn PayloadApplier + Send + Sync),
    ) -> Result<Vec<EngineBlockOutcome>, DerivationError> {
        // Each source can expand into multiple payloads; accumulate their engine outcomes in order.
        let segments_total = sources.len();
        let mut outcomes = Vec::new();
        // Best-effort lookup of the last finalized block hash; missing data should not block
        // payload application.
        let finalized_block_hash =
            self.finalized_block_hash_for(meta.last_finalized_proposal_id).await;
        info!(
            proposal_id = meta.proposal_id,
            segment_count = segments_total,
            "processing manifest segments"
        );
        for (segment_index, segment) in sources.into_iter().enumerate() {
            let segment_ctx = SegmentContext { meta, segment_index, segments_total };
            let segment_outcomes = self
                .process_manifest_segment(
                    segment,
                    state,
                    segment_ctx,
                    applier,
                    finalized_block_hash,
                )
                .await?;

            outcomes.extend(segment_outcomes);
        }

        info!(
            proposal_id = meta.proposal_id,
            block_count = outcomes.len(),
            "completed payload derivation for proposal"
        );
        Ok(outcomes)
    }

    /// Apply validation rules to a manifest segment.
    async fn prepare_segment_manifest(
        &self,
        manifest: DerivationSourceManifest,
        state: &ParentState,
        meta: &BundleMeta,
        segment_index: usize,
        segments_total: usize,
        is_forced_inclusion: bool,
    ) -> Result<DerivationSourceManifest, DerivationError> {
        info!(
            proposal_id = meta.proposal_id,
            segment_index,
            segments_total,
            forced_inclusion = is_forced_inclusion,
            "processing proposal segment",
        );

        // Sanitize the manifest before deriving payload attributes.
        let mut decoded_manifest = manifest;

        if is_forced_inclusion || manifest_is_default(&decoded_manifest) {
            state.apply_inherited_metadata(&mut decoded_manifest, meta);
        }

        let validation_ctx = state.build_validation_context(meta, is_forced_inclusion);

        match validate_source_manifest(&decoded_manifest, &validation_ctx) {
            Ok(()) => {
                info!(
                    proposal_id = meta.proposal_id,
                    segment_index, "manifest segment validation succeeded"
                );
            }
            Err(ValidationError::EmptyManifest | ValidationError::DefaultManifest) => {
                info!(
                    proposal_id = meta.proposal_id,
                    segment_index,
                    "manifest segment is empty or default; proceeding with default payload"
                );
                decoded_manifest = DerivationSourceManifest::default();
                state.apply_inherited_metadata(&mut decoded_manifest, meta);
            }
        }

        Ok(decoded_manifest)
    }

    /// Process a single manifest segment, producing one or more payload attributes.
    #[instrument(
        skip(self, segment, state, ctx, applier),
        fields(proposal_id = ctx.meta.proposal_id, segment_index = ctx.segment_index, segments_total = ctx.segments_total, forced = segment.is_forced_inclusion)
    )]
    async fn process_manifest_segment(
        &self,
        segment: SourceManifestSegment,
        state: &mut ParentState,
        ctx: SegmentContext<'_>,
        applier: &(dyn PayloadApplier + Send + Sync),
        finalized_block_hash: Option<B256>,
    ) -> Result<Vec<EngineBlockOutcome>, DerivationError> {
        let SegmentContext { meta, segment_index, segments_total } = ctx;
        let SourceManifestSegment { manifest, is_forced_inclusion } = segment;

        let decoded_manifest = self
            .prepare_segment_manifest(
                manifest,
                state,
                meta,
                segment_index,
                segments_total,
                is_forced_inclusion,
            )
            .await?;

        let blocks_len = decoded_manifest.blocks.len();
        let mut outcomes = Vec::with_capacity(blocks_len);

        for (block_index, block) in decoded_manifest.blocks.iter().enumerate() {
            let block_ctx = BlockContext {
                meta,
                position: BlockPosition {
                    segment_index,
                    segments_total,
                    block_index,
                    blocks_len,
                    forced_inclusion: is_forced_inclusion,
                },
            };
            let outcome = self
                .process_block_manifest(block, state, block_ctx, applier, finalized_block_hash)
                .await?;
            outcomes.push(outcome);
        }

        debug!(
            proposal_id = meta.proposal_id,
            segment_index,
            derived_blocks = outcomes.len(),
            "completed segment processing"
        );
        Ok(outcomes)
    }

    /// Convert a manifest block into payload attributes while updating the rolling parent state.
    #[instrument(
        skip(self, block, state, ctx, applier),
        fields(proposal_id = ctx.meta.proposal_id, block_idx = ctx.position.block_index, segment_index = ctx.position.segment_index)
    )]
    async fn process_block_manifest(
        &self,
        block: &BlockManifest,
        state: &mut ParentState,
        ctx: BlockContext<'_>,
        applier: &(dyn PayloadApplier + Send + Sync),
        finalized_block_hash: Option<B256>,
    ) -> Result<EngineBlockOutcome, DerivationError> {
        let BlockContext { meta, .. } = ctx;
        let derived_block = self.prepare_block(block, state, ctx).await?;
        let BlockDerivationContext { payload, parent_hash, is_final_block, .. } = derived_block;

        let outcome = applier.apply_payload(&payload, parent_hash, finalized_block_hash).await?;
        let header = outcome.block.header.clone().into_consensus();
        *state = state.advance(header, block.anchor_block_number)?;

        info!(
            proposal_id = meta.proposal_id,
            block_number = outcome.block_number(),
            block_hash = ?outcome.block_hash(),
            "payload applied to execution engine"
        );

        self.sync_l1_origin(meta, &payload, &outcome, is_final_block).await?;

        Ok(outcome)
    }

    /// Prepare the payload attributes and anchor transaction for a manifest block without
    /// submitting it to the execution engine.
    ///
    /// The result is reused by the canonical-batch detector to avoid repeating heavy
    /// computations such as anchor assembly when we only need to validate existing blocks.
    ///
    /// `block` is final here (inherited metadata and validation already applied), so its
    /// timestamp decides the fork. An Etna block gets no anchor transaction (no golden-touch nonce
    /// query, no signature) and commits to its L1 anchor through `parentBeaconBlockRoot` instead.
    async fn prepare_block(
        &self,
        block: &BlockManifest,
        state: &ParentState,
        ctx: BlockContext<'_>,
    ) -> Result<BlockDerivationContext, DerivationError> {
        let BlockContext { meta, position } = ctx;

        let block_number = state.next_block_number();
        let is_etna = is_etna_at(state.etna_fork_timestamp, block.timestamp);
        info!(
            proposal_id = meta.proposal_id,
            block_number,
            is_etna,
            forced_inclusion = position.is_forced_inclusion(),
            transactions = block.transactions.len(),
            "processing manifest block"
        );
        let block_base_fee = state.compute_block_base_fee()?;
        let parent_mix_hash = B256::from(state.header.difficulty.to_be_bytes::<32>());
        let mix_hash = calculate_shasta_mix_hash(parent_mix_hash, block_number);

        let (anchor_tx, parent_beacon_block_root) = if is_etna {
            (None, self.resolve_etna_anchor_root(state, block.anchor_block_number).await?)
        } else {
            let anchor_inputs = AnchorTxInputs { block, block_number, block_base_fee };
            (Some(self.build_anchor_transaction(state, meta, anchor_inputs).await?), B256::ZERO)
        };

        let transactions: Vec<_> = anchor_tx.iter().chain(&block.transactions).cloned().collect();

        let parent_hash = state.header.hash_slow();

        info!(
            proposal_id = meta.proposal_id,
            block_number,
            block_base_fee,
            mix_hash = ?mix_hash,
            transaction_count = transactions.len(),
            has_anchor = anchor_tx.is_some(),
            parent_beacon_block_root = ?parent_beacon_block_root,
            parent_hash = ?parent_hash,
            "calculated block parameters"
        );

        let payload = self.create_payload_attributes(
            &transactions,
            PayloadContext {
                block,
                meta,
                block_base_fee,
                mix_hash,
                block_number,
                parent_hash,
                position,
                is_etna,
                parent_beacon_block_root,
            },
        )?;

        Ok(BlockDerivationContext {
            payload,
            anchor_tx,
            parent_hash,
            block_number,
            anchor_block_number: block.anchor_block_number,
            is_final_block: position.is_final(),
        })
    }

    /// Resolve the `parentBeaconBlockRoot` of a new non-genesis Etna block anchored to L1 block
    /// `anchor_block_number`: an Etna block commits to the state root of its L1 anchor block.
    ///
    /// A non-genesis Etna parent with the same anchor number shares its root, so it is reused
    /// without an L1 call (inherited anchors keep the parent's number/root pair). Every other
    /// case reads the state root of the L1 block by number: the first Etna block (whose pre-Etna
    /// parent has a zero root) and a child of the Etna genesis (anchor 0) always fetch. A missing
    /// parent root or a zero L1 state root is an error before any engine call.
    async fn resolve_etna_anchor_root(
        &self,
        state: &ParentState,
        anchor_block_number: u64,
    ) -> Result<B256, DerivationError> {
        if state.is_etna() &&
            state.header.number != 0 &&
            anchor_block_number == state.anchor_block_number
        {
            return match state.header.parent_beacon_block_root {
                Some(root) if !root.is_zero() => Ok(root),
                _ => Err(DerivationError::MissingEtnaParentRoot {
                    parent_block_number: state.header.number,
                }),
            };
        }

        let (_, state_root) = self.resolve_anchor_block_fields(anchor_block_number).await?;
        if state_root.is_zero() {
            return Err(DerivationError::ZeroAnchorStateRoot { block_number: anchor_block_number });
        }
        Ok(state_root)
    }

    /// Construct the `TaikoPayloadAttributes` structure that gets sent to the execution
    /// engine.
    ///
    /// The fork-dependent fields follow the block's own fork, decided by its timestamp:
    /// - the header gas limit is the manifest gas limit plus the anchor gas reserve before Etna,
    ///   and the manifest gas limit alone for an Etna block, which has no anchor transaction;
    /// - `extraData` is the 7-byte `[basefeeSharingPctg | proposalId]` before Etna, and the 13-byte
    ///   `[basefeeSharingPctg | proposalId | anchorBlockNumber]` for an Etna block;
    /// - `parentBeaconBlockRoot` is zero before Etna, and the state root of the L1 anchor block for
    ///   an Etna block.
    ///
    /// The transaction list is always explicit, so an empty block sends `0xc0`.
    fn create_payload_attributes(
        &self,
        transactions: &[TxEnvelope],
        ctx: PayloadContext<'_>,
    ) -> Result<TaikoPayloadAttributes, DerivationError> {
        let PayloadContext {
            block,
            meta,
            block_base_fee,
            mix_hash,
            block_number,
            parent_hash,
            position,
            is_etna,
            parent_beacon_block_root,
        } = ctx;
        let l1_block_hash = meta.l1_block_hash;

        let tx_list = encode_transactions(transactions);
        let extra_data = if is_etna {
            encode_etna_extra_data(
                meta.basefee_sharing_pctg,
                meta.proposal_id,
                block.anchor_block_number,
            )
            .map_err(DerivationError::EtnaExtraData)?
        } else {
            encode_extra_data(meta.basefee_sharing_pctg, meta.proposal_id)
        };

        // The manifest gas limit excludes the anchor reserve; add it back for pre-Etna blocks,
        // whose anchor transaction runs on top of the manifest budget.
        let gas_limit = block.gas_limit.saturating_add(anchor_gas_reserve(is_etna));

        let payload = build_payload_attributes_with_id(
            PayloadAttributesInput {
                beneficiary: block.coinbase,
                timestamp: block.timestamp,
                mix_hash,
                gas_limit,
                tx_list: Some(tx_list),
                extra_data,
                base_fee_per_gas: U256::from(block_base_fee),
                block_number,
                l1_block_height: Some(U256::from(meta.l1_block_number)),
                l1_block_hash: Some(l1_block_hash),
                is_forced_inclusion: position.is_forced_inclusion(),
                signature: [0u8; 65],
                // Zero before Etna (the payload fingerprint skips a zero root, so it matches the
                // V2-era value); the nonzero L1 anchor state root for an Etna block.
                parent_beacon_block_root: Some(parent_beacon_block_root),
                anchor_transaction: None,
            },
            &parent_hash,
        );

        debug!(
            l1_origin = ?payload.l1_origin,
            payload_attributes = ?payload.payload_attributes,
            "constructed payload attributes"
        );

        Ok(payload)
    }

    /// Synchronise the execution engine's L1 origin tables with the derived block metadata.
    #[instrument(
        skip(self, meta, payload, outcome),
        fields(proposal_id = meta.proposal_id, block_number = outcome.block_number(), final_block = is_final_block)
    )]
    async fn sync_l1_origin(
        &self,
        meta: &BundleMeta,
        payload: &TaikoPayloadAttributes,
        outcome: &EngineBlockOutcome,
        is_final_block: bool,
    ) -> Result<(), DerivationError> {
        let block_id = U256::from(outcome.block_number());
        let mut origin = payload.l1_origin.clone();
        origin.block_id = block_id;
        origin.l2_block_hash = outcome.block_hash();

        if let Some(existing) = self.rpc.l1_origin_by_id(block_id).await? {
            origin.signature = existing.signature;
            if existing.build_payload_args_id != [0u8; 8] {
                origin.build_payload_args_id = existing.build_payload_args_id;
            }
            origin.is_forced_inclusion |= existing.is_forced_inclusion;
        }

        self.rpc.update_l1_origin(&origin).await?;
        DriverMetrics::derivation_l1_origin_updates_total().inc();

        if is_final_block {
            self.rpc.set_head_l1_origin(block_id).await?;
            self.rpc.set_batch_to_last_block(U256::from(meta.proposal_id), block_id).await?;
            info!(
                proposal_id = meta.proposal_id,
                block_number = outcome.block_number(),
                "updated head l1 origin for final proposal block"
            );
        } else {
            debug!(
                proposal_id = meta.proposal_id,
                block_number = outcome.block_number(),
                "updated l1 origin entry"
            );
        }

        Ok(())
    }

    /// Attempt to determine whether every block in the manifest already exists in the
    /// canonical chain. When successful, returns the canonical outcomes so callers can skip
    /// payload submission and simply update L1 origin metadata.
    pub(super) async fn detect_known_canonical_proposal(
        &self,
        meta: &BundleMeta,
        sources: &[SourceManifestSegment],
        initial_state: &ParentState,
    ) -> Result<Option<Vec<KnownCanonicalBlock>>, DerivationError> {
        if sources.is_empty() {
            return Ok(None);
        }

        let mut state = initial_state.clone();
        let mut known_blocks = Vec::new();
        let segments_total = sources.len();

        for (segment_index, segment) in sources.iter().enumerate() {
            let decoded_manifest = self
                .prepare_segment_manifest(
                    segment.manifest.clone(),
                    &state,
                    meta,
                    segment_index,
                    segments_total,
                    segment.is_forced_inclusion,
                )
                .await?;
            for (block_index, block) in decoded_manifest.blocks.iter().enumerate() {
                // Reuse the same derivation inputs that would normally drive payload creation.
                let position = BlockPosition {
                    segment_index,
                    segments_total,
                    block_index,
                    blocks_len: decoded_manifest.blocks.len(),
                    forced_inclusion: segment.is_forced_inclusion,
                };
                let block_ctx = BlockContext { meta, position };
                let derived_block = self.prepare_block(block, &state, block_ctx).await?;

                // Any mismatch immediately aborts the fast-path and falls back to fresh payloads.
                let Some(verified) = self.verify_canonical_block(meta, &derived_block).await?
                else {
                    debug!(
                        proposal_id = meta.proposal_id,
                        block_number = derived_block.block_number,
                        segment_index,
                        block_index,
                        "canonical detection aborted; falling back to payload derivation"
                    );
                    return Ok(None);
                };

                // Mirror the normal derivation advance so later blocks use the correct parent.
                state = state.advance(verified.header, derived_block.anchor_block_number)?;

                known_blocks.push(KnownCanonicalBlock {
                    payload: derived_block.payload,
                    outcome: verified.outcome,
                    is_final_block: derived_block.is_final_block,
                });
            }
        }

        if known_blocks.is_empty() {
            return Ok(None);
        }

        info!(
            proposal_id = meta.proposal_id,
            block_count = known_blocks.len(),
            "proposal already present in canonical chain; skipping payload submission"
        );
        Ok(Some(known_blocks))
    }

    /// Refresh origins and forkchoice finality for a proposal already on the canonical chain.
    pub(super) async fn update_canonical_proposal_origins(
        &self,
        meta: &BundleMeta,
        blocks: &[KnownCanonicalBlock],
    ) -> Result<(), DerivationError> {
        for block in blocks {
            self.sync_l1_origin(meta, &block.payload, &block.outcome, block.is_final_block).await?;
        }
        self.refresh_finalized_forkchoice(meta.last_finalized_proposal_id).await
    }

    /// Advance finality without rebuilding known blocks or rewinding the current unsafe head.
    ///
    /// Missing checkpoint metadata is non-blocking. Replay never lowers finalized, and RPC or
    /// engine failures propagate so the canonical proposal can be retried.
    async fn refresh_finalized_forkchoice(
        &self,
        last_finalized_proposal_id: Option<u64>,
    ) -> Result<(), DerivationError> {
        let Some(checkpoint) = self.finalized_block_for(last_finalized_proposal_id).await? else {
            return Ok(());
        };
        let finalized =
            match self.rpc.l2_provider.get_block_by_number(BlockNumberOrTag::Finalized).await {
                Ok(block) => block,
                Err(err)
                    if err.as_error_resp().is_some_and(|payload| {
                        is_finalized_block_not_found(payload.code, payload.message.as_ref())
                    }) =>
                {
                    None
                }
                Err(err) => return Err(err.into()),
            };
        if finalized.is_some_and(|block| block.header.number >= checkpoint.number) {
            return Ok(());
        }
        let head =
            self.rpc.l2_provider.get_block_by_number(BlockNumberOrTag::Latest).await?.ok_or_else(
                || anyhow::anyhow!("missing execution head for finalized forkchoice update"),
            )?;
        let state = ForkchoiceState {
            head_block_hash: head.header.hash,
            safe_block_hash: checkpoint.hash,
            finalized_block_hash: checkpoint.hash,
        };
        let response = self.rpc.engine_forkchoice_updated_v3(state, None).await?;
        ensure_valid_forkchoice_status(head.header.number, response.payload_status.status)?;
        Ok(())
    }

    /// Verify that a derived block matches the canonical execution block at the same height.
    ///
    /// The fork is keyed on the derived block's timestamp. A pre-Etna block must start with the
    /// derived anchor transaction and carry a zero root. An Etna block has no anchor (tx 0 is an
    /// ordinary transaction and the block may be empty with zero difficulty) and its header must
    /// carry the derived anchor root.
    ///
    /// Beyond a pre-Etna block's anchor, the body is never compared with the derived transaction
    /// list. The execution engine's builder skips transactions it cannot include (a bad nonce or
    /// balance, an unsupported type, everything after the zk gas runs out), so a canonical body
    /// can be a strict, ordered subset of the derived list; requiring equality would re-insert
    /// the block and reorg every later block, preconfirmed ones included. As for pre-Etna user
    /// transactions, the binding is the stored nonzero payload fingerprint, required for every
    /// fork: it hashes keccak(txList) together with the root, `extraData`, timestamp, prevRandao,
    /// coinbase and parent. The stored origin must also name the canonical block's hash: the
    /// engine writes the origin as soon as a build finishes, before the block is inserted, so a
    /// build interrupted before promotion leaves a matching fingerprint over another canonical
    /// block.
    async fn verify_canonical_block(
        &self,
        meta: &BundleMeta,
        derived_block: &BlockDerivationContext,
    ) -> Result<Option<VerifiedCanonicalBlock>, DerivationError> {
        let block_id = derived_block.block_number;
        let payload_id = PayloadId::new(derived_block.payload.l1_origin.build_payload_args_id);
        let is_etna = is_etna_at(
            self.etna_fork_timestamp,
            derived_block.payload.payload_attributes.timestamp,
        );

        // Start by comparing payload IDs against the L1 origin record set during the first
        // derivation attempt.
        let Some(origin) = self.rpc.l1_origin_by_id(U256::from(block_id)).await? else {
            debug!(
                proposal_id = meta.proposal_id,
                block_id, "missing L1 origin for block; falling back to payload derivation"
            );
            return Ok(None);
        };

        if origin.build_payload_args_id == [0u8; 8] {
            debug!(
                proposal_id = meta.proposal_id,
                block_id, "origin missing payload args id; cannot confirm canonical proposal"
            );
            return Ok(None);
        }

        if origin.build_payload_args_id != derived_block.payload.l1_origin.build_payload_args_id {
            warn!(
                proposal_id = meta.proposal_id,
                block_id,
                origin_payload_id = %PayloadId::new(origin.build_payload_args_id),
                expected_payload_id = %payload_id,
                "payload id mismatch when checking canonical proposal"
            );
            return Ok(None);
        }

        // Fetch the canonical execution block and ensure we have full transaction bodies.
        let Some(block) = self
            .rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Number(block_id))
            .full()
            .await?
            .map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
        else {
            debug!(
                proposal_id = meta.proposal_id,
                block_id, "missing canonical block while checking batch"
            );
            return Ok(None);
        };

        if origin.l2_block_hash != block.header.hash {
            warn!(
                proposal_id = meta.proposal_id,
                block_id,
                origin_block_hash = ?origin.l2_block_hash,
                canonical_block_hash = ?block.header.hash,
                "stored L1 origin names another block when checking canonical proposal"
            );
            return Ok(None);
        }

        let Some(txs) = block.transactions.as_transactions() else {
            debug!(
                proposal_id = meta.proposal_id,
                block_id, "canonical block only exposed transaction hashes"
            );
            return Ok(None);
        };

        // An Etna block has no anchor transaction to compare: its tx 0 is ordinary (possibly
        // anchor-shaped calldata from any sender) and the block may be empty.
        if !is_etna {
            let Some(anchor_tx) = derived_block.anchor_tx.as_ref() else {
                debug!(
                    proposal_id = meta.proposal_id,
                    block_id, "derived pre-Etna block has no anchor transaction"
                );
                return Ok(None);
            };

            let Some(first_tx) = txs.first() else {
                debug!(
                    proposal_id = meta.proposal_id,
                    block_id, "canonical block missing transactions"
                );
                return Ok(None);
            };

            if first_tx != anchor_tx {
                warn!(
                    proposal_id = meta.proposal_id,
                    block_id, "anchor transaction mismatch when confirming canonical block"
                );
                return Ok(None);
            }
        }

        if block.header.parent_hash != derived_block.parent_hash {
            debug!(
                proposal_id = meta.proposal_id,
                block_id,
                canonical_parent = ?block.header.parent_hash,
                expected_parent = ?derived_block.parent_hash,
                "parent hash mismatch when confirming canonical block"
            );
            return Ok(None);
        }

        let empty_ommers_hash = keccak256([0xc0u8]);
        if block.header.ommers_hash != empty_ommers_hash {
            debug!(proposal_id = meta.proposal_id, block_id, "ommers hash mismatch");
            return Ok(None);
        }

        if block.header.beneficiary !=
            derived_block.payload.payload_attributes.suggested_fee_recipient
        {
            debug!(proposal_id = meta.proposal_id, block_id, "coinbase mismatch");
            return Ok(None);
        }

        let unzen_active = unzen_active_for_chain_timestamp(self.chain_id, block.header.timestamp)
            .map_err(|err| DerivationError::Other(err.into()))?;

        if unzen_active {
            // The difficulty is the block's zk gas: an empty Etna block has none.
            if !is_etna && block.header.difficulty == U256::ZERO {
                debug!(proposal_id = meta.proposal_id, block_id, "difficulty zero during Unzen");
                return Ok(None);
            }

            if block.header.blob_gas_used != Some(0) {
                debug!(proposal_id = meta.proposal_id, block_id, "blob gas used mismatch");
                return Ok(None);
            }

            if block.header.excess_blob_gas != Some(0) {
                debug!(proposal_id = meta.proposal_id, block_id, "excess blob gas mismatch");
                return Ok(None);
            }

            // Before Etna the root is zero; an Etna block carries the nonzero derived anchor root.
            let expected_root = if is_etna {
                derived_block
                    .payload
                    .payload_attributes
                    .parent_beacon_block_root
                    .filter(|root| !root.is_zero())
            } else {
                Some(B256::ZERO)
            };
            if expected_root.is_none() || block.header.parent_beacon_block_root != expected_root {
                debug!(
                    proposal_id = meta.proposal_id,
                    block_id,
                    is_etna,
                    canonical_root = ?block.header.parent_beacon_block_root,
                    expected_root = ?expected_root,
                    "parent beacon root mismatch"
                );
                return Ok(None);
            }

            if block.header.requests_hash != Some(EMPTY_REQUESTS_HASH) {
                debug!(proposal_id = meta.proposal_id, block_id, "requests hash mismatch");
                return Ok(None);
            }
        } else {
            if block.header.difficulty != U256::ZERO {
                debug!(proposal_id = meta.proposal_id, block_id, "difficulty non-zero");
                return Ok(None);
            }

            if block.header.blob_gas_used.is_some() {
                debug!(proposal_id = meta.proposal_id, block_id, "unexpected blob gas used");
                return Ok(None);
            }

            if block.header.excess_blob_gas.is_some() {
                debug!(proposal_id = meta.proposal_id, block_id, "unexpected excess blob gas");
                return Ok(None);
            }

            if block.header.parent_beacon_block_root.is_some() {
                debug!(
                    proposal_id = meta.proposal_id,
                    block_id, "unexpected parent beacon root before Unzen"
                );
                return Ok(None);
            }

            if block.header.requests_hash.is_some() {
                debug!(
                    proposal_id = meta.proposal_id,
                    block_id, "unexpected requests hash before Unzen"
                );
                return Ok(None);
            }
        }

        if block.header.mix_hash != derived_block.payload.payload_attributes.prev_randao {
            debug!(proposal_id = meta.proposal_id, block_id, "mix digest mismatch");
            return Ok(None);
        }

        if block.header.number != block_id {
            debug!(
                proposal_id = meta.proposal_id,
                block_id,
                canonical = block.header.number,
                "block number mismatch"
            );
            return Ok(None);
        }

        if block.header.gas_limit != derived_block.payload.block_metadata.gas_limit {
            debug!(proposal_id = meta.proposal_id, block_id, "gas limit mismatch");
            return Ok(None);
        }

        if block.header.timestamp != derived_block.payload.payload_attributes.timestamp {
            debug!(proposal_id = meta.proposal_id, block_id, "timestamp mismatch");
            return Ok(None);
        }

        if block.header.extra_data != derived_block.payload.block_metadata.extra_data {
            debug!(proposal_id = meta.proposal_id, block_id, "extra data mismatch");
            return Ok(None);
        }

        match block.header.base_fee_per_gas {
            Some(base_fee) if U256::from(base_fee) == derived_block.payload.base_fee_per_gas => {}
            _ => {
                debug!(proposal_id = meta.proposal_id, block_id, "base fee mismatch");
                return Ok(None);
            }
        }

        // Shasta derivation currently produces empty withdrawal lists, so any non-empty value is
        // a strong indicator the block does not belong to this proposal.
        if block.withdrawals.as_ref().is_some_and(|w| !w.is_empty()) {
            debug!(
                proposal_id = meta.proposal_id,
                block_id, "withdrawals present in canonical block"
            );
            return Ok(None);
        }

        // Treat the canonical block as if it just came back from the execution engine so the rest
        // of the pipeline (metrics, L1 origin sync, etc.) can reuse existing code paths.
        let outcome = EngineBlockOutcome { block: block.clone(), payload_id };
        let header = block.header.inner.clone();

        Ok(Some(VerifiedCanonicalBlock { outcome, header }))
    }

    /// Build the anchor transaction for the provided manifest block.
    #[instrument(skip(self, parent_state, meta, inputs))]
    async fn build_anchor_transaction(
        &self,
        parent_state: &ParentState,
        meta: &BundleMeta,
        inputs: AnchorTxInputs<'_>,
    ) -> Result<TxEnvelope, DerivationError> {
        let AnchorTxInputs { block, block_number, block_base_fee } = inputs;

        let (anchor_block_hash, anchor_state_root) =
            self.resolve_anchor_block_fields(block.anchor_block_number).await?;
        info!(
            proposal_id = meta.proposal_id,
            block_number,
            anchor_block = block.anchor_block_number,
            anchor_block_hash = ?anchor_block_hash,
            parent_hash = ?parent_state.header.hash_slow(),
            "building anchorV4 transaction"
        );

        let tx = self
            .anchor_constructor
            .assemble_anchor_v4_tx(
                parent_state.header.hash_slow(),
                AnchorV4Input {
                    anchor_block_number: block.anchor_block_number,
                    anchor_block_hash,
                    anchor_state_root,
                    l2_height: block_number,
                    base_fee: U256::from(block_base_fee),
                },
            )
            .await?;

        Ok(tx)
    }

    /// Resolve anchor block hash and state root from L1.
    #[instrument(skip(self), fields(anchor_block_number))]
    async fn resolve_anchor_block_fields(
        &self,
        anchor_block_number: u64,
    ) -> Result<(B256, B256), DerivationError> {
        tracing::Span::current().record("anchor_block_number", anchor_block_number as i64);
        let block = self
            .rpc
            .l1_provider
            .get_block_by_number(BlockNumberOrTag::Number(anchor_block_number))
            .await
            .map_err(|err| DerivationError::AnchorBlockQuery {
                block_number: anchor_block_number,
                reason: err.to_string(),
            })?
            .ok_or(DerivationError::AnchorBlockMissing { block_number: anchor_block_number })?;

        debug!(
            anchor_block_number,
            hash = ?block.header.hash,
            "resolved anchor block fields"
        );
        Ok((block.header.hash, block.header.inner.state_root))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alethia_reth_consensus::anchor_constants::anchorV4Call;
    use alethia_reth_primitives::{
        addresses::TAIKO_GOLDEN_TOUCH_ADDRESS, payload::attributes::RpcL1Origin,
    };
    use alloy::{
        rpc::types::eth::{Block as RpcBlock, BlockTransactions},
        sol_types::SolCall,
    };
    use alloy_consensus::{
        EthereumTypedTransaction, SignableTransaction, TxEip1559, TxEnvelope,
        transaction::Recovered,
    };
    use alloy_eips::eip2930::AccessList;
    use alloy_primitives::{Bytes, Signature, TxKind};
    use alloy_transport::mock::Asserter;
    use anyhow::Result;

    use alethia_reth_consensus::validation::ANCHOR_V3_V4_GAS_LIMIT;
    use bindings::anchor::ICheckpointStore::Checkpoint;
    use protocol::{
        FixedKSigner,
        shasta::constants::{TAIKO_DEVNET_CHAIN_ID, min_base_fee_for_chain},
    };

    use super::super::sample_meta;
    use crate::test_support::mock_client_with_asserters;

    /// Anchor contract address bound into every test pipeline.
    fn anchor_address() -> Address {
        Address::repeat_byte(0x44)
    }

    /// Non-genesis parent block 6 at timestamp 1_000 (30M gas) anchored to L1 block 50, carrying
    /// `root` as its `parentBeaconBlockRoot`.
    fn sample_parent_state(etna_fork_timestamp: Option<u64>, root: Option<B256>) -> ParentState {
        ParentState {
            header: Header {
                number: 6,
                timestamp: 1_000,
                gas_limit: 30_000_000,
                base_fee_per_gas: Some(10_000_000),
                difficulty: U256::from(1u64),
                parent_beacon_block_root: root,
                ..Default::default()
            },
            anchor_block_number: 50,
            parent_block_time_delta_secs: 12,
            shasta_fork_timestamp: 0,
            min_base_fee_to_clamp: min_base_fee_for_chain(TAIKO_DEVNET_CHAIN_ID),
            chain_id: TAIKO_DEVNET_CHAIN_ID,
            etna_fork_timestamp,
        }
    }

    /// Position of the only block of a single-segment proposal.
    fn final_position() -> BlockPosition {
        BlockPosition {
            segment_index: 0,
            segments_total: 1,
            block_index: 0,
            blocks_len: 1,
            forced_inclusion: false,
        }
    }

    /// Manifest block with a 29M manifest gas limit.
    fn manifest_block(
        timestamp: u64,
        anchor_block_number: u64,
        transactions: Vec<TxEnvelope>,
    ) -> BlockManifest {
        BlockManifest {
            timestamp,
            coinbase: Address::repeat_byte(0x33),
            anchor_block_number,
            gas_limit: 29_000_000,
            transactions,
        }
    }

    /// Ordinary signed user transaction calling `to` with `input`.
    fn user_tx(nonce: u64, to: Address, input: Bytes) -> TxEnvelope {
        let tx = TxEip1559 {
            chain_id: TAIKO_DEVNET_CHAIN_ID,
            nonce,
            max_fee_per_gas: 1_000_000_000,
            max_priority_fee_per_gas: 1,
            gas_limit: 21_000,
            to: TxKind::Call(to),
            value: U256::ZERO,
            access_list: AccessList::default(),
            input,
        };
        let sighash = tx.signature_hash();
        TxEnvelope::new_unchecked(
            EthereumTypedTransaction::Eip1559(tx),
            Signature::test_signature(),
            sighash,
        )
    }

    /// L1 mock answering one by-number header lookup for `number` with `state_root`.
    fn l1_anchor_block(number: u64, state_root: B256) -> Asserter {
        let l1_asserter = Asserter::new();
        let mut anchor_block = RpcBlock::<TxEnvelope>::default();
        anchor_block.header.hash = B256::with_last_byte(0xbb);
        anchor_block.header.inner.number = number;
        anchor_block.header.inner.state_root = state_root;
        l1_asserter.push_success(&Some(anchor_block));
        l1_asserter
    }

    /// L2 mock pre-loaded with the anchor constructor's chain-id probe. Nothing else is scripted,
    /// so any golden-touch nonce query (anchor assembly) fails the test.
    fn l2_with_chain_id() -> Asserter {
        let l2_asserter = Asserter::new();
        l2_asserter.push_success(&TAIKO_DEVNET_CHAIN_ID);
        l2_asserter
    }

    /// Devnet pipeline over the given mocks with Etna at `etna_fork_timestamp`.
    async fn pipeline_with(
        l1_asserter: Asserter,
        l2_asserter: Asserter,
        etna_fork_timestamp: Option<u64>,
    ) -> ShastaDerivationPipeline {
        let client =
            mock_client_with_asserters(l1_asserter, l2_asserter, Asserter::new(), anchor_address());
        super::super::test_pipeline(
            client,
            anchor_address(),
            TAIKO_DEVNET_CHAIN_ID,
            etna_fork_timestamp,
        )
        .await
    }

    /// Prepare `block` on `state` for proposal [`sample_meta`].
    async fn prepare(
        pipeline: &ShastaDerivationPipeline,
        block: &BlockManifest,
        state: &ParentState,
    ) -> Result<BlockDerivationContext, DerivationError> {
        let meta = sample_meta();
        pipeline
            .prepare_block(block, state, BlockContext { meta: &meta, position: final_position() })
            .await
    }

    #[tokio::test]
    async fn etna_block_drops_the_anchor_and_commits_to_the_l1_state_root() {
        let state_root = B256::with_last_byte(0x55);
        let l1_asserter = l1_anchor_block(55, state_root);
        let l2_asserter = l2_with_chain_id();
        let pipeline = pipeline_with(l1_asserter.clone(), l2_asserter.clone(), Some(1_001)).await;
        let user_txs = vec![
            user_tx(0, Address::repeat_byte(0x01), Bytes::new()),
            user_tx(1, Address::repeat_byte(0x02), Bytes::from_static(&[0xde, 0xad])),
        ];

        // First Etna block on an Unzen parent (zero root, anchor 50).
        let derived = prepare(
            &pipeline,
            &manifest_block(1_001, 55, user_txs.clone()),
            &sample_parent_state(Some(1_001), Some(B256::ZERO)),
        )
        .await
        .expect("the Etna block prepares");

        assert!(derived.anchor_tx.is_none());
        let attributes = &derived.payload;
        assert_eq!(attributes.payload_attributes.parent_beacon_block_root, Some(state_root));
        assert_eq!(attributes.block_metadata.tx_list, Some(encode_transactions(&user_txs)));
        assert_eq!(attributes.block_metadata.gas_limit, 29_000_000, "no anchor reserve");
        assert_eq!(
            attributes.block_metadata.extra_data,
            encode_etna_extra_data(75, 3, 55).expect("extraData should encode")
        );
        assert_eq!(attributes.block_metadata.extra_data.len(), 13);
        assert_eq!(derived.anchor_block_number, 55);
        assert!(l1_asserter.read_q().is_empty(), "the anchor block header was read by number");
        assert!(l2_asserter.read_q().is_empty());
    }

    #[tokio::test]
    async fn empty_etna_block_sends_an_explicit_empty_list() {
        let pipeline = pipeline_with(
            l1_anchor_block(55, B256::with_last_byte(0x55)),
            l2_with_chain_id(),
            Some(1_001),
        )
        .await;

        let derived = prepare(
            &pipeline,
            &manifest_block(1_001, 55, Vec::new()),
            &sample_parent_state(Some(1_001), Some(B256::ZERO)),
        )
        .await
        .expect("the empty Etna block prepares");

        assert_eq!(
            derived.payload.block_metadata.tx_list.as_ref().map(|list| list.as_ref()),
            Some(&[0xc0u8][..]),
            "an empty Etna block sends an explicit empty list, never a mempool request"
        );
    }

    #[tokio::test]
    async fn etna_block_reuses_the_root_of_an_etna_parent_with_the_same_anchor() {
        let parent_root = B256::with_last_byte(0xaa);
        // The empty L1 mock fails any anchor header lookup.
        let pipeline = pipeline_with(Asserter::new(), l2_with_chain_id(), Some(900)).await;

        let derived = prepare(
            &pipeline,
            &manifest_block(1_001, 50, Vec::new()),
            &sample_parent_state(Some(900), Some(parent_root)),
        )
        .await
        .expect("the Etna block reuses its parent's root");

        assert_eq!(derived.payload.payload_attributes.parent_beacon_block_root, Some(parent_root));
        assert_eq!(
            derived.payload.block_metadata.extra_data,
            encode_etna_extra_data(75, 3, 50).expect("extraData should encode")
        );
    }

    #[tokio::test]
    async fn etna_block_fetches_the_l1_root_when_its_anchor_moves_past_the_parent() {
        let state_root = B256::with_last_byte(0x55);
        let l1_asserter = l1_anchor_block(55, state_root);
        let pipeline = pipeline_with(l1_asserter.clone(), l2_with_chain_id(), Some(900)).await;

        let derived = prepare(
            &pipeline,
            &manifest_block(1_001, 55, Vec::new()),
            &sample_parent_state(Some(900), Some(B256::with_last_byte(0xaa))),
        )
        .await
        .expect("the Etna block prepares");

        assert_eq!(derived.payload.payload_attributes.parent_beacon_block_root, Some(state_root));
        assert!(l1_asserter.read_q().is_empty());
    }

    #[tokio::test]
    async fn first_etna_block_fetches_the_l1_root_even_for_the_parent_anchor() {
        // The Unzen parent also anchors to 50 but its root is zero: it is never reused.
        let state_root = B256::with_last_byte(0x50);
        let l1_asserter = l1_anchor_block(50, state_root);
        let pipeline = pipeline_with(l1_asserter.clone(), l2_with_chain_id(), Some(1_001)).await;

        let derived = prepare(
            &pipeline,
            &manifest_block(1_001, 50, Vec::new()),
            &sample_parent_state(Some(1_001), Some(B256::ZERO)),
        )
        .await
        .expect("the first Etna block prepares");

        assert_eq!(derived.payload.payload_attributes.parent_beacon_block_root, Some(state_root));
        assert!(l1_asserter.read_q().is_empty());
    }

    #[tokio::test]
    async fn etna_block_on_the_etna_genesis_fetches_l1_block_zero() {
        let state_root = B256::with_last_byte(0x01);
        let l1_asserter = l1_anchor_block(0, state_root);
        let pipeline = pipeline_with(l1_asserter.clone(), l2_with_chain_id(), Some(0)).await;
        let mut genesis = sample_parent_state(Some(0), Some(B256::ZERO));
        genesis.header.number = 0;
        genesis.header.timestamp = 0;
        genesis.anchor_block_number = 0;

        let derived = prepare(&pipeline, &manifest_block(12, 0, Vec::new()), &genesis)
            .await
            .expect("block 1 on an Etna genesis prepares");

        assert_eq!(derived.payload.payload_attributes.parent_beacon_block_root, Some(state_root));
        assert!(l1_asserter.read_q().is_empty());
    }

    #[tokio::test]
    async fn etna_block_rejects_a_zero_l1_state_root() {
        let pipeline =
            pipeline_with(l1_anchor_block(55, B256::ZERO), l2_with_chain_id(), Some(1_001)).await;

        let err = prepare(
            &pipeline,
            &manifest_block(1_001, 55, Vec::new()),
            &sample_parent_state(Some(1_001), Some(B256::ZERO)),
        )
        .await
        .expect_err("a zero anchor root never reaches the engine");

        assert!(
            matches!(err, DerivationError::ZeroAnchorStateRoot { block_number: 55 }),
            "unexpected error: {err:?}"
        );
    }

    #[tokio::test]
    async fn etna_block_rejects_an_etna_parent_without_a_root_to_reuse() {
        for parent_root in [None, Some(B256::ZERO)] {
            let pipeline = pipeline_with(Asserter::new(), l2_with_chain_id(), Some(900)).await;

            let err = prepare(
                &pipeline,
                &manifest_block(1_001, 50, Vec::new()),
                &sample_parent_state(Some(900), parent_root),
            )
            .await
            .expect_err("an Etna parent must carry the root it shares");

            assert!(
                matches!(err, DerivationError::MissingEtnaParentRoot { parent_block_number: 6 }),
                "unexpected error: {err:?}"
            );
        }
    }

    #[tokio::test]
    async fn pre_etna_block_keeps_the_anchor_the_reserve_and_a_zero_root() {
        let l2_asserter = l2_with_chain_id();
        l2_asserter.push_success(&U256::ZERO); // golden-touch nonce at the parent
        let pipeline = pipeline_with(
            l1_anchor_block(55, B256::with_last_byte(0x55)),
            l2_asserter.clone(),
            Some(2_000),
        )
        .await;
        let user_txs = vec![user_tx(0, Address::repeat_byte(0x01), Bytes::new())];

        let derived = prepare(
            &pipeline,
            &manifest_block(1_001, 55, user_txs.clone()),
            &sample_parent_state(Some(2_000), Some(B256::ZERO)),
        )
        .await
        .expect("the pre-Etna block prepares");

        let anchor_tx = derived.anchor_tx.clone().expect("a pre-Etna block has an anchor");
        let attributes = &derived.payload;
        assert_eq!(attributes.payload_attributes.parent_beacon_block_root, Some(B256::ZERO));
        assert_eq!(
            attributes.block_metadata.tx_list,
            Some(encode_transactions(&[vec![anchor_tx], user_txs].concat()))
        );
        assert_eq!(attributes.block_metadata.gas_limit, 29_000_000 + ANCHOR_V3_V4_GAS_LIMIT);
        assert_eq!(attributes.block_metadata.extra_data, encode_extra_data(75, 3));
        assert!(l2_asserter.read_q().is_empty(), "the anchor nonce was read");
    }

    #[test]
    fn anchor_signature_recovers_to_golden_touch() -> Result<()> {
        let signer = FixedKSigner::golden_touch()?;
        let anchor_address = Address::repeat_byte(0x11);

        let tx = TxEip1559 {
            chain_id: 167,
            nonce: 0,
            max_fee_per_gas: 1_000_000_000,
            max_priority_fee_per_gas: 0,
            gas_limit: ANCHOR_V3_V4_GAS_LIMIT,
            to: TxKind::Call(anchor_address),
            value: U256::ZERO,
            access_list: AccessList::default(),
            input: Bytes::from(vec![0u8; 4]),
        };

        let sighash = tx.signature_hash();
        let mut hash_bytes = [0u8; 32];
        hash_bytes.copy_from_slice(sighash.as_slice());
        let signature = signer.sign_with_predefined_k(&hash_bytes)?;

        let envelope = TxEnvelope::new_unchecked(
            EthereumTypedTransaction::Eip1559(tx),
            signature.signature,
            sighash,
        );

        let TxEnvelope::Eip1559(signed) = &envelope else {
            panic!("expected eip1559 envelope");
        };

        let recovered = signed.recover_signer()?;
        assert_eq!(recovered, Address::from(TAIKO_GOLDEN_TOUCH_ADDRESS));
        Ok(())
    }

    /// Etna activation used by the canonical-detection tests.
    const CANONICAL_ETNA_TIMESTAMP: u64 = 1_000;

    /// Derived block 7 on parent `0x…06` at `timestamp` with `transactions` after the optional
    /// anchor, built the way `prepare_block` builds it for the block's fork.
    fn derived_block(
        timestamp: u64,
        root: B256,
        anchor_tx: Option<TxEnvelope>,
        transactions: &[TxEnvelope],
    ) -> BlockDerivationContext {
        let is_etna = anchor_tx.is_none();
        let parent_hash = B256::with_last_byte(0x06);
        let all_transactions = anchor_tx.iter().chain(transactions).cloned().collect::<Vec<_>>();
        let payload = build_payload_attributes_with_id(
            PayloadAttributesInput {
                beneficiary: Address::repeat_byte(0x33),
                timestamp,
                mix_hash: B256::with_last_byte(0x03),
                gas_limit: 29_000_000 + anchor_gas_reserve(is_etna),
                tx_list: Some(encode_transactions(&all_transactions)),
                extra_data: if is_etna {
                    encode_etna_extra_data(75, 3, 55).expect("extraData should encode")
                } else {
                    encode_extra_data(75, 3)
                },
                base_fee_per_gas: U256::from(10_000_000u64),
                block_number: 7,
                l1_block_height: Some(U256::from(60u64)),
                l1_block_hash: Some(B256::with_last_byte(0x60)),
                is_forced_inclusion: false,
                signature: [0u8; 65],
                parent_beacon_block_root: Some(root),
                anchor_transaction: None,
            },
            &parent_hash,
        );
        BlockDerivationContext {
            payload,
            anchor_tx,
            parent_hash,
            block_number: 7,
            anchor_block_number: 55,
            is_final_block: true,
        }
    }

    /// Hash of every canonical block built by [`canonical_block`].
    const CANONICAL_BLOCK_HASH: B256 = B256::repeat_byte(0x07);

    /// Canonical Unzen-shaped block matching `derived` field by field, with the given header root,
    /// difficulty and body.
    fn canonical_block(
        derived: &BlockDerivationContext,
        root: Option<B256>,
        difficulty: u64,
        transactions: &[TxEnvelope],
    ) -> RpcBlock<RpcTransaction> {
        let payload = &derived.payload;
        let mut block = RpcBlock::<RpcTransaction>::default();
        block.header.hash = CANONICAL_BLOCK_HASH;
        block.header.inner.parent_hash = derived.parent_hash;
        block.header.inner.ommers_hash = keccak256([0xc0u8]);
        block.header.inner.beneficiary = payload.payload_attributes.suggested_fee_recipient;
        block.header.inner.difficulty = U256::from(difficulty);
        block.header.inner.blob_gas_used = Some(0);
        block.header.inner.excess_blob_gas = Some(0);
        block.header.inner.parent_beacon_block_root = root;
        block.header.inner.requests_hash = Some(EMPTY_REQUESTS_HASH);
        block.header.inner.mix_hash = payload.payload_attributes.prev_randao;
        block.header.inner.number = derived.block_number;
        block.header.inner.gas_limit = payload.block_metadata.gas_limit;
        block.header.inner.timestamp = payload.payload_attributes.timestamp;
        block.header.inner.extra_data = payload.block_metadata.extra_data.clone();
        block.header.inner.base_fee_per_gas = Some(payload.base_fee_per_gas.to::<u64>());
        block.transactions = BlockTransactions::Full(
            transactions
                .iter()
                .map(|tx| RpcTransaction {
                    inner: Recovered::new_unchecked(tx.clone(), Address::repeat_byte(0x99)),
                    block_hash: None,
                    block_number: None,
                    transaction_index: None,
                    effective_gas_price: None,
                })
                .collect(),
        );
        block.withdrawals = Some(Default::default());
        block
    }

    /// L1 origin the engine stores for `derived` once its build produced the block `block_hash`.
    fn stored_origin(derived: &BlockDerivationContext, block_hash: B256) -> RpcL1Origin {
        let mut origin = derived.payload.l1_origin.clone();
        origin.l2_block_hash = block_hash;
        origin
    }

    /// Verify `derived` against `canonical` with `origin` stored, on a devnet pipeline with Etna
    /// at [`CANONICAL_ETNA_TIMESTAMP`].
    async fn verify_with_origin(
        derived: &BlockDerivationContext,
        origin: RpcL1Origin,
        canonical: RpcBlock<RpcTransaction>,
    ) -> Option<VerifiedCanonicalBlock> {
        let l2_asserter = l2_with_chain_id();
        l2_asserter.push_success(&Some(origin));
        l2_asserter.push_success(&Some(canonical));
        let pipeline =
            pipeline_with(Asserter::new(), l2_asserter, Some(CANONICAL_ETNA_TIMESTAMP)).await;
        pipeline.verify_canonical_block(&sample_meta(), derived).await.expect("checks run")
    }

    /// Verify `derived` against `canonical`, with the origin the engine stored when it built
    /// `canonical` from `derived`.
    async fn verify_against(
        derived: &BlockDerivationContext,
        canonical: RpcBlock<RpcTransaction>,
    ) -> Option<VerifiedCanonicalBlock> {
        let origin = stored_origin(derived, canonical.header.hash);
        verify_with_origin(derived, origin, canonical).await
    }

    /// Ordinary transaction whose calldata is a well-formed `anchorV4` call to the anchor.
    fn anchor_shaped_user_tx() -> TxEnvelope {
        let checkpoint = Checkpoint {
            blockNumber: alloy_primitives::aliases::U48::from(999u64),
            blockHash: B256::with_last_byte(0x22),
            stateRoot: B256::with_last_byte(0x33),
        };
        user_tx(0, anchor_address(), Bytes::from(anchorV4Call(checkpoint.into()).abi_encode()))
    }

    #[tokio::test]
    async fn empty_etna_block_with_the_derived_root_and_zero_difficulty_is_canonical() {
        let root = B256::with_last_byte(0x55);
        let derived = derived_block(1_001, root, None, &[]);

        let verified =
            verify_against(&derived, canonical_block(&derived, Some(root), 0, &[])).await;

        assert!(verified.is_some(), "no anchor and zero difficulty are expected for Etna");
    }

    #[tokio::test]
    async fn etna_block_with_an_anchor_shaped_first_transaction_is_canonical() {
        let root = B256::with_last_byte(0x55);
        let transactions =
            vec![anchor_shaped_user_tx(), user_tx(1, Address::repeat_byte(0x01), Bytes::new())];
        let derived = derived_block(1_001, root, None, &transactions);

        let verified =
            verify_against(&derived, canonical_block(&derived, Some(root), 42, &transactions))
                .await;

        assert!(verified.is_some(), "tx 0 of an Etna block is an ordinary transaction");
    }

    /// The engine's builder skips derived transactions it cannot include, so a canonical Etna
    /// body may be any ordered subset of the derived list (including none of it); the matching
    /// stored fingerprint and root still make the block canonical.
    #[tokio::test]
    async fn etna_block_whose_body_skips_derived_transactions_is_canonical() {
        let root = B256::with_last_byte(0x55);
        let transactions = vec![
            user_tx(0, Address::repeat_byte(0x01), Bytes::new()),
            user_tx(1, Address::repeat_byte(0x02), Bytes::new()),
            user_tx(2, Address::repeat_byte(0x03), Bytes::new()),
        ];
        let derived = derived_block(1_001, root, None, &transactions);

        for (body, difficulty) in [
            (vec![transactions[0].clone(), transactions[2].clone()], 42),
            (vec![transactions[0].clone()], 42),
            (Vec::new(), 0),
        ] {
            let verified =
                verify_against(&derived, canonical_block(&derived, Some(root), difficulty, &body))
                    .await;
            assert!(verified.is_some(), "a body of {} derived txs must stay canonical", body.len());
        }
    }

    /// The stored fingerprint is what binds an Etna body: a block whose L1 origin records another
    /// (or no) payload ID is not canonical, even with a matching header.
    #[tokio::test]
    async fn etna_block_with_another_or_no_stored_fingerprint_is_not_canonical() {
        let root = B256::with_last_byte(0x55);
        let transactions = vec![user_tx(0, Address::repeat_byte(0x01), Bytes::new())];
        let derived = derived_block(1_001, root, None, &transactions);
        let other_list = derived_block(1_001, root, None, &[]);

        for stored_id in [other_list.payload.l1_origin.build_payload_args_id, [0u8; 8]] {
            let mut origin = stored_origin(&derived, CANONICAL_BLOCK_HASH);
            origin.build_payload_args_id = stored_id;
            let canonical = canonical_block(&derived, Some(root), 42, &transactions);

            let verified = verify_with_origin(&derived, origin, canonical).await;
            assert!(verified.is_none(), "stored payload ID {stored_id:?} must not match");
        }
    }

    /// The engine stores the origin of a build before the built block is inserted. If the driver
    /// stops between the two, the canonical block at that height can be another one with the same
    /// header fields (e.g. a preconfirmed block built from another list): the stored fingerprint
    /// then matches the derived one, but the origin names the unpromoted build, not this block.
    #[tokio::test]
    async fn block_whose_stored_origin_names_another_build_is_not_canonical() {
        let root = B256::with_last_byte(0x55);
        let derived_list = vec![user_tx(0, Address::repeat_byte(0x01), Bytes::new())];
        let preconfirmed_list = vec![user_tx(0, Address::repeat_byte(0x02), Bytes::new())];
        let derived = derived_block(1_001, root, None, &derived_list);
        let preconfirmed = canonical_block(&derived, Some(root), 42, &preconfirmed_list);

        for origin_hash in [B256::repeat_byte(0x08), B256::ZERO] {
            let origin = stored_origin(&derived, origin_hash);
            let verified = verify_with_origin(&derived, origin, preconfirmed.clone()).await;
            assert!(verified.is_none(), "an origin naming {origin_hash} must not match");
        }

        let anchor_tx = anchor_shaped_user_tx();
        let derived = derived_block(999, B256::ZERO, Some(anchor_tx.clone()), &derived_list);
        let preconfirmed = canonical_block(
            &derived,
            Some(B256::ZERO),
            42,
            &[vec![anchor_tx], preconfirmed_list].concat(),
        );
        let origin = stored_origin(&derived, B256::repeat_byte(0x08));
        assert!(
            verify_with_origin(&derived, origin, preconfirmed).await.is_none(),
            "a pre-Etna block is bound to the stored origin's hash too"
        );
    }

    #[tokio::test]
    async fn etna_block_with_another_or_no_header_root_is_not_canonical() {
        let derived = derived_block(1_001, B256::with_last_byte(0x55), None, &[]);

        for header_root in [Some(B256::with_last_byte(0x56)), Some(B256::ZERO), None] {
            let verified =
                verify_against(&derived, canonical_block(&derived, header_root, 0, &[])).await;
            assert!(verified.is_none(), "header root {header_root:?} must not match");
        }
    }

    #[tokio::test]
    async fn pre_etna_block_requires_its_anchor_and_a_zero_header_root() {
        let anchor_tx = anchor_shaped_user_tx();
        let derived = derived_block(999, B256::ZERO, Some(anchor_tx.clone()), &[]);

        let canonical =
            canonical_block(&derived, Some(B256::ZERO), 42, std::slice::from_ref(&anchor_tx));
        assert!(verify_against(&derived, canonical).await.is_some(), "the Unzen block matches");

        let etna_shaped =
            canonical_block(&derived, Some(B256::with_last_byte(0x55)), 42, &[anchor_tx]);
        assert!(verify_against(&derived, etna_shaped).await.is_none(), "nonzero root before Etna");

        let anchorless = canonical_block(&derived, Some(B256::ZERO), 42, &[]);
        assert!(verify_against(&derived, anchorless).await.is_none(), "missing anchor");

        let zero_difficulty =
            canonical_block(&derived, Some(B256::ZERO), 0, &[anchor_shaped_user_tx()]);
        assert!(
            verify_against(&derived, zero_difficulty).await.is_none(),
            "zero difficulty before Etna"
        );
    }
}

#[cfg(test)]
mod finality_tests;

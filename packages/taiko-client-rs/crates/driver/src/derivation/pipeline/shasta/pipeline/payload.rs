use alethia_reth_consensus::validation::ANCHOR_V3_V4_GAS_LIMIT;
use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy::{
    eips::{BlockNumberOrTag, eip7685::EMPTY_REQUESTS_HASH},
    primitives::{Address, B256, U256, keccak256},
    providers::Provider,
};
use alloy_consensus::{Header, TxEnvelope};
use alloy_rpc_types::Transaction as RpcTransaction;
use alloy_rpc_types_engine::PayloadId;
use protocol::shasta::{
    PayloadAttributesInput, build_payload_attributes_with_id, calculate_shasta_mix_hash,
    encode_extra_data, encode_transactions,
    manifest::{BlockManifest, DerivationSourceManifest},
    unzen_active_for_chain_timestamp,
};

use crate::{
    derivation::DerivationError,
    metrics::DriverMetrics,
    sync::engine::{EngineBlockOutcome, PayloadApplier},
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
    /// Anchor transaction paired with `payload`.
    anchor_tx: TxEnvelope,
    /// Parent hash used to build the payload.
    parent_hash: B256,
    /// L2 block number expected from execution.
    block_number: u64,
    /// Anchor block number encoded into the anchor transaction.
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

impl<P> ShastaDerivationPipeline<P>
where
    P: Provider + Clone + 'static,
{
    /// Resolve the hash of the last finalized proposal's block if available.
    ///
    /// Errors are logged but never propagated so payload application can proceed even when the
    /// mapping is unavailable.
    async fn finalized_block_hash_for(
        &self,
        maybe_last_finalized_proposal_id: Option<u64>,
    ) -> Option<B256> {
        let last_finalized_proposal_id = maybe_last_finalized_proposal_id?;

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
                return None;
            }
            Err(err) => {
                warn!(
                    proposal_id = last_finalized_proposal_id,
                    error = %err,
                    "failed to query finalized proposal block id"
                );
                return None;
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
                Some(block.header.hash)
            }
            Ok(None) => {
                warn!(
                    proposal_id = last_finalized_proposal_id,
                    block_number, "missing block for finalized proposal id"
                );
                None
            }
            Err(err) => {
                warn!(
                    proposal_id = last_finalized_proposal_id,
                    block_number,
                    error = %err,
                    "failed to fetch finalized block by number"
                );
                None
            }
        }
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

        let applied = applier.apply_payload(&payload, parent_hash, finalized_block_hash).await?;
        let header = applied.outcome.block.header.clone().into_consensus();
        *state = state.advance(header, block.anchor_block_number)?;

        info!(
            proposal_id = meta.proposal_id,
            block_number = applied.outcome.block_number(),
            block_hash = ?applied.outcome.block_hash(),
            "payload applied to execution engine"
        );

        self.sync_l1_origin(meta, &payload, &applied.outcome, is_final_block).await?;

        Ok(applied.outcome)
    }

    /// Prepare the payload attributes and anchor transaction for a manifest block without
    /// submitting it to the execution engine.
    ///
    /// The result is reused by the canonical-batch detector to avoid repeating heavy
    /// computations such as anchor assembly when we only need to validate existing blocks.
    async fn prepare_block(
        &self,
        block: &BlockManifest,
        state: &ParentState,
        ctx: BlockContext<'_>,
    ) -> Result<BlockDerivationContext, DerivationError> {
        let BlockContext { meta, position } = ctx;

        let block_number = state.next_block_number();
        info!(
            proposal_id = meta.proposal_id,
            block_number,
            forced_inclusion = position.is_forced_inclusion(),
            transactions = block.transactions.len(),
            "processing manifest block"
        );
        let block_base_fee = state.compute_block_base_fee()?;
        let parent_mix_hash = B256::from(state.header.difficulty.to_be_bytes::<32>());
        let mix_hash = calculate_shasta_mix_hash(parent_mix_hash, block_number);

        let anchor_inputs = AnchorTxInputs { block, block_number, block_base_fee };

        let anchor_tx = self.build_anchor_transaction(state, meta, anchor_inputs).await?;

        let mut transactions = Vec::with_capacity(block.transactions.len() + 1);
        transactions.push(anchor_tx.clone());
        transactions.extend(block.transactions.clone());

        let parent_hash = state.header.hash_slow();

        info!(
            proposal_id = meta.proposal_id,
            block_number,
            block_base_fee,
            mix_hash = ?mix_hash,
            transaction_count_with_anchor = transactions.len(),
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
            },
        );

        Ok(BlockDerivationContext {
            payload,
            anchor_tx,
            parent_hash,
            block_number,
            anchor_block_number: block.anchor_block_number,
            is_final_block: position.is_final(),
        })
    }

    /// Construct the `TaikoPayloadAttributes` structure that gets sent to the execution
    /// engine.
    fn create_payload_attributes(
        &self,
        transactions: &[TxEnvelope],
        ctx: PayloadContext<'_>,
    ) -> TaikoPayloadAttributes {
        let PayloadContext {
            block,
            meta,
            block_base_fee,
            mix_hash,
            block_number,
            parent_hash,
            position,
        } = ctx;
        let l1_block_hash = meta.l1_block_hash;

        let tx_list = encode_transactions(transactions);
        let extra_data = encode_extra_data(meta.basefee_sharing_pctg, meta.proposal_id);

        // Gas limit in manifest excludes the reserved budget for the anchor transaction, so
        // add it back here.
        let gas_limit = block.gas_limit.saturating_add(ANCHOR_V3_V4_GAS_LIMIT);

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
                parent_beacon_block_root: None,
                anchor_transaction: None,
            },
            &parent_hash,
        );

        debug!(
            l1_origin = ?payload.l1_origin,
            payload_attributes = ?payload.payload_attributes,
            "constructed payload attributes"
        );

        payload
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

    /// Update the L1 origin metadata for a proposal that already lives on the canonical chain.
    pub(super) async fn update_canonical_proposal_origins(
        &self,
        meta: &BundleMeta,
        blocks: &[KnownCanonicalBlock],
    ) -> Result<(), DerivationError> {
        for block in blocks {
            self.sync_l1_origin(meta, &block.payload, &block.outcome, block.is_final_block).await?;
        }
        Ok(())
    }

    /// Verify that a derived block matches the canonical execution block at the same height.
    async fn verify_canonical_block(
        &self,
        meta: &BundleMeta,
        derived_block: &BlockDerivationContext,
    ) -> Result<Option<VerifiedCanonicalBlock>, DerivationError> {
        let block_id = derived_block.block_number;
        let payload_id = PayloadId::new(derived_block.payload.l1_origin.build_payload_args_id);

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

        let Some(txs) = block.transactions.as_transactions() else {
            debug!(
                proposal_id = meta.proposal_id,
                block_id, "canonical block only exposed transaction hashes"
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

        if first_tx != &derived_block.anchor_tx {
            warn!(
                proposal_id = meta.proposal_id,
                block_id, "anchor transaction mismatch when confirming canonical block"
            );
            return Ok(None);
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
            if block.header.difficulty == U256::ZERO {
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

            if block.header.parent_beacon_block_root != Some(B256::ZERO) {
                debug!(proposal_id = meta.proposal_id, block_id, "parent beacon root mismatch");
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
    use crate::derivation::manifest::fetcher::shasta::ShastaSourceManifestFetcher;
    use alethia_reth_consensus::anchor_constants::anchorV4Call;
    use alethia_reth_primitives::{
        addresses::TAIKO_GOLDEN_TOUCH_ADDRESS,
        payload::attributes::{EngineRpcL1Origin, RpcL1Origin, TaikoBlockMetadata},
    };
    use alloy::{
        consensus::transaction::Recovered,
        rpc::types::eth::{Block as RpcBlock, BlockTransactions, Transaction as RpcTransaction},
        sol_types::SolCall,
    };
    use alloy_consensus::{EthereumTypedTransaction, SignableTransaction, TxEip1559, TxEnvelope};
    use alloy_eips::eip2930::AccessList;
    use alloy_primitives::{Bytes, TxKind};
    use alloy_provider::{ProviderBuilder, RootProvider};
    use alloy_rpc_types_engine_2::PayloadAttributes as EthPayloadAttributes;
    use alloy_transport::mock::Asserter;
    use anyhow::Result;
    use bindings::{
        anchor::{Anchor::AnchorInstance, ICheckpointStore::Checkpoint},
        inbox::Inbox::InboxInstance,
    };
    use protocol::{
        FixedKSigner,
        shasta::{
            AnchorTxConstructor,
            constants::{TAIKO_MAINNET_CHAIN_ID, min_base_fee_for_chain},
        },
    };
    use rpc::{
        blob::BlobDataSource,
        client::{Client, ShastaProtocolInstance},
    };
    use std::sync::Arc;

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

    /// Byte constants used to seed every field of the matching pair so that a single-field flip
    /// is unambiguous (each field carries a distinct value that nothing else shares).
    const ANCHOR_ADDRESS: Address = Address::repeat_byte(0x44);
    const ANCHOR_BLOCK_NUMBER: u64 = 55;
    const BLOCK_NUMBER: u64 = 5;
    const PARENT_HASH: B256 = B256::repeat_byte(0xA1);
    const FEE_RECIPIENT: Address = Address::repeat_byte(0xB2);
    const PREV_RANDAO: B256 = B256::repeat_byte(0xC3);
    const GAS_LIMIT: u64 = 30_000_000;
    const TIMESTAMP: u64 = 1_775_200_000;
    const BASE_FEE: u64 = 1_000_000_000;
    const PAYLOAD_ARGS_ID: [u8; 8] = [7u8; 8];
    /// Arbitrary non-empty extra data; the canonical header and the payload metadata must agree.
    const EXTRA_DATA: [u8; 3] = [0xD4, 0xD5, 0xD6];

    /// Build a signed golden-touch anchorV4 transaction for the given anchor block number.
    ///
    /// `matching_anchor_tx()` (using `ANCHOR_BLOCK_NUMBER`) is shared by the derivation context and
    /// the canonical block's first transaction so they compare equal; the anchor-mismatch flip uses
    /// a different block number to produce a well-formed but unequal tx.
    fn anchor_tx(anchor_block_number: u64) -> TxEnvelope {
        let signer = FixedKSigner::golden_touch().expect("golden touch signer should load");
        let checkpoint = Checkpoint {
            blockNumber: alloy_primitives::aliases::U48::from(anchor_block_number),
            blockHash: B256::from([0x22; 32]),
            stateRoot: B256::from([0x33; 32]),
        };
        let tx = TxEip1559 {
            chain_id: TAIKO_MAINNET_CHAIN_ID,
            nonce: 0,
            max_fee_per_gas: 1_000_000_000,
            max_priority_fee_per_gas: 0,
            gas_limit: 250_000,
            to: TxKind::Call(ANCHOR_ADDRESS),
            value: U256::ZERO,
            access_list: AccessList::default(),
            input: Bytes::from(anchorV4Call(checkpoint.into()).abi_encode()),
        };
        let sighash = tx.signature_hash();
        let mut hash_bytes = [0u8; 32];
        hash_bytes.copy_from_slice(sighash.as_slice());
        let signature =
            signer.sign_with_predefined_k(&hash_bytes).expect("test anchor tx should sign");
        TxEnvelope::new_unchecked(
            EthereumTypedTransaction::Eip1559(tx),
            signature.signature,
            sighash,
        )
    }

    /// The anchor tx the matching pair agrees on.
    fn matching_anchor_tx() -> TxEnvelope {
        anchor_tx(ANCHOR_BLOCK_NUMBER)
    }

    /// Minimal proposal metadata; only `proposal_id` is read by `verify_canonical_block` (for
    /// logging), the rest satisfy the struct.
    fn matching_meta() -> BundleMeta {
        BundleMeta {
            proposal_id: 9,
            last_finalized_proposal_id: None,
            proposal_timestamp: TIMESTAMP,
            l1_block_number: 100,
            l1_block_hash: B256::repeat_byte(0x06),
            origin_block_number: 100,
            proposer: Address::repeat_byte(0x02),
            basefee_sharing_pctg: 0,
        }
    }

    /// Payload attributes whose fields line up with the canonical header built below.
    fn matching_payload() -> TaikoPayloadAttributes {
        TaikoPayloadAttributes {
            payload_attributes: EthPayloadAttributes {
                timestamp: TIMESTAMP,
                prev_randao: PREV_RANDAO,
                suggested_fee_recipient: FEE_RECIPIENT,
                withdrawals: Some(Vec::new()),
                parent_beacon_block_root: None,
                slot_number: None,
            },
            base_fee_per_gas: U256::from(BASE_FEE),
            block_metadata: TaikoBlockMetadata {
                beneficiary: FEE_RECIPIENT,
                gas_limit: GAS_LIMIT,
                timestamp: U256::from(TIMESTAMP),
                mix_hash: PREV_RANDAO,
                tx_list: None,
                extra_data: Bytes::from(EXTRA_DATA.to_vec()),
            },
            l1_origin: RpcL1Origin {
                block_id: U256::from(BLOCK_NUMBER),
                l2_block_hash: B256::ZERO,
                l1_block_height: None,
                l1_block_hash: None,
                build_payload_args_id: PAYLOAD_ARGS_ID,
                is_forced_inclusion: false,
                signature: [0u8; 65],
            },
            // `verify_canonical_block` never inspects this field, so leaving it unset keeps the
            // fixture minimal.
            anchor_transaction: None,
        }
    }

    /// Build the derivation context paired with the canonical block below.
    fn matching_derivation_context(anchor_tx: TxEnvelope) -> BlockDerivationContext {
        BlockDerivationContext {
            payload: matching_payload(),
            anchor_tx,
            parent_hash: PARENT_HASH,
            block_number: BLOCK_NUMBER,
            anchor_block_number: ANCHOR_BLOCK_NUMBER,
            is_final_block: true,
        }
    }

    /// Wrap a signed envelope as the RPC `Transaction` shape that `get_block_by_number(..).full()`
    /// deserializes into (it carries the recovered sender, which a bare envelope lacks). The
    /// golden-touch address is the recovered signer of every anchor tx here.
    fn as_rpc_transaction(envelope: TxEnvelope) -> RpcTransaction {
        RpcTransaction {
            inner: Recovered::new_unchecked(envelope, Address::from(TAIKO_GOLDEN_TOUCH_ADDRESS)),
            block_hash: None,
            block_number: None,
            transaction_index: None,
            effective_gas_price: None,
        }
    }

    /// Build the canonical execution block that, unflipped, satisfies every comparison in
    /// `verify_canonical_block` on a mainnet (pre-Unzen) chain. Transactions use the RPC
    /// `Transaction` shape so the block round-trips through the mocked `.full()` fetch, after which
    /// the pipeline maps them back to `TxEnvelope`.
    fn matching_canonical_block(anchor_tx: TxEnvelope) -> RpcBlock {
        let mut block: RpcBlock = RpcBlock::default();
        // `Header::default()` already sets ommers_hash to the empty-list hash and every optional
        // Unzen field (blob gas, beacon root, requests hash) to None, matching the pre-Unzen leg.
        block.header.number = BLOCK_NUMBER;
        block.header.parent_hash = PARENT_HASH;
        block.header.beneficiary = FEE_RECIPIENT;
        block.header.difficulty = U256::ZERO;
        block.header.mix_hash = PREV_RANDAO;
        block.header.gas_limit = GAS_LIMIT;
        block.header.timestamp = TIMESTAMP;
        block.header.extra_data = Bytes::from(EXTRA_DATA.to_vec());
        block.header.base_fee_per_gas = Some(BASE_FEE);
        block.withdrawals = None;
        block.transactions = BlockTransactions::Full(vec![as_rpc_transaction(anchor_tx)]);
        block
    }

    /// The L1 origin the engine returns for the block; its payload args id must line up with the
    /// derivation context so the fast path is not rejected before the header comparisons.
    fn matching_origin() -> EngineRpcL1Origin {
        EngineRpcL1Origin(RpcL1Origin {
            block_id: U256::from(BLOCK_NUMBER),
            l2_block_hash: B256::ZERO,
            l1_block_height: None,
            l1_block_hash: None,
            build_payload_args_id: PAYLOAD_ARGS_ID,
            is_forced_inclusion: false,
            signature: [0u8; 65],
        })
    }

    /// Drive `verify_canonical_block` with a mainnet pipeline whose L2 provider serves, in order,
    /// the L1 origin lookup then the canonical block. Returns whether the fast path was taken.
    async fn run_verify(
        meta: &BundleMeta,
        derived_block: &BlockDerivationContext,
        origin: EngineRpcL1Origin,
        canonical_block: RpcBlock,
    ) -> Option<VerifiedCanonicalBlock> {
        // The L2 provider used by `verify_canonical_block` serves ONLY the two responses that
        // function issues: `l1_origin_by_id` (taiko_l1OriginByID) then
        // `get_block_by_number(..).full()`, in order.
        let l2_asserter = Asserter::new();
        l2_asserter.push_success(&Some(origin));
        l2_asserter.push_success(&Some(canonical_block));

        let l1_provider = ProviderBuilder::new()
            .disable_recommended_fillers()
            .connect_mocked_client(Asserter::new());
        let l2_provider =
            ProviderBuilder::new().disable_recommended_fillers().connect_mocked_client(l2_asserter);
        let l2_auth_provider = ProviderBuilder::new()
            .disable_recommended_fillers()
            .connect_mocked_client(Asserter::new());
        let inbox = InboxInstance::new(Address::ZERO, l1_provider.clone());
        let anchor = AnchorInstance::new(ANCHOR_ADDRESS, l2_auth_provider.clone());
        let shasta = ShastaProtocolInstance { inbox, anchor };
        let client: Client<RootProvider> = Client {
            chain_id: TAIKO_MAINNET_CHAIN_ID,
            l1_provider,
            l2_provider,
            l2_auth_provider,
            shasta,
        };

        let blob_source = Arc::new(
            BlobDataSource::new(None, None, true)
                .await
                .expect("blob data source should initialise"),
        );
        // `AnchorTxConstructor::new` issues its own `get_chain_id` call, so give it a dedicated
        // provider rather than draining `verify_canonical_block`'s L2 asserter.
        let anchor_asserter = Asserter::new();
        anchor_asserter.push_success(&TAIKO_MAINNET_CHAIN_ID);
        let anchor_provider = ProviderBuilder::new()
            .disable_recommended_fillers()
            .connect_mocked_client(anchor_asserter);
        let anchor_constructor = AnchorTxConstructor::new(anchor_provider, ANCHOR_ADDRESS)
            .await
            .expect("anchor constructor should initialise");
        let pipeline = ShastaDerivationPipeline {
            rpc: client,
            anchor_constructor,
            derivation_source_manifest_fetcher: ShastaSourceManifestFetcher::new(blob_source),
            shasta_fork_timestamp: 0,
            min_base_fee_to_clamp: min_base_fee_for_chain(TAIKO_MAINNET_CHAIN_ID),
            chain_id: TAIKO_MAINNET_CHAIN_ID,
            initial_proposal_id: U256::ZERO,
        };

        pipeline
            .verify_canonical_block(meta, derived_block)
            .await
            .expect("verify_canonical_block should not error for these inputs")
    }

    /// The known-canonical fast path must accept an exactly-matching (context, block) pair and
    /// reject it the moment any single guarded header/tx field diverges. Regression guard for the
    /// ~25 comparisons in `verify_canonical_block`, which previously had zero unit coverage.
    ///
    /// Scope: this fixture drives the pre-Unzen leg only (mainnet's Unzen fork is unscheduled, so
    /// `unzen_active` is false for `matching_canonical_block`). The Unzen-active guards
    /// (payload.rs:781-805: zero-difficulty mirror, and the blob_gas / excess_blob_gas /
    /// beacon-root / requests-hash presence checks) are NOT exercised here. An Unzen variant of
    /// this fixture family is the follow-up.
    #[tokio::test]
    async fn verify_canonical_block_rejects_field_mismatches() {
        // Sanity: the unflipped pair takes the fast path. This must hold before any flip below is
        // meaningful.
        {
            let meta = matching_meta();
            let ctx = matching_derivation_context(matching_anchor_tx());
            let verdict = run_verify(
                &meta,
                &ctx,
                matching_origin(),
                matching_canonical_block(ctx.anchor_tx.clone()),
            )
            .await;
            assert!(verdict.is_some(), "unflipped matching pair must take the canonical fast path");
        }

        // Each flip mutates exactly ONE field on the canonical block (the "block side") and must
        // drop the fast path. A mismatch means "derive it yourself", i.e. Ok(None) rather than an
        // error, so `run_verify` unwraps the Ok and we assert None here.
        type Flip = fn(&mut RpcBlock);
        let flips: [(&str, Flip); 6] = [
            ("parent_hash", |b| b.header.parent_hash = B256::repeat_byte(0xEE)),
            ("base_fee", |b| b.header.base_fee_per_gas = Some(BASE_FEE + 1)),
            ("gas_limit", |b| b.header.gas_limit += 1),
            // The timestamp also feeds `unzen_active_for_chain_timestamp`, which selects which
            // guard leg (pre- vs post-Unzen) runs. This flip is safe here only because mainnet's
            // Unzen fork is unscheduled, so nudging the timestamp cannot cross the fork boundary
            // and change what the flip tests. A future mainnet Unzen timestamp near the fixture's
            // TIMESTAMP constant would silently alter that.
            ("timestamp", |b| b.header.timestamp += 1),
            ("difficulty", |b| b.header.difficulty = U256::from(999)),
            ("anchor_tx", |b| {
                // Replace the anchor tx with a different (but still valid) golden-touch tx so the
                // first-transaction comparison fails.
                b.transactions = BlockTransactions::Full(vec![as_rpc_transaction(anchor_tx(
                    ANCHOR_BLOCK_NUMBER + 1,
                ))]);
            }),
        ];

        for (label, flip) in flips {
            let meta = matching_meta();
            let ctx = matching_derivation_context(matching_anchor_tx());
            let mut canonical_block = matching_canonical_block(ctx.anchor_tx.clone());
            flip(&mut canonical_block);
            let verdict = run_verify(&meta, &ctx, matching_origin(), canonical_block).await;
            assert!(verdict.is_none(), "{label} mismatch must reject the canonical fast path");
        }
    }
}

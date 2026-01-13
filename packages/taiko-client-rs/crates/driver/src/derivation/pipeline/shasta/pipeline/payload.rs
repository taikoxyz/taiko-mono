use alethia_reth_consensus::validation::ANCHOR_V3_V4_GAS_LIMIT;
use alethia_reth_primitives::payload::attributes::{
    RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes,
};
use alloy::{
    eips::BlockNumberOrTag,
    primitives::{Address, B256, U256, keccak256},
    providers::Provider,
};
use alloy_consensus::{Header, TxEnvelope};
use alloy_rpc_types::{Transaction as RpcTransaction, eth::Withdrawal};
use alloy_rpc_types_engine::{PayloadAttributes as EthPayloadAttributes, PayloadId};
use metrics::counter;
use protocol::shasta::{
    calculate_shasta_difficulty, compute_build_payload_args_id, encode_extra_data,
    encode_transactions,
    manifest::{BlockManifest, DerivationSourceManifest},
};

use crate::{
    derivation::{DerivationError, pipeline::shasta::anchor::AnchorV4Input},
    metrics::DriverMetrics,
    sync::engine::{EngineBlockOutcome, PayloadApplier},
};
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
    /// Difficulty used when sealing the block.
    difficulty: B256,
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
    // Check if this is the final block of the final segment.
    fn is_final(&self) -> bool {
        self.segment_index + 1 == self.segments_total && self.block_index + 1 == self.blocks_len
    }

    // Check if this block is part of a forced inclusion segment.
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
    payload: TaikoPayloadAttributes,
    anchor_tx: TxEnvelope,
    parent_hash: B256,
    block_number: u64,
    anchor_block_number: u64,
    is_final_block: bool,
}

/// Canonical block data captured when a proposal's blocks already exist on the execution chain.
#[derive(Debug)]
pub(super) struct KnownCanonicalBlock {
    pub(super) payload: TaikoPayloadAttributes,
    pub(super) outcome: EngineBlockOutcome,
    pub(super) is_final_block: bool,
}

/// Output of a successful canonical-chain verification.
///
/// Carries both the execution outcome (for L1 origin updates) and the consensus header so the
/// parent state can advance without talking to the engine again.
#[derive(Debug)]
struct VerifiedCanonicalBlock {
    outcome: EngineBlockOutcome,
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
    async fn finalized_block_hash_for(&self, last_finalized_proposal_id: u64) -> Option<B256> {
        if last_finalized_proposal_id == 0 {
            return None;
        }

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
        let parent_difficulty = B256::from(state.header.difficulty.to_be_bytes::<32>());
        let difficulty = calculate_shasta_difficulty(parent_difficulty, block_number);

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
            difficulty = ?difficulty,
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
                difficulty,
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
            difficulty,
            block_number,
            parent_hash,
            position,
        } = ctx;
        let l1_block_hash = meta.l1_block_hash;

        let tx_list = encode_transactions(transactions);
        let extra_data = encode_extra_data(meta.basefee_sharing_pctg, meta.proposal_id);

        let withdrawals: Vec<Withdrawal> = Vec::new();
        let build_payload_args_id = compute_build_payload_args_id(
            parent_hash,
            block.timestamp,
            difficulty,
            block.coinbase,
            &withdrawals,
            &tx_list,
        );

        let l1_origin = RpcL1Origin {
            block_id: U256::from(block_number),
            l2_block_hash: B256::ZERO,
            l1_block_height: Some(U256::from(meta.l1_block_number)),
            l1_block_hash: Some(l1_block_hash),
            build_payload_args_id,
            is_forced_inclusion: position.is_forced_inclusion(),
            signature: [0u8; 65],
        };

        // Gas limit in manifest excludes the reserved budget for the anchor transaction, so
        // add it back here.
        let gas_limit = block.gas_limit.saturating_add(ANCHOR_V3_V4_GAS_LIMIT);

        let block_metadata = TaikoBlockMetadata {
            beneficiary: block.coinbase,
            gas_limit,
            timestamp: U256::from(block.timestamp),
            mix_hash: difficulty,
            tx_list,
            extra_data,
        };

        let payload_attributes = EthPayloadAttributes {
            timestamp: block.timestamp,
            prev_randao: difficulty,
            suggested_fee_recipient: block.coinbase,
            withdrawals: Some(withdrawals),
            parent_beacon_block_root: None,
        };

        debug!(
            l1_origin = ?l1_origin,
            payload_attributes = ?payload_attributes,
            "constructed payload attributes"
        );

        TaikoPayloadAttributes {
            payload_attributes,
            base_fee_per_gas: U256::from(block_base_fee),
            block_metadata,
            l1_origin,
        }
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
        counter!(DriverMetrics::DERIVATION_L1_ORIGIN_UPDATES_TOTAL).increment(1);

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

        if block.header.difficulty != U256::ZERO {
            debug!(proposal_id = meta.proposal_id, block_id, "difficulty non-zero");
            return Ok(None);
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

    // Build the anchor transaction for the given block.
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

    // Fetch the anchor block fields.
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
    use alethia_reth_evm::alloy::TAIKO_GOLDEN_TOUCH_ADDRESS;
    use alloy_consensus::{EthereumTypedTransaction, SignableTransaction, TxEip1559, TxEnvelope};
    use alloy_eips::eip2930::AccessList;
    use alloy_primitives::{Bytes, TxKind};
    use anyhow::Result;

    use crate::signer::FixedKSigner;

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
}

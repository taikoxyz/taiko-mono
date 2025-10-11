use alethia_reth_primitives::payload::attributes::{
    RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes,
};
use alloy::{
    primitives::{B256, U256},
    providers::Provider,
};
use alloy_rpc_types::eth::Withdrawal;
use alloy_rpc_types_engine::PayloadAttributes as EthPayloadAttributes;
use protocol::shasta::manifest::{BlockManifest, DerivationSourceManifest};

use crate::derivation::DerivationError;

use super::{
    super::validation::{ValidationError, validate_source_manifest},
    ShastaDerivationPipeline,
    bundle::{BundleMeta, SourceManifestSegment},
    state::ParentState,
    util::{
        calculate_shasta_difficulty, encode_extra_data, encode_transactions, estimate_gas_used,
    },
};

/// Context describing a manifest segment during payload derivation.
struct SegmentContext<'a> {
    meta: &'a BundleMeta,
    origin_block_hash: B256,
    shasta_fork_height: u64,
    position: SegmentPosition,
}

/// Tracks the absolute position of a segment within the proposal bundle.
#[derive(Clone, Copy)]
struct SegmentPosition {
    index: usize,
    total: usize,
}

/// Position metadata passed down to block-level processing.
#[derive(Clone, Copy)]
struct BlockPosition {
    segment_index: usize,
    segments_total: usize,
    block_index: usize,
    blocks_len: usize,
    forced_inclusion: bool,
}

/// Shared inputs required when converting a manifest block into payload attributes.
struct BlockContext<'a> {
    meta: &'a BundleMeta,
    origin_block_hash: B256,
    shasta_fork_height: u64,
    position: BlockPosition,
}

/// Aggregate of per-block data forwarded to `create_payload_attributes`.
struct PayloadContext<'a> {
    block: &'a BlockManifest,
    meta: &'a BundleMeta,
    origin_block_hash: B256,
    block_base_fee: u64,
    difficulty: B256,
    block_number: u64,
    position: BlockPosition,
}

impl SegmentPosition {
    // Convert the segment position into a block position for a specific block within the segment.
    fn to_block_position(
        &self,
        block_index: usize,
        blocks_len: usize,
        forced_inclusion: bool,
    ) -> BlockPosition {
        BlockPosition {
            segment_index: self.index,
            segments_total: self.total,
            block_index,
            blocks_len,
            forced_inclusion,
        }
    }
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

impl<P> ShastaDerivationPipeline<P>
where
    P: Provider + Clone + 'static,
{
    /// Process all manifest segments in order, producing a flat list of payload attributes.
    pub(super) fn build_payloads_from_sources(
        &self,
        sources: Vec<SourceManifestSegment>,
        meta: &BundleMeta,
        origin_block_hash: B256,
        shasta_fork_height: u64,
        state: &mut ParentState,
    ) -> Result<Vec<TaikoPayloadAttributes>, DerivationError> {
        // Each source can expand into multiple payloads; accumulate them in order.
        let segments_total = sources.len();
        let mut payloads = Vec::new();

        for (segment_index, segment) in sources.into_iter().enumerate() {
            let segment_ctx = SegmentContext {
                meta,
                origin_block_hash,
                shasta_fork_height,
                position: SegmentPosition { index: segment_index, total: segments_total },
            };
            let segment_payloads = self.process_manifest_segment(segment, state, segment_ctx)?;
            payloads.extend(segment_payloads);
        }

        Ok(payloads)
    }

    /// Process a single manifest segment, producing one or more payload attributes.
    fn process_manifest_segment(
        &self,
        segment: SourceManifestSegment,
        state: &mut ParentState,
        ctx: SegmentContext<'_>,
    ) -> Result<Vec<TaikoPayloadAttributes>, DerivationError> {
        let SegmentContext { meta, origin_block_hash, shasta_fork_height, position } = ctx;

        // Sanitize the manifest before deriving payload attributes.
        let mut decoded_manifest = segment.manifest;
        let ctx = state.build_validation_context(meta, segment.is_forced_inclusion);

        match validate_source_manifest(&mut decoded_manifest, &ctx) {
            Ok(()) => {}
            Err(ValidationError::EmptyManifest | ValidationError::DefaultManifest) => {
                decoded_manifest = DerivationSourceManifest::default();
                validate_source_manifest(&mut decoded_manifest, &ctx)
                    .map_err(DerivationError::from)?;
            }
        }

        let blocks_len = decoded_manifest.blocks.len();
        let mut payloads = Vec::with_capacity(blocks_len);

        for (block_index, block) in decoded_manifest.blocks.iter().enumerate() {
            let block_ctx = BlockContext {
                meta,
                origin_block_hash,
                shasta_fork_height,
                position: position.to_block_position(
                    block_index,
                    blocks_len,
                    segment.is_forced_inclusion,
                ),
            };
            let payload = self.process_block_manifest(block, state, block_ctx);
            payloads.push(payload);
        }

        Ok(payloads)
    }

    /// Convert a manifest block into payload attributes while updating the rolling parent state.
    fn process_block_manifest(
        &self,
        block: &BlockManifest,
        state: &mut ParentState,
        ctx: BlockContext<'_>,
    ) -> TaikoPayloadAttributes {
        let BlockContext { meta, origin_block_hash, shasta_fork_height, position } = ctx;

        let block_number = state.advance_block_number();
        let block_time = block.timestamp.saturating_sub(state.timestamp).max(1);
        let block_base_fee =
            state.compute_block_base_fee(block_number, block_time, shasta_fork_height);
        let difficulty = calculate_shasta_difficulty(state.prev_randao, block_number);
        state.prev_randao = difficulty;

        let payload = self.create_payload_attributes(PayloadContext {
            block,
            meta,
            origin_block_hash,
            block_base_fee,
            difficulty,
            block_number,
            position,
        });

        let estimated_gas_used = estimate_gas_used(&block.transactions, block.gas_limit);
        state.apply_block_updates(block, block_base_fee, difficulty, estimated_gas_used);

        payload
    }

    /// Construct the `TaikoPayloadAttributes` structure that gets sent to the execution
    /// engine.
    fn create_payload_attributes(&self, ctx: PayloadContext<'_>) -> TaikoPayloadAttributes {
        let PayloadContext {
            block,
            meta,
            origin_block_hash,
            block_base_fee,
            difficulty,
            block_number,
            position,
        } = ctx;

        let tx_list = encode_transactions(&block.transactions);
        let extra_data =
            encode_extra_data(meta.basefee_sharing_pctg, false, meta.bond_instructions_hash);

        let mut signature = [0u8; 65];
        let prover_slice = meta.prover_auth_bytes.as_ref();
        let copy_len = prover_slice.len().min(signature.len());
        signature[..copy_len].copy_from_slice(&prover_slice[..copy_len]);

        let mut build_payload_args_id = [0u8; 8];
        if position.is_final() {
            build_payload_args_id = meta.proposal_id.to_be_bytes();
        }

        let l1_origin = RpcL1Origin {
            block_id: U256::from(block_number),
            l2_block_hash: B256::ZERO,
            l1_block_height: Some(U256::from(meta.origin_block_number)),
            l1_block_hash: Some(origin_block_hash),
            build_payload_args_id,
            is_forced_inclusion: position.is_forced_inclusion(),
            signature,
        };

        let block_metadata = TaikoBlockMetadata {
            beneficiary: block.coinbase,
            gas_limit: block.gas_limit,
            timestamp: U256::from(block.timestamp),
            mix_hash: difficulty,
            tx_list,
            extra_data,
        };

        let payload_attributes = EthPayloadAttributes {
            timestamp: block.timestamp,
            prev_randao: difficulty,
            suggested_fee_recipient: block.coinbase,
            withdrawals: Some(Vec::<Withdrawal>::new()),
            parent_beacon_block_root: None,
        };

        TaikoPayloadAttributes {
            payload_attributes,
            base_fee_per_gas: U256::from(block_base_fee),
            block_metadata,
            l1_origin,
        }
    }
}

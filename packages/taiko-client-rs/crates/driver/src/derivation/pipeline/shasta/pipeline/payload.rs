use alethia_reth::payload::attributes::{RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes};
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

impl<P> ShastaDerivationPipeline<P>
where
    P: Provider + Clone + 'static,
{
    pub(super) fn build_payloads_from_sources(
        &self,
        sources: Vec<SourceManifestSegment>,
        meta: &BundleMeta,
        origin_block_hash: Option<B256>,
        shasta_fork_height: u64,
        state: &mut ParentState,
    ) -> Result<Vec<TaikoPayloadAttributes>, DerivationError> {
        let segments_total = sources.len();
        let mut payloads = Vec::new();

        for (segment_index, segment) in sources.into_iter().enumerate() {
            let segment_payloads = self.process_manifest_segment(
                segment,
                meta,
                origin_block_hash,
                shasta_fork_height,
                state,
                segment_index,
                segments_total,
            )?;
            payloads.extend(segment_payloads);
        }

        Ok(payloads)
    }

    fn process_manifest_segment(
        &self,
        segment: SourceManifestSegment,
        meta: &BundleMeta,
        origin_block_hash: Option<B256>,
        shasta_fork_height: u64,
        state: &mut ParentState,
        segment_index: usize,
        segments_total: usize,
    ) -> Result<Vec<TaikoPayloadAttributes>, DerivationError> {
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
            let payload = self.process_block_manifest(
                block,
                meta,
                origin_block_hash,
                shasta_fork_height,
                state,
                segment.is_forced_inclusion,
                segment_index,
                segments_total,
                block_index,
                blocks_len,
            );
            payloads.push(payload);
        }

        Ok(payloads)
    }

    fn process_block_manifest(
        &self,
        block: &BlockManifest,
        meta: &BundleMeta,
        origin_block_hash: Option<B256>,
        shasta_fork_height: u64,
        state: &mut ParentState,
        is_forced_inclusion: bool,
        segment_index: usize,
        segments_total: usize,
        block_index: usize,
        blocks_len: usize,
    ) -> TaikoPayloadAttributes {
        let block_number = state.advance_block_number();
        let block_time = block.timestamp.saturating_sub(state.timestamp).max(1);
        let block_base_fee =
            state.compute_block_base_fee(block_number, block_time, shasta_fork_height);
        let difficulty = calculate_shasta_difficulty(state.prev_randao, block_number);
        state.prev_randao = difficulty;

        let is_final_payload = segment_index + 1 == segments_total && block_index + 1 == blocks_len;

        let payload = self.create_payload_attributes(
            block,
            meta,
            origin_block_hash,
            block_base_fee,
            difficulty,
            block_number,
            is_forced_inclusion,
            is_final_payload,
        );

        let estimated_gas_used = estimate_gas_used(&block.transactions, block.gas_limit);
        state.apply_block_updates(block, block_base_fee, difficulty, estimated_gas_used);

        payload
    }

    fn create_payload_attributes(
        &self,
        block: &BlockManifest,
        meta: &BundleMeta,
        origin_block_hash: Option<B256>,
        block_base_fee: u64,
        difficulty: B256,
        block_number: u64,
        is_forced_inclusion: bool,
        is_final_payload: bool,
    ) -> TaikoPayloadAttributes {
        let tx_list = encode_transactions(&block.transactions);
        let extra_data =
            encode_extra_data(meta.basefee_sharing_pctg, false, meta.bond_instructions_hash);

        let mut signature = [0u8; 65];
        let prover_slice = meta.prover_auth_bytes.as_ref();
        let copy_len = prover_slice.len().min(signature.len());
        signature[..copy_len].copy_from_slice(&prover_slice[..copy_len]);

        let mut build_payload_args_id = [0u8; 8];
        if is_final_payload {
            build_payload_args_id = meta.proposal_id.to_be_bytes();
        }

        let l1_origin = RpcL1Origin {
            block_id: U256::from(block_number),
            l2_block_hash: B256::ZERO,
            l1_block_height: Some(U256::from(meta.origin_block_number)),
            l1_block_hash: origin_block_hash,
            build_payload_args_id,
            is_forced_inclusion,
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

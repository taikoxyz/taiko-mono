use alethia_reth_primitives::payload::attributes::{
    RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes,
};
use alloy::{
    eips::BlockNumberOrTag,
    primitives::{B256, U256},
    providers::Provider,
};
use alloy_consensus::{Transaction as _, TxEnvelope};
use alloy_primitives::Bytes;
use alloy_rpc_types::eth::Withdrawal;
use alloy_rpc_types_engine::{ForkchoiceState, PayloadAttributes as EthPayloadAttributes};
use anyhow::anyhow;
use bindings::taiko_anchor::LibBonds::BondInstruction;
use protocol::shasta::{
    constants::BOND_PROCESSING_DELAY,
    manifest::{BlockManifest, DerivationSourceManifest},
};

use crate::{
    derivation::{DerivationError, pipeline::shasta::anchor::UpdateStateInput},
    sync::engine::{EngineBlockOutcome, PayloadApplier},
};

use super::{
    super::validation::{ValidationError, validate_source_manifest},
    ShastaDerivationPipeline,
    bundle::{BundleMeta, SourceManifestSegment},
    state::ParentState,
    util::{
        calculate_bond_instruction_hash, calculate_shasta_difficulty, encode_extra_data,
        encode_transactions,
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
    blocks_before: usize,
}

/// Position metadata passed down to block-level processing.
#[derive(Clone, Copy)]
struct BlockPosition {
    segment_index: usize,
    segments_total: usize,
    block_index: usize,
    blocks_len: usize,
    blocks_before_segment: usize,
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

/// Aggregated bond instruction data for a derived block.
struct BondInstructionData {
    instructions: Vec<BondInstruction>,
    next_hash: B256,
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
            blocks_before_segment: self.blocks_before,
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

    // Compute the global index of this block within the entire proposal bundle.
    fn global_index(&self) -> usize {
        self.blocks_before_segment + self.block_index
    }
}

impl<P> ShastaDerivationPipeline<P>
where
    P: Provider + Clone + 'static,
{
    /// Process all manifest segments in order, materialising blocks via the execution engine.
    pub(super) async fn build_payloads_from_sources(
        &self,
        sources: Vec<SourceManifestSegment>,
        meta: &BundleMeta,
        origin_block_hash: B256,
        shasta_fork_height: u64,
        state: &mut ParentState,
        applier: &(dyn PayloadApplier + Send + Sync),
    ) -> Result<Vec<EngineBlockOutcome>, DerivationError> {
        // Each source can expand into multiple payloads; accumulate their engine outcomes in order.
        let segments_total = sources.len();
        let mut blocks_before = 0usize;
        let mut outcomes = Vec::new();
        let mut forkchoice_state = ForkchoiceState {
            head_block_hash: state.block_hash,
            safe_block_hash: state.block_hash,
            finalized_block_hash: state.header.parent_hash,
        };

        for (segment_index, segment) in sources.into_iter().enumerate() {
            let blocks_len = segment.manifest.blocks.len();
            let segment_ctx = SegmentContext {
                meta,
                origin_block_hash,
                shasta_fork_height,
                position: SegmentPosition {
                    index: segment_index,
                    total: segments_total,
                    blocks_before,
                },
            };
            let segment_outcomes = self
                .process_manifest_segment(
                    segment,
                    state,
                    segment_ctx,
                    applier,
                    &mut forkchoice_state,
                )
                .await?;
            outcomes.extend(segment_outcomes);
            blocks_before += blocks_len;
        }

        Ok(outcomes)
    }

    /// Process a single manifest segment, producing one or more payload attributes.
    async fn process_manifest_segment(
        &self,
        segment: SourceManifestSegment,
        state: &mut ParentState,
        ctx: SegmentContext<'_>,
        applier: &(dyn PayloadApplier + Send + Sync),
        forkchoice_state: &mut ForkchoiceState,
    ) -> Result<Vec<EngineBlockOutcome>, DerivationError> {
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
        let mut outcomes = Vec::with_capacity(blocks_len);

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
            let outcome = self
                .process_block_manifest(block, state, block_ctx, applier, forkchoice_state)
                .await?;
            outcomes.push(outcome);
        }

        Ok(outcomes)
    }

    /// Convert a manifest block into payload attributes while updating the rolling parent state.
    async fn process_block_manifest(
        &self,
        block: &BlockManifest,
        state: &mut ParentState,
        ctx: BlockContext<'_>,
        applier: &(dyn PayloadApplier + Send + Sync),
        forkchoice_state: &mut ForkchoiceState,
    ) -> Result<EngineBlockOutcome, DerivationError> {
        let BlockContext { meta, origin_block_hash, shasta_fork_height, position } = ctx;

        let block_number = state.advance_block_number();
        let block_base_fee = state.compute_block_base_fee(
            block_number,
            block.timestamp.saturating_sub(state.timestamp),
            shasta_fork_height,
        );
        let difficulty = calculate_shasta_difficulty(state.prev_randao, block_number);
        state.prev_randao = difficulty;

        let bond_data = self.assemble_bond_instructions(state, meta, &position).await?;

        let anchor_tx = self
            .build_anchor_transaction(
                &*state,
                meta,
                block,
                &position,
                block_number,
                block_base_fee,
                &bond_data.instructions,
                bond_data.next_hash,
            )
            .await?;

        // Push the anchor transaction first, then the rest of the block's transactions.
        let mut transactions = Vec::with_capacity(block.transactions.len() + 1);
        transactions.push(anchor_tx);
        transactions.extend(block.transactions.clone());

        let payload = self.create_payload_attributes(
            &transactions,
            PayloadContext {
                block,
                meta,
                origin_block_hash,
                block_base_fee,
                difficulty,
                block_number,
                position,
            },
        );

        let applied = applier.apply_payload(&payload, forkchoice_state).await?;
        state.apply_execution_payload(block, &applied.payload, bond_data.next_hash)?;

        Ok(applied.outcome)
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
            origin_block_hash,
            block_base_fee,
            difficulty,
            block_number,
            position,
        } = ctx;

        let tx_list = encode_transactions(transactions);
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

    async fn assemble_bond_instructions(
        &self,
        state: &ParentState,
        meta: &BundleMeta,
        position: &BlockPosition,
    ) -> Result<BondInstructionData, DerivationError> {
        let mut aggregated_hash = state.bond_instructions_hash;
        let mut instructions = Vec::new();

        if position.segment_index == 0 &&
            position.block_index == 0 &&
            meta.proposal_id > BOND_PROCESSING_DELAY
        {
            let target_id = meta.proposal_id - BOND_PROCESSING_DELAY;
            let target_payload = self
                .indexer
                .get_proposal_by_id(U256::from(target_id))
                .ok_or(DerivationError::IncompleteMetadata(target_id))?;

            let expected_hash =
                B256::from_slice(target_payload.core_state.bondInstructionsHash.as_slice());

            if aggregated_hash != expected_hash {
                let tx_hash = target_payload.log.transaction_hash.ok_or_else(|| {
                    DerivationError::Other(anyhow!(
                        "missing transaction hash for proposal {}",
                        target_id
                    ))
                })?;

                let tx = self
                    .rpc
                    .l1_provider
                    .get_transaction_by_hash(tx_hash)
                    .await
                    .map_err(|err| {
                        DerivationError::Other(anyhow!(
                            "failed to fetch propose transaction for proposal {target_id}: {err}"
                        ))
                    })?
                    .ok_or_else(|| {
                        DerivationError::Other(anyhow!(
                            "propose transaction {tx_hash:?} not found for proposal {target_id}"
                        ))
                    })?;

                let input: Bytes = tx.input().clone();
                let decoded =
                    self.rpc.shasta.codec.decodeProposeInput(input).call().await.map_err(
                        |err| {
                            DerivationError::Other(anyhow!(
                                "failed to decode propose input for proposal {target_id}: {err}"
                            ))
                        },
                    )?;

                'outer: for record in decoded.transitionRecords {
                    for instruction in record.bondInstructions {
                        let instruction = BondInstruction {
                            proposalId: instruction.proposalId,
                            bondType: instruction.bondType,
                            payer: instruction.payer,
                            payee: instruction.payee,
                        };
                        aggregated_hash =
                            calculate_bond_instruction_hash(aggregated_hash, &instruction);
                        instructions.push(instruction);

                        if aggregated_hash == expected_hash {
                            break 'outer;
                        }
                    }
                }

                if aggregated_hash != expected_hash {
                    return Err(DerivationError::Other(anyhow!(
                        "bond instructions hash mismatch for proposal {target_id}: calculated {:?}, expected {:?}",
                        aggregated_hash,
                        expected_hash
                    )));
                }
            }
        }

        Ok(BondInstructionData { instructions, next_hash: aggregated_hash })
    }

    // Build the anchor transaction for the given block.
    async fn build_anchor_transaction(
        &self,
        parent_state: &ParentState,
        meta: &BundleMeta,
        block: &BlockManifest,
        position: &BlockPosition,
        block_number: u64,
        block_base_fee: u64,
        bond_instructions: &[BondInstruction],
        bond_instructions_hash: B256,
    ) -> Result<TxEnvelope, DerivationError> {
        let (anchor_block_hash, anchor_state_root) =
            self.resolve_anchor_block_fields(block.anchor_block_number, parent_state).await?;

        let block_index = u16::try_from(position.global_index())
            .map_err(|_| DerivationError::Other(anyhow!("block index exceeds u16 range")))?;

        let tx = self
            .anchor_constructor
            .assemble_update_state_tx(
                parent_state.block_hash,
                UpdateStateInput {
                    proposal_id: meta.proposal_id,
                    proposer: meta.proposer,
                    prover_auth: meta.prover_auth_bytes.clone().to_vec(),
                    bond_instructions_hash,
                    bond_instructions: bond_instructions.to_vec(),
                    block_index,
                    anchor_block_number: block.anchor_block_number,
                    anchor_block_hash,
                    anchor_state_root,
                    end_of_submission_window_timestamp: meta.end_of_submission_window_timestamp,
                    l2_height: block_number,
                    base_fee: U256::from(block_base_fee),
                },
            )
            .await?;

        Ok(tx)
    }

    // Fetch and validate the anchor block fields.
    async fn resolve_anchor_block_fields(
        &self,
        anchor_block_number: u64,
        parent_state: &ParentState,
    ) -> Result<(B256, B256), DerivationError> {
        if anchor_block_number == 0 || anchor_block_number <= parent_state.anchor_block_number {
            return Ok((B256::ZERO, B256::ZERO));
        }

        let block = self
            .rpc
            .l1_provider
            .get_block_by_number(BlockNumberOrTag::Number(anchor_block_number))
            .await
            .map_err(|err| {
                DerivationError::Other(anyhow!(
                    "failed to fetch anchor block {anchor_block_number}: {err}"
                ))
            })?
            .ok_or_else(|| {
                DerivationError::Other(anyhow!("anchor block {anchor_block_number} not found"))
            })?;

        let block_hash = block.header.hash;
        let state_root = block.header.inner.state_root;

        Ok((block_hash, state_root))
    }
}

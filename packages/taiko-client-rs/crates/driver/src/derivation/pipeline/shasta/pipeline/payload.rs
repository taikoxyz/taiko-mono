use alethia_reth_primitives::payload::attributes::{
    RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes,
};
use alloy::{
    eips::BlockNumberOrTag,
    primitives::{Address, B256, U256},
    providers::Provider,
};
use alloy_consensus::{Transaction as _, TxEnvelope};
use alloy_eips::{BlockId, eip1898::RpcBlockHash};
use alloy_primitives::{Bytes, aliases::U48};
use alloy_rpc_types::eth::Withdrawal;
use alloy_rpc_types_engine::{ForkchoiceState, PayloadAttributes as EthPayloadAttributes};
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
    /// Proposal metadata shared across all segments.
    meta: &'a BundleMeta,
    /// Hash of the proposal's L1 origin block.
    proposal_origin_block_hash: B256,
    /// Fork height for Shasta activation.
    shasta_fork_height: u64,
    /// Positional data describing where the segment sits within the proposal.
    position: SegmentPosition,
}

/// Tracks the absolute position of a segment within the proposal bundle.
#[derive(Clone, Copy)]
struct SegmentPosition {
    /// Index of the segment within the proposal bundle.
    index: usize,
    /// Total number of segments in the proposal bundle.
    total: usize,
    /// Number of blocks included prior to this segment.
    blocks_before: usize,
}

/// Position metadata passed down to block-level processing.
#[derive(Clone, Copy)]
struct BlockPosition {
    /// Index of the segment containing the block.
    segment_index: usize,
    /// Total number of segments in the bundle.
    segments_total: usize,
    /// Index of the block within its segment.
    block_index: usize,
    /// Total number of blocks in the segment.
    blocks_len: usize,
    /// Global offset of the first block in the segment.
    blocks_before_segment: usize,
    /// Whether the block originates from a forced inclusion segment.
    forced_inclusion: bool,
}

/// Shared inputs required when converting a manifest block into payload attributes.
struct BlockContext<'a> {
    /// Immutable metadata describing the entire proposal bundle.
    meta: &'a BundleMeta,
    /// Hash of the proposal's L1 origin block.
    origin_block_hash: B256,
    /// Fork height governing Shasta base-fee transitions.
    shasta_fork_height: u64,
    /// Positional data describing where the block sits within the proposal.
    position: BlockPosition,
    /// Indicates whether the proposal is a low-bond proposal (falls back to default manifest).
    is_low_bond_proposal: bool,
}

/// Aggregate of per-block data forwarded to `create_payload_attributes`.
struct PayloadContext<'a> {
    /// Manifest-provided block metadata.
    block: &'a BlockManifest,
    /// Proposal-level metadata reused for payload construction.
    meta: &'a BundleMeta,
    /// Hash of the proposal's L1 origin block.
    origin_block_hash: B256,
    /// Base fee target for the upcoming block.
    block_base_fee: u64,
    /// Difficulty used when sealing the block.
    difficulty: B256,
    /// Height of the block being built.
    block_number: u64,
    /// Positional data describing where the block sits within the proposal.
    position: BlockPosition,
    /// Indicates whether the low-bond flag should be encoded.
    is_low_bond_proposal: bool,
}

/// Aggregated bond instruction data for a derived block.
struct BondInstructionData {
    /// Instructions that must be embedded into the anchor transaction.
    instructions: Vec<BondInstruction>,
    /// Rolling hash after applying the block's bond instructions.
    next_hash: B256,
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
        proposal_origin_block_hash: B256,
        shasta_fork_height: u64,
        state: &mut ParentState,
        applier: &(dyn PayloadApplier + Send + Sync),
    ) -> Result<Vec<EngineBlockOutcome>, DerivationError> {
        // Each source can expand into multiple payloads; accumulate their engine outcomes in order.
        let segments_total = sources.len();
        let mut blocks_before = 0usize;
        let mut outcomes = Vec::new();
        let parent_hash = state.header.hash_slow();
        let mut forkchoice_state = ForkchoiceState {
            head_block_hash: parent_hash,
            safe_block_hash: B256::ZERO,
            finalized_block_hash: B256::ZERO,
        };

        for (segment_index, segment) in sources.into_iter().enumerate() {
            let segment_ctx = SegmentContext {
                meta,
                proposal_origin_block_hash,
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

            let blocks_produced = segment_outcomes.len();
            outcomes.extend(segment_outcomes);
            blocks_before += blocks_produced;
        }

        // Ensure the derived bond instruction hash matches what the proposal advertised.
        if state.bond_instructions_hash != meta.bond_instructions_hash {
            return Err(DerivationError::BondInstructionsMismatch {
                expected: meta.bond_instructions_hash,
                actual: state.bond_instructions_hash,
            });
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
        let SegmentContext { meta, proposal_origin_block_hash, shasta_fork_height, position } = ctx;

        // Sanitize the manifest before deriving payload attributes.
        let mut decoded_manifest = segment.manifest;
        let mut is_low_bond_proposal = false;

        if !segment.is_forced_inclusion && !manifest_is_default(&decoded_manifest) {
            is_low_bond_proposal = self.detect_low_bond_proposal(state, meta).await?;
            if is_low_bond_proposal {
                decoded_manifest = DerivationSourceManifest::default();
            }
        }

        let validation_ctx = state.build_validation_context(meta, segment.is_forced_inclusion);

        match validate_source_manifest(&mut decoded_manifest, &validation_ctx) {
            Ok(()) => {}
            Err(ValidationError::EmptyManifest | ValidationError::DefaultManifest) => {
                decoded_manifest = DerivationSourceManifest::default();
                validate_source_manifest(&mut decoded_manifest, &validation_ctx)
                    .map_err(DerivationError::from)?;
            }
        }

        let blocks_len = decoded_manifest.blocks.len();
        let mut outcomes = Vec::with_capacity(blocks_len);

        for (block_index, block) in decoded_manifest.blocks.iter().enumerate() {
            let block_ctx = BlockContext {
                meta,
                origin_block_hash: proposal_origin_block_hash,
                shasta_fork_height,
                position: position.to_block_position(
                    block_index,
                    blocks_len,
                    segment.is_forced_inclusion,
                ),
                is_low_bond_proposal,
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
        let BlockContext {
            meta,
            origin_block_hash,
            shasta_fork_height,
            position,
            is_low_bond_proposal,
        } = ctx;

        let block_number = state.next_block_number();
        let block_base_fee = state.compute_block_base_fee(
            block_number,
            block.timestamp.saturating_sub(state.header.timestamp),
            shasta_fork_height,
        );
        let difficulty = calculate_shasta_difficulty(state.header.mix_hash, block_number);

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
                is_low_bond_proposal,
            },
        );

        let applied = applier.apply_payload(&payload, forkchoice_state).await?;
        *state = state.advance(block, &applied.payload, bond_data.next_hash)?;

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
            is_low_bond_proposal,
        } = ctx;

        let tx_list = encode_transactions(transactions);
        let extra_data = encode_extra_data(meta.basefee_sharing_pctg, is_low_bond_proposal);

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

    /// Query the anchor contract to determine if the proposal is designated as low-bond.
    async fn detect_low_bond_proposal(
        &self,
        state: &ParentState,
        meta: &BundleMeta,
    ) -> Result<bool, DerivationError> {
        let designated_prover_info = self
            .rpc
            .shasta
            .anchor
            .getDesignatedProver(
                U48::from(meta.proposal_id),
                meta.proposer,
                meta.prover_auth_bytes.clone(),
            )
            .block(BlockId::Hash(RpcBlockHash {
                block_hash: state.header.hash_slow(),
                require_canonical: Some(false),
            }))
            .call()
            .await?;

        Ok(designated_prover_info.isLowBondProposal_)
    }

    /// Assemble bond instructions that must be embedded into the next anchor transaction.
    async fn assemble_bond_instructions(
        &self,
        state: &ParentState,
        meta: &BundleMeta,
        position: &BlockPosition,
    ) -> Result<BondInstructionData, DerivationError> {
        let mut aggregated_hash = state.bond_instructions_hash;
        let mut instructions = Vec::new();

        // Only the first block of a proposal needs to incorporate delayed bond instructions.
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
                let tx_hash = target_payload
                    .log
                    .transaction_hash
                    .ok_or(DerivationError::MissingProposeTxHash { proposal_id: target_id })?;

                let tx = self
                    .rpc
                    .l1_provider
                    .get_transaction_by_hash(tx_hash)
                    .await
                    .map_err(|err| DerivationError::ProposeTransactionQuery {
                        proposal_id: target_id,
                        reason: err.to_string(),
                    })?
                    .ok_or_else(|| DerivationError::MissingProposeTransaction {
                        proposal_id: target_id,
                        tx_hash,
                    })?;

                let input: Bytes = tx.input().clone();
                let decoded =
                    self.rpc.shasta.codec.decodeProposeInput(input).call().await.map_err(
                        |err| DerivationError::ProposeInputDecode {
                            proposal_id: target_id,
                            reason: err.to_string(),
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
                    return Err(DerivationError::BondInstructionsMismatch {
                        expected: expected_hash,
                        actual: aggregated_hash,
                    });
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
            .map_err(|_| DerivationError::BlockIndexOverflow { index: position.global_index() })?;

        let tx = self
            .anchor_constructor
            .assemble_update_state_tx(
                parent_state.header.hash_slow(),
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
            .map_err(|err| DerivationError::AnchorBlockQuery {
                block_number: anchor_block_number,
                reason: err.to_string(),
            })?
            .ok_or(DerivationError::AnchorBlockMissing { block_number: anchor_block_number })?;

        let block_hash = block.header.hash;
        let state_root = block.header.inner.state_root;

        Ok((block_hash, state_root))
    }
}

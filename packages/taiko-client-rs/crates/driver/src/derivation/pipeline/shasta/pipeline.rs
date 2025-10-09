use std::sync::Arc;

use alethia_reth::{
    consensus::{
        eip4396::{SHASTA_INITIAL_BASE_FEE, calculate_next_block_eip4396_base_fee},
        validation::{ANCHOR_V3_GAS_LIMIT, SHASTA_INITIAL_BASE_FEE_BLOCKS},
    },
    payload::attributes::{RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes},
};
use alloy::{
    eips::BlockNumberOrTag,
    primitives::{Address, B256, Bytes, U256, keccak256},
    providers::Provider,
    rpc::types::Log,
    sol_types::SolEvent,
};
use alloy_consensus::{Header, Transaction, TxEnvelope};
use alloy_rlp::{BytesMut, encode_list};
use alloy_rpc_types::{
    Transaction as RpcTransaction,
    eth::{Block as RpcBlock, Withdrawal},
};
use alloy_rpc_types_engine::PayloadAttributes as EthPayloadAttributes;
use alloy_sol_types::{SolValue, sol};
use anyhow::anyhow;
use async_trait::async_trait;
use bindings::{
    codec_optimized::IInbox::{DerivationSource, ProposedEventPayload},
    i_inbox::IInbox::Proposed,
};
use event_indexer::indexer::ShastaEventIndexer;
use protocol::shasta::manifest::{BlockManifest, DerivationSourceManifest, ProposalManifest};
use rpc::{blob::BlobDataSource, client::Client};

use crate::derivation::{
    manifest::{
        ManifestFetcher,
        fetcher::shasta::{ShastaProposalManifestFetcher, ShastaSourceManifestFetcher},
    },
    pipeline::shasta::anchor::AnchorTxConstructor,
};

use super::{
    super::{DerivationError, DerivationPipeline},
    validation::{ValidationContext, ValidationError, validate_source_manifest},
};

sol! {
    struct ShastaDifficultyInput {
        bytes32 parentDifficulty;
        uint256 blockNumber;
    }
}

/// Segment of a derivation source manifest along with its forced inclusion flag.
#[derive(Debug, Clone)]
pub struct SourceManifestSegment {
    manifest: DerivationSourceManifest,
    is_forced_inclusion: bool,
}

/// Represents a complete Shasta proposal bundle derived from a proposal log.
#[derive(Debug, Clone)]
pub struct ShastaProposalBundle {
    proposal_id: u64,
    proposal_timestamp: u64,
    origin_block_number: u64,
    proposer: Address,
    basefee_sharing_pctg: u8,
    bond_instructions_hash: B256,
    prover_auth_bytes: Bytes,
    end_of_submission_window_timestamp: u64,
    sources: Vec<SourceManifestSegment>,
}

#[derive(Debug, Clone)]
struct BundleMeta {
    proposal_id: u64,
    proposal_timestamp: u64,
    origin_block_number: u64,
    proposer: Address,
    basefee_sharing_pctg: u8,
    bond_instructions_hash: B256,
    prover_auth_bytes: Bytes,
}

#[derive(Debug, Clone)]
struct ParentState {
    header: Header,
    timestamp: u64,
    gas_limit: u64,
    block_number: u64,
    anchor_block_number: u64,
    prev_randao: B256,
}

/// Shasta-specific derivation pipeline.
pub struct ShastaDerivationPipeline<P>
where
    P: Provider + Clone + 'static,
{
    rpc: Client<P>,
    _indexer: Arc<ShastaEventIndexer>,
    _anchor_constructor: AnchorTxConstructor<P>,
    derivation_source_manifest_fetcher:
        Arc<dyn ManifestFetcher<Manifest = DerivationSourceManifest>>,
    proposal_manifest_fetcher: Arc<dyn ManifestFetcher<Manifest = ProposalManifest>>,
}

impl<P> ShastaDerivationPipeline<P>
where
    P: Provider + Clone + 'static,
{
    /// Create a new derivation pipeline instance.
    pub async fn new(
        rpc: Client<P>,
        blob_source: BlobDataSource,
        indexer: Arc<ShastaEventIndexer>,
    ) -> Result<Self, DerivationError> {
        let source_manifest_fetcher: Arc<dyn ManifestFetcher<Manifest = DerivationSourceManifest>> =
            Arc::new(ShastaSourceManifestFetcher::new(
                blob_source.clone(),
                DerivationSourceManifest::decompress_and_decode,
            ));
        let proposal_manifest_fetcher: Arc<dyn ManifestFetcher<Manifest = ProposalManifest>> =
            Arc::new(ShastaProposalManifestFetcher::new(
                blob_source,
                ProposalManifest::decompress_and_decode,
            ));
        let anchor_constructor = AnchorTxConstructor::new(rpc.clone()).await?;
        Ok(Self {
            rpc,
            _indexer: indexer,
            _anchor_constructor: anchor_constructor,
            derivation_source_manifest_fetcher: source_manifest_fetcher,
            proposal_manifest_fetcher,
        })
    }

    /// Load the parent L2 block used as context when constructing payload attributes.
    ///
    /// Preference is given to the execution engine's cached origin pointer for the proposal.
    /// If unavailable, fall back to the latest canonical block.
    async fn load_parent_block(
        &self,
        proposal_id: u64,
    ) -> Result<RpcBlock<TxEnvelope>, DerivationError> {
        if let Some(origin) = self.rpc.last_l1_origin_by_batch_id(U256::from(proposal_id)).await? {
            // Prefer the concrete block referenced by the cached origin hash.
            if origin.l2_block_hash != B256::ZERO {
                if let Some(block) =
                    self.rpc.l2_provider.get_block_by_hash(origin.l2_block_hash).await?
                {
                    return Ok(block.map_transactions(|tx: RpcTransaction| tx.into()));
                }
            }
        }

        // Use the latest canonical block (common after beacon sync or at
        // startup when only genesis is present).
        self.rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await?
            .map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
            .ok_or_else(|| DerivationError::Other(anyhow!("latest L2 block not found")))
    }

    // Extract blob hashes from a derivation source.
    fn derivation_source_to_blob_hashes(&self, source: &DerivationSource) -> Vec<B256> {
        source.blobSlice.blobHashes.iter().map(|hash| B256::from_slice(hash.as_ref())).collect()
    }

    // Decode a proposal log into its event payload.
    async fn decode_log_to_event_payload(
        &self,
        log: &Log,
    ) -> Result<ProposedEventPayload, DerivationError> {
        Ok(self
            .rpc
            .shasta
            .codec
            .decodeProposedEvent(Proposed::decode_log_data(log.data())?.data)
            .call()
            .await?)
    }

    // Fetch and decode a single manifest from a derivation source.
    async fn fetch_and_decode_manifest<M>(
        &self,
        fetcher: &dyn ManifestFetcher<Manifest = M>,
        source: &DerivationSource,
    ) -> Result<M, DerivationError>
    where
        M: Send,
    {
        Ok(fetcher
            .fetch_and_decode_manifest(
                &self.derivation_source_to_blob_hashes(source),
                source.blobSlice.offset.to::<u64>() as usize,
            )
            .await?)
    }

    // Initialize the parent state from the parent block.
    async fn initialize_parent_state(
        &self,
        parent_block: &RpcBlock<TxEnvelope>,
    ) -> Result<(ParentState, u64), DerivationError> {
        let parent_hash = parent_block.hash();
        let anchor_state = self.rpc.shasta_anchor_state_by_hash(parent_hash).await?;
        let shasta_fork_height = self.rpc.shasta.anchor.shastaForkHeight().call().await?;

        let mut header = parent_block.header.inner.clone();
        if header.base_fee_per_gas.is_none() {
            header.base_fee_per_gas = Some(SHASTA_INITIAL_BASE_FEE);
        }

        let state = ParentState {
            header,
            timestamp: parent_block.header.timestamp,
            gas_limit: parent_block.header.gas_limit,
            block_number: parent_block.number(),
            anchor_block_number: anchor_state.anchorBlockNumber.to::<u64>(),
            prev_randao: parent_block.header.mix_hash,
        };

        Ok((state, shasta_fork_height))
    }

    fn build_payloads_from_sources(
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

#[async_trait]
impl<P> DerivationPipeline for ShastaDerivationPipeline<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    type Manifest = ShastaProposalBundle;

    // Convert a proposal log into a manifest for processing.
    async fn log_to_manifest(&self, log: &Log) -> Result<Self::Manifest, DerivationError> {
        let payload = self.decode_log_to_event_payload(log).await?;
        let sources = &payload.derivation.sources;

        // If sources is empty, we return an error, which should never happen for the current
        // Shasta protocol inbox implementation.
        let Some((last_source, forced_inclusion_sources)) = sources.split_last() else {
            return Err(DerivationError::EmptyDerivationSources(payload.proposal.id.to()));
        };

        // Fetch the forced inclusion sources first.
        let mut manifest_segments = Vec::with_capacity(sources.len());
        for source in forced_inclusion_sources {
            let manifest = self
                .fetch_and_decode_manifest(self.derivation_source_manifest_fetcher.as_ref(), source)
                .await?;
            manifest_segments.push(SourceManifestSegment {
                manifest,
                is_forced_inclusion: source.isForcedInclusion,
            });
        }

        // Fetch the proposal manifest last.
        let final_manifest: ProposalManifest = self
            .fetch_and_decode_manifest(self.proposal_manifest_fetcher.as_ref(), last_source)
            .await?;

        let prover_auth_bytes = final_manifest.prover_auth_bytes.clone();
        for manifest in final_manifest.sources.into_iter() {
            manifest_segments.push(SourceManifestSegment {
                manifest,
                is_forced_inclusion: last_source.isForcedInclusion,
            });
        }

        let bundle = ShastaProposalBundle {
            proposal_id: payload.proposal.id.to::<u64>(),
            proposal_timestamp: payload.proposal.timestamp.to::<u64>(),
            origin_block_number: payload.derivation.originBlockNumber.to::<u64>(),
            proposer: payload.proposal.proposer.into(),
            basefee_sharing_pctg: payload.derivation.basefeeSharingPctg,
            bond_instructions_hash: B256::from(payload.coreState.bondInstructionsHash),
            prover_auth_bytes,
            end_of_submission_window_timestamp: payload
                .proposal
                .endOfSubmissionWindowTimestamp
                .to::<u64>(),
            sources: manifest_segments,
        };

        Ok(bundle)
    }

    // Convert a manifest into payload attributes for block production.
    async fn manifest_to_payload_attributes(
        &self,
        manifest: Self::Manifest,
    ) -> Result<Vec<TaikoPayloadAttributes>, DerivationError> {
        let ShastaProposalBundle {
            proposal_id,
            proposal_timestamp,
            origin_block_number,
            proposer,
            basefee_sharing_pctg,
            bond_instructions_hash,
            prover_auth_bytes,
            end_of_submission_window_timestamp: _ignored_submission_window,
            sources,
        } = manifest;

        let parent_block = self.load_parent_block(proposal_id).await?;
        let origin_block_hash = self.rpc.l1_block_hash_by_number(origin_block_number).await?;
        let (mut parent_state, shasta_fork_height) =
            self.initialize_parent_state(&parent_block).await?;

        let meta = BundleMeta {
            proposal_id,
            proposal_timestamp,
            origin_block_number,
            proposer,
            basefee_sharing_pctg,
            bond_instructions_hash,
            prover_auth_bytes,
        };

        self.build_payloads_from_sources(
            sources,
            &meta,
            origin_block_hash,
            shasta_fork_height,
            &mut parent_state,
        )
    }
}

impl ParentState {
    fn advance_block_number(&mut self) -> u64 {
        self.block_number = self.block_number.saturating_add(1);
        self.block_number
    }

    fn compute_block_base_fee(
        &self,
        block_number: u64,
        block_time: u64,
        shasta_fork_height: u64,
    ) -> u64 {
        if block_number < shasta_fork_height + SHASTA_INITIAL_BASE_FEE_BLOCKS {
            SHASTA_INITIAL_BASE_FEE
        } else {
            calculate_next_block_eip4396_base_fee(&self.header, block_time)
        }
    }

    fn apply_block_updates(
        &mut self,
        block: &BlockManifest,
        block_base_fee: u64,
        difficulty: B256,
        estimated_gas_used: u64,
    ) {
        self.header.gas_limit = block.gas_limit;
        self.header.gas_used = estimated_gas_used;
        self.header.base_fee_per_gas = Some(block_base_fee);
        self.header.timestamp = block.timestamp;
        self.header.number = self.block_number;
        self.header.mix_hash = difficulty;

        self.timestamp = block.timestamp;
        self.gas_limit = block.gas_limit;
        self.anchor_block_number = block.anchor_block_number;
    }

    fn build_validation_context(
        &self,
        meta: &BundleMeta,
        is_forced_inclusion: bool,
    ) -> ValidationContext {
        ValidationContext {
            parent_timestamp: self.timestamp,
            parent_gas_limit: self.gas_limit,
            parent_block_number: self.block_number,
            parent_anchor_block_number: self.anchor_block_number,
            proposal_timestamp: meta.proposal_timestamp,
            origin_block_number: meta.origin_block_number,
            proposer: meta.proposer,
            is_forced_inclusion,
        }
    }
}

fn calculate_shasta_difficulty(parent_randao: B256, block_number: u64) -> B256 {
    let params = ShastaDifficultyInput {
        parentDifficulty: parent_randao,
        blockNumber: U256::from(block_number),
    };
    B256::from(keccak256(params.abi_encode()))
}

fn estimate_gas_used(transactions: &[TxEnvelope], gas_limit: u64) -> u64 {
    let used: u128 = transactions.iter().fold(0u128, |acc, tx| acc + tx.gas_limit() as u128);
    let capped = used.min(gas_limit as u128);
    capped.max(ANCHOR_V3_GAS_LIMIT.min(gas_limit) as u128).min(gas_limit as u128) as u64
}

fn encode_transactions(transactions: &[TxEnvelope]) -> Bytes {
    let mut buf = BytesMut::new();
    encode_list(transactions, &mut buf);
    Bytes::from(buf.freeze())
}

fn encode_extra_data(
    basefee_sharing_pctg: u8,
    is_low_bond_proposal: bool,
    bond_hash: B256,
) -> Bytes {
    let mut data = Vec::with_capacity(2 + bond_hash.as_slice().len());
    data.push(basefee_sharing_pctg);
    data.push(u8::from(is_low_bond_proposal));
    data.extend_from_slice(bond_hash.as_slice());
    Bytes::from(data)
}

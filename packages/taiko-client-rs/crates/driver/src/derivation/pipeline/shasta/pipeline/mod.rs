use std::{
    collections::VecDeque,
    sync::{Arc, Mutex},
};

use alloy::{
    eips::{BlockNumberOrTag, merge::EPOCH_SLOTS},
    primitives::{B256, U256},
    providers::Provider,
    rpc::types::Log,
    sol_types::SolEvent,
};
use alloy_consensus::TxEnvelope;
use alloy_rpc_types::{Transaction as RpcTransaction, eth::Block as RpcBlock};
use async_trait::async_trait;
use bindings::{
    anchor::LibBonds::BondInstruction,
    codec_optimized::{
        IInbox::{DerivationSource, ProposedEventPayload},
        LibBonds::BondInstruction as CodecBondInstruction,
    },
    i_inbox::IInbox::Proposed,
};
use metrics::{counter, gauge};
use protocol::shasta::{
    constants::{BOND_PROCESSING_DELAY, shasta_fork_timestamp_for_chain},
    manifest::DerivationSourceManifest,
};
use rpc::{blob::BlobDataSource, client::Client};
use tracing::{debug, info, instrument, warn};

use crate::{
    derivation::{
        manifest::{ManifestFetcher, fetcher::shasta::ShastaSourceManifestFetcher},
        pipeline::shasta::anchor::AnchorTxConstructor,
    },
    metrics::DriverMetrics,
    sync::engine::{EngineBlockOutcome, PayloadApplier},
};

use super::super::{DerivationError, DerivationPipeline};

/// Number of proposal records retained in the bond-instruction cache.
///
/// Two beacon epochs (2 × 32 slots) cover canonical reorg depth, and we extend this by the bond
/// delay so the delayed-instruction window remains intact even after rewinding.
const BOND_CACHE_CAPACITY: usize = ((2 * EPOCH_SLOTS) as usize) + (BOND_PROCESSING_DELAY as usize);

mod bundle;
mod payload;
mod state;
mod util;

use bundle::{BundleMeta, SourceManifestSegment};
use state::ParentState;

pub use bundle::ShastaProposalBundle;

/// Shasta-specific derivation pipeline.
///
/// The pipeline consumes proposal logs emitted by the Shasta inbox, resolves the
/// referenced manifests, and converts them into execution payloads that materialise new
/// blocks in the execution engine.
pub struct ShastaDerivationPipeline<P>
where
    P: Provider + Clone + 'static,
{
    rpc: Client<P>,
    anchor_constructor: AnchorTxConstructor<P>,
    derivation_source_manifest_fetcher:
        Arc<dyn ManifestFetcher<Manifest = DerivationSourceManifest>>,
    shasta_fork_timestamp: u64,
    initial_proposal_id: U256,
    /// Cached bond instruction entries, bounded to protect against reorgs.
    bond_instruction_cache: Mutex<VecDeque<BondInstructionCacheEntry>>,
}

/// Cache entry for bond instructions associated with a proposal.
#[derive(Debug)]
struct BondInstructionCacheEntry {
    proposal_id: u64,
    hash: B256,
    instructions: Vec<BondInstruction>,
}

impl<P> ShastaDerivationPipeline<P>
where
    P: Provider + Clone + 'static,
{
    /// Create a new derivation pipeline instance.
    ///
    /// Manifests are fetched via the supplied blob source while the driver client is
    /// reused to query both L1 contracts and L2 execution state.
    #[instrument(skip(rpc, blob_source), name = "shasta_derivation_new")]
    pub async fn new(
        rpc: Client<P>,
        blob_source: Arc<BlobDataSource>,
        initial_proposal_id: U256,
    ) -> Result<Self, DerivationError> {
        let source_manifest_fetcher: Arc<dyn ManifestFetcher<Manifest = DerivationSourceManifest>> =
            Arc::new(ShastaSourceManifestFetcher::new(blob_source.clone()));
        let anchor_constructor = AnchorTxConstructor::new(rpc.clone()).await?;
        let chain_id = rpc.l2_provider.get_chain_id().await?;
        let shasta_fork_timestamp = shasta_fork_timestamp_for_chain(chain_id)
            .map_err(|err| DerivationError::Other(err.into()))?;
        info!(chain_id, shasta_fork_timestamp, "initialised shasta derivation pipeline");
        Ok(Self {
            rpc,
            anchor_constructor,
            derivation_source_manifest_fetcher: source_manifest_fetcher,
            shasta_fork_timestamp,
            initial_proposal_id,
            bond_instruction_cache: Mutex::new(VecDeque::with_capacity(BOND_CACHE_CAPACITY)),
        })
    }

    /// Cache the bond instructions bundled within a decoded proposal payload.
    fn cache_bond_instructions_from_payload(
        &self,
        payload: &ProposedEventPayload,
    ) -> Result<(), DerivationError> {
        let instructions =
            payload.bondInstructions.iter().map(convert_codec_bond_instruction).collect();
        let proposal_id = payload.proposal.id.to::<u64>();
        let hash = B256::from(payload.coreState.bondInstructionsHash);
        self.store_bond_instructions(proposal_id, hash, instructions)?;
        Ok(())
    }

    /// Store or refresh the cached entry for `proposal_id`, trimming the queue when it exceeds the
    /// ring-buffer-derived capacity.
    fn store_bond_instructions(
        &self,
        proposal_id: u64,
        hash: B256,
        instructions: Vec<BondInstruction>,
    ) -> Result<(), DerivationError> {
        let mut cache = self.bond_instruction_cache.lock().map_err(|err| {
            DerivationError::BondInstructionCachePoisoned {
                operation: "store",
                message: err.to_string(),
            }
        })?;
        if let Some(pos) = cache.iter().position(|entry| entry.proposal_id == proposal_id) {
            cache.remove(pos);
        }
        cache.push_back(BondInstructionCacheEntry { proposal_id, hash, instructions });
        if cache.len() > BOND_CACHE_CAPACITY {
            cache.pop_front();
        }
        gauge!(DriverMetrics::DERIVATION_BOND_CACHE_DEPTH).set(cache.len() as f64);
        Ok(())
    }

    /// Fetch cached bond instructions for a delayed proposal, if available.
    pub(super) fn bond_instructions_for(
        &self,
        proposal_id: u64,
    ) -> Result<Option<(B256, Vec<BondInstruction>)>, DerivationError> {
        let cache = self.bond_instruction_cache.lock().map_err(|err| {
            DerivationError::BondInstructionCachePoisoned {
                operation: "fetch",
                message: err.to_string(),
            }
        })?;
        let result = cache
            .iter()
            .rev()
            .find(|entry| entry.proposal_id == proposal_id)
            .map(|entry| (entry.hash, entry.instructions.clone()));
        Ok(result)
    }

    /// Load the parent L2 block used as context when constructing payload attributes.
    ///
    /// Preference is given to the execution engine's cached origin pointer for the proposal.
    /// If unavailable, fall back to the latest canonical block.
    #[instrument(skip(self), fields(proposal_id), level = "debug")]
    async fn load_parent_block(
        &self,
        proposal_id: u64,
    ) -> Result<RpcBlock<TxEnvelope>, DerivationError> {
        tracing::Span::current().record("proposal_id", proposal_id);
        let parent_proposal_id = proposal_id.saturating_sub(1);
        if parent_proposal_id == 0 {
            info!(proposal_id, "using genesis block as parent for first proposal");
            return self
                .rpc
                .l2_provider
                .get_block_by_number(BlockNumberOrTag::Number(0))
                .await?
                .map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
                .ok_or(DerivationError::BlockUnavailable(0));
        }
        if let Some(origin) =
            self.rpc.last_l1_origin_by_batch_id(U256::from(parent_proposal_id)).await?
        {
            // Prefer the concrete block referenced by the cached origin hash.
            if origin.l2_block_hash != B256::ZERO &&
                let Some(block) =
                    self.rpc.l2_provider.get_block_by_hash(origin.l2_block_hash).await?
            {
                info!(
                    proposal_id,
                    parent_block_number = block.number(),
                    parent_hash = ?origin.l2_block_hash,
                    "using cached origin pointer for parent block"
                );
                return Ok(block.map_transactions(|tx: RpcTransaction| tx.into()));
            }
        }

        // Derive the parent block via the batch-to-block mapping so we always anchor to the last
        // execution block produced for the preceding proposal.
        info!(proposal_id, parent_proposal_id, "loading parent block via batch-to-block mapping");

        let block_number = self
            .rpc
            .last_block_id_by_batch_id(U256::from(parent_proposal_id))
            .await?
            .ok_or(DerivationError::MissingBatchLastBlock { proposal_id: parent_proposal_id })?
            .to::<u64>();
        self.rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Number(block_number))
            .await?
            .map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
            .ok_or(DerivationError::BlockUnavailable(block_number))
    }

    /// Extract blob hashes from a derivation source, preserving the order expected by
    /// the decoder.
    fn derivation_source_to_blob_hashes(&self, source: &DerivationSource) -> Vec<B256> {
        source.blobSlice.blobHashes.iter().map(|hash| B256::from_slice(hash.as_ref())).collect()
    }

    /// Decode a proposal log into the event payload.
    #[instrument(skip(self, log), level = "debug")]
    async fn decode_log_to_event_payload(
        &self,
        log: &Log,
    ) -> Result<ProposedEventPayload, DerivationError> {
        let payload = self
            .rpc
            .shasta
            .codec
            .decodeProposedEvent(Proposed::decode_log_data(log.data())?.data)
            .call()
            .await?;
        debug!(
            proposal_id = payload.proposal.id.to::<u64>(),
            timestamp = payload.proposal.timestamp.to::<u64>(),
            source_count = payload.derivation.sources.len(),
            "decoded proposed event payload"
        );
        Ok(payload)
    }

    /// Fetch and decode a single manifest from the blob store.
    ///
    /// The caller is responsible for providing the correct fetcher implementation for
    /// the manifest type.
    async fn fetch_and_decode_manifest<M>(
        &self,
        fetcher: &dyn ManifestFetcher<Manifest = M>,
        source: &DerivationSource,
    ) -> Result<M, DerivationError>
    where
        M: Send,
    {
        let hashes = self.derivation_source_to_blob_hashes(source);
        let offset = source.blobSlice.offset.to::<u64>() as usize;
        let timestamp = source.blobSlice.timestamp.to::<u64>();
        debug!(hash_count = hashes.len(), offset, timestamp, "fetching manifest sidecars");
        let manifest = fetcher.fetch_and_decode_manifest(timestamp, &hashes, offset).await?;
        Ok(manifest)
    }

    /// Build a proposal bundle from a decoded event payload.
    async fn build_manifest_from_payload(
        &self,
        payload: &ProposedEventPayload,
    ) -> Result<ShastaProposalBundle, DerivationError> {
        let sources = &payload.derivation.sources;
        let proposal_id = payload.proposal.id.to::<u64>();
        info!(proposal_id, source_count = sources.len(), "decoded proposal payload");

        // If sources is empty, we return an error, which should never happen for the current
        // Shasta protocol inbox implementation.
        let Some((last_source, forced_inclusion_sources)) = sources.split_last() else {
            let err = DerivationError::EmptyDerivationSources(proposal_id);
            warn!(proposal_id, "proposal contained no derivation sources");
            return Err(err);
        };

        // Fetch the normal proposal manifest first so we can reuse its prover auth.
        let final_manifest = self
            .fetch_and_decode_manifest(
                self.derivation_source_manifest_fetcher.as_ref(),
                last_source,
            )
            .await?;

        let prover_auth_bytes = final_manifest.prover_auth_bytes.clone();

        // Fetch the forced inclusion sources afterwards, injecting the proposal-level prover auth
        // so every segment carries the same signature payload as required by the protocol.
        let mut manifest_segments = Vec::with_capacity(sources.len());
        for source in forced_inclusion_sources {
            let mut manifest = self
                .fetch_and_decode_manifest(self.derivation_source_manifest_fetcher.as_ref(), source)
                .await?;
            // For forced-inclusion source, ensure it contains exactly one block and blob hash.
            if source.isForcedInclusion && manifest.blocks.len() != 1 {
                info!(
                    proposal_id,
                    blocks = manifest.blocks.len(),
                    blob_hashes = source.blobSlice.blobHashes.len(),
                    "invalid blocks count in forced-inclusion source manifest, using default payload instead"
                );
                manifest = DerivationSourceManifest::default();
            }
            // Inject the proposal-level prover auth into every segment.
            manifest.prover_auth_bytes = prover_auth_bytes.clone();
            manifest_segments.push(SourceManifestSegment {
                manifest,
                is_forced_inclusion: source.isForcedInclusion,
            });
        }

        manifest_segments.push(SourceManifestSegment {
            manifest: final_manifest,
            is_forced_inclusion: last_source.isForcedInclusion,
        });

        // Assemble the full Shasta protocol proposal bundle.
        let bundle = ShastaProposalBundle {
            meta: BundleMeta {
                proposal_id,
                proposal_timestamp: payload.proposal.timestamp.to::<u64>(),
                origin_block_number: payload.derivation.originBlockNumber.to::<u64>(),
                origin_block_hash: B256::from(payload.derivation.originBlockHash),
                proposer: payload.proposal.proposer,
                basefee_sharing_pctg: payload.derivation.basefeeSharingPctg,
                bond_instructions_hash: B256::from(payload.coreState.bondInstructionsHash),
                prover_auth_bytes,
            },
            sources: manifest_segments,
        };

        self.cache_bond_instructions_from_payload(payload)?;

        info!(proposal_id, segment_count = bundle.sources.len(), "assembled proposal bundle");
        Ok(bundle)
    }

    /// Initialize the rolling parent state used while constructing payload attributes.
    #[instrument(skip(self, parent_block), level = "debug")]
    async fn initialize_parent_state(
        &self,
        parent_block: &RpcBlock<TxEnvelope>,
    ) -> Result<ParentState, DerivationError> {
        let anchor_state = self.rpc.shasta_anchor_state_by_hash(parent_block.hash()).await?;
        let parent_header = parent_block.header.inner.clone();

        let grandparent_timestamp = if parent_header.number == 0 {
            parent_header.timestamp
        } else {
            let grandparent_block = self
                .rpc
                .l2_provider
                .get_block_by_hash(parent_header.parent_hash)
                .await?
                .ok_or_else(|| {
                    DerivationError::BlockUnavailable(parent_header.number.saturating_sub(1))
                })?;

            grandparent_block.header.timestamp
        };

        let state = ParentState {
            parent_block_time: parent_header.timestamp.saturating_sub(grandparent_timestamp),
            header: parent_header,
            bond_instructions_hash: anchor_state.bond_instructions_hash,
            anchor_block_number: anchor_state.anchor_block_number,
            shasta_fork_timestamp: self.shasta_fork_timestamp,
        };
        debug!(
            parent_number = state.header.number,
            parent_hash = ?state.header.hash_slow(),
            anchor_block = state.anchor_block_number,
            "initialised parent state for proposal derivation"
        );

        Ok(state)
    }
}

#[async_trait]
impl<P> DerivationPipeline for ShastaDerivationPipeline<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    type Manifest = ShastaProposalBundle;

    // Convert a proposal log into a manifest for processing.
    #[instrument(skip(self, log), name = "shasta_manifest_from_log")]
    async fn log_to_manifest(&self, log: &Log) -> Result<Self::Manifest, DerivationError> {
        let payload = self.decode_log_to_event_payload(log).await?;
        self.build_manifest_from_payload(&payload).await
    }

    // Convert a manifest into execution engine blocks for block production.
    #[instrument(skip(self, manifest, applier), name = "shasta_manifest_to_blocks")]
    async fn manifest_to_engine_blocks(
        &self,
        manifest: Self::Manifest,
        applier: &(dyn PayloadApplier + Send + Sync),
    ) -> Result<Vec<EngineBlockOutcome>, DerivationError> {
        let ShastaProposalBundle { meta, sources, .. } = manifest;
        if meta.proposal_id < self.initial_proposal_id.to() {
            info!(
                proposal_id = meta.proposal_id,
                initial_proposal_id = ?self.initial_proposal_id,
                "skipping proposal below initial proposal id"
            );
            counter!(DriverMetrics::EVENT_PROPOSALS_SKIPPED_TOTAL).increment(1);
            return Ok(Vec::new());
        }
        info!(
            proposal_id = meta.proposal_id,
            origin_block = meta.origin_block_number,
            segment_count = sources.len(),
            "deriving execution blocks from bundle"
        );

        let parent_block = self.load_parent_block(meta.proposal_id).await?;
        let mut parent_state = self.initialize_parent_state(&parent_block).await?;

        // If every block already sits in the canonical chain we skip payload submission and only
        // refresh L1 origins.
        if let Some(known_blocks) =
            self.detect_known_canonical_proposal(&meta, &sources, &parent_state).await?
        {
            let outcomes =
                known_blocks.iter().map(|block| block.outcome.clone()).collect::<Vec<_>>();
            counter!(DriverMetrics::DERIVATION_CANONICAL_HITS_TOTAL).increment(1);
            self.update_canonical_proposal_origins(&meta, &known_blocks).await?;
            return Ok(outcomes);
        }

        let outcomes =
            self.build_payloads_from_sources(sources, &meta, &mut parent_state, applier).await?;
        info!(
            proposal_id = meta.proposal_id,
            block_count = outcomes.len(),
            "proposal derivation produced execution blocks"
        );
        Ok(outcomes)
    }

    #[instrument(skip(self, log, applier), name = "shasta_process_proposal")]
    async fn process_proposal(
        &self,
        log: &Log,
        applier: &(dyn PayloadApplier + Send + Sync),
    ) -> Result<Vec<EngineBlockOutcome>, DerivationError> {
        let payload = self.decode_log_to_event_payload(log).await?;
        let proposal_id = payload.proposal.id.to::<u64>();

        if proposal_id == 0 {
            info!(proposal_id, "skipping proposal with zero id");
            counter!(DriverMetrics::EVENT_PROPOSALS_SKIPPED_TOTAL).increment(1);
            return Ok(Vec::new());
        }

        let manifest = self.build_manifest_from_payload(&payload).await?;
        let outcomes = self.manifest_to_engine_blocks(manifest, applier).await?;

        if let Some(last) = outcomes.last() {
            let last_block_number = last.block_number();
            let last_block_hash = last.block_hash();
            info!(
                proposal_id,
                last_l2_block_number = last_block_number,
                last_l2_block_hash = ?last_block_hash,
                "recorded final l2 block derived from proposal",
            );
        } else {
            info!(
                proposal_id,
                "proposal derivation produced no execution blocks; nothing to record",
            );
        }

        Ok(outcomes)
    }
}

/// Convert the codec-generated bond instruction into the anchor binding representation.
fn convert_codec_bond_instruction(instr: &CodecBondInstruction) -> BondInstruction {
    BondInstruction {
        proposalId: instr.proposalId,
        bondType: instr.bondType,
        payer: instr.payer,
        payee: instr.payee,
    }
}

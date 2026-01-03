use std::sync::Arc;

use alloy::{
    eips::{BlockId, BlockNumberOrTag, eip1898::RpcBlockHash},
    primitives::{B256, U256},
    providers::Provider,
    rpc::types::Log,
    sol_types::SolEvent,
};
use alloy_consensus::TxEnvelope;
use alloy_rpc_types::{Transaction as RpcTransaction, eth::Block as RpcBlock};
use anyhow::anyhow;
use async_trait::async_trait;
use bindings::inbox::{IInbox::DerivationSource, Inbox::Proposed};
use metrics::{counter, gauge};
use protocol::shasta::{
    constants::shasta_fork_timestamp_for_chain, manifest::DerivationSourceManifest,
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

/// Decoded Shasta `Proposed` event enriched with the containing L1 block metadata.
#[derive(Debug, Clone)]
struct ProposedEventContext {
    /// Raw decoded `Proposed` event payload.
    event: Proposed,
    /// L1 block number that emitted the event.
    l1_block_number: u64,
    /// Hash of the L1 block that emitted the event.
    l1_block_hash: B256,
    /// Timestamp of the emitting L1 block (used as proposal timestamp).
    l1_timestamp: u64,
}

mod bundle;
mod payload;
mod state;
mod util;

use bundle::{BundleMeta, SourceManifestSegment};
use state::ParentState;

pub use bundle::ShastaProposalBundle;

/// Convert a derivation source's blob slice into ordered blob hashes for manifest fetch.
fn derivation_source_to_blob_hashes(source: &DerivationSource) -> Vec<B256> {
    source.blobSlice.blobHashes.iter().map(|hash| B256::from_slice(hash.as_ref())).collect()
}

/// Ensure forced-inclusion manifests adhere to protocol rules (single block) or default them.
fn validate_forced_inclusion_manifest(
    proposal_id: u64,
    source: &DerivationSource,
    manifest: DerivationSourceManifest,
) -> DerivationSourceManifest {
    if source.isForcedInclusion && manifest.blocks.len() != 1 {
        info!(
            proposal_id,
            blocks = manifest.blocks.len(),
            blob_hashes = source.blobSlice.blobHashes.len(),
            "invalid blocks count in forced-inclusion source manifest, using default payload instead"
        );
        DerivationSourceManifest::default()
    } else {
        manifest
    }
}

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
        })
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

    /// Decode a proposal log into the event payload and enrich it with L1 block metadata.
    #[instrument(skip(self, log), level = "debug")]
    async fn decode_log_to_event_context(
        &self,
        log: &Log,
    ) -> Result<ProposedEventContext, DerivationError> {
        let event = Proposed::decode_raw_log(log.topics(), log.data().data.as_ref())?;

        let l1_block_hash = log.block_hash.ok_or(DerivationError::MissingL1BlockHash)?;
        let l1_block_number = log.block_number.ok_or(DerivationError::MissingL1BlockNumber)?;

        let l1_block = self
            .rpc
            .l1_provider
            .get_block_by_hash(l1_block_hash)
            .await?
            .ok_or(DerivationError::BlockUnavailable(l1_block_number))?;

        let l1_timestamp = l1_block.header.timestamp;

        debug!(
            proposal_id = event.id.to::<u64>(),
            l1_block_number = l1_block_number,
            l1_block_hash = ?l1_block_hash,
            source_count = event.sources.len(),
            "decoded proposed event"
        );

        Ok(ProposedEventContext { event, l1_block_number, l1_block_hash, l1_timestamp })
    }

    /// Read the inbox core state at the proposal log's block to extract the last finalized id.
    async fn inbox_last_finalized_proposal_id(&self, log: &Log) -> Result<u64, DerivationError> {
        let block_hash = log
            .block_hash
            .ok_or_else(|| DerivationError::Other(anyhow!("proposal log missing block hash")))?;
        let core_state = self
            .rpc
            .shasta
            .inbox
            .getCoreState()
            .block(BlockId::Hash(RpcBlockHash { block_hash, require_canonical: Some(false) }))
            .call()
            .await?;
        Ok(core_state.lastFinalizedProposalId.to::<u64>())
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
        let hashes = derivation_source_to_blob_hashes(source);
        let offset = source.blobSlice.offset.to::<u64>() as usize;
        let timestamp = source.blobSlice.timestamp.to::<u64>();
        debug!(hash_count = hashes.len(), offset, timestamp, "fetching manifest sidecars");
        let manifest = fetcher.fetch_and_decode_manifest(timestamp, &hashes, offset).await?;
        Ok(manifest)
    }

    /// Build a proposal bundle from a decoded event payload.
    async fn build_manifest_from_event(
        &self,
        event: &ProposedEventContext,
        last_finalized_proposal_id: u64,
    ) -> Result<ShastaProposalBundle, DerivationError> {
        let sources = &event.event.sources;
        let proposal_id = event.event.id.to::<u64>();
        info!(proposal_id, source_count = sources.len(), "decoded proposal payload");

        // If sources is empty, we return an error, which should never happen for the current
        // Shasta protocol inbox implementation.
        let Some((last_source, forced_inclusion_sources)) = sources.split_last() else {
            let err = DerivationError::EmptyDerivationSources(proposal_id);
            warn!(proposal_id, "proposal contained no derivation sources");
            return Err(err);
        };

        // Fetch the normal proposal manifest for the final source.
        let final_manifest = self
            .fetch_and_decode_manifest(
                self.derivation_source_manifest_fetcher.as_ref(),
                last_source,
            )
            .await?;

        // Fetch the forced inclusion sources afterwards.
        let mut manifest_segments = Vec::with_capacity(sources.len());
        for source in forced_inclusion_sources {
            let manifest = self
                .fetch_and_decode_manifest(self.derivation_source_manifest_fetcher.as_ref(), source)
                .await?;
            let manifest = validate_forced_inclusion_manifest(proposal_id, source, manifest);
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
                last_finalized_proposal_id,
                proposal_timestamp: event.l1_timestamp,
                l1_block_number: event.l1_block_number,
                l1_block_hash: event.l1_block_hash,
                origin_block_number: event.l1_block_number.saturating_sub(1),
                proposer: event.event.proposer,
                basefee_sharing_pctg: event.event.basefeeSharingPctg,
            },
            sources: manifest_segments,
        };

        gauge!(DriverMetrics::DERIVATION_LAST_FINALIZED_PROPOSAL_ID)
            .set(bundle.meta.last_finalized_proposal_id as f64);

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
        let event = self.decode_log_to_event_context(log).await?;
        let last_finalized_proposal_id = self.inbox_last_finalized_proposal_id(log).await?;
        self.build_manifest_from_event(&event, last_finalized_proposal_id).await
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
        let event = self.decode_log_to_event_context(log).await?;
        let proposal_id = event.event.id.to::<u64>();
        let last_finalized_proposal_id = self.inbox_last_finalized_proposal_id(log).await?;

        if proposal_id == 0 {
            info!(proposal_id, "skipping proposal with zero id");
            counter!(DriverMetrics::EVENT_PROPOSALS_SKIPPED_TOTAL).increment(1);
            return Ok(Vec::new());
        }

        let manifest = self.build_manifest_from_event(&event, last_finalized_proposal_id).await?;
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

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::primitives::{
        B256, FixedBytes,
        aliases::{U24, U48},
    };
    use bindings::inbox::LibBlobs::BlobSlice;
    use protocol::shasta::manifest::{BlockManifest, DerivationSourceManifest};

    fn sample_derivation_source(
        blob_hashes: Vec<FixedBytes<32>>,
        is_forced: bool,
    ) -> DerivationSource {
        DerivationSource {
            isForcedInclusion: is_forced,
            blobSlice: BlobSlice {
                blobHashes: blob_hashes,
                offset: U24::from(0u32),
                timestamp: U48::from(0u64),
            },
        }
    }

    #[test]
    fn derivation_source_to_blob_hashes_preserves_order() {
        let source = sample_derivation_source(
            vec![FixedBytes::from([1u8; 32]), FixedBytes::from([2u8; 32])],
            false,
        );
        let hashes = derivation_source_to_blob_hashes(&source);
        assert_eq!(hashes.len(), 2);
        assert_eq!(hashes[0], B256::from([1u8; 32]));
        assert_eq!(hashes[1], B256::from([2u8; 32]));
    }

    #[test]
    fn forced_inclusion_manifest_defaults_when_block_count_invalid() {
        let source = sample_derivation_source(vec![FixedBytes::from([0u8; 32])], true);
        let manifest = DerivationSourceManifest {
            blocks: vec![BlockManifest::default(), BlockManifest::default()],
        };

        let validated = validate_forced_inclusion_manifest(1, &source, manifest);

        assert_eq!(validated.blocks.len(), 1);
    }
}

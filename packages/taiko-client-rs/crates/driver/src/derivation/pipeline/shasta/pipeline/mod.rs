use std::sync::Arc;

use alloy::{
    eips::BlockNumberOrTag,
    primitives::{B256, U256},
    providers::Provider,
    rpc::types::Log,
    sol_types::SolEvent,
};
use alloy_consensus::TxEnvelope;
use alloy_rpc_types::{Transaction as RpcTransaction, eth::Block as RpcBlock};
use async_trait::async_trait;
use bindings::{
    codec_optimized::IInbox::{DerivationSource, ProposedEventPayload},
    i_inbox::IInbox::Proposed,
};
use event_indexer::indexer::ShastaEventIndexer;
use protocol::shasta::manifest::{DerivationSourceManifest, ProposalManifest};
use rpc::{blob::BlobDataSource, client::Client};

use crate::{
    derivation::{
        manifest::{
            ManifestFetcher,
            fetcher::shasta::{ShastaProposalManifestFetcher, ShastaSourceManifestFetcher},
        },
        pipeline::shasta::anchor::AnchorTxConstructor,
    },
    sync::engine::{EngineBlockOutcome, PayloadApplier},
};

use super::super::{DerivationError, DerivationPipeline};

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
    indexer: Arc<ShastaEventIndexer>,
    anchor_constructor: AnchorTxConstructor<P>,
    derivation_source_manifest_fetcher:
        Arc<dyn ManifestFetcher<Manifest = DerivationSourceManifest>>,
    proposal_manifest_fetcher: Arc<dyn ManifestFetcher<Manifest = ProposalManifest>>,
}

impl<P> ShastaDerivationPipeline<P>
where
    P: Provider + Clone + 'static,
{
    /// Create a new derivation pipeline instance.
    ///
    /// Manifests are fetched via the supplied blob source while the driver client is
    /// reused to query both L1 contracts and L2 execution state.
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
            indexer,
            anchor_constructor,
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
            if origin.l2_block_hash != B256::ZERO &&
                let Some(block) =
                    self.rpc.l2_provider.get_block_by_hash(origin.l2_block_hash).await?
            {
                return Ok(block.map_transactions(|tx: RpcTransaction| tx.into()));
            }
        }

        // Use the latest canonical block (common after beacon sync or at
        // startup when only genesis is present).
        self.rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await?
            .map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
            .ok_or(DerivationError::LatestL2BlockMissing)
    }

    /// Extract blob hashes from a derivation source, preserving the order expected by
    /// the decoder.
    fn derivation_source_to_blob_hashes(&self, source: &DerivationSource) -> Vec<B256> {
        source.blobSlice.blobHashes.iter().map(|hash| B256::from_slice(hash.as_ref())).collect()
    }

    /// Decode a proposal log into the event payload.
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
        Ok(fetcher
            .fetch_and_decode_manifest(
                &self.derivation_source_to_blob_hashes(source),
                source.blobSlice.offset.to::<u64>() as usize,
            )
            .await?)
    }

    /// Initialize the rolling parent state used while constructing payload attributes.
    async fn initialize_parent_state(
        &self,
        parent_block: &RpcBlock<TxEnvelope>,
    ) -> Result<(ParentState, u64), DerivationError> {
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
        };

        // TODO: retrieve the fork height from protocol configuration once exposed by bindings.
        let shasta_fork_height = 0u64;

        Ok((state, shasta_fork_height))
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

        // Assemble the full Shasta protocol proposal bundle.
        let bundle = ShastaProposalBundle {
            meta: BundleMeta {
                proposal_id: payload.proposal.id.to::<u64>(),
                proposal_timestamp: payload.proposal.timestamp.to::<u64>(),
                origin_block_number: payload.derivation.originBlockNumber.to::<u64>(),
                proposer: payload.proposal.proposer,
                basefee_sharing_pctg: payload.derivation.basefeeSharingPctg,
                bond_instructions_hash: B256::from(payload.coreState.bondInstructionsHash),
                prover_auth_bytes,
            },
            sources: manifest_segments,
        };

        Ok(bundle)
    }

    // Convert a manifest into execution engine blocks for block production.
    async fn manifest_to_engine_blocks(
        &self,
        manifest: Self::Manifest,
        applier: &(dyn PayloadApplier + Send + Sync),
    ) -> Result<Vec<EngineBlockOutcome>, DerivationError> {
        let ShastaProposalBundle { meta, sources, .. } = manifest;

        let parent_block = self.load_parent_block(meta.proposal_id).await?;
        let proposal_origin_block_hash =
            self.rpc.l1_block_hash_by_number(meta.origin_block_number).await?.ok_or(
                DerivationError::ProposalOriginBlockHashMissing {
                    block_number: meta.origin_block_number,
                },
            )?;

        let (mut parent_state, shasta_fork_height) =
            self.initialize_parent_state(&parent_block).await?;

        self.build_payloads_from_sources(
            sources,
            &meta,
            proposal_origin_block_hash,
            shasta_fork_height,
            &mut parent_state,
            applier,
        )
        .await
    }
}

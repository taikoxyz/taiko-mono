use std::sync::Arc;

use alethia_reth::payload::attributes::TaikoPayloadAttributes;
use alloy::{primitives::B256, providers::Provider, rpc::types::Log, sol_types::SolEvent};
use anyhow::Error;
use async_trait::async_trait;
use bindings::{
    codec_optimized::IInbox::{DerivationSource, ProposedEventPayload},
    i_inbox::IInbox::Proposed,
};
use protocol::shasta::manifest::{DerivationSourceManifest, ProposalManifest};
use rpc::client::Client;

use crate::derivation::manifest::ManifestFetcher;

use super::{DerivationError, DerivationPipeline};

/// Shasta-specific derivation pipeline.
pub struct ShastaDerivationPipeline<P>
where
    P: Provider + Clone,
{
    rpc: Client<P>,
    source_manifest_fetcher: Arc<dyn ManifestFetcher<Manifest = DerivationSourceManifest>>,
    proposal_manifest_fetcher: Arc<dyn ManifestFetcher<Manifest = ProposalManifest>>,
}

impl<P> ShastaDerivationPipeline<P>
where
    P: Provider + Clone,
{
    /// Create a new derivation pipeline instance.
    pub fn new(
        rpc: Client<P>,
        source_manifest_fetcher: Arc<dyn ManifestFetcher<Manifest = DerivationSourceManifest>>,
        proposal_manifest_fetcher: Arc<dyn ManifestFetcher<Manifest = ProposalManifest>>,
    ) -> Self {
        Self { rpc, source_manifest_fetcher, proposal_manifest_fetcher }
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
        self.rpc
            .shasta
            .codec
            .decodeProposedEvent(Proposed::decode_log_data(log.data())?.data)
            .call()
            .await
            .map_err(|err| DerivationError::Other(Error::msg(err.to_string())))
    }

    async fn fetch_and_decode_source_manifest<M>(
        &self,
        fetcher: &dyn ManifestFetcher<Manifest = M>,
        source: &DerivationSource,
    ) -> Result<M, DerivationError>
    where
        M: Send,
    {
        fetcher
            .fetch_and_decode_manifest(
                &self.derivation_source_to_blob_hashes(source),
                source.blobSlice.offset.to::<u64>() as usize,
            )
            .await
            .map_err(|err| DerivationError::Other(Error::msg(err.to_string())))
    }
}

#[async_trait]
impl<P> DerivationPipeline for ShastaDerivationPipeline<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    type Manifest = ProposalManifest;

    async fn log_to_manifest(&self, log: &Log) -> Result<Self::Manifest, DerivationError> {
        let payload = self.decode_log_to_event_payload(log).await?;
        let sources = &payload.derivation.sources;

        // If sources is empty, we return an error, which should never happen for the current
        // Shasta protocol inbox implementation.
        let Some((last_source, forced_inclusion_sources)) = sources.split_last() else {
            return Err(DerivationError::EmptyDerivationSources(payload.proposal.id.to()));
        };

        // Fetch the forced inclusion sources first.
        let mut combined_sources = Vec::new();
        for source in forced_inclusion_sources {
            combined_sources.push(
                self.fetch_and_decode_source_manifest(
                    self.source_manifest_fetcher.as_ref(),
                    source,
                )
                .await?,
            );
        }

        // Fetch the proposal manifest last.
        let mut final_manifest: ProposalManifest = self
            .fetch_and_decode_source_manifest(self.proposal_manifest_fetcher.as_ref(), last_source)
            .await?;

        combined_sources.extend(final_manifest.sources);
        final_manifest.sources = combined_sources;

        Ok(final_manifest)
    }

    async fn manifest_to_payload_attributes(
        &self,
        _manifests: Self::Manifest,
    ) -> Result<Vec<TaikoPayloadAttributes>, DerivationError> {
        Ok(Vec::new())
    }
}

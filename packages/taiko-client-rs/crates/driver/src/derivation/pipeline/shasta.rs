use std::sync::Arc;

use alethia_reth::payload::attributes::TaikoPayloadAttributes;
use alloy::{primitives::B256, providers::Provider, rpc::types::Log, sol_types::SolEvent};
use anyhow::Error;
use async_trait::async_trait;
use bindings::i_inbox::IInbox::Proposed;
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
}

#[async_trait]
impl<P> DerivationPipeline for ShastaDerivationPipeline<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    type Manifest = ProposalManifest;

    async fn log_to_manifests(&self, log: &Log) -> Result<Vec<Self::Manifest>, DerivationError> {
        let payload = self
            .rpc
            .shasta
            .codec
            .decodeProposedEvent(Proposed::decode_log_data(log.data())?.data)
            .call()
            .await
            .map_err(|err| DerivationError::Other(Error::msg(err.to_string())))?;

        let sources = &payload.derivation.sources;
        if sources.is_empty() {
            return Ok(vec![ProposalManifest::default()]);
        }

        let (last_source, prefix_sources) =
            sources.split_last().expect("sources is non-empty due to earlier check");

        let mut combined_sources = Vec::with_capacity(prefix_sources.len());
        for source in prefix_sources {
            let blob_hashes: Vec<B256> = source
                .blobSlice
                .blobHashes
                .iter()
                .map(|hash| B256::from_slice(hash.as_ref()))
                .collect();

            let offset = source.blobSlice.offset.to::<u64>() as usize;
            let manifest = self
                .source_manifest_fetcher
                .fetch_and_decode_manifest(&blob_hashes, offset)
                .await
                .map_err(|err| DerivationError::Other(Error::msg(err.to_string())))?;

            combined_sources.push(manifest);
        }

        let last_blob_hashes: Vec<B256> = last_source
            .blobSlice
            .blobHashes
            .iter()
            .map(|hash| B256::from_slice(hash.as_ref()))
            .collect();
        let last_offset = last_source.blobSlice.offset.to::<u64>() as usize;

        let mut final_manifest = self
            .proposal_manifest_fetcher
            .fetch_and_decode_manifest(&last_blob_hashes, last_offset)
            .await
            .map_err(|err| DerivationError::Other(Error::msg(err.to_string())))?;

        final_manifest.sources.extend(combined_sources);

        Ok(vec![final_manifest])
    }

    async fn manifests_to_payload_attributes(
        &self,
        _manifests: &[Self::Manifest],
    ) -> Result<Vec<TaikoPayloadAttributes>, DerivationError> {
        Ok(Vec::new())
    }
}

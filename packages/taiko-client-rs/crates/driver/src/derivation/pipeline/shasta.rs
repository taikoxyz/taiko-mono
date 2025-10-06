use std::sync::Arc;

use alethia_reth::payload::attributes::TaikoPayloadAttributes;
use alloy::{primitives::B256, providers::Provider, rpc::types::Log};
use anyhow::Error;
use async_trait::async_trait;
use protocol::shasta::manifest::ProposalManifest;
use rpc::client::Client;

use crate::derivation::manifest::ManifestFetcher;

use super::{DerivationError, DerivationPipeline};

/// Shasta-specific derivation pipeline.
pub struct ShastaDerivationPipeline<P>
where
    P: Provider + Clone,
{
    rpc: Client<P>,
    manifest_fetcher: Arc<dyn ManifestFetcher<Manifest = ProposalManifest>>,
}

impl<P> ShastaDerivationPipeline<P>
where
    P: Provider + Clone,
{
    /// Create a new derivation pipeline instance.
    pub fn new(
        rpc: Client<P>,
        manifest_fetcher: Arc<dyn ManifestFetcher<Manifest = ProposalManifest>>,
    ) -> Self {
        Self { rpc, manifest_fetcher }
    }
}

#[async_trait]
impl<P> DerivationPipeline for ShastaDerivationPipeline<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    type Manifest = ProposalManifest;

    async fn log_to_manifests(&self, log: &Log) -> Result<Vec<Self::Manifest>, DerivationError> {
        let data = log.data().data.clone();
        let payload = self
            .rpc
            .shasta
            .codec
            .decodeProposedEvent(data)
            .call()
            .await
            .map_err(|err| DerivationError::Other(Error::msg(err.to_string())))?;

        let mut manifests = Vec::new();
        for source in payload.derivation.sources.iter() {
            let blob_hashes: Vec<B256> = source
                .blobSlice
                .blobHashes
                .iter()
                .map(|hash| B256::from_slice(hash.as_ref()))
                .collect();

            let manifest = self
                .manifest_fetcher
                .fetch_and_decode_manifest(
                    &blob_hashes,
                    source.blobSlice.offset.to::<u64>() as usize,
                )
                .await
                .map_err(|err| DerivationError::Other(Error::msg(err.to_string())))?;

            manifests.push(manifest);
        }

        Ok(manifests)
    }

    async fn manifests_to_payload_attributes(
        &self,
        _manifests: &[Self::Manifest],
    ) -> Result<Vec<TaikoPayloadAttributes>, DerivationError> {
        Ok(Vec::new())
    }
}

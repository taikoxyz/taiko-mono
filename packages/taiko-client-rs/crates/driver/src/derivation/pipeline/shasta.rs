use std::sync::Arc;

use alethia_reth::payload::attributes::TaikoPayloadAttributes;
use alloy::{providers::Provider, rpc::types::Log};
use async_trait::async_trait;
use protocol::shasta::manifest::ProposalManifest;

use crate::derivation::manifest::ManifestFetcher;

use super::{DerivationError, DerivationPipeline};

/// Shasta-specific derivation pipeline.
pub struct ShastaDerivationPipeline<P>
where
    P: Provider + Clone,
{
    rpc: rpc::client::Client<P>,
    manifest_fetcher: Arc<dyn ManifestFetcher<Manifest = ProposalManifest>>,
}

impl<P> ShastaDerivationPipeline<P>
where
    P: Provider + Clone,
{
    /// Create a new derivation pipeline instance.
    pub fn new(
        rpc: rpc::client::Client<P>,
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
    async fn process_proposal(
        &self,
        _log: &Log,
    ) -> Result<Vec<TaikoPayloadAttributes>, DerivationError> {
        let _ = (&self.rpc, &self.manifest_fetcher);
        todo!()
    }
}

//! Derivation pipeline abstractions shared across protocol forks.

use alethia_reth::payload::attributes::TaikoPayloadAttributes;
use alloy::rpc::types::Log;
use async_trait::async_trait;

mod error;
pub mod shasta;

pub use error::DerivationError;
pub use shasta::ShastaDerivationPipeline;

/// Trait implemented by derivation pipelines for different protocol forks.
#[async_trait]
pub trait DerivationPipeline: Send + Sync {
    /// Fork-specific manifest type produced by the decoder.
    type Manifest: Send;

    /// Convert a proposal log into one or more manifests for processing.
    async fn log_to_manifests(&self, log: &Log) -> Result<Vec<Self::Manifest>, DerivationError>;

    /// Convert a set of manifests into payload attributes for block production.
    async fn manifests_to_payload_attributes(
        &self,
        manifests: &[Self::Manifest],
    ) -> Result<Vec<TaikoPayloadAttributes>, DerivationError>;

    /// Process the provided proposal log, returning payload attributes to deliver to the engine.
    async fn process_proposal(
        &self,
        log: &Log,
    ) -> Result<Vec<TaikoPayloadAttributes>, DerivationError> {
        let manifests = self.log_to_manifests(log).await?;
        self.manifests_to_payload_attributes(&manifests).await
    }
}

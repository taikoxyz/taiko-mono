//! Derivation pipeline abstractions shared across protocol forks.

use alloy::rpc::types::Log;
use async_trait::async_trait;

mod error;
pub mod shasta;

pub use error::DerivationError;
pub use shasta::ShastaDerivationPipeline;

use crate::sync::engine::{EngineBlockOutcome, PayloadApplier};

/// Trait implemented by derivation pipelines for different protocol forks.
#[async_trait]
pub trait DerivationPipeline: Send + Sync {
    /// Fork-specific manifest types.
    type Manifest: Send;

    /// Convert a proposal log into a manifest for processing.
    async fn log_to_manifest(&self, log: &Log) -> Result<Self::Manifest, DerivationError>;

    /// Convert a manifest into execution engine blocks for block production.
    async fn manifest_to_engine_blocks(
        &self,
        manifest: Self::Manifest,
        applier: &(dyn PayloadApplier + Send + Sync),
    ) -> Result<Vec<EngineBlockOutcome>, DerivationError>;

    /// Process the provided proposal log, materialising the derived blocks in the execution
    /// engine.
    async fn process_proposal(
        &self,
        log: &Log,
        applier: &(dyn PayloadApplier + Send + Sync),
    ) -> Result<Vec<EngineBlockOutcome>, DerivationError> {
        let manifest = self.log_to_manifest(log).await?;
        self.manifest_to_engine_blocks(manifest, applier).await
    }
}

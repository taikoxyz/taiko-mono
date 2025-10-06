//! Derivation pipeline abstractions shared across protocol forks.

use alethia_reth::payload::attributes::TaikoPayloadAttributes;
use alloy::rpc::types::Log;
use async_trait::async_trait;
use rpc::RpcClientError;
use thiserror::Error;

pub mod shasta;

pub use shasta::ShastaDerivationPipeline;

/// Errors emitted by derivation stages.
#[derive(Debug, Error)]
pub enum DerivationError {
    /// RPC failure while talking to the execution engine.
    #[error(transparent)]
    Rpc(#[from] RpcClientError),
    /// The required L2 block has not been produced yet.
    #[error("l2 block {0} not yet available")]
    BlockUnavailable(u64),
    /// Missing metadata required to finalise the proposal.
    #[error("proposal metadata incomplete for id {0}")]
    IncompleteMetadata(u64),
    /// Generic error bucket.
    #[error(transparent)]
    Other(#[from] anyhow::Error),
}

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

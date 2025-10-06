//! Derivation pipeline abstractions shared across protocol forks.

use alethia_reth::payload::attributes::TaikoPayloadAttributes;
use alloy::rpc::types::Log;
use async_trait::async_trait;
use thiserror::Error;

pub mod shasta;

pub use shasta::ShastaDerivationPipeline;

/// Errors emitted by derivation stages.
#[derive(Debug, Error)]
pub enum DerivationError {
    /// RPC failure while talking to the execution engine.
    #[error(transparent)]
    Rpc(#[from] rpc::error::RpcClientError),
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
    /// Process the provided proposal log, updating the execution engine state as needed.
    async fn process_proposal(
        &self,
        log: &Log,
    ) -> Result<Vec<TaikoPayloadAttributes>, DerivationError>;
}

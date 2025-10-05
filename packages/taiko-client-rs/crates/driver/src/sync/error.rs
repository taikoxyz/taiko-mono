//! Synchronization error types.

use event_indexer::error::IndexerError;
use std::result::Result as StdResult;
use thiserror::Error;

/// Result type alias for sync operations.
pub type Result<T> = StdResult<T, SyncError>;

/// Errors emitted by sync components.
#[derive(Debug, Error)]
pub enum SyncError {
    /// Beacon sync: checkpoint node has no L1 origin.
    #[error("checkpoint node has no L1 origin")]
    CheckpointNoOrigin,

    /// Beacon sync: failed to query checkpoint head.
    #[error("failed to query checkpoint head: {0}")]
    CheckpointQuery(String),

    /// Beacon sync: failed to submit remote block.
    #[error("failed to submit remote block {block_number}: {error}")]
    RemoteBlockSubmit { block_number: u64, error: String },

    /// Beacon sync: checkpoint head behind local head.
    #[error("checkpoint head {checkpoint} is behind local head {local}")]
    CheckpointBehind { checkpoint: u64, local: u64 },

    /// Event sync: indexer initialization failed.
    #[error("failed to initialize event indexer: {0}")]
    IndexerInit(String),

    /// Event sync: indexer task terminated unexpectedly.
    #[error("event indexer task terminated unexpectedly")]
    IndexerTerminated,

    /// Event sync: derivation failed.
    #[error("derivation failed: {0}")]
    Derivation(String),

    /// Event sync: RPC error.
    #[error("RPC error: {0}")]
    Rpc(String),

    /// Generic sync error.
    #[error("{0}")]
    Other(String),
}

// Manual From implementations
impl From<IndexerError> for SyncError {
    fn from(err: IndexerError) -> Self {
        SyncError::IndexerInit(err.to_string())
    }
}

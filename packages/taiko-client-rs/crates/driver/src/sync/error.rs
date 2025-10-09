//! Synchronization error types.

use anyhow::Error as AnyhowError;
use event_indexer::error::IndexerError;
use rpc::RpcClientError;
use std::result::Result as StdResult;
use thiserror::Error;

use crate::derivation::DerivationError;

/// Result type alias for sync operations.
pub type Result<T> = StdResult<T, SyncError>;

/// Errors emitted by sync components.
#[derive(Debug, Error)]
pub enum SyncError {
    /// Beacon sync: checkpoint node has no L1 origin.
    #[error("checkpoint node has no L1 origin")]
    CheckpointNoOrigin,

    /// Beacon sync: failed to query checkpoint head.
    #[error("failed to query checkpoint head")]
    CheckpointQuery(#[source] RpcClientError),

    /// Beacon sync: failed to submit remote block.
    #[error("failed to submit remote block {block_number}")]
    RemoteBlockSubmit {
        block_number: u64,
        #[source]
        error: AnyhowError,
    },

    /// Beacon sync: checkpoint head behind local head.
    #[error("checkpoint head {checkpoint} is behind local head {local}")]
    CheckpointBehind { checkpoint: u64, local: u64 },

    /// Event sync: indexer initialization failed.
    #[error("failed to initialize event indexer")]
    IndexerInit(#[from] IndexerError),

    /// Event sync: indexer task terminated unexpectedly.
    #[error("event indexer task terminated unexpectedly")]
    IndexerTerminated,

    /// Event sync: derivation failed.
    #[error("derivation failed")]
    Derivation(#[from] DerivationError),

    /// Event sync: RPC error.
    #[error(transparent)]
    Rpc(#[from] RpcClientError),

    /// Generic sync error.
    #[error(transparent)]
    Other(#[from] AnyhowError),
}

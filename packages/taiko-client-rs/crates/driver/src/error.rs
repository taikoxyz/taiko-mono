//! Driver specific error types.

use thiserror::Error;
use tokio::sync::oneshot::error::RecvError;

use crate::sync::{SyncError, error::EngineSubmissionError};

/// Convenient result alias for driver operations.
pub type Result<T> = std::result::Result<T, DriverError>;

/// Error variants emitted by the driver.
#[derive(Debug, Error)]
pub enum DriverError {
    /// Errors originating from the RPC client layer.
    #[error("rpc error: {0}")]
    Rpc(#[from] rpc::error::RpcClientError),

    /// Sync subsystem reported a failure.
    #[error(transparent)]
    Sync(#[from] SyncError),

    /// Block not found on remote node.
    #[error("remote node missing block {0}")]
    BlockNotFound(u64),

    /// Engine API returned syncing status.
    #[error("engine API returned SYNCING for block {0}")]
    EngineSyncing(u64),

    /// Engine API returned invalid payload.
    #[error("engine API returned INVALID: {0}")]
    EngineInvalidPayload(String),

    /// Preconfirmation payload injection failed with context.
    #[error("preconfirmation injection failed for block {block_number}: {source}")]
    PreconfInjectionFailed {
        block_number: u64,
        #[source]
        source: EngineSubmissionError,
    },

    /// Timed out while enqueuing a preconfirmation payload.
    #[error("preconfirmation enqueue timed out after {waited:?}")]
    PreconfEnqueueTimeout { waited: std::time::Duration },

    /// Channel send failed when enqueueing a preconfirmation payload.
    #[error("failed to enqueue preconfirmation: {0}")]
    PreconfEnqueueFailed(String),

    /// Timed out waiting for a preconfirmation processing response.
    #[error("preconfirmation result timed out after {waited:?}")]
    PreconfResponseTimeout { waited: std::time::Duration },

    /// Response channel for a preconfirmation payload was closed before delivery.
    #[error("preconfirmation response dropped: {recv_error}")]
    PreconfResponseDropped {
        #[from]
        #[source]
        recv_error: RecvError,
    },

    /// Generic boxed error.
    #[error(transparent)]
    Other(#[from] anyhow::Error),
}

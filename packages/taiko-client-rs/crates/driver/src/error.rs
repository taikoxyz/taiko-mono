//! Driver specific error types.

use std::{io, path::PathBuf, result::Result as StdResult, time::Duration};

use anyhow::Error as AnyhowError;
#[cfg(feature = "standalone-rpc")]
use reth_ipc::server::IpcServerStartError;
use rpc::error::RpcClientError;
use thiserror::Error;
use tokio::sync::oneshot::error::RecvError;

use crate::sync::{SyncError, error::EngineSubmissionError};

/// Convenient result alias for driver operations.
pub type Result<T> = StdResult<T, DriverError>;

/// Error variants emitted by the driver.
#[derive(Debug, Error)]
pub enum DriverError {
    /// Errors originating from the RPC client layer.
    #[error("rpc error: {0}")]
    Rpc(#[from] RpcClientError),

    /// Sync subsystem reported a failure.
    #[error(transparent)]
    Sync(#[from] SyncError),

    /// I/O error emitted by the runtime.
    #[error("io error: {0}")]
    Io(#[from] io::Error),

    /// Driver RPC server requires a JWT secret path when enabled.
    #[error("driver RPC JWT secret path is required")]
    DriverRpcJwtSecretMissing,

    /// Failed to read the JWT secret configured for the driver RPC server.
    #[error("failed to read jwt secret for driver RPC server")]
    DriverRpcJwtSecretReadFailed,

    /// IPC server failed to start.
    #[cfg(feature = "standalone-rpc")]
    #[error("failed to start IPC server: {0}")]
    IpcServerStart(#[from] IpcServerStartError),

    /// A non-socket file exists at the IPC socket path.
    #[error("non-socket file exists at IPC path: {0}")]
    IpcPathNotSocket(PathBuf),

    /// IPC socket is already in use by another running server.
    #[error("IPC socket already in use: {path}")]
    IpcSocketInUse {
        /// Path to the socket that is already in use.
        path: PathBuf,
    },

    /// Preconfirmation support is disabled in the driver configuration.
    #[error("preconfirmation is not enabled in driver config")]
    PreconfirmationDisabled,

    /// Preconfirmation ingress loop has not started yet.
    #[error("preconfirmation ingress loop is not ready")]
    PreconfIngressNotReady,

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
    PreconfEnqueueTimeout { waited: Duration },

    /// Channel send failed when enqueueing a preconfirmation payload.
    #[error("failed to enqueue preconfirmation: {0}")]
    PreconfEnqueueFailed(String),

    /// Timed out waiting for a preconfirmation processing response.
    #[error("preconfirmation result timed out after {waited:?}")]
    PreconfResponseTimeout { waited: Duration },

    /// Response channel for a preconfirmation payload was closed before delivery.
    #[error("preconfirmation response dropped: {recv_error}")]
    PreconfResponseDropped {
        #[from]
        #[source]
        recv_error: RecvError,
    },

    /// Generic boxed error.
    #[error(transparent)]
    Other(#[from] AnyhowError),
}

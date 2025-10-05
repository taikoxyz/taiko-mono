//! Driver specific error types.

use thiserror::Error;

use crate::sync::SyncError;

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
    /// Generic boxed error.
    #[error(transparent)]
    Other(#[from] anyhow::Error),
}

//! Error types for the P2P SDK.

use std::time::Duration;

use preconfirmation_service::NetworkError;
use thiserror::Error;

/// Convenient result alias for SDK operations.
pub type Result<T> = std::result::Result<T, P2pSdkError>;

/// Unified error surface exposed by the SDK.
#[derive(Debug, Error)]
pub enum P2pSdkError {
    /// Underlying network-layer failure surfaced from `preconfirmation_service`.
    #[error("network: {0}")]
    Network(#[from] NetworkError),
    /// Validation failure (e.g., signature, slot, size limits).
    #[error("validation: {0}")]
    Validation(String),
    /// Storage backend failure.
    #[error("storage: {0}")]
    Storage(String),
    /// Request/response timed out after the specified duration.
    #[error("timeout after {0:?}")]
    Timeout(Duration),
    /// Local backpressure guard rejected an enqueue.
    #[error("backpressure: channel full")]
    Backpressure,
    /// SDK is shutting down or the caller raced a shutdown path.
    #[error("shutdown")]
    Shutdown,
    /// Catch-all for unexpected conditions.
    #[error("other: {0}")]
    Other(String),
}

impl From<&str> for P2pSdkError {
    /// Convert a string slice into a generic `Other` error.
    fn from(value: &str) -> Self {
        Self::Other(value.to_owned())
    }
}

impl From<anyhow::Error> for P2pSdkError {
    /// Convert an `anyhow::Error` into a generic `Other` error.
    fn from(err: anyhow::Error) -> Self {
        Self::Other(err.to_string())
    }
}

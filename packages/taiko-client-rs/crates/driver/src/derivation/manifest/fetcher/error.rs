use rpc::{blob::BlobDataError, error::RpcClientError};
use thiserror::Error;

/// Errors that can occur while fetching or decoding manifests.
#[derive(Debug, Error)]
pub enum ManifestFetcherError {
    /// Index out of bounds when selecting a derivation source.
    #[error("invalid derivation source index {0}")]
    InvalidSourceIndex(usize),
    /// Blob fetching failed.
    #[error(transparent)]
    Blob(#[from] BlobDataError),
    /// RPC failure while retrieving blob sidecars from beacon.
    #[error(transparent)]
    Rpc(#[from] RpcClientError),
    /// Mismatch between requested and received blob counts.
    #[error("blob count mismatch: expected {expected}, got {actual}")]
    BlobCountMismatch { expected: usize, actual: usize },
    /// Manifest bytes were invalid.
    #[error("invalid shasta manifest: {0}")]
    Invalid(String),
}

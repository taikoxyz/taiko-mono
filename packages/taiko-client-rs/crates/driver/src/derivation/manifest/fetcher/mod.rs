use rpc::{blob::BlobDataError, error::RpcClientError};
use thiserror::Error;

/// Shasta manifest fetcher implementation.
pub mod shasta;

pub use shasta::ShastaSourceManifestFetcher;

/// Errors that can occur while fetching or decoding manifests.
#[derive(Debug, Error)]
pub enum ManifestFetcherError {
    /// No blob hashes were provided for retrieval.
    #[error("no blob hashes provided for manifest fetch")]
    EmptyBlobHashes,
    /// No blob sidecars were provided for decoding.
    #[error("no blob sidecars provided for manifest decode")]
    EmptyBlobSidecars,
    /// Blob fetching failed.
    #[error(transparent)]
    Blob(#[from] BlobDataError),
    /// RPC failure while retrieving blob sidecars from beacon.
    #[error(transparent)]
    Rpc(#[from] RpcClientError),
    /// Mismatch between requested and received blob counts.
    #[error("blob count mismatch: expected {expected}, got {actual}")]
    BlobCountMismatch {
        /// Number of blob hashes requested by the caller.
        expected: usize,
        /// Number of sidecars returned by the data source.
        actual: usize,
    },
    /// Manifest bytes were invalid.
    #[error("invalid shasta manifest: {0}")]
    Invalid(String),
}

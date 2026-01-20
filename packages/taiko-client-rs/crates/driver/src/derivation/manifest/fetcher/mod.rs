use alloy_consensus::BlobTransactionSidecar;
use alloy_primitives::B256;
use async_trait::async_trait;
use rpc::{
    blob::{BlobDataError, BlobDataSource},
    error::RpcClientError,
};
use thiserror::Error;
use tracing::{debug, error};

pub mod shasta;

pub use shasta::ShastaSourceManifestFetcher;

/// Errors that can occur while fetching or decoding manifests.
#[derive(Debug, Error)]
pub enum ManifestFetcherError {
    /// Index out of bounds when selecting a derivation source.
    #[error("invalid derivation source index {0}")]
    InvalidSourceIndex(usize),
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
    BlobCountMismatch { expected: usize, actual: usize },
    /// Manifest bytes were invalid.
    #[error("invalid shasta manifest: {0}")]
    Invalid(String),
}

/// Trait describing manifest fetch behaviour for different forks.
#[async_trait]
pub trait ManifestFetcher: Send + Sync {
    /// Fork-specific manifest type produced by the decoder.
    type Manifest;

    /// Access the blob data source used by this fetcher.
    fn blob_source(&self) -> &BlobDataSource;

    /// Fetch blobs from the provided source for the given blob hashes.
    async fn fetch_blobs(
        &self,
        timestamp: u64,
        blob_hashes: &[B256],
    ) -> Result<Vec<BlobTransactionSidecar>, ManifestFetcherError> {
        if blob_hashes.is_empty() {
            return Err(ManifestFetcherError::EmptyBlobHashes);
        }

        debug!(hash_count = blob_hashes.len(), timestamp, "fetching blob sidecars");
        let sidecars = self.blob_source().get_blobs(timestamp, blob_hashes).await?;
        if sidecars.len() != blob_hashes.len() {
            error!(
                expected = blob_hashes.len(),
                actual = sidecars.len(),
                "blob response count mismatch"
            );
            return Err(ManifestFetcherError::BlobCountMismatch {
                expected: blob_hashes.len(),
                actual: sidecars.len(),
            });
        }

        Ok(sidecars)
    }

    /// Decode the manifest for the given sidecars.
    async fn decode_manifest(
        &self,
        sidecars: &[BlobTransactionSidecar],
        offset: usize,
    ) -> Result<Self::Manifest, ManifestFetcherError>;

    /// Fetch and decode the manifest for the given blob hashes.
    async fn fetch_and_decode_manifest(
        &self,
        timestamp: u64,
        blob_hashes: &[B256],
        offset: usize,
    ) -> Result<Self::Manifest, ManifestFetcherError> {
        let sidecars = self.fetch_blobs(timestamp, blob_hashes).await?;
        self.decode_manifest(&sidecars, offset).await
    }
}

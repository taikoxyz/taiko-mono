use alloy_consensus::BlobTransactionSidecar;
use alloy_primitives::B256;
use async_trait::async_trait;

pub mod error;
pub mod shasta;

pub use error::ManifestFetcherError;
use rpc::blob::BlobDataSource;
pub use shasta::{ShastaProposalManifestFetcher, ShastaSourceManifestFetcher};
use tracing::error;

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
        blob_hashes: &[B256],
    ) -> Result<Vec<BlobTransactionSidecar>, ManifestFetcherError> {
        if blob_hashes.is_empty() {
            return Err(ManifestFetcherError::EmptyBlobHashes);
        }

        let sidecars = self.blob_source().get_blobs(blob_hashes).await?;
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
        blob_hashes: &[B256],
        offset: usize,
    ) -> Result<Self::Manifest, ManifestFetcherError> {
        let sidecars = self.fetch_blobs(blob_hashes).await?;
        self.decode_manifest(&sidecars, offset).await
    }
}

use std::sync::Arc;

use alloy_consensus::BlobTransactionSidecar;
use alloy_primitives::B256;
use protocol::shasta::{BlobCoder, manifest::DerivationSourceManifest};
use rpc::blob::BlobDataSource;
use tracing::{debug, error, instrument};

use super::ManifestFetcherError;

/// Decode a Shasta derivation-source manifest from blob sidecars.
fn decode_manifest_from_sidecars(
    sidecars: &[BlobTransactionSidecar],
    offset: usize,
    max_blocks: usize,
) -> Result<DerivationSourceManifest, ManifestFetcherError> {
    if sidecars.is_empty() {
        return Err(ManifestFetcherError::EmptyBlobSidecars);
    }

    let mut concatenated = Vec::new();

    for sidecar in sidecars {
        let decoded = BlobCoder::decode_blobs(&sidecar.blobs)
            .ok_or_else(|| ManifestFetcherError::Invalid("invalid blob encoding".to_string()))?;

        for chunk in decoded {
            concatenated.extend_from_slice(&chunk);
        }
    }

    DerivationSourceManifest::decompress_and_decode_with_max_blocks(
        &concatenated,
        offset,
        max_blocks,
    )
    .map_err(|err| ManifestFetcherError::Invalid(err.to_string()))
}

/// Fetcher for Shasta derivation source manifests from blob sidecars.
#[derive(Clone)]
pub struct ShastaSourceManifestFetcher {
    /// Blob data source used to fetch sidecars.
    blob_source: Arc<BlobDataSource>,
}

impl ShastaSourceManifestFetcher {
    /// Create a new Shasta manifest fetcher with the given blob source.
    pub fn new(blob_source: Arc<BlobDataSource>) -> Self {
        Self { blob_source }
    }

    /// Fetch blob sidecars for the given blob hashes.
    async fn fetch_blobs(
        &self,
        timestamp: u64,
        blob_hashes: &[B256],
    ) -> Result<Vec<BlobTransactionSidecar>, ManifestFetcherError> {
        if blob_hashes.is_empty() {
            return Err(ManifestFetcherError::EmptyBlobHashes);
        }

        debug!(hash_count = blob_hashes.len(), timestamp, "fetching blob sidecars");
        let sidecars = self.blob_source.get_blobs(timestamp, blob_hashes).await?;
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

    /// Fetch and decode the manifest for the given blob hashes.
    #[instrument(skip(self, blob_hashes), fields(hash_count = blob_hashes.len(), offset))]
    pub async fn fetch_and_decode_manifest(
        &self,
        timestamp: u64,
        blob_hashes: &[B256],
        offset: usize,
        max_blocks: usize,
    ) -> Result<DerivationSourceManifest, ManifestFetcherError> {
        let sidecars = self.fetch_blobs(timestamp, blob_hashes).await?;
        let manifest = decode_manifest_from_sidecars(&sidecars, offset, max_blocks)?;
        debug!(offset, max_blocks, "decoded shasta manifest from blob sidecars");
        Ok(manifest)
    }
}

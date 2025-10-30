use std::sync::Arc;

use alloy_consensus::BlobTransactionSidecar;
use async_trait::async_trait;
use protocol::shasta::{BlobCoder, manifest::DerivationSourceManifest};
use rpc::blob::BlobDataSource;

use super::{ManifestFetcher, ManifestFetcherError};

// Helper to decode a manifest from sidecars using the derivation manifest decoder.
fn decode_manifest_from_sidecars(
    sidecars: &[BlobTransactionSidecar],
    offset: usize,
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

    DerivationSourceManifest::decompress_and_decode(&concatenated, offset)
        .map_err(|err| ManifestFetcherError::Invalid(err.to_string()))
}

#[derive(Clone)]
pub struct ShastaSourceManifestFetcher {
    blob_source: Arc<BlobDataSource>,
}

impl ShastaSourceManifestFetcher {
    /// Create a new Shasta manifest fetcher with the given blob source.
    pub fn new(blob_source: BlobDataSource) -> Self {
        Self { blob_source: Arc::new(blob_source) }
    }
}

#[async_trait]
impl ManifestFetcher for ShastaSourceManifestFetcher {
    type Manifest = DerivationSourceManifest;

    /// Access the underlying blob data source.
    fn blob_source(&self) -> &BlobDataSource {
        &self.blob_source
    }

    /// Decode a manifest from the provided sidecars and offset.
    async fn decode_manifest(
        &self,
        sidecars: &[BlobTransactionSidecar],
        offset: usize,
    ) -> Result<Self::Manifest, ManifestFetcherError> {
        decode_manifest_from_sidecars(sidecars, offset)
    }
}

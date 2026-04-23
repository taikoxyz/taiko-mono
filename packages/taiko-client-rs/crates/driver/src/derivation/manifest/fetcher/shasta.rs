use std::sync::Arc;

use alloy_consensus::BlobTransactionSidecar;
use async_trait::async_trait;
use protocol::shasta::{
    BlobCoder, constants::derivation_source_max_blocks_for_timestamp,
    manifest::DerivationSourceManifest,
};
use rpc::blob::BlobDataSource;
use tracing::{debug, instrument};

use super::{ManifestFetcher, ManifestFetcherError};

/// Decode a Shasta derivation-source manifest from blob sidecars.
fn decode_manifest_from_sidecars(
    sidecars: &[BlobTransactionSidecar],
    offset: usize,
    chain_id: u64,
    timestamp: u64,
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

    let max_blocks = derivation_source_max_blocks_for_timestamp(chain_id, timestamp)
        .map_err(|err| ManifestFetcherError::Invalid(err.to_string()))?;

    DerivationSourceManifest::decompress_and_decode_with_limit(&concatenated, offset, max_blocks)
        .map_err(|err| ManifestFetcherError::Invalid(err.to_string()))
}

/// Fetcher for Shasta derivation source manifests from blob sidecars.
#[derive(Clone)]
pub struct ShastaSourceManifestFetcher {
    /// Blob data source used to fetch sidecars.
    blob_source: Arc<BlobDataSource>,
    /// L2 chain ID used to resolve timestamp-aware manifest limits.
    chain_id: u64,
}

impl ShastaSourceManifestFetcher {
    /// Create a new Shasta manifest fetcher with the given blob source.
    pub fn new(blob_source: Arc<BlobDataSource>, chain_id: u64) -> Self {
        Self { blob_source, chain_id }
    }
}

#[async_trait]
impl ManifestFetcher for ShastaSourceManifestFetcher {
    /// The type of manifest produced by this fetcher.
    type Manifest = DerivationSourceManifest;

    /// Access the underlying blob data source.
    fn blob_source(&self) -> &BlobDataSource {
        &self.blob_source
    }

    /// Decode a manifest from the provided sidecars and offset.
    #[instrument(skip(self, sidecars), fields(sidecar_count = sidecars.len(), offset))]
    async fn decode_manifest(
        &self,
        sidecars: &[BlobTransactionSidecar],
        offset: usize,
        timestamp: u64,
    ) -> Result<Self::Manifest, ManifestFetcherError> {
        let manifest = decode_manifest_from_sidecars(sidecars, offset, self.chain_id, timestamp)?;
        debug!(
            offset,
            timestamp,
            chain_id = self.chain_id,
            "decoded shasta manifest from blob sidecars"
        );
        Ok(manifest)
    }
}

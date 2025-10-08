use std::sync::Arc;

use alloy_consensus::BlobTransactionSidecar;
use async_trait::async_trait;
use protocol::shasta::manifest::{DerivationSourceManifest, ProposalManifest};
use rpc::blob::BlobDataSource;

use super::{ManifestFetcher, ManifestFetcherError};

fn decode_proposal_manifest_from_sidecars(
    sidecars: &[BlobTransactionSidecar],
    offset: usize,
) -> Result<ProposalManifest, ManifestFetcherError> {
    if sidecars.is_empty() {
        return Ok(ProposalManifest::default());
    }

    let mut concatenated = Vec::new();
    for sidecar in sidecars {
        for blob in &sidecar.blobs {
            concatenated.extend_from_slice(blob.as_slice());
        }
    }

    ProposalManifest::decompress_and_decode(&concatenated, offset)
        .map_err(|err| ManifestFetcherError::Invalid(err.to_string()))
}

/// Fetcher capable of retrieving proposal manifests.
#[derive(Clone)]
pub struct ShastaProposalManifestFetcher {
    blob_source: Arc<BlobDataSource>,
}

impl ShastaProposalManifestFetcher {
    /// Create a new fetcher backed by the provided [`BlobDataSource`].
    pub fn new(blob_source: BlobDataSource) -> Self {
        Self { blob_source: Arc::new(blob_source) }
    }
}

#[async_trait]
impl ManifestFetcher for ShastaProposalManifestFetcher {
    type Manifest = ProposalManifest;

    fn blob_source(&self) -> &BlobDataSource {
        &self.blob_source
    }

    async fn decode_manifest(
        &self,
        sidecars: &[BlobTransactionSidecar],
        offset: usize,
    ) -> Result<Self::Manifest, ManifestFetcherError> {
        decode_proposal_manifest_from_sidecars(sidecars, offset)
    }
}

/// Fetcher capable of retrieving individual derivation source manifests.
#[derive(Clone)]
pub struct ShastaSourceManifestFetcher {
    blob_source: Arc<BlobDataSource>,
}

impl ShastaSourceManifestFetcher {
    /// Create a new fetcher backed by the provided [`BlobDataSource`].
    pub fn new(blob_source: BlobDataSource) -> Self {
        Self { blob_source: Arc::new(blob_source) }
    }
}

#[async_trait]
impl ManifestFetcher for ShastaSourceManifestFetcher {
    type Manifest = DerivationSourceManifest;

    fn blob_source(&self) -> &BlobDataSource {
        &self.blob_source
    }

    async fn decode_manifest(
        &self,
        sidecars: &[BlobTransactionSidecar],
        offset: usize,
    ) -> Result<Self::Manifest, ManifestFetcherError> {
        let manifest = decode_proposal_manifest_from_sidecars(sidecars, offset)?;
        manifest
            .sources
            .into_iter()
            .next()
            .ok_or_else(|| ManifestFetcherError::Invalid("proposal manifest missing derivation source".into()))
    }
}

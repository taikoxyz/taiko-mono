use std::sync::Arc;

use alloy_consensus::BlobTransactionSidecar;
use async_trait::async_trait;
use protocol::shasta::{
    BlobCoder,
    error::Result as ProtocolResult,
    manifest::{DerivationSourceManifest, ProposalManifest},
};
use rpc::blob::BlobDataSource;

use super::{ManifestFetcher, ManifestFetcherError};

// Helper to decode a manifest from sidecars using the provided decoder function.
fn decode_manifest_from_sidecars<M>(
    sidecars: &[BlobTransactionSidecar],
    offset: usize,
    decoder: fn(&[u8], usize) -> ProtocolResult<M>,
) -> Result<M, ManifestFetcherError> {
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

    decoder(&concatenated, offset).map_err(|err| ManifestFetcherError::Invalid(err.to_string()))
}

#[derive(Clone)]
pub struct ShastaManifestFetcher<M>
where
    M: Send + 'static,
{
    blob_source: Arc<BlobDataSource>,
    decoder: fn(&[u8], usize) -> ProtocolResult<M>,
}

impl<M> ShastaManifestFetcher<M>
where
    M: Send + Default + 'static,
{
    /// Create a new Shasta manifest fetcher with the given blob source and decoder function.
    pub fn new(
        blob_source: BlobDataSource,
        decoder: fn(&[u8], usize) -> ProtocolResult<M>,
    ) -> Self {
        Self { blob_source: Arc::new(blob_source), decoder }
    }
}

#[async_trait]
impl<M> ManifestFetcher for ShastaManifestFetcher<M>
where
    M: Send + Default + 'static,
{
    type Manifest = M;

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
        decode_manifest_from_sidecars(sidecars, offset, self.decoder)
    }
}

pub type ShastaProposalManifestFetcher = ShastaManifestFetcher<ProposalManifest>;
pub type ShastaSourceManifestFetcher = ShastaManifestFetcher<DerivationSourceManifest>;

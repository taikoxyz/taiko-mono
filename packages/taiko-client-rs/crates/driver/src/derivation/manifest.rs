//! Shasta manifest fetching and decoding utilities.

use std::{io::Read, sync::Arc};

use alloy::primitives::B256;
use alloy_rlp::Decodable;
use flate2::read::ZlibDecoder;
use protocol::shasta::{
    constants::{PROPOSAL_MAX_BLOCKS, SHASTA_PAYLOAD_VERSION},
    manifest::ProposalManifest,
};
use rpc::{
    blob::{BlobDataError, BlobDataSource},
    error::RpcClientError,
};
use thiserror::Error;
use tracing::{debug, warn};

use async_trait::async_trait;
use event_indexer::indexer::ProposedEventPayload;

/// Errors that can occur while fetching or decoding manifests.
#[derive(Debug, Error)]
pub enum ManifestError {
    /// Index out of bounds when selecting a derivation source.
    #[error("invalid derivation source index {0}")]
    InvalidSourceIndex(usize),
    /// Blob fetching failed.
    #[error(transparent)]
    Blob(#[from] BlobDataError),
    /// RPC failure while retrieving blob sidecars from beacon.
    #[error(transparent)]
    Rpc(#[from] RpcClientError),
    /// Manifest bytes were invalid.
    #[error("invalid shasta manifest: {0}")]
    Invalid(String),
}

/// Trait describing manifest fetch behaviour for different forks.
#[async_trait]
pub trait ManifestFetcher: Send + Sync {
    /// Fetch and decode the manifest for the given derivation source index.
    async fn fetch_manifest(
        &self,
        payload: &ProposedEventPayload,
        source_idx: usize,
    ) -> Result<ProposalManifest, ManifestError>;
}

/// Fetcher capable of retrieving Shasta manifests for proposals.
#[derive(Clone)]
pub struct ShastaManifestFetcher {
    blob_source: Arc<BlobDataSource>,
}

impl ShastaManifestFetcher {
    /// Create a new fetcher backed by the provided [`BlobDataSource`].
    pub fn new(blob_source: BlobDataSource) -> Self {
        Self { blob_source: Arc::new(blob_source) }
    }
}

impl Default for ShastaManifestFetcher {
    fn default() -> Self {
        Self::new(BlobDataSource::new(None))
    }
}

#[async_trait]
impl ManifestFetcher for ShastaManifestFetcher {
    async fn fetch_manifest(
        &self,
        payload: &ProposedEventPayload,
        source_idx: usize,
    ) -> Result<ProposalManifest, ManifestError> {
        let Some(source) = payload.derivation.sources.get(source_idx) else {
            return Err(ManifestError::InvalidSourceIndex(source_idx));
        };

        let blob_slice = &source.blobSlice;
        let blob_hashes: Vec<B256> =
            blob_slice.blobHashes.iter().map(|hash| B256::from_slice(hash.as_ref())).collect();

        if blob_hashes.is_empty() {
            debug!("no blob hashes supplied; returning default manifest");
            return Ok(ProposalManifest::default());
        }

        let sidecars = self.blob_source.get_blobs(&blob_hashes).await?;

        if sidecars.len() != blob_hashes.len() {
            warn!(
                expected = blob_hashes.len(),
                actual = sidecars.len(),
                "blob response count mismatch"
            );
        }

        let mut concatenated = Vec::new();
        for sidecar in sidecars.iter() {
            for blob in &sidecar.blobs {
                concatenated.extend_from_slice(blob.as_slice());
            }
        }

        let offset = blob_slice.offset.to::<u64>() as usize;
        decode_manifest_bytes(&concatenated, offset)
    }
}


fn decode_manifest_bytes(bytes: &[u8], offset: usize) -> Result<ProposalManifest, ManifestError> {
    if bytes.len() < offset + 64 {
        return Err(ManifestError::Invalid("blob payload shorter than header".into()));
    }

    let version = u32::from_be_bytes(
        bytes[offset + 28..offset + 32]
            .try_into()
            .map_err(|_| ManifestError::Invalid("malformed manifest version".into()))?,
    );
    if version != SHASTA_PAYLOAD_VERSION as u32 {
        warn!(version, "unsupported shasta manifest version");
        return Ok(ProposalManifest::default());
    }

    let size = u64::from_be_bytes(
        bytes[offset + 56..offset + 64]
            .try_into()
            .map_err(|_| ManifestError::Invalid("malformed manifest size".into()))?,
    ) as usize;

    if bytes.len() < offset + 64 + size {
        return Err(ManifestError::Invalid("blob payload shorter than declared size".into()));
    }

    let compressed = &bytes[offset + 64..offset + 64 + size];
    let mut decoder = ZlibDecoder::new(compressed);
    let mut decoded = Vec::new();
    decoder.read_to_end(&mut decoded).map_err(|err| ManifestError::Invalid(err.to_string()))?;

    let manifest = ProposalManifest::decode(&mut decoded.as_slice())
        .map_err(|err| ManifestError::Invalid(err.to_string()))?;

    if manifest.blocks.len() > PROPOSAL_MAX_BLOCKS {
        warn!(blocks = manifest.blocks.len(), "manifest contains too many blocks");
        return Ok(ProposalManifest::default());
    }

    Ok(manifest)
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::primitives::{Address, Bytes};
    use protocol::shasta::manifest::{BlockManifest, ProposalManifest};

    #[test]
    fn decode_roundtrip_manifest() {
        let manifest = ProposalManifest {
            prover_auth_bytes: Bytes::from_static(b"auth"),
            blocks: vec![BlockManifest {
                timestamp: 1,
                coinbase: Address::ZERO,
                anchor_block_number: 10,
                gas_limit: 100,
                transactions: vec![],
            }],
        };

        let encoded = manifest.encode().unwrap();
        let decoded = decode_manifest_bytes(&encoded, 0).unwrap();
        assert_eq!(decoded.blocks.len(), 1);
        assert_eq!(decoded.blocks[0].anchor_block_number, 10);
    }
}

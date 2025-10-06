use std::sync::Arc;

use alloy_consensus::BlobTransactionSidecar;
use async_trait::async_trait;
use protocol::shasta::manifest::ProposalManifest;
use rpc::blob::BlobDataSource;

use super::{ManifestFetcher, ManifestFetcherError};

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

    /// Decode the manifest for the given sidecars, starting from the provided byte offset.
    fn decode_with_offset(
        &self,
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
}

#[async_trait]
impl ManifestFetcher for ShastaManifestFetcher {
    type Manifest = ProposalManifest;

    fn blob_source(&self) -> &BlobDataSource {
        &self.blob_source
    }

    async fn decode_manifest(
        &self,
        sidecars: &[BlobTransactionSidecar],
    ) -> Result<Self::Manifest, ManifestFetcherError> {
        self.decode_with_offset(sidecars, 0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::primitives::{Address, Bytes};
    use protocol::shasta::manifest;

    #[test]
    fn decode_roundtrip_manifest() {
        let manifest = ProposalManifest {
            prover_auth_bytes: Bytes::from_static(b"auth"),
            blocks: vec![manifest::BlockManifest {
                timestamp: 1,
                coinbase: Address::ZERO,
                anchor_block_number: 10,
                gas_limit: 100,
                transactions: vec![],
            }],
        };

        let encoded = manifest.encode_and_compress().unwrap();
        let decoded = ProposalManifest::decompress_and_decode(&encoded, 0).unwrap();
        assert_eq!(decoded.blocks.len(), 1);
        assert_eq!(decoded.blocks[0].anchor_block_number, 10);
    }
}

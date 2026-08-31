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

#[cfg(test)]
mod tests {
    use alloy_consensus::BlobTransactionSidecar;
    use alloy_eips::eip4844::{BYTES_PER_BLOB, Blob};

    use super::{ManifestFetcherError, decode_manifest_from_sidecars};

    /// Build a single-blob sidecar whose Kona encoding is invalid: it declares a payload length of
    /// zero yet carries a stray non-zero byte past that length. This mirrors the forced-inclusion
    /// blob observed on-chain (proposal 1812 / L1 block 5167) that wedged derivation: the first
    /// field element is all zeros (version 0, length 0), so the decoder's trailing-zero check
    /// rejects the stray byte.
    fn sidecar_with_undecodable_blob() -> BlobTransactionSidecar {
        let mut raw = [0u8; BYTES_PER_BLOB];
        // byte[0] header, byte[1] version, byte[2..5] 24-bit length (all zero => length 0);
        // byte[6] sits past the declared length, so a non-zero value is "extraneous data".
        raw[6] = 0x02;
        BlobTransactionSidecar {
            blobs: vec![Blob::from(raw)],
            commitments: Vec::new(),
            proofs: Vec::new(),
        }
    }

    #[test]
    fn decode_manifest_rejects_undecodable_blob_with_invalid_error() {
        let sidecar = sidecar_with_undecodable_blob();

        let err = decode_manifest_from_sidecars(&[sidecar], 0, 100)
            .expect_err("an undecodable blob must not decode into a manifest");

        assert!(
            matches!(&err, ManifestFetcherError::Invalid(msg) if msg == "invalid blob encoding"),
            "expected invalid-blob-encoding error, got {err:?}"
        );
    }
}

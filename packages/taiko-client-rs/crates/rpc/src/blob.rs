//! Utilities for fetching blob sidecars from beacon or blob servers.

use alloy::primitives::{B256, hex};
use alloy_eips::eip4844::Blob;
use alloy_rpc_types::BlobTransactionSidecar;
use once_cell::sync::OnceCell;
use reqwest::Client as HttpClient;
use serde::Deserialize;
use thiserror::Error;
use url::Url;

/// Error type returned when fetching blobs.
#[derive(Debug, Error)]
pub enum BlobDataError {
    /// The remote server responded with an unexpected status code.
    #[error("blob server returned status {status}")]
    HttpStatus { status: u16 },
    /// The remote server returned malformed JSON.
    #[error("failed to parse blob server response: {0}")]
    Parse(String),
    /// Any other error type.
    #[error(transparent)]
    Other(#[from] anyhow::Error),
}

#[derive(Debug, Deserialize)]
struct BlobServerResponse {
    #[serde(rename = "versioned_hash", alias = "versionedHash")]
    _versioned_hash: String,
    #[serde(rename = "commitment")]
    _commitment: String,
    data: String,
}

/// A data source capable of fetching blob sidecars from a public HTTP endpoint.
#[derive(Debug, Clone)]
pub struct BlobDataSource {
    endpoint: Url,
    client: OnceCell<HttpClient>,
}

impl BlobDataSource {
    /// Create a new [`BlobDataSource`] targeting the given endpoint.
    pub fn new(endpoint: Url) -> Self {
        Self { endpoint, client: OnceCell::new() }
    }

    fn http_client(&self) -> &HttpClient {
        self.client.get_or_init(HttpClient::new)
    }

    /// Fetch the blobs identified by the provided versioned hashes.
    pub async fn get_blobs(
        &self,
        blob_hashes: &[B256],
    ) -> Result<Vec<BlobTransactionSidecar>, BlobDataError> {
        let mut blobs = Vec::with_capacity(blob_hashes.len());
        let client = self.http_client().clone();

        for hash in blob_hashes {
            let url = self
                .endpoint
                .join(&format!("/blobs/{}", hash))
                .map_err(|err| BlobDataError::Other(err.into()))?;

            let response = client
                .get(url)
                .header("accept", "application/json")
                .send()
                .await
                .map_err(|err| BlobDataError::Other(err.into()))?;

            if !response.status().is_success() {
                return Err(BlobDataError::HttpStatus { status: response.status().as_u16() });
            }

            let payload: BlobServerResponse =
                response.json().await.map_err(|err| BlobDataError::Parse(err.to_string()))?;

            let blob = parse_blob(&payload.data)?;

            blobs.push(BlobTransactionSidecar {
                blobs: vec![blob],
                // Only the blob contents are required for manifest decoding; commitments and proofs
                // are unused in the driver, so we keep them empty to avoid extra parsing work.
                commitments: Vec::new(),
                proofs: Vec::new(),
            });
        }

        Ok(blobs)
    }
}

// Helper functions for parsing hex-encoded data from the blob server.
// Parses a hex-encoded blob into a `Blob`.
fn parse_blob(value: &str) -> Result<Blob, BlobDataError> {
    let bytes = decode_hex(value)?;
    Blob::try_from(bytes.as_slice()).map_err(|err| BlobDataError::Parse(err.to_string()))
}

// Decodes a hex string, optionally prefixed with "0x", into a byte vector.
fn decode_hex(value: &str) -> Result<Vec<u8>, BlobDataError> {
    let mut stripped = value.trim_start_matches("0x").to_owned();
    if stripped.len() % 2 == 1 {
        stripped.insert(0, '0');
    }
    hex::decode(stripped).map_err(|err| BlobDataError::Parse(err.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn display_blob_sidecar() {
        let sidecar = BlobTransactionSidecar {
            blobs: vec![Blob::ZERO],
            commitments: Vec::new(),
            proofs: Vec::new(),
        };

        assert_eq!(sidecar.blobs.len(), 1);
        assert!(sidecar.commitments.is_empty());
        assert!(sidecar.proofs.is_empty());
    }
}

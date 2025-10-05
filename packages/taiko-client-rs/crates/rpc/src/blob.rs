//! Utilities for fetching blob sidecars from beacon or blob servers.

use alloy::primitives::{B256, hex};
use alloy_eips::eip4844::{Blob, Bytes48};
use alloy_rpc_types::BlobTransactionSidecar;
use once_cell::sync::OnceCell;
use reqwest::Client as HttpClient;
use serde::Deserialize;
use thiserror::Error;
use url::Url;

/// Error type returned when fetching blobs.
#[derive(Debug, Error)]
pub enum BlobDataError {
    /// No blob server or beacon endpoint was configured.
    #[error("blob data source not configured")]
    NotConfigured,
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
    #[serde(alias = "versioned_hash", alias = "versionedHash")]
    versioned_hash: String,
    commitment: String,
    data: String,
}

/// A data source capable of fetching blob sidecars from a public HTTP endpoint.
#[derive(Debug, Clone)]
pub struct BlobDataSource {
    endpoint: Option<Url>,
    client: OnceCell<HttpClient>,
}

impl BlobDataSource {
    /// Create a new [`BlobDataSource`] targeting the given endpoint. Passing `None` results in a
    /// data source that always returns [`BlobDataError::NotConfigured`].
    pub fn new(endpoint: Option<Url>) -> Self {
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
        let endpoint = self.endpoint.clone().ok_or(BlobDataError::NotConfigured)?;
        let mut blobs = Vec::with_capacity(blob_hashes.len());
        let client = self.http_client().clone();

        for hash in blob_hashes {
            let url = endpoint
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

            let _versioned_hash = parse_hash(&payload.versioned_hash)?;
            let kzg_commitment = parse_commitment(&payload.commitment)?;
            let blob = parse_blob(&payload.data)?;

            blobs.push(BlobTransactionSidecar {
                blobs: vec![*blob],
                commitments: vec![kzg_commitment],
                proofs: vec![Bytes48::ZERO], // TODO: fetch real proofs
            });
        }

        Ok(blobs)
    }
}

fn parse_hash(value: &str) -> Result<B256, BlobDataError> {
    let bytes = decode_hex(value)?;
    Ok(B256::from_slice(bytes.as_slice()))
}

fn parse_commitment(value: &str) -> Result<Bytes48, BlobDataError> {
    let bytes = decode_hex(value)?;
    Bytes48::try_from(bytes.as_slice()).map_err(|err| BlobDataError::Parse(err.to_string()))
}

fn parse_blob(value: &str) -> Result<Box<Blob>, BlobDataError> {
    let bytes = decode_hex(value)?;
    let blob =
        Blob::try_from(bytes.as_slice()).map_err(|err| BlobDataError::Parse(err.to_string()))?;
    Ok(Box::new(blob))
}

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
            commitments: vec![Bytes48::ZERO],
            proofs: vec![Bytes48::ZERO],
        };

        assert_eq!(sidecar.blobs.len(), 1);
        assert_eq!(sidecar.commitments.len(), 1);
        assert_eq!(sidecar.proofs.len(), 1);
    }
}

//! Utilities for fetching blob sidecars from beacon or blob servers.

use std::sync::Arc;

use alloy::primitives::{B256, hex};
use alloy_eips::eip4844::{Blob, Bytes48, VERSIONED_HASH_VERSION_KZG};
use alloy_rpc_types::BlobTransactionSidecar;
use once_cell::sync::OnceCell;
use reqwest::Client as HttpClient;
use serde::Deserialize;
use sha2::{Digest, Sha256};
use thiserror::Error;
use tracing::{debug, warn};
use url::Url;

use crate::beacon::{BeaconClient, BeaconSidecar};

/// Error type returned when fetching blobs.
#[derive(Debug, Error)]
pub enum BlobDataError {
    /// The remote server responded with an unexpected status code.
    #[error("blob server returned status {status}")]
    HttpStatus { status: u16 },
    /// Error when communicating with the beacon endpoint.
    #[error("beacon error: {0}")]
    Beacon(String),
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
    versioned_hash: String,
    #[serde(rename = "commitment")]
    commitment: String,
    #[serde(rename = "proof", alias = "kzg_proof")]
    proof: Option<String>,
    data: String,
}

/// A data source capable of fetching blob sidecars from a public HTTP endpoint.
#[derive(Debug)]
pub struct BlobDataSource {
    beacon: Option<Arc<BeaconClient>>,
    blob_server_endpoint: Option<Url>,
    client: OnceCell<HttpClient>,
}

impl BlobDataSource {
    /// Create a new [`BlobDataSource`] targeting the given endpoint.
    pub async fn new(
        beacon_endpoint: Option<Url>,
        blob_server_endpoint: Option<Url>,
        disable_beacon: bool,
    ) -> Result<Self, BlobDataError> {
        let beacon = if let (Some(endpoint), false) = (beacon_endpoint, disable_beacon) {
            Some(Arc::new(BeaconClient::new(endpoint).await?))
        } else {
            None
        };
        Ok(Self { beacon, blob_server_endpoint, client: OnceCell::new() })
    }

    /// Access the HTTP client used for blob fetches.
    fn http_client(&self) -> Result<&HttpClient, BlobDataError> {
        self.client.get_or_try_init(|| {
            HttpClient::builder().build().map_err(|err| BlobDataError::Other(err.into()))
        })
    }

    /// Fetch the blobs identified by the provided versioned hashes.
    pub async fn get_blobs(
        &self,
        timestamp: u64,
        blob_hashes: &[B256],
    ) -> Result<Vec<BlobTransactionSidecar>, BlobDataError> {
        if let Some(beacon) = &self.beacon {
            match beacon.blobs_by_timestamp(timestamp).await {
                Ok(sidecars) => {
                    if let Some(matched) = Self::match_beacon_sidecars(&sidecars, blob_hashes)? {
                        debug!(
                            timestamp,
                            hash_count = blob_hashes.len(),
                            "successfully fetched blob sidecars from beacon"
                        );
                        return Ok(matched);
                    }
                    debug!(
                        timestamp,
                        hash_count = blob_hashes.len(),
                        "no matching sidecars returned by beacon; falling back to blob server"
                    );
                }
                Err(err) => {
                    warn!(
                        ?err,
                        timestamp,
                        hash_count = blob_hashes.len(),
                        "failed to fetch blobs from beacon; falling back to blob server"
                    );
                }
            }
        }

        if let Some(endpoint) = &self.blob_server_endpoint {
            return self.fetch_from_blob_server(endpoint, blob_hashes).await;
        }

        Err(BlobDataError::Beacon("no beacon or blob server available for blob retrieval".into()))
    }

    /// Look up the execution-layer block number associated with a given timestamp via the beacon
    /// endpoint.
    pub async fn execution_block_number_by_timestamp(
        &self,
        timestamp: u64,
    ) -> Result<u64, BlobDataError> {
        let beacon = self
            .beacon
            .as_ref()
            .ok_or_else(|| BlobDataError::Beacon("beacon endpoint not configured".into()))?;
        beacon.execution_block_number_by_timestamp(timestamp).await
    }

    async fn fetch_from_blob_server(
        &self,
        endpoint: &Url,
        blob_hashes: &[B256],
    ) -> Result<Vec<BlobTransactionSidecar>, BlobDataError> {
        let client = self.http_client()?.clone();
        let mut blobs = Vec::with_capacity(blob_hashes.len());

        for hash in blob_hashes {
            let url = endpoint
                .join(&format!("/blobs/{}", hash))
                .map_err(|err| BlobDataError::Other(err.into()))?;
            debug!(hash = ?hash, url = url.as_str(), "requesting blob sidecar from endpoint");

            let response = client
                .get(url)
                .header("accept", "application/json")
                .send()
                .await
                .map_err(|err| BlobDataError::Other(err.into()))?;

            if !response.status().is_success() {
                warn!(status = response.status().as_u16(), hash = ?hash, "blob server returned error status");
                return Err(BlobDataError::HttpStatus { status: response.status().as_u16() });
            }

            let payload: BlobServerResponse =
                response.json().await.map_err(|err| BlobDataError::Parse(err.to_string()))?;

            let blob = parse_blob(&payload.data)?;
            let commitment = parse_bytes48(&payload.commitment)?;
            let proof = if let Some(proof) = payload.proof {
                parse_bytes48(&proof)?
            } else {
                Bytes48::default()
            };

            let versioned_hash = versioned_hash_from_commitment(&commitment);
            if let Ok(reported_hash) = payload.versioned_hash.parse::<B256>() &&
                reported_hash != versioned_hash
            {
                warn!(
                    ?hash,
                    reported = ?reported_hash,
                    derived = ?versioned_hash,
                    "blob server reported mismatched versioned hash"
                );
                return Err(BlobDataError::Parse("blob hash mismatch from blob server".into()));
            }
            if versioned_hash != *hash {
                warn!(
                ?hash,
                returned_hash = ?versioned_hash,
                "blob server returned mismatched blob hash"
                );
                return Err(BlobDataError::Parse("blob hash mismatch from blob server".into()));
            }

            blobs.push(BlobTransactionSidecar {
                blobs: vec![blob],
                commitments: vec![commitment],
                proofs: vec![proof],
            });
            debug!(hash = ?hash, "fetched blob sidecar successfully");
        }

        Ok(blobs)
    }

    fn match_beacon_sidecars(
        sidecars: &[BeaconSidecar],
        blob_hashes: &[B256],
    ) -> Result<Option<Vec<BlobTransactionSidecar>>, BlobDataError> {
        if sidecars.is_empty() {
            return Ok(None);
        }

        let mut used = vec![false; sidecars.len()];
        let mut matched = Vec::with_capacity(blob_hashes.len());

        for target_hash in blob_hashes {
            let mut found = None;
            for (index, sidecar) in sidecars.iter().enumerate() {
                if used[index] {
                    continue;
                }

                let versioned_hash = versioned_hash_from_commitment(&sidecar.commitment);
                if &versioned_hash == target_hash {
                    used[index] = true;
                    matched.push(BlobTransactionSidecar {
                        blobs: vec![sidecar.blob],
                        commitments: vec![sidecar.commitment],
                        proofs: vec![sidecar.proof],
                    });
                    found = Some(());
                    break;
                }
            }

            if found.is_none() {
                return Ok(None);
            }
        }

        Ok(Some(matched))
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

/// Parses a hex-encoded 48-byte value into a `Bytes48`.
fn parse_bytes48(value: &str) -> Result<Bytes48, BlobDataError> {
    let bytes = decode_hex(value)?;
    Bytes48::try_from(bytes.as_slice())
        .map_err(|_| BlobDataError::Parse("invalid 48-byte value".into()))
}

/// Computes the versioned hash from a KZG commitment.
fn versioned_hash_from_commitment(commitment: &Bytes48) -> B256 {
    let mut hash: [u8; 32] = Sha256::digest(commitment.as_slice()).into();
    hash[0] = VERSIONED_HASH_VERSION_KZG;
    B256::from(hash)
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

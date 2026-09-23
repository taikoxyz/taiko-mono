//! Utilities for fetching blob sidecars from beacon or blob servers.

use std::sync::Arc;

use alloy::primitives::{B256, hex};
use alloy_eips::eip4844::{Blob, Bytes48, VERSIONED_HASH_VERSION_KZG, c_kzg};
use alloy_rpc_types::BlobTransactionSidecar;
use once_cell::sync::OnceCell;
use reqwest::Client as HttpClient;
use serde::Deserialize;
use sha2::{Digest, Sha256};
use thiserror::Error;
use tracing::{debug, warn};
use url::Url;

use crate::{beacon::BeaconClient, client::DEFAULT_HTTP_TIMEOUT};

/// Error type returned when fetching blobs.
#[derive(Debug, Error)]
pub enum BlobDataError {
    /// The remote server responded with an unexpected status code.
    #[error("blob server returned status {status}")]
    HttpStatus {
        /// HTTP status code returned by the remote endpoint.
        status: u16,
    },
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

/// Wire format for a blob sidecar response returned by a blob server.
#[derive(Debug, Deserialize)]
struct BlobServerResponse {
    /// Versioned hash reported by the blob server.
    #[serde(rename = "versioned_hash", alias = "versionedHash")]
    versioned_hash: String,
    /// Hex-encoded KZG commitment.
    #[serde(rename = "commitment")]
    commitment: String,
    /// Optional hex-encoded KZG proof.
    #[serde(rename = "proof", alias = "kzg_proof")]
    proof: Option<String>,
    /// Hex-encoded blob payload.
    data: String,
}

/// A data source capable of fetching blob sidecars from a public HTTP endpoint.
#[derive(Debug)]
pub struct BlobDataSource {
    /// Optional beacon client used as the primary blob source.
    beacon: Option<Arc<BeaconClient>>,
    /// Optional fallback blob-server endpoint.
    blob_server_endpoint: Option<Url>,
    /// Lazily constructed HTTP client for blob-server requests.
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
            HttpClient::builder()
                .timeout(DEFAULT_HTTP_TIMEOUT)
                .build()
                .map_err(|err| BlobDataError::Other(err.into()))
        })
    }

    /// Fetch the blobs identified by the provided versioned hashes, in the same order.
    ///
    /// The beacon node is asked first; the blob server is the fallback when the beacon request
    /// fails or the beacon node does not return every requested blob.
    pub async fn get_blobs(
        &self,
        timestamp: u64,
        blob_hashes: &[B256],
    ) -> Result<Vec<BlobTransactionSidecar>, BlobDataError> {
        if let Some(beacon) = &self.beacon {
            match beacon.blobs_by_timestamp(timestamp, blob_hashes).await {
                Ok(sidecars) => {
                    debug!(
                        timestamp,
                        hash_count = blob_hashes.len(),
                        "successfully fetched blobs from beacon"
                    );
                    return Ok(sidecars);
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

    /// Fetch blob sidecars from the configured blob-server endpoint.
    async fn fetch_from_blob_server(
        &self,
        endpoint: &Url,
        blob_hashes: &[B256],
    ) -> Result<Vec<BlobTransactionSidecar>, BlobDataError> {
        let client = self.http_client()?.clone();
        let mut blobs = Vec::with_capacity(blob_hashes.len());

        for hash in blob_hashes {
            let url = endpoint
                .join(&format!("/blobs/{hash}"))
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

            // On the blocking thread pool: the first commitment loads the KZG trusted setup, which
            // takes seconds on a CPU-limited node and would otherwise stall the async runtime.
            let hash = *hash;
            blobs.push(
                tokio::task::spawn_blocking(move || sidecar_from_blob_server(hash, &payload))
                    .await
                    .map_err(|err| BlobDataError::Other(err.into()))??,
            );
            debug!(hash = ?hash, "fetched blob sidecar successfully");
        }

        Ok(blobs)
    }
}

/// Decode a blob server payload into a sidecar, verifying the blob against the requested versioned
/// hash instead of trusting the payload's metadata.
fn sidecar_from_blob_server(
    hash: B256,
    payload: &BlobServerResponse,
) -> Result<BlobTransactionSidecar, BlobDataError> {
    let blob = parse_blob(&payload.data)?;
    let commitment = compute_blob_commitment(&blob)?;
    let proof = payload.proof.as_deref().map(parse_bytes48).transpose()?.unwrap_or_default();

    let versioned_hash = versioned_hash_from_commitment(&commitment);
    if versioned_hash != hash {
        warn!(?hash, returned_hash = ?versioned_hash, "blob server returned mismatched blob hash");
        return Err(BlobDataError::Parse("blob hash mismatch from blob server".into()));
    }

    if let Ok(reported_commitment) = parse_bytes48(&payload.commitment) &&
        reported_commitment != commitment
    {
        debug!(
            ?hash,
            reported = ?reported_commitment,
            computed = ?commitment,
            "blob server reported mismatched KZG commitment metadata"
        );
    }
    if let Ok(reported_hash) = payload.versioned_hash.parse::<B256>() &&
        reported_hash != versioned_hash
    {
        debug!(
            ?hash,
            reported = ?reported_hash,
            computed = ?versioned_hash,
            "blob server reported mismatched versioned hash metadata"
        );
    }

    Ok(BlobTransactionSidecar {
        blobs: vec![blob],
        commitments: vec![commitment],
        proofs: vec![proof],
    })
}

/// Parse a hex-encoded blob server payload into a fixed-size `Blob`.
pub(crate) fn parse_blob(value: &str) -> Result<Blob, BlobDataError> {
    let bytes = decode_hex(value)?;
    Blob::try_from(bytes.as_slice()).map_err(|err| BlobDataError::Parse(err.to_string()))
}

/// Decode hex text (with optional `0x`) into raw bytes.
fn decode_hex(value: &str) -> Result<Vec<u8>, BlobDataError> {
    let mut stripped = value.trim_start_matches("0x").to_owned();
    if stripped.len() % 2 == 1 {
        stripped.insert(0, '0');
    }
    hex::decode(stripped).map_err(|err| BlobDataError::Parse(err.to_string()))
}

/// Parses a hex-encoded 48-byte value into a `Bytes48`.
pub(crate) fn parse_bytes48(value: &str) -> Result<Bytes48, BlobDataError> {
    let bytes = decode_hex(value)?;
    Bytes48::try_from(bytes.as_slice())
        .map_err(|_| BlobDataError::Parse("invalid 48-byte value".into()))
}

/// Computes the KZG commitment for a blob using the default Ethereum trusted setup.
///
/// The setup is loaded without precomputation: it only speeds up cell proofs, and would add about
/// 96 MiB to every driver process (see the c-kzg README).
pub(crate) fn compute_blob_commitment(blob: &Blob) -> Result<Bytes48, BlobDataError> {
    let kzg_blob = c_kzg::Blob::from_bytes(blob.as_slice())
        .map_err(|err| BlobDataError::Other(anyhow::anyhow!(err.to_string())))?;
    let commitment = c_kzg::ethereum_kzg_settings(0)
        .blob_to_kzg_commitment(&kzg_blob)
        .map_err(|err| BlobDataError::Other(anyhow::anyhow!(err.to_string())))?;

    Ok(Bytes48::from_slice(commitment.to_bytes().as_ref()))
}

/// Computes the versioned hash from a KZG commitment.
pub(crate) fn versioned_hash_from_commitment(commitment: &Bytes48) -> B256 {
    let mut hash: [u8; 32] = Sha256::digest(commitment.as_slice()).into();
    hash[0] = VERSIONED_HASH_VERSION_KZG;
    B256::from(hash)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::{
        TestServer, assert_waits_for_blocking_pool, single_blocking_thread_runtime, start_beacon,
    };
    use alloy_eips::eip4844::env_settings::EnvKzgSettings;
    use hyper::StatusCode;

    #[tokio::test]
    async fn blob_server_rejects_blob_bytes_that_do_not_match_commitment_metadata() {
        let zero_sidecar = sidecar_for_blob(Blob::ZERO);
        let zero_commitment = zero_sidecar.commitments[0];
        let zero_hash = versioned_hash_from_commitment(&zero_commitment);
        let body = blob_server_body(&Blob::repeat_byte(0x11), &zero_commitment, zero_hash);
        let server = TestServer::start(move |_| (StatusCode::OK, body.clone())).await;
        let source = BlobDataSource::new(None, Some(server.endpoint()), true)
            .await
            .expect("blob source should be constructed");

        let result = source.get_blobs(0, &[zero_hash]).await;
        assert!(
            matches!(result, Err(BlobDataError::Parse(_))),
            "expected parse error for blob bytes that do not match metadata, got {result:?}",
        );
    }

    #[tokio::test]
    async fn blob_server_accepts_valid_blob_even_if_commitment_metadata_is_wrong() {
        let zero_sidecar = sidecar_for_blob(Blob::ZERO);
        let zero_hash = versioned_hash_from_commitment(&zero_sidecar.commitments[0]);
        let wrong_commitment = Bytes48::repeat_byte(0x42);
        let body = blob_server_body(&Blob::ZERO, &wrong_commitment, zero_hash);
        let server = TestServer::start(move |_| (StatusCode::OK, body.clone())).await;
        let source = BlobDataSource::new(None, Some(server.endpoint()), true)
            .await
            .expect("blob source should be constructed");

        let sidecars = source
            .get_blobs(0, &[zero_hash])
            .await
            .expect("valid blob data should be accepted despite wrong metadata");

        assert_eq!(sidecars.len(), 1);
        assert_eq!(sidecars[0].blobs, vec![Blob::ZERO]);
        assert_eq!(sidecars[0].commitments, vec![zero_sidecar.commitments[0]]);
        assert_eq!(sidecars[0].proofs, vec![Bytes48::default()]);
    }

    #[tokio::test]
    async fn get_blobs_falls_back_to_blob_server_when_beacon_misses_blobs() {
        let zero_sidecar = sidecar_for_blob(Blob::ZERO);
        let zero_commitment = zero_sidecar.commitments[0];
        let zero_hash = versioned_hash_from_commitment(&zero_commitment);
        // The beacon node answers, but without the requested blob (e.g. pruned or not custodied).
        let beacon = start_beacon(|_| (StatusCode::OK, r#"{"data":[]}"#.to_owned())).await;
        let body = blob_server_body(&Blob::ZERO, &zero_commitment, zero_hash);
        let blob_server = TestServer::start(move |_| (StatusCode::OK, body.clone())).await;
        let source =
            BlobDataSource::new(Some(beacon.endpoint()), Some(blob_server.endpoint()), false)
                .await
                .expect("blob source should be constructed");

        let sidecars = source
            .get_blobs(0, &[zero_hash])
            .await
            .expect("the blob server should serve the blob the beacon node missed");

        assert_eq!(sidecars.len(), 1);
        assert_eq!(sidecars[0].blobs, vec![Blob::ZERO]);
        assert_eq!(beacon.requests_with_prefix("/eth/v1/beacon/blobs/").len(), 1);
        assert!(beacon.requests_with_prefix("/eth/v1/beacon/blob_sidecars/").is_empty());
        assert_eq!(blob_server.requests_with_prefix(&format!("/blobs/{zero_hash}")).len(), 1);
    }

    #[test]
    fn blob_server_blobs_are_matched_on_the_blocking_pool() {
        single_blocking_thread_runtime().block_on(async {
            let zero_sidecar = sidecar_for_blob(Blob::ZERO);
            let zero_commitment = zero_sidecar.commitments[0];
            let zero_hash = versioned_hash_from_commitment(&zero_commitment);
            let body = blob_server_body(&Blob::ZERO, &zero_commitment, zero_hash);
            let server = TestServer::start(move |_| (StatusCode::OK, body.clone())).await;
            let source = BlobDataSource::new(None, Some(server.endpoint()), true)
                .await
                .expect("blob source should be constructed");

            assert_waits_for_blocking_pool(source.get_blobs(0, &[zero_hash])).await;
        });
    }

    fn sidecar_for_blob(blob: Blob) -> BlobTransactionSidecar {
        BlobTransactionSidecar::try_from_blobs_with_settings(
            vec![blob],
            EnvKzgSettings::Default.get(),
        )
        .expect("test blob should produce a KZG sidecar")
    }

    fn blob_server_body(blob: &Blob, commitment: &Bytes48, versioned_hash: B256) -> String {
        serde_json::json!({
            "versionedHash": versioned_hash.to_string(),
            "commitment": format!("0x{}", hex::encode(commitment.as_slice())),
            "data": format!("0x{}", hex::encode(blob.as_slice())),
        })
        .to_string()
    }
}

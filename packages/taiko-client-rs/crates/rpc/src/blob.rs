//! Utilities for fetching blob sidecars from beacon or blob servers.

use std::sync::Arc;

use alloy::primitives::{B256, hex};
use alloy_eips::eip4844::{
    Blob, Bytes48, VERSIONED_HASH_VERSION_KZG, c_kzg, env_settings::EnvKzgSettings,
};
use alloy_rpc_types::BlobTransactionSidecar;
use once_cell::sync::OnceCell;
use reqwest::Client as HttpClient;
use serde::Deserialize;
use sha2::{Digest, Sha256};
use thiserror::Error;
use tracing::{debug, warn};
use url::Url;

use crate::{
    beacon::{BeaconClient, BeaconSidecar},
    client::DEFAULT_HTTP_TIMEOUT,
};

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

            let blob = parse_blob(&payload.data)?;
            let commitment = compute_blob_commitment(&blob)?;
            let proof =
                payload.proof.as_deref().map(parse_bytes48).transpose()?.unwrap_or_default();

            let versioned_hash = versioned_hash_from_commitment(&commitment);
            if versioned_hash != *hash {
                warn!(
                ?hash,
                returned_hash = ?versioned_hash,
                "blob server returned mismatched blob hash"
                );
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

            blobs.push(BlobTransactionSidecar {
                blobs: vec![blob],
                commitments: vec![commitment],
                proofs: vec![proof],
            });
            debug!(hash = ?hash, "fetched blob sidecar successfully");
        }

        Ok(blobs)
    }

    /// Match requested blob hashes to fetched beacon sidecars in order.
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
            let matched_index = sidecars.iter().enumerate().find(|(index, sidecar)| {
                !used[*index] && &versioned_hash_from_commitment(&sidecar.commitment) == target_hash
            });
            let Some((index, sidecar)) = matched_index else {
                return Ok(None);
            };
            used[index] = true;
            matched.push(BlobTransactionSidecar {
                blobs: vec![sidecar.blob],
                commitments: vec![sidecar.commitment],
                proofs: vec![sidecar.proof],
            });
        }

        Ok(Some(matched))
    }
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
fn compute_blob_commitment(blob: &Blob) -> Result<Bytes48, BlobDataError> {
    let kzg_blob = c_kzg::Blob::from_bytes(blob.as_slice())
        .map_err(|err| BlobDataError::Other(anyhow::anyhow!(err.to_string())))?;
    let commitment = EnvKzgSettings::Default
        .get()
        .blob_to_kzg_commitment(&kzg_blob)
        .map_err(|err| BlobDataError::Other(anyhow::anyhow!(err.to_string())))?;

    Ok(Bytes48::from_slice(commitment.to_bytes().as_ref()))
}

/// Computes the versioned hash from a KZG commitment.
fn versioned_hash_from_commitment(commitment: &Bytes48) -> B256 {
    let mut hash: [u8; 32] = Sha256::digest(commitment.as_slice()).into();
    hash[0] = VERSIONED_HASH_VERSION_KZG;
    B256::from(hash)
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use super::*;
    use alloy_eips::eip4844::env_settings::EnvKzgSettings;
    use http_body_util::Full;
    use hyper::{
        StatusCode, body::Bytes as HyperBytes, header::CONTENT_TYPE,
        server::conn::http1::Builder as Http1Builder, service::service_fn,
    };
    use tokio::{net::TcpListener, select, spawn, sync::Notify, task::JoinHandle};

    struct TestBlobServer {
        endpoint: Url,
        shutdown: Arc<Notify>,
        handle: JoinHandle<()>,
    }

    impl TestBlobServer {
        async fn start(body: String) -> Self {
            let listener = TcpListener::bind("127.0.0.1:0")
                .await
                .expect("test server should bind an ephemeral port");
            let addr = listener.local_addr().expect("listener address should be available");
            let endpoint =
                Url::parse(&format!("http://{addr}")).expect("test endpoint URL should parse");

            let shutdown = Arc::new(Notify::new());
            let cancel = shutdown.clone();
            let body = Arc::new(body);

            let handle = spawn(async move {
                loop {
                    select! {
                        _ = cancel.notified() => break,
                        accept_result = listener.accept() => {
                            let Ok((stream, _)) = accept_result else { continue };
                            let body = body.clone();
                            spawn(async move {
                                let io = hyper_util::rt::TokioIo::new(stream);
                                let service = service_fn(move |_| {
                                    let body = body.clone();
                                    async move {
                                        Ok::<_, hyper::Error>(
                                            hyper::Response::builder()
                                                .status(StatusCode::OK)
                                                .header(CONTENT_TYPE, "application/json")
                                                .body(Full::new(HyperBytes::from(
                                                    body.as_bytes().to_vec(),
                                                )))
                                                .expect("test response should build"),
                                        )
                                    }
                                });
                                let _ = Http1Builder::new().serve_connection(io, service).await;
                            });
                        }
                    }
                }
            });

            Self { endpoint, shutdown, handle }
        }

        fn endpoint(&self) -> Url {
            self.endpoint.clone()
        }
    }

    impl Drop for TestBlobServer {
        fn drop(&mut self) {
            self.shutdown.notify_waiters();
            self.handle.abort();
        }
    }

    #[tokio::test]
    async fn blob_server_rejects_blob_bytes_that_do_not_match_commitment_metadata() {
        let zero_sidecar = sidecar_for_blob(Blob::ZERO);
        let zero_commitment = zero_sidecar.commitments[0];
        let zero_hash = versioned_hash_from_commitment(&zero_commitment);
        let body = blob_server_body(&Blob::repeat_byte(0x11), &zero_commitment, zero_hash);
        let server = TestBlobServer::start(body).await;
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
        let server = TestBlobServer::start(body).await;
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

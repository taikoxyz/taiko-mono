//! Utilities for fetching blob sidecars from beacon or blob servers.

use std::{sync::Arc, time::Duration};

use alloy::primitives::{B256, hex};
use alloy_eips::eip4844::{
    BYTES_PER_BLOB, Blob, Bytes48, VERSIONED_HASH_VERSION_KZG, c_kzg, env_settings::EnvKzgSettings,
};
use alloy_rpc_types::BlobTransactionSidecar;
use once_cell::sync::OnceCell;
use reqwest::{Client as HttpClient, Response};
use serde::Deserialize;
use sha2::{Digest, Sha256};
use thiserror::Error;
use tracing::{debug, warn};
use url::Url;

use crate::beacon::{BeaconClient, BeaconSidecar};

/// Default timeout for blob fetches from the beacon node or a blob server.
///
/// Deliberately much larger than [`DEFAULT_HTTP_TIMEOUT`](crate::client::DEFAULT_HTTP_TIMEOUT):
/// PeerDAS beacon nodes (e.g. lighthouse `--semi-supernode`) reconstruct blobs from data columns
/// on request, which has been measured at multiple seconds per blob in the requested slot.
pub const DEFAULT_BLOB_FETCH_TIMEOUT: Duration = Duration::from_secs(120);

/// Number of leading characters of an unexpected response body included in error messages.
const BODY_EXCERPT_CHARS: usize = 120;

/// Largest response body accepted from a blob server, in bytes.
///
/// One blob is [`BYTES_PER_BLOB`] bytes, so its hex encoding is twice that; the headroom covers
/// the `0x` prefix, JSON quoting, and the commitment, proof and storage-reference fields that
/// share the metadata response. Both blob-server routes are bounded by this.
const MAX_BLOB_SERVER_RESPONSE_BYTES: usize = BYTES_PER_BLOB * 2 + 4096;

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
///
/// Servers such as the Taiko blob storage service inline the blob payload in `data`, while
/// blobscan's `/blobs/{hash}` route omits it (returning `dataStorageReferences` instead) and
/// serves the payload from the dedicated `/blobs/{hash}/data` route.
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
    /// Hex-encoded blob payload; absent on blobscan-style responses.
    #[serde(default)]
    data: Option<String>,
}

/// A data source capable of fetching blob sidecars from a public HTTP endpoint.
#[derive(Debug)]
pub struct BlobDataSource {
    /// Optional beacon client used as the primary blob source.
    beacon: Option<Arc<BeaconClient>>,
    /// Optional fallback blob-server endpoint.
    blob_server_endpoint: Option<Url>,
    /// Timeout applied to beacon and blob-server blob fetches.
    fetch_timeout: Duration,
    /// Lazily constructed HTTP client for blob-server requests.
    client: OnceCell<HttpClient>,
}

impl BlobDataSource {
    /// Create a new [`BlobDataSource`] targeting the given endpoint.
    ///
    /// `fetch_timeout` bounds every blob fetch against the beacon node and the blob server;
    /// [`DEFAULT_BLOB_FETCH_TIMEOUT`] is used when unset.
    pub async fn new(
        beacon_endpoint: Option<Url>,
        blob_server_endpoint: Option<Url>,
        disable_beacon: bool,
        fetch_timeout: Option<Duration>,
    ) -> Result<Self, BlobDataError> {
        let fetch_timeout = fetch_timeout.unwrap_or(DEFAULT_BLOB_FETCH_TIMEOUT);
        let beacon = if let (Some(endpoint), false) = (beacon_endpoint, disable_beacon) {
            Some(Arc::new(BeaconClient::new(endpoint, fetch_timeout).await?))
        } else {
            None
        };
        Ok(Self { beacon, blob_server_endpoint, fetch_timeout, client: OnceCell::new() })
    }

    /// Access the HTTP client used for blob fetches.
    fn http_client(&self) -> Result<&HttpClient, BlobDataError> {
        self.client.get_or_try_init(|| {
            HttpClient::builder()
                .timeout(self.fetch_timeout)
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
                .get(url.clone())
                .header("accept", "application/json")
                .send()
                .await
                .map_err(|err| BlobDataError::Other(err.into()))?;

            if !response.status().is_success() {
                warn!(status = response.status().as_u16(), hash = ?hash, "blob server returned error status");
                return Err(BlobDataError::HttpStatus { status: response.status().as_u16() });
            }

            let body = read_bounded_body(response, &url).await?;
            let payload: BlobServerResponse =
                serde_json::from_str(&body).map_err(|err| BlobDataError::Parse(err.to_string()))?;

            // Blobscan-style responses carry only metadata and storage references; the blob
            // payload itself lives behind the dedicated `/blobs/{hash}/data` route.
            let blob_hex = match payload.data.as_deref() {
                Some(data) if !data.is_empty() => data.to_owned(),
                _ => self.fetch_blob_data(&client, endpoint, hash).await?,
            };
            let blob = parse_blob(&blob_hex)?;
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

    /// Fetch the hex-encoded blob payload from a blob server's `/blobs/{hash}/data` route.
    ///
    /// Blobscan serves the payload as a JSON-encoded string (`"0x…"`); a bare hex body is
    /// accepted as well for other blob-server implementations. Anything else — an error
    /// envelope served with HTTP 200, an empty body, a truncated payload — is rejected here
    /// with the route and a body excerpt, rather than being handed to the hex decoder where it
    /// surfaces as an unattributable parse error.
    async fn fetch_blob_data(
        &self,
        client: &HttpClient,
        endpoint: &Url,
        hash: &B256,
    ) -> Result<String, BlobDataError> {
        let url = endpoint
            .join(&format!("/blobs/{hash}/data"))
            .map_err(|err| BlobDataError::Other(err.into()))?;
        debug!(hash = ?hash, url = url.as_str(), "requesting blob payload from data endpoint");

        let response = client
            .get(url.clone())
            .header("accept", "application/json")
            .send()
            .await
            .map_err(|err| BlobDataError::Other(err.into()))?;

        if !response.status().is_success() {
            warn!(
                status = response.status().as_u16(),
                hash = ?hash,
                url = url.as_str(),
                "blob server data endpoint returned error status"
            );
            return Err(BlobDataError::HttpStatus { status: response.status().as_u16() });
        }

        let body = read_bounded_body(response, &url).await?;
        let trimmed = body.trim();
        let payload =
            serde_json::from_str::<String>(trimmed).unwrap_or_else(|_| trimmed.to_owned());

        if !is_blob_sized_hex(&payload) {
            warn!(
                hash = ?hash,
                url = url.as_str(),
                body_len = trimmed.len(),
                "blob server data endpoint returned a body that is not a blob-sized hex payload"
            );
            return Err(BlobDataError::Parse(format!(
                "unexpected body from {url}: {} bytes, expected {} hex characters; body starts \
                 with {:?}",
                trimmed.len(),
                BYTES_PER_BLOB * 2,
                excerpt(trimmed),
            )));
        }

        Ok(payload)
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

/// Read a blob-server response body, refusing to buffer more than
/// [`MAX_BLOB_SERVER_RESPONSE_BYTES`].
///
/// `Response::text` and `Response::json` buffer the whole body with no ceiling, so a hostile or
/// malfunctioning blob server could stream a chunked body for the entire fetch timeout — up to
/// two minutes by default — and exhaust a follower's memory. Accumulating chunk by chunk against
/// a running limit fails fast instead. `Content-Length` only lets the rejection happen before any
/// body is read; it is not load-bearing, because a chunked response declares no length at all.
async fn read_bounded_body(mut response: Response, url: &Url) -> Result<String, BlobDataError> {
    if let Some(declared) = response.content_length() &&
        declared > MAX_BLOB_SERVER_RESPONSE_BYTES as u64
    {
        return Err(BlobDataError::Parse(format!(
            "blob server response from {url} declares {declared} bytes, over the \
             {MAX_BLOB_SERVER_RESPONSE_BYTES} byte limit"
        )));
    }

    let mut body: Vec<u8> = Vec::new();
    while let Some(chunk) =
        response.chunk().await.map_err(|err| BlobDataError::Other(err.into()))?
    {
        if body.len() + chunk.len() > MAX_BLOB_SERVER_RESPONSE_BYTES {
            return Err(BlobDataError::Parse(format!(
                "blob server response from {url} exceeds the {MAX_BLOB_SERVER_RESPONSE_BYTES} \
                 byte limit"
            )));
        }
        body.extend_from_slice(&chunk);
    }

    String::from_utf8(body)
        .map_err(|err| BlobDataError::Parse(format!("non-UTF-8 body from {url}: {err}")))
}

/// Whether `value` is hex text (with optional `0x`) of exactly one blob's length.
///
/// Used to reject non-blob bodies from a blob server's `/data` route before they reach the hex
/// decoder, where an HTTP 200 error envelope would otherwise surface as a bare invalid-character
/// message and an empty body as a slice-conversion failure.
fn is_blob_sized_hex(value: &str) -> bool {
    let stripped = value.strip_prefix("0x").unwrap_or(value);
    stripped.len() == BYTES_PER_BLOB * 2 && stripped.bytes().all(|byte| byte.is_ascii_hexdigit())
}

/// Leading characters of an unexpected response body, for error messages.
///
/// Truncates on a character boundary so non-UTF-8-ish bodies cannot panic the error path.
fn excerpt(body: &str) -> String {
    body.chars().take(BODY_EXCERPT_CHARS).collect()
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
    use http_body_util::{Full, StreamBody};
    use hyper::{
        StatusCode,
        body::{Bytes as HyperBytes, Frame},
        header::CONTENT_TYPE,
        server::conn::http1::Builder as Http1Builder,
        service::service_fn,
    };
    use tokio::{net::TcpListener, select, spawn, sync::Notify, task::JoinHandle};

    struct TestBlobServer {
        endpoint: Url,
        shutdown: Arc<Notify>,
        handle: JoinHandle<()>,
    }

    impl TestBlobServer {
        /// Serve `body` with HTTP 200 for every request path.
        async fn start(body: String) -> Self {
            Self::start_with_routes(vec![], Some(body)).await
        }

        /// Serve exact-path `routes` with HTTP 200; unmatched paths fall back to `catch_all`
        /// when provided and to HTTP 404 otherwise.
        async fn start_with_routes(
            routes: Vec<(String, String)>,
            catch_all: Option<String>,
        ) -> Self {
            let listener = TcpListener::bind("127.0.0.1:0")
                .await
                .expect("test server should bind an ephemeral port");
            let addr = listener.local_addr().expect("listener address should be available");
            let endpoint =
                Url::parse(&format!("http://{addr}")).expect("test endpoint URL should parse");

            let shutdown = Arc::new(Notify::new());
            let cancel = shutdown.clone();
            let routes = Arc::new(routes);
            let catch_all = Arc::new(catch_all);

            let handle = spawn(async move {
                loop {
                    select! {
                        _ = cancel.notified() => break,
                        accept_result = listener.accept() => {
                            let Ok((stream, _)) = accept_result else { continue };
                            let routes = routes.clone();
                            let catch_all = catch_all.clone();
                            spawn(async move {
                                let io = hyper_util::rt::TokioIo::new(stream);
                                let service = service_fn(move |req: hyper::Request<hyper::body::Incoming>| {
                                    let routes = routes.clone();
                                    let catch_all = catch_all.clone();
                                    async move {
                                        let path = req.uri().path().to_owned();
                                        let matched = routes
                                            .iter()
                                            .find(|(route, _)| *route == path)
                                            .map(|(_, body)| body.clone())
                                            .or_else(|| catch_all.as_ref().clone());
                                        let (status, body) = match matched {
                                            Some(body) => (StatusCode::OK, body),
                                            None => (StatusCode::NOT_FOUND, String::new()),
                                        };
                                        Ok::<_, hyper::Error>(
                                            hyper::Response::builder()
                                                .status(status)
                                                .header(CONTENT_TYPE, "application/json")
                                                .body(Full::new(HyperBytes::from(
                                                    body.into_bytes(),
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

    /// Serves a chunked response with no `Content-Length`, so the streaming limit is exercised
    /// rather than the declared-length early reject.
    struct TestChunkedServer {
        /// Base URL of the running server.
        endpoint: Url,
        /// Signals the accept loop to stop.
        shutdown: Arc<Notify>,
        /// Accept-loop task.
        handle: JoinHandle<()>,
    }

    impl TestChunkedServer {
        /// Serve `chunk_count` chunks of `chunk_size` bytes each, for every request path.
        async fn start(chunk_count: usize, chunk_size: usize) -> Self {
            let listener = TcpListener::bind("127.0.0.1:0")
                .await
                .expect("test server should bind an ephemeral port");
            let addr = listener.local_addr().expect("listener address should be available");
            let endpoint =
                Url::parse(&format!("http://{addr}")).expect("test endpoint URL should parse");

            let shutdown = Arc::new(Notify::new());
            let cancel = shutdown.clone();

            let handle = spawn(async move {
                loop {
                    select! {
                        _ = cancel.notified() => break,
                        accept_result = listener.accept() => {
                            let Ok((stream, _)) = accept_result else { continue };
                            spawn(async move {
                                let io = hyper_util::rt::TokioIo::new(stream);
                                let service = service_fn(move |_| async move {
                                    let frames = (0..chunk_count).map(move |_| {
                                        Ok::<_, hyper::Error>(Frame::data(HyperBytes::from(
                                            vec![b'0'; chunk_size],
                                        )))
                                    });
                                    Ok::<_, hyper::Error>(
                                        hyper::Response::builder()
                                            .status(StatusCode::OK)
                                            .header(CONTENT_TYPE, "application/json")
                                            .body(StreamBody::new(futures::stream::iter(frames)))
                                            .expect("test response should build"),
                                    )
                                });
                                let _ = Http1Builder::new().serve_connection(io, service).await;
                            });
                        }
                    }
                }
            });

            Self { endpoint, shutdown, handle }
        }

        /// Base URL of the running server.
        fn endpoint(&self) -> Url {
            self.endpoint.clone()
        }
    }

    impl Drop for TestChunkedServer {
        fn drop(&mut self) {
            self.shutdown.notify_waiters();
            self.handle.abort();
        }
    }

    #[tokio::test]
    async fn blob_server_rejects_oversized_declared_response() {
        // A single body larger than the limit, served with `Content-Length` so the rejection
        // happens before any of it is read.
        let oversized = "0".repeat(MAX_BLOB_SERVER_RESPONSE_BYTES + 1);
        let server = TestBlobServer::start(oversized).await;
        let source = BlobDataSource::new(None, Some(server.endpoint()), true, None)
            .await
            .expect("blob source should be constructed");

        let Err(BlobDataError::Parse(message)) = source.get_blobs(0, &[B256::ZERO]).await else {
            panic!("expected an oversized-response error");
        };
        assert!(
            message.contains("declares") && message.contains("over the"),
            "error should report the declared length, got {message}",
        );
    }

    #[tokio::test]
    async fn blob_server_rejects_oversized_chunked_response() {
        // A chunked body declares no length, so only the running limit can stop it. Streaming
        // well past the cap must fail without buffering the whole body.
        let chunk_size = 16 * 1024;
        let chunk_count = MAX_BLOB_SERVER_RESPONSE_BYTES.div_ceil(chunk_size) + 8;
        let server = TestChunkedServer::start(chunk_count, chunk_size).await;
        let source = BlobDataSource::new(None, Some(server.endpoint()), true, None)
            .await
            .expect("blob source should be constructed");

        let Err(BlobDataError::Parse(message)) = source.get_blobs(0, &[B256::ZERO]).await else {
            panic!("expected an oversized-chunked-response error");
        };
        assert!(
            message.contains("exceeds the"),
            "error should report the streaming limit, got {message}",
        );
    }

    #[tokio::test]
    async fn blob_server_rejects_blob_bytes_that_do_not_match_commitment_metadata() {
        let zero_sidecar = sidecar_for_blob(Blob::ZERO);
        let zero_commitment = zero_sidecar.commitments[0];
        let zero_hash = versioned_hash_from_commitment(&zero_commitment);
        let body = blob_server_body(&Blob::repeat_byte(0x11), &zero_commitment, zero_hash);
        let server = TestBlobServer::start(body).await;
        let source = BlobDataSource::new(None, Some(server.endpoint()), true, None)
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
        let source = BlobDataSource::new(None, Some(server.endpoint()), true, None)
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
    async fn blob_server_without_inline_data_falls_back_to_data_endpoint() {
        let zero_sidecar = sidecar_for_blob(Blob::ZERO);
        let zero_commitment = zero_sidecar.commitments[0];
        let zero_hash = versioned_hash_from_commitment(&zero_commitment);
        let server = TestBlobServer::start_with_routes(
            vec![
                (
                    format!("/blobs/{zero_hash}"),
                    blobscan_metadata_body(&zero_commitment, zero_hash),
                ),
                (format!("/blobs/{zero_hash}/data"), quoted_hex_body(&Blob::ZERO)),
            ],
            None,
        )
        .await;
        let source = BlobDataSource::new(None, Some(server.endpoint()), true, None)
            .await
            .expect("blob source should be constructed");

        let sidecars = source
            .get_blobs(0, &[zero_hash])
            .await
            .expect("blobscan-style response without inline data should resolve via /data");

        assert_eq!(sidecars.len(), 1);
        assert_eq!(sidecars[0].blobs, vec![Blob::ZERO]);
        assert_eq!(sidecars[0].commitments, vec![zero_commitment]);
    }

    #[tokio::test]
    async fn blob_server_data_endpoint_accepts_raw_hex_body() {
        let zero_sidecar = sidecar_for_blob(Blob::ZERO);
        let zero_commitment = zero_sidecar.commitments[0];
        let zero_hash = versioned_hash_from_commitment(&zero_commitment);
        let server = TestBlobServer::start_with_routes(
            vec![
                (
                    format!("/blobs/{zero_hash}"),
                    blobscan_metadata_body(&zero_commitment, zero_hash),
                ),
                (
                    format!("/blobs/{zero_hash}/data"),
                    format!("0x{}", hex::encode(Blob::ZERO.as_slice())),
                ),
            ],
            None,
        )
        .await;
        let source = BlobDataSource::new(None, Some(server.endpoint()), true, None)
            .await
            .expect("blob source should be constructed");

        let sidecars =
            source.get_blobs(0, &[zero_hash]).await.expect("raw hex /data body should be accepted");

        assert_eq!(sidecars.len(), 1);
        assert_eq!(sidecars[0].blobs, vec![Blob::ZERO]);
    }

    #[tokio::test]
    async fn blob_server_with_empty_inline_data_falls_back_to_data_endpoint() {
        let zero_sidecar = sidecar_for_blob(Blob::ZERO);
        let zero_commitment = zero_sidecar.commitments[0];
        let zero_hash = versioned_hash_from_commitment(&zero_commitment);
        // A present-but-empty `data` field is as unusable as a missing one and must take the
        // same `/data` route rather than being decoded into a zero-length blob.
        let mut metadata: serde_json::Value =
            serde_json::from_str(&blobscan_metadata_body(&zero_commitment, zero_hash))
                .expect("metadata body should parse");
        metadata["data"] = serde_json::json!("");
        let server = TestBlobServer::start_with_routes(
            vec![
                (format!("/blobs/{zero_hash}"), metadata.to_string()),
                (format!("/blobs/{zero_hash}/data"), quoted_hex_body(&Blob::ZERO)),
            ],
            None,
        )
        .await;
        let source = BlobDataSource::new(None, Some(server.endpoint()), true, None)
            .await
            .expect("blob source should be constructed");

        let sidecars = source
            .get_blobs(0, &[zero_hash])
            .await
            .expect("empty inline data should fall back to the /data route");

        assert_eq!(sidecars.len(), 1);
        assert_eq!(sidecars[0].blobs, vec![Blob::ZERO]);
    }

    #[tokio::test]
    async fn blob_server_data_endpoint_missing_is_reported_as_http_status() {
        let zero_sidecar = sidecar_for_blob(Blob::ZERO);
        let zero_commitment = zero_sidecar.commitments[0];
        let zero_hash = versioned_hash_from_commitment(&zero_commitment);
        // Only the metadata route is served, so `/data` 404s by construction.
        let server = TestBlobServer::start_with_routes(
            vec![(
                format!("/blobs/{zero_hash}"),
                blobscan_metadata_body(&zero_commitment, zero_hash),
            )],
            None,
        )
        .await;
        let source = BlobDataSource::new(None, Some(server.endpoint()), true, None)
            .await
            .expect("blob source should be constructed");

        let result = source.get_blobs(0, &[zero_hash]).await;
        assert!(
            matches!(result, Err(BlobDataError::HttpStatus { status: 404 })),
            "expected the /data route's 404 to surface as an HTTP status error, got {result:?}",
        );
    }

    #[tokio::test]
    async fn blob_server_data_endpoint_error_envelope_is_diagnosable() {
        let zero_sidecar = sidecar_for_blob(Blob::ZERO);
        let zero_commitment = zero_sidecar.commitments[0];
        let zero_hash = versioned_hash_from_commitment(&zero_commitment);
        // A JSON error envelope served with HTTP 200 is what CDNs and gateways return; it must
        // not reach the hex decoder, where it surfaced as a bare invalid-character message with
        // no indication of which route produced it.
        let server = TestBlobServer::start_with_routes(
            vec![
                (
                    format!("/blobs/{zero_hash}"),
                    blobscan_metadata_body(&zero_commitment, zero_hash),
                ),
                (
                    format!("/blobs/{zero_hash}/data"),
                    r#"{"error":"blob expired","code":"NOT_FOUND"}"#.to_owned(),
                ),
            ],
            None,
        )
        .await;
        let source = BlobDataSource::new(None, Some(server.endpoint()), true, None)
            .await
            .expect("blob source should be constructed");

        let Err(BlobDataError::Parse(message)) = source.get_blobs(0, &[zero_hash]).await else {
            panic!("expected a parse error for an error envelope served with HTTP 200");
        };
        assert!(
            message.contains("/data") && message.contains("blob expired"),
            "error should name the route and quote the body, got {message}",
        );
    }

    #[tokio::test]
    async fn blob_server_data_endpoint_empty_body_is_diagnosable() {
        let zero_sidecar = sidecar_for_blob(Blob::ZERO);
        let zero_commitment = zero_sidecar.commitments[0];
        let zero_hash = versioned_hash_from_commitment(&zero_commitment);
        let server = TestBlobServer::start_with_routes(
            vec![
                (
                    format!("/blobs/{zero_hash}"),
                    blobscan_metadata_body(&zero_commitment, zero_hash),
                ),
                (format!("/blobs/{zero_hash}/data"), String::new()),
            ],
            None,
        )
        .await;
        let source = BlobDataSource::new(None, Some(server.endpoint()), true, None)
            .await
            .expect("blob source should be constructed");

        let Err(BlobDataError::Parse(message)) = source.get_blobs(0, &[zero_hash]).await else {
            panic!("expected a parse error for an empty /data body");
        };
        assert!(
            message.contains("0 bytes"),
            "error should report the empty body length, got {message}",
        );
    }

    #[tokio::test]
    async fn blob_server_data_endpoint_blob_mismatch_is_rejected() {
        let zero_sidecar = sidecar_for_blob(Blob::ZERO);
        let zero_commitment = zero_sidecar.commitments[0];
        let zero_hash = versioned_hash_from_commitment(&zero_commitment);
        let server = TestBlobServer::start_with_routes(
            vec![
                (
                    format!("/blobs/{zero_hash}"),
                    blobscan_metadata_body(&zero_commitment, zero_hash),
                ),
                (format!("/blobs/{zero_hash}/data"), quoted_hex_body(&Blob::repeat_byte(0x11))),
            ],
            None,
        )
        .await;
        let source = BlobDataSource::new(None, Some(server.endpoint()), true, None)
            .await
            .expect("blob source should be constructed");

        let result = source.get_blobs(0, &[zero_hash]).await;
        assert!(
            matches!(result, Err(BlobDataError::Parse(_))),
            "expected parse error for /data blob that does not match the requested hash, got {result:?}",
        );
    }

    /// Blobscan-style `/blobs/{hash}` metadata body: commitment and hash metadata but no
    /// inline `data` field, only storage references.
    fn blobscan_metadata_body(commitment: &Bytes48, versioned_hash: B256) -> String {
        serde_json::json!({
            "versionedHash": versioned_hash.to_string(),
            "commitment": format!("0x{}", hex::encode(commitment.as_slice())),
            "proof": format!("0x{}", hex::encode([0u8; 48])),
            "usageSize": 66573,
            "size": 131072,
            "dataStorageReferences": [
                {"storage": "google", "url": "https://example.invalid/blob.bin"},
                {"storage": "postgres", "url": "http://localhost:3001/blobs/0x00/data"},
            ],
        })
        .to_string()
    }

    /// JSON string body (`"0x…"`) as served by blobscan's `/blobs/{hash}/data` endpoint.
    fn quoted_hex_body(blob: &Blob) -> String {
        serde_json::json!(format!("0x{}", hex::encode(blob.as_slice()))).to_string()
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

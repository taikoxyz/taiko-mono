//! Minimal beacon API stub for driver tests.

use std::{
    collections::HashMap,
    sync::{Arc, RwLock},
};

use alloy_eips::{eip4844::kzg_to_versioned_hash, eip7594::BlobTransactionSidecarVariant};
use alloy_primitives::{B256, hex};
use anyhow::Result;
use http_body_util::Full;
use hyper::{
    Method, StatusCode, body::Bytes as HyperBytes, header::CONTENT_TYPE,
    server::conn::http1::Builder as Http1Builder, service::service_fn,
};
use tokio::{net::TcpListener, select, spawn, sync::Notify, task::JoinHandle};
use url::Url;

/// A blob served by the stub.
#[derive(Clone)]
struct StoredBlob {
    /// Versioned hash of the KZG commitment the blob was added with.
    versioned_hash: B256,
    /// Hex-encoded blob body.
    blob: String,
}

/// Shared state for the served blobs.
struct BlobStoreInner {
    /// Blobs keyed by slot, in block order.
    by_slot: HashMap<u64, Vec<StoredBlob>>,
    /// Default blobs returned for any slot not in `by_slot`.
    default: Vec<StoredBlob>,
}

type BlobStore = Arc<RwLock<BlobStoreInner>>;

/// Minimal beacon API stub for driver startup (genesis/spec/block/blobs endpoints).
pub struct BeaconStubServer {
    endpoint: Url,
    shutdown: Arc<Notify>,
    handle: JoinHandle<()>,
    blobs: BlobStore,
}

impl BeaconStubServer {
    pub async fn start() -> Result<Self> {
        let listener = TcpListener::bind("127.0.0.1:0").await?;
        let addr = listener.local_addr()?;
        let endpoint = Url::parse(&format!("http://{addr}"))?;

        let shutdown = Arc::new(Notify::new());
        let cancel = shutdown.clone();

        let blobs: BlobStore =
            Arc::new(RwLock::new(BlobStoreInner { by_slot: HashMap::new(), default: Vec::new() }));
        let store = blobs.clone();

        let handle = spawn(async move {
            loop {
                select! {
                    _ = cancel.notified() => break,
                    accept_result = listener.accept() => {
                        let Ok((stream, _)) = accept_result else { continue };
                        let store = store.clone();
                        spawn(async move {
                            let io = hyper_util::rt::TokioIo::new(stream);
                            let service = service_fn(move |req| {
                                let store = store.clone();
                                async move {
                                    Ok::<_, hyper::Error>(handle_beacon_request(req, &store))
                                }
                            });
                            let _ = Http1Builder::new().serve_connection(io, service).await;
                        });
                    }
                }
            }
        });

        Ok(Self { endpoint, shutdown, handle, blobs })
    }

    /// Stub genesis time (matches the value returned by `/eth/v1/beacon/genesis`).
    pub const GENESIS_TIME: u64 = 0;

    /// Stub seconds per slot (matches the value returned by `/eth/v1/config/spec`).
    pub const SECONDS_PER_SLOT: u64 = 12;

    pub fn endpoint(&self) -> &Url {
        &self.endpoint
    }

    /// Convert a timestamp to a beacon slot using the stub's genesis time and slot duration.
    pub fn timestamp_to_slot(timestamp: u64) -> u64 {
        (timestamp - Self::GENESIS_TIME) / Self::SECONDS_PER_SLOT
    }

    /// Add a blob sidecar's blobs for the given slot. Can be called multiple times for the same
    /// slot.
    pub fn add_blob_sidecar(&self, slot: u64, sidecar: BlobTransactionSidecarVariant) {
        let mut store = self.blobs.write().unwrap();
        let entry = store.by_slot.entry(slot).or_default();
        Self::append_sidecar_blobs(entry, &sidecar);
    }

    /// Set the default blob sidecar whose blobs are returned for ANY slot that has no specific
    /// blobs, replacing any previously set default. Useful for tests that don't know the exact
    /// slot ahead of time.
    pub fn set_default_blob_sidecar(&self, sidecar: BlobTransactionSidecarVariant) {
        let mut store = self.blobs.write().unwrap();
        store.default.clear();
        Self::append_sidecar_blobs(&mut store.default, &sidecar);
    }

    /// Append a blob sidecar to the defaults without discarding earlier ones. Use when
    /// several proposals must stay fetchable at once: consumers request blobs by versioned
    /// hash, and reconnect replay can re-fetch an earlier proposal's blob at any point.
    pub fn add_default_blob_sidecar(&self, sidecar: BlobTransactionSidecarVariant) {
        let mut store = self.blobs.write().unwrap();
        Self::append_sidecar_blobs(&mut store.default, &sidecar);
    }

    fn append_sidecar_blobs(target: &mut Vec<StoredBlob>, sidecar: &BlobTransactionSidecarVariant) {
        // Extract the EIP-4844 sidecar from the variant
        let sidecar = sidecar.as_eip4844().expect("Expected EIP-4844 sidecar variant");

        for (blob, commitment) in sidecar.blobs.iter().zip(&sidecar.commitments) {
            target.push(StoredBlob {
                versioned_hash: kzg_to_versioned_hash(commitment.as_slice()),
                blob: hex::encode_prefixed(blob),
            });
        }
    }

    pub async fn shutdown(mut self) -> Result<()> {
        self.shutdown.notify_waiters();
        // Await by reference: Drop still owns the handle and its abort is a no-op on
        // the already-finished task.
        (&mut self.handle).await?;
        Ok(())
    }
}

impl Drop for BeaconStubServer {
    /// Aborts the accept loop so tests that return early (failed `ensure!`, `?`) cannot
    /// leak a listener that keeps serving stale blobs while teardown runs.
    fn drop(&mut self) {
        self.handle.abort();
    }
}

/// Handle a single beacon API request against the blob store.
fn handle_beacon_request(
    req: hyper::Request<hyper::body::Incoming>,
    store: &BlobStore,
) -> hyper::Response<Full<HyperBytes>> {
    let empty_response = |status| {
        hyper::Response::builder().status(status).body(Full::new(HyperBytes::new())).unwrap()
    };

    if req.method() != Method::GET {
        return empty_response(StatusCode::METHOD_NOT_ALLOWED);
    }

    let path = req.uri().path();

    // Handle the blobs endpoint, which serves only the blobs of the requested versioned hashes
    // (every blob of the slot when there are none), in block order.
    if let Some(slot_str) = path.strip_prefix("/eth/v1/beacon/blobs/") {
        let Ok(slot) = slot_str.parse::<u64>() else {
            return empty_response(StatusCode::BAD_REQUEST);
        };
        let Some(requested) = requested_versioned_hashes(req.uri().query()) else {
            return empty_response(StatusCode::BAD_REQUEST);
        };

        let store = store.read().unwrap();
        // Return slot-specific blobs if available, otherwise return the default blobs.
        let blobs = store.by_slot.get(&slot).unwrap_or(&store.default);
        let data: Vec<&str> = blobs
            .iter()
            .filter(|stored| requested.is_empty() || requested.contains(&stored.versioned_hash))
            .map(|stored| stored.blob.as_str())
            .collect();
        let response = serde_json::json!({
            "execution_optimistic": false,
            "finalized": false,
            "data": data,
        });
        let body = serde_json::to_vec(&response).expect("serialization never fails");

        return hyper::Response::builder()
            .status(StatusCode::OK)
            .header(CONTENT_TYPE, "application/json")
            .body(Full::new(HyperBytes::from(body)))
            .unwrap();
    }

    let json = match path {
        "/eth/v1/beacon/genesis" => r#"{"data":{"genesis_time":"0"}}"#,
        "/eth/v1/config/spec" => r#"{"data":{"SECONDS_PER_SLOT":"12","SLOTS_PER_EPOCH":"32"}}"#,
        _ if path.starts_with("/eth/v2/beacon/blocks/") => {
            r#"{"data":{"message":{"body":{"execution_payload":{"block_number":"0"}}}}}"#
        }
        _ => return empty_response(StatusCode::NOT_FOUND),
    };

    hyper::Response::builder()
        .status(StatusCode::OK)
        .header(CONTENT_TYPE, "application/json")
        .body(Full::new(HyperBytes::from(json)))
        .unwrap()
}

/// Parse the repeated `versioned_hashes` query parameter of a blobs request. Returns `None`, a
/// bad request, for a malformed or duplicated hash, since the parameter holds unique items.
fn requested_versioned_hashes(query: Option<&str>) -> Option<Vec<B256>> {
    let mut hashes = Vec::new();
    for (key, value) in url::form_urlencoded::parse(query.unwrap_or_default().as_bytes()) {
        if key != "versioned_hashes" {
            continue;
        }
        let hash = value.parse::<B256>().ok()?;
        if hashes.contains(&hash) {
            return None;
        }
        hashes.push(hash);
    }
    Some(hashes)
}

#[cfg(test)]
mod tests {
    use alloy_eips::eip4844::{Blob, BlobTransactionSidecar, Bytes48};
    use http_body_util::{BodyExt, Empty};

    use super::*;

    fn sidecar_with_commitment(byte: u8) -> BlobTransactionSidecarVariant {
        BlobTransactionSidecarVariant::Eip4844(BlobTransactionSidecar {
            blobs: vec![Blob::repeat_byte(byte)],
            commitments: vec![Bytes48::repeat_byte(byte)],
            proofs: vec![Bytes48::repeat_byte(byte)],
        })
    }

    /// Versioned hash of the commitment `sidecar_with_commitment(byte)` carries.
    fn versioned_hash(byte: u8) -> B256 {
        kzg_to_versioned_hash(&[byte; 48])
    }

    /// Hex encoding of the blob `sidecar_with_commitment(byte)` carries.
    fn expected_blob(byte: u8) -> String {
        hex::encode_prefixed([byte; 131_072])
    }

    /// Requests `path_and_query` from the stub and returns the status and the served blobs.
    async fn fetch_blobs(
        server: &BeaconStubServer,
        path_and_query: &str,
    ) -> (StatusCode, Vec<String>) {
        let endpoint = server.endpoint();
        let addr = format!(
            "{}:{}",
            endpoint.host_str().expect("stub endpoint has a host"),
            endpoint.port().expect("stub endpoint has a port")
        );
        let stream = tokio::net::TcpStream::connect(addr).await.expect("connect to stub");
        let io = hyper_util::rt::TokioIo::new(stream);
        let (mut sender, connection) =
            hyper::client::conn::http1::handshake(io).await.expect("http1 handshake");
        spawn(connection);

        let request = hyper::Request::builder()
            .uri(path_and_query)
            .header(hyper::header::HOST, "localhost")
            .body(Empty::<HyperBytes>::new())
            .expect("build request");
        let response = sender.send_request(request).await.expect("send request");
        let status = response.status();
        let body = response.into_body().collect().await.expect("read body").to_bytes();
        if status != StatusCode::OK {
            return (status, Vec::new());
        }
        let json: serde_json::Value = serde_json::from_slice(&body).expect("parse body");
        let blobs = json["data"]
            .as_array()
            .expect("data array")
            .iter()
            .map(|blob| blob.as_str().expect("hex blob").to_string())
            .collect();
        (status, blobs)
    }

    #[tokio::test]
    async fn set_default_blob_sidecar_replaces_previous_default() {
        let server = BeaconStubServer::start().await.expect("start stub");
        server.set_default_blob_sidecar(sidecar_with_commitment(0xAA));
        server.set_default_blob_sidecar(sidecar_with_commitment(0xBB));

        let (status, blobs) = fetch_blobs(&server, "/eth/v1/beacon/blobs/0").await;

        assert_eq!(status, StatusCode::OK);
        assert_eq!(blobs, vec![expected_blob(0xBB)]);
        server.shutdown().await.expect("shutdown stub");
    }

    #[tokio::test]
    async fn add_default_blob_sidecar_accumulates() {
        let server = BeaconStubServer::start().await.expect("start stub");
        server.set_default_blob_sidecar(sidecar_with_commitment(0xAA));
        server.add_default_blob_sidecar(sidecar_with_commitment(0xBB));

        let (status, blobs) = fetch_blobs(&server, "/eth/v1/beacon/blobs/0").await;

        assert_eq!(status, StatusCode::OK);
        assert_eq!(blobs, vec![expected_blob(0xAA), expected_blob(0xBB)]);
        server.shutdown().await.expect("shutdown stub");
    }

    #[tokio::test]
    async fn blobs_are_filtered_by_versioned_hashes_in_block_order() {
        let server = BeaconStubServer::start().await.expect("start stub");
        server.add_blob_sidecar(7, sidecar_with_commitment(0xAA));
        server.add_blob_sidecar(7, sidecar_with_commitment(0xBB));
        server.add_blob_sidecar(7, sidecar_with_commitment(0xCC));
        server.set_default_blob_sidecar(sidecar_with_commitment(0xDD));

        let path = format!(
            "/eth/v1/beacon/blobs/7?versioned_hashes={}&versioned_hashes={}",
            versioned_hash(0xCC),
            versioned_hash(0xAA)
        );
        let (status, blobs) = fetch_blobs(&server, &path).await;
        assert_eq!(status, StatusCode::OK);
        assert_eq!(blobs, vec![expected_blob(0xAA), expected_blob(0xCC)]);

        // Other slots serve the default blobs, which do not hold the requested hashes.
        let (status, blobs) = fetch_blobs(&server, &path.replace("/blobs/7", "/blobs/8")).await;
        assert_eq!(status, StatusCode::OK);
        assert!(blobs.is_empty());
        server.shutdown().await.expect("shutdown stub");
    }

    #[tokio::test]
    async fn blobs_reject_duplicated_or_malformed_versioned_hashes() {
        let server = BeaconStubServer::start().await.expect("start stub");
        server.set_default_blob_sidecar(sidecar_with_commitment(0xAA));

        let hash = versioned_hash(0xAA);
        for query in [
            format!("versioned_hashes={hash}&versioned_hashes={hash}"),
            "versioned_hashes=0x01".into(),
        ] {
            let (status, _) =
                fetch_blobs(&server, &format!("/eth/v1/beacon/blobs/0?{query}")).await;
            assert_eq!(status, StatusCode::BAD_REQUEST, "{query}");
        }
        server.shutdown().await.expect("shutdown stub");
    }
}

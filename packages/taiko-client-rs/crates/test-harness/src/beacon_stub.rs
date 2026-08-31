//! Minimal beacon API stub for driver tests.

use std::{
    collections::HashMap,
    sync::{Arc, RwLock},
};

use alloy_eips::eip7594::BlobTransactionSidecarVariant;
use alloy_primitives::hex;
use anyhow::Result;
use http_body_util::Full;
use hyper::{
    Method, StatusCode, body::Bytes as HyperBytes, header::CONTENT_TYPE,
    server::conn::http1::Builder as Http1Builder, service::service_fn,
};
use serde::Serialize;
use tokio::{net::TcpListener, select, spawn, sync::Notify, task::JoinHandle};
use url::Url;

/// Blob sidecar data stored in hex-encoded format for JSON serialization.
#[derive(Clone, Serialize)]
struct BlobSidecarData {
    blob: String,
    #[serde(rename = "kzg_commitment")]
    kzg_commitment: String,
    #[serde(rename = "kzg_proof")]
    kzg_proof: String,
}

/// Shared state for blob sidecars.
struct BlobSidecarStoreInner {
    /// Sidecars keyed by slot.
    by_slot: HashMap<u64, Vec<BlobSidecarData>>,
    /// Default sidecars returned for any slot not in `by_slot`.
    default: Vec<BlobSidecarData>,
}

type BlobSidecarStore = Arc<RwLock<BlobSidecarStoreInner>>;

/// Minimal beacon API stub for driver startup (genesis/spec/block/blob_sidecars endpoints).
pub struct BeaconStubServer {
    endpoint: Url,
    shutdown: Arc<Notify>,
    handle: JoinHandle<()>,
    blob_sidecars: BlobSidecarStore,
}

impl BeaconStubServer {
    pub async fn start() -> Result<Self> {
        let listener = TcpListener::bind("127.0.0.1:0").await?;
        let addr = listener.local_addr()?;
        let endpoint = Url::parse(&format!("http://{addr}"))?;

        let shutdown = Arc::new(Notify::new());
        let cancel = shutdown.clone();

        let blob_sidecars: BlobSidecarStore = Arc::new(RwLock::new(BlobSidecarStoreInner {
            by_slot: HashMap::new(),
            default: Vec::new(),
        }));
        let store = blob_sidecars.clone();

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

        Ok(Self { endpoint, shutdown, handle, blob_sidecars })
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

    /// Add a blob sidecar for the given slot. Can be called multiple times for the same slot.
    pub fn add_blob_sidecar(&self, slot: u64, sidecar: BlobTransactionSidecarVariant) {
        let mut store = self.blob_sidecars.write().unwrap();
        let entry = store.by_slot.entry(slot).or_default();
        Self::append_sidecar_data(entry, &sidecar);
    }

    /// Set the default blob sidecar returned for ANY slot that has no specific sidecars,
    /// replacing any previously set default. Useful for tests that don't know the exact
    /// slot ahead of time.
    pub fn set_default_blob_sidecar(&self, sidecar: BlobTransactionSidecarVariant) {
        let mut store = self.blob_sidecars.write().unwrap();
        store.default.clear();
        Self::append_sidecar_data(&mut store.default, &sidecar);
    }

    /// Append a blob sidecar to the defaults without discarding earlier ones. Use when
    /// several proposals must stay fetchable at once: consumers hash-match against every
    /// returned sidecar, and reconnect replay can re-fetch an earlier proposal's blob at
    /// any point.
    pub fn add_default_blob_sidecar(&self, sidecar: BlobTransactionSidecarVariant) {
        let mut store = self.blob_sidecars.write().unwrap();
        Self::append_sidecar_data(&mut store.default, &sidecar);
    }

    fn append_sidecar_data(
        target: &mut Vec<BlobSidecarData>,
        sidecar: &BlobTransactionSidecarVariant,
    ) {
        // Extract the EIP-4844 sidecar from the variant
        let sidecar = sidecar.as_eip4844().expect("Expected EIP-4844 sidecar variant");

        for (i, blob) in sidecar.blobs.iter().enumerate() {
            let commitment = sidecar.commitments.get(i).map(|c| c.as_slice()).unwrap_or(&[]);
            let proof = sidecar.proofs.get(i).map(|p| p.as_slice()).unwrap_or(&[]);

            target.push(BlobSidecarData {
                blob: format!("0x{}", hex::encode(blob.as_slice())),
                kzg_commitment: format!("0x{}", hex::encode(commitment)),
                kzg_proof: format!("0x{}", hex::encode(proof)),
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
    /// leak a listener that keeps serving stale sidecars while teardown runs.
    fn drop(&mut self) {
        self.handle.abort();
    }
}

/// Handle a single beacon API request against the sidecar store.
fn handle_beacon_request(
    req: hyper::Request<hyper::body::Incoming>,
    store: &BlobSidecarStore,
) -> hyper::Response<Full<HyperBytes>> {
    let empty_response = |status| {
        hyper::Response::builder().status(status).body(Full::new(HyperBytes::new())).unwrap()
    };

    if req.method() != Method::GET {
        return empty_response(StatusCode::METHOD_NOT_ALLOWED);
    }

    let path = req.uri().path();

    // Handle blob_sidecars endpoint
    if let Some(slot_str) = path.strip_prefix("/eth/v1/beacon/blob_sidecars/") {
        let Ok(slot) = slot_str.parse::<u64>() else {
            return empty_response(StatusCode::BAD_REQUEST);
        };

        let sidecars = store.read().unwrap();
        // Return slot-specific sidecars if available, otherwise return default sidecars.
        let data = sidecars.by_slot.get(&slot).cloned().unwrap_or_else(|| sidecars.default.clone());

        #[derive(Serialize)]
        struct BlobSidecarsResponse {
            data: Vec<BlobSidecarData>,
        }

        let response = BlobSidecarsResponse { data };
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

    /// Fetches the sidecars served for an arbitrary slot and returns their commitments.
    async fn fetch_default_commitments(server: &BeaconStubServer) -> Vec<String> {
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
            .uri("/eth/v1/beacon/blob_sidecars/0")
            .header(hyper::header::HOST, "localhost")
            .body(Empty::<HyperBytes>::new())
            .expect("build request");
        let response = sender.send_request(request).await.expect("send request");
        assert_eq!(response.status(), StatusCode::OK);
        let body = response.into_body().collect().await.expect("read body").to_bytes();
        let json: serde_json::Value = serde_json::from_slice(&body).expect("parse body");
        json["data"]
            .as_array()
            .expect("data array")
            .iter()
            .map(|entry| entry["kzg_commitment"].as_str().expect("commitment").to_string())
            .collect()
    }

    fn expected_commitment(byte: u8) -> String {
        format!("0x{}", hex::encode([byte; 48]))
    }

    #[tokio::test]
    async fn set_default_blob_sidecar_replaces_previous_default() {
        let server = BeaconStubServer::start().await.expect("start stub");
        server.set_default_blob_sidecar(sidecar_with_commitment(0xAA));
        server.set_default_blob_sidecar(sidecar_with_commitment(0xBB));

        let commitments = fetch_default_commitments(&server).await;

        assert_eq!(commitments, vec![expected_commitment(0xBB)]);
        server.shutdown().await.expect("shutdown stub");
    }

    #[tokio::test]
    async fn add_default_blob_sidecar_accumulates() {
        let server = BeaconStubServer::start().await.expect("start stub");
        server.set_default_blob_sidecar(sidecar_with_commitment(0xAA));
        server.add_default_blob_sidecar(sidecar_with_commitment(0xBB));

        let commitments = fetch_default_commitments(&server).await;

        assert_eq!(commitments, vec![expected_commitment(0xAA), expected_commitment(0xBB)]);
        server.shutdown().await.expect("shutdown stub");
    }
}

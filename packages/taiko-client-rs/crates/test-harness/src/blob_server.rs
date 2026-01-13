use std::{collections::HashMap, sync::Arc};

use alloy_eips::eip4844::{BlobTransactionSidecar, kzg_to_versioned_hash};
use alloy_primitives::hex;
use anyhow::{Context, Result, anyhow};
use http_body_util::Full;
use hyper::{
    Method, Request, Response, StatusCode,
    body::{Bytes as HyperBytes, Incoming},
    server::conn::http1,
    service::service_fn,
};
use hyper_util::rt::TokioIo;
use serde::Serialize;
use tokio::{net::TcpListener, select, spawn, sync::Notify, task::JoinHandle};
use tracing::warn;
use url::Url;

/// Minimal HTTP server that serves blob sidecars over `/blobs/{hash}`.
pub struct BlobServer {
    endpoint: Url,
    shutdown: Option<Arc<Notify>>,
    handle: JoinHandle<()>,
}

impl BlobServer {
    /// Spins up a per-test blob server bound to localhost with deterministic responses.
    pub async fn start(sidecar: BlobTransactionSidecar) -> Result<Self> {
        let listener = TcpListener::bind("127.0.0.1:0").await?;
        let addr = listener.local_addr()?;
        let endpoint = Url::parse(format!("http://{}", addr).as_str())?;

        let responses =
            Arc::new(build_blob_responses(sidecar).context("failed to build blob store")?);

        let shutdown = Arc::new(tokio::sync::Notify::new());
        let cancel = shutdown.clone();

        let handle = spawn(async move {
            loop {
                select! {
                    _ = cancel.notified() => {
                        break;
                    }
                    accept_result = listener.accept() => {
                        let Ok((stream, _peer)) = accept_result else {
                            continue;
                        };

                        let store = responses.clone();
                        tokio::spawn(async move {
                            let io = TokioIo::new(stream);
                            if let Err(err) = http1::Builder::new()
                                .serve_connection(io, service_fn(move |req| {
                                    let store = store.clone();
                                    async move {
                                        Ok::<_, hyper::Error>(handle_blob_request(req, store))
                                    }
                                }))
                                .await
                            {
                                warn!(?err, "blob server connection error");
                            }
                        });
                    }
                }
            }
        });

        Ok(Self { endpoint, shutdown: Some(shutdown), handle })
    }

    /// Returns the server's endpoint URL.
    pub fn endpoint(&self) -> &Url {
        &self.endpoint
    }

    /// Returns the base URL as a plain string for downstream config wiring.
    pub fn base_url(&self) -> String {
        self.endpoint.to_string()
    }

    /// Gracefully shuts down the server.
    pub async fn shutdown(self) -> Result<()> {
        if let Some(notify) = self.shutdown {
            notify.notify_waiters();
        }
        self.handle.await?;
        Ok(())
    }
}

#[derive(Serialize)]
struct BlobResponse {
    #[serde(rename = "versionedHash")]
    versioned_hash: String,
    commitment: String,
    data: String,
}

/// Builds a map of versioned hash (hex string) to `BlobResponse` from the given sidecar.
fn build_blob_responses(sidecar: BlobTransactionSidecar) -> Result<HashMap<String, BlobResponse>> {
    let mut responses = HashMap::new();
    for (index, commitment) in sidecar.commitments.iter().enumerate() {
        let versioned_hash = kzg_to_versioned_hash(commitment.as_slice());
        let blob = sidecar
            .blobs
            .get(index)
            .ok_or_else(|| anyhow!("missing blob for commitment index {}", index))?;

        let hash_str = format!("{:#x}", versioned_hash);
        let response = BlobResponse {
            versioned_hash: hash_str.clone(),
            commitment: format!("0x{}", hex::encode(commitment.as_slice())),
            data: format!("0x{}", hex::encode(blob.as_slice())),
        };
        responses.insert(hash_str, response);
    }

    Ok(responses)
}

/// Handles incoming HTTP requests and serves blob responses from the store.
fn handle_blob_request(
    req: Request<Incoming>,
    store: Arc<HashMap<String, BlobResponse>>,
) -> Response<Full<HyperBytes>> {
    if req.method() != Method::GET {
        return Response::builder()
            .status(StatusCode::METHOD_NOT_ALLOWED)
            .body(Full::new(HyperBytes::new()))
            .unwrap();
    }

    let Some(hash) = req.uri().path().strip_prefix("/blobs/") else {
        return Response::builder()
            .status(StatusCode::NOT_FOUND)
            .body(Full::new(HyperBytes::new()))
            .unwrap();
    };

    let key = if hash.starts_with("0x") { hash.to_string() } else { format!("0x{}", hash) };
    let Some(response) = store.get(&key) else {
        return Response::builder()
            .status(StatusCode::NOT_FOUND)
            .body(Full::new(HyperBytes::new()))
            .unwrap();
    };

    let body = serde_json::to_vec(response).expect("blob response serialization never fails");

    Response::builder()
        .status(StatusCode::OK)
        .header(hyper::header::CONTENT_TYPE, "application/json")
        .body(Full::new(HyperBytes::from(body)))
        .unwrap()
}

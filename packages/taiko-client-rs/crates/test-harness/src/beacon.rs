//! A fake L1 beacon node serving anvil's blobs.
//!
//! anvil keeps the blobs of the type-3 transactions it mines and serves them by versioned hash
//! (`anvil_getBlobByHash`), but its beacon API lacks `/eth/v1/config/spec`, which
//! `rpc::beacon::BeaconClient` reads when it connects. [`FakeBeacon`] serves the routes that
//! client uses, with genesis at time 0 and one-second slots (a slot number is an L1 timestamp):
//! `/eth/v1/beacon/genesis`, `/eth/v1/config/spec` and
//! `/eth/v1/beacon/blobs/{block_id}?versioned_hashes=…`, which answers every requested hash from
//! anvil whatever the block (the client matches each blob to its hash by KZG commitment).

use alloy_primitives::{B256, Bytes};
use alloy_provider::RootProvider;
use anyhow::Result;
use axum::{
    Json, Router,
    extract::{RawQuery, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::get,
};
use rpc::client::{DEFAULT_HTTP_TIMEOUT, connect_http_with_timeout};
use serde_json::{Value, json};
use tokio::{net::TcpListener, task::JoinHandle};
use url::Url;

use crate::{boot::local_url, l1::anvil_request};

/// A running fake beacon node; dropping it stops the server.
#[derive(Debug)]
pub struct FakeBeacon {
    /// Its REST endpoint (`http://127.0.0.1:<port>/`).
    pub url: Url,
    /// The server task.
    task: JoinHandle<()>,
}

impl FakeBeacon {
    /// Serves a fake beacon over the anvil at `anvil_http` on an ephemeral local port, from a
    /// task of the current tokio runtime.
    pub async fn start(anvil_http: Url) -> Result<FakeBeacon> {
        let l1 = connect_http_with_timeout(anvil_http, DEFAULT_HTTP_TIMEOUT);
        let listener = TcpListener::bind("127.0.0.1:0").await?;
        let url = local_url(listener.local_addr()?.port())?;
        let router = Router::new()
            .route("/eth/v1/beacon/genesis", get(genesis))
            .route("/eth/v1/config/spec", get(spec))
            .route("/eth/v1/beacon/blobs/:block_id", get(blobs))
            .with_state(l1);
        let task = tokio::spawn(async move {
            if let Err(e) = axum::serve(listener, router).await {
                eprintln!("fake beacon stopped: {e}");
            }
        });
        Ok(Self { url, task })
    }
}

impl Drop for FakeBeacon {
    /// Stops the server.
    fn drop(&mut self) {
        self.task.abort();
    }
}

/// `/eth/v1/beacon/genesis`: genesis at time 0.
async fn genesis() -> Json<Value> {
    Json(json!({ "data": { "genesis_time": "0" } }))
}

/// `/eth/v1/config/spec`: one-second slots, 32 per epoch.
async fn spec() -> Json<Value> {
    Json(json!({ "data": { "SECONDS_PER_SLOT": "1", "SLOTS_PER_EPOCH": "32" } }))
}

/// `/eth/v1/beacon/blobs/{block_id}?versioned_hashes=…` (repeated or comma-separated): anvil's
/// blob of every requested hash, in request order, whatever the block. Answers 400 without a
/// hash or for a malformed one, 404 when anvil lacks a blob and 502 when anvil fails.
async fn blobs(State(l1): State<RootProvider>, RawQuery(query): RawQuery) -> Response {
    let query = query.unwrap_or_default();
    let mut hashes = Vec::new();
    for (key, value) in url::form_urlencoded::parse(query.as_bytes()) {
        if key != "versioned_hashes" {
            continue;
        }
        for hash in value.split(',') {
            match hash.parse::<B256>() {
                Ok(hash) => hashes.push(hash),
                Err(e) => {
                    let message = format!("versioned hash {hash:?}: {e}");
                    return (StatusCode::BAD_REQUEST, message).into_response();
                }
            }
        }
    }
    if hashes.is_empty() {
        return (StatusCode::BAD_REQUEST, "versioned_hashes required").into_response();
    }
    let mut data = Vec::with_capacity(hashes.len());
    for hash in hashes {
        match anvil_request::<Option<Bytes>>(&l1, "anvil_getBlobByHash", json!([hash])).await {
            Ok(Some(blob)) => data.push(blob),
            Ok(None) => {
                return (StatusCode::NOT_FOUND, format!("anvil has no blob {hash}")).into_response();
            }
            Err(e) => return (StatusCode::BAD_GATEWAY, format!("{e:#}")).into_response(),
        }
    }
    Json(json!({ "data": data })).into_response()
}

#[cfg(test)]
mod tests {
    use rpc::beacon::BeaconClient;

    use super::*;

    /// The beacon client connects to the fake beacon (genesis 0, one-second slots); a blobs
    /// request without a versioned hash is refused, and one anvil cannot answer fails.
    #[tokio::test]
    async fn the_beacon_client_connects_and_blob_requests_go_to_anvil() {
        // A free port nothing listens on: anvil is unreachable.
        let addr = std::net::TcpListener::bind("127.0.0.1:0").unwrap().local_addr().unwrap();
        let beacon = FakeBeacon::start(Url::parse(&format!("http://{addr}")).unwrap())
            .await
            .expect("starts");
        let client = BeaconClient::new(beacon.url.clone()).await.expect("connects");
        assert_eq!(client.genesis_time(), 0);
        assert_eq!(client.slots_per_epoch(), 32);
        assert_eq!(client.timestamp_to_epoch(64).unwrap(), 2, "one-second slots");

        let http = reqwest::Client::builder().no_proxy().build().unwrap();
        let blobs = beacon.url.join("/eth/v1/beacon/blobs/7").unwrap();
        let status = |url: Url| {
            let http = http.clone();
            async move { http.get(url).send().await.unwrap().status() }
        };
        assert_eq!(status(blobs.clone()).await, StatusCode::BAD_REQUEST);
        let mut malformed = blobs.clone();
        malformed.set_query(Some("versioned_hashes=0x01"));
        assert_eq!(status(malformed).await, StatusCode::BAD_REQUEST);
        let mut unanswered = blobs;
        unanswered.set_query(Some(&format!("versioned_hashes={}", B256::repeat_byte(1))));
        assert_eq!(status(unanswered).await, StatusCode::BAD_GATEWAY);
    }
}

//! Lightweight beacon client used for fetching blobs.
//!
//! The Go driver first asks a beacon node for a proposal's blobs through
//! `/eth/v1/beacon/blobs/<slot>?versioned_hashes=...` and only falls back to the blob server if the
//! beacon call fails. This module provides the same functionality so the Rust driver mirrors the Go
//! behaviour.

use std::{
    collections::HashMap,
    time::{SystemTime, UNIX_EPOCH},
};

use alloy::primitives::B256;
use alloy_eips::eip4844::{Blob, Bytes48};
use alloy_rpc_types::BlobTransactionSidecar;
use reqwest::{Client as HttpClient, header::ACCEPT};
use serde::Deserialize;
use tracing::{debug, warn};
use url::Url;

use crate::{
    blob::{BlobDataError, compute_blob_commitment, parse_blob, versioned_hash_from_commitment},
    client::DEFAULT_HTTP_TIMEOUT,
};

/// JSON payload returned by `/eth/v1/beacon/genesis`.
#[derive(Debug, Deserialize)]
struct GenesisResponse {
    /// Parsed genesis payload body.
    data: GenesisData,
}

/// Inner data of the genesis response.
#[derive(Debug, Deserialize)]
struct GenesisData {
    /// Beacon-chain genesis time as a decimal string.
    #[serde(rename = "genesis_time")]
    genesis_time: String,
}

/// JSON payload returned by `/eth/v1/config/spec`.
#[derive(Debug, Deserialize)]
struct SpecResponse {
    /// Raw beacon spec map keyed by field name.
    data: serde_json::Value,
}

/// JSON payload returned by `/eth/v1/beacon/blobs/<slot>`.
#[derive(Debug, Deserialize)]
struct BlobsResponse {
    /// Hex-encoded blobs, in block order per the spec (Lighthouse keeps the request order).
    data: Vec<String>,
}

/// JSON payload returned by `/eth/v2/beacon/blocks/<slot>`.
#[derive(Debug, Deserialize)]
struct BeaconBlockResponse {
    /// Block payload for the queried slot.
    data: BeaconBlockData,
}

/// Inner data of a beacon block response.
#[derive(Debug, Deserialize)]
struct BeaconBlockData {
    /// Beacon block message content.
    message: BeaconBlockMessage,
}

/// Beacon block message body.
#[derive(Debug, Deserialize)]
struct BeaconBlockMessage {
    /// Block body that may include execution payload metadata.
    body: BeaconBlockBody,
}

/// Beacon block body containing the execution payload or header.
#[derive(Debug, Deserialize)]
struct BeaconBlockBody {
    /// Full execution payload when the block is unblinded.
    #[serde(rename = "execution_payload")]
    execution_payload: Option<ExecutionPayload>,
    /// Execution payload header when the block is blinded.
    #[serde(rename = "execution_payload_header")]
    execution_payload_header: Option<ExecutionPayloadHeader>,
}

/// Execution payload returned by the beacon node.
#[derive(Debug, Deserialize)]
struct ExecutionPayload {
    /// Execution-layer block number encoded as decimal string.
    #[serde(rename = "block_number")]
    block_number: String,
}

/// Blinded execution payload header returned by the beacon node.
#[derive(Debug, Deserialize)]
struct ExecutionPayloadHeader {
    /// Execution-layer block number encoded as decimal string.
    #[serde(rename = "block_number")]
    block_number: String,
}

/// Minimal beacon client capable of retrieving blobs.
#[derive(Debug)]
pub struct BeaconClient {
    /// Base beacon REST endpoint URL.
    endpoint: Url,
    /// Shared HTTP client used for beacon requests.
    http: HttpClient,
    /// Beacon genesis timestamp (seconds since UNIX epoch).
    genesis_time: u64,
    /// Slot duration in seconds from beacon spec.
    seconds_per_slot: u64,
    /// Number of slots per epoch from beacon spec.
    slots_per_epoch: u64,
}

impl BeaconClient {
    /// Build a new beacon client by fetching genesis and slot/epoch metadata.
    ///
    /// The Go client follows the same pattern: it reads `/eth/v1/beacon/genesis` to determine
    /// the genesis timestamp and `/eth/v1/config/spec` to fetch `SECONDS_PER_SLOT`. Those values
    /// allow proposal timestamps to be converted into the correct beacon slot.
    pub async fn new(endpoint: Url) -> Result<Self, BlobDataError> {
        let http = HttpClient::builder()
            .no_proxy()
            .timeout(DEFAULT_HTTP_TIMEOUT)
            .build()
            .map_err(|err| BlobDataError::Other(err.into()))?;

        let genesis_url = endpoint
            .join("/eth/v1/beacon/genesis")
            .map_err(|err| BlobDataError::Other(err.into()))?;
        let genesis_res =
            http.get(genesis_url).send().await.map_err(|err| BlobDataError::Other(err.into()))?;
        if !genesis_res.status().is_success() {
            return Err(BlobDataError::Beacon(format!(
                "genesis request failed with status {}",
                genesis_res.status()
            )));
        }
        let genesis: GenesisResponse =
            genesis_res.json().await.map_err(|err| BlobDataError::Parse(err.to_string()))?;
        let genesis_time = genesis
            .data
            .genesis_time
            .parse::<u64>()
            .map_err(|err| BlobDataError::Parse(err.to_string()))?;

        let spec_url =
            endpoint.join("/eth/v1/config/spec").map_err(|err| BlobDataError::Other(err.into()))?;
        let spec_res =
            http.get(spec_url).send().await.map_err(|err| BlobDataError::Other(err.into()))?;
        if !spec_res.status().is_success() {
            return Err(BlobDataError::Beacon(format!(
                "spec request failed with status {}",
                spec_res.status()
            )));
        }
        let spec: SpecResponse =
            spec_res.json().await.map_err(|err| BlobDataError::Parse(err.to_string()))?;
        let seconds_per_slot = parse_spec_positive_u64(&spec.data, "SECONDS_PER_SLOT")?;
        let slots_per_epoch = parse_spec_positive_u64(&spec.data, "SLOTS_PER_EPOCH")?;

        debug!(
            seconds_per_slot,
            slots_per_epoch, genesis_time, "initialised beacon client metadata"
        );

        Ok(Self { endpoint, http, genesis_time, seconds_per_slot, slots_per_epoch })
    }

    /// Fetch the blobs with the given versioned hashes from the beacon block at the slot that
    /// corresponds to the provided timestamp, as one sidecar per hash in the order of
    /// `blob_hashes`.
    ///
    /// Beacon nodes return blobs without their KZG commitments, in block order per the spec
    /// (Lighthouse keeps the request order instead), so every returned blob is matched to a
    /// versioned hash by recomputing its commitment: a beacon node can make this call fail, but it
    /// cannot make it return a blob that does not match the requested versioned hash. The
    /// sidecars carry no KZG proofs.
    ///
    /// If the beacon node returns an error status or misses a blob, the caller is expected to fall
    /// back to the blob server. This mirrors the Go driver's behaviour.
    pub async fn blobs_by_timestamp(
        &self,
        timestamp: u64,
        blob_hashes: &[B256],
    ) -> Result<Vec<BlobTransactionSidecar>, BlobDataError> {
        if blob_hashes.is_empty() {
            return Ok(Vec::new());
        }

        let slot = self.timestamp_to_slot(timestamp)?;
        // The endpoint takes unique versioned hashes, while a proposal may reference the same blob
        // twice.
        let mut unique_hashes = Vec::with_capacity(blob_hashes.len());
        for hash in blob_hashes {
            if !unique_hashes.contains(hash) {
                unique_hashes.push(*hash);
            }
        }

        let blobs = self.blobs_by_slot(slot, &unique_hashes).await?;
        match_blobs_off_runtime(slot, blobs, blob_hashes).await
    }

    /// Fetch the blobs with the given versioned hashes from the beacon block at `slot`.
    async fn blobs_by_slot(
        &self,
        slot: u64,
        blob_hashes: &[B256],
    ) -> Result<Vec<Blob>, BlobDataError> {
        let mut blobs_url = self
            .endpoint
            .join(&format!("/eth/v1/beacon/blobs/{slot}"))
            .map_err(|err| BlobDataError::Other(err.into()))?;
        for hash in blob_hashes {
            blobs_url.query_pairs_mut().append_pair("versioned_hashes", &hash.to_string());
        }
        debug!(slot, url = blobs_url.as_str(), "requesting beacon blobs");

        let response = self
            .http
            .get(blobs_url.clone())
            .header(ACCEPT, "application/json")
            .send()
            .await
            .map_err(|err| BlobDataError::Other(err.into()))?;
        if !response.status().is_success() {
            debug!(
                status = response.status().as_u16(),
                url = blobs_url.as_str(),
                "beacon blobs request failed"
            );
            return Err(BlobDataError::HttpStatus { status: response.status().as_u16() });
        }

        let payload: BlobsResponse =
            response.json().await.map_err(|err| BlobDataError::Parse(err.to_string()))?;

        // A plain loop: iterator adapters copy each 128 KiB blob through several stack frames.
        let mut blobs = Vec::with_capacity(payload.data.len());
        for blob in &payload.data {
            blobs.push(parse_blob(blob)?);
        }
        Ok(blobs)
    }

    /// Resolve the execution-layer block number for the provided timestamp by querying the beacon
    /// node. If the computed slot does not contain a block (missed slot), the search walks
    /// backwards until a block with an execution payload or header is found.
    pub async fn execution_block_number_by_timestamp(
        &self,
        timestamp: u64,
    ) -> Result<u64, BlobDataError> {
        let mut slot = self.timestamp_to_slot(timestamp)?;
        loop {
            match self.execution_block_number_by_slot(slot).await {
                Ok(Some(number)) => return Ok(number),
                Ok(None) => {
                    debug!(slot, "beacon slot missing execution payload; trying previous slot");
                }
                Err(BlobDataError::HttpStatus { status: 404 }) => {
                    debug!(slot, "beacon block not found for slot; trying previous slot");
                }
                Err(err) => return Err(err),
            }

            if slot == 0 {
                break;
            }
            slot -= 1;
        }

        Err(BlobDataError::Beacon(format!(
            "unable to locate execution block for timestamp {timestamp}"
        )))
    }

    /// Fetch the execution block number for a specific beacon slot.
    async fn execution_block_number_by_slot(
        &self,
        slot: u64,
    ) -> Result<Option<u64>, BlobDataError> {
        let block_url = self
            .endpoint
            .join(&format!("/eth/v2/beacon/blocks/{slot}"))
            .map_err(|err| BlobDataError::Other(err.into()))?;
        debug!(slot, url = block_url.as_str(), "requesting beacon block by slot");

        let response = self
            .http
            .get(block_url.clone())
            .send()
            .await
            .map_err(|err| BlobDataError::Other(err.into()))?;
        if !response.status().is_success() {
            warn!(
                status = response.status().as_u16(),
                slot,
                url = block_url.as_str(),
                "beacon block request failed"
            );
            return Err(BlobDataError::HttpStatus { status: response.status().as_u16() });
        }

        let payload: BeaconBlockResponse =
            response.json().await.map_err(|err| BlobDataError::Parse(err.to_string()))?;

        let Some(block_number) = payload.execution_block_number() else {
            debug!(slot, "beacon block missing execution payload");
            return Ok(None);
        };

        let block_number =
            block_number.parse::<u64>().map_err(|err| BlobDataError::Parse(err.to_string()))?;
        Ok(Some(block_number))
    }

    /// Convert an L1 timestamp into a beacon slot using the cached genesis metadata.
    fn timestamp_to_slot(&self, timestamp: u64) -> Result<u64, BlobDataError> {
        if timestamp < self.genesis_time {
            return Err(BlobDataError::Beacon(format!(
                "timestamp {} precedes genesis time {}",
                timestamp, self.genesis_time
            )));
        }
        Ok((timestamp - self.genesis_time) / self.seconds_per_slot)
    }

    /// Convert a timestamp to a beacon epoch.
    pub fn timestamp_to_epoch(&self, timestamp: u64) -> Result<u64, BlobDataError> {
        Ok(self.timestamp_to_slot(timestamp)? / self.slots_per_epoch)
    }

    /// Return the current beacon slot based on local wall-clock time.
    ///
    /// Mirrors the Go driver implementation:
    /// `(now_utc_unix - genesis_time) / seconds_per_slot`.
    fn current_slot(&self) -> u64 {
        let now_secs = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|duration| duration.as_secs())
            .unwrap_or_default();

        now_secs.saturating_sub(self.genesis_time) / self.seconds_per_slot
    }

    /// Return the current beacon epoch based on local wall-clock time.
    ///
    /// Mirrors the Go driver implementation:
    /// `current_slot / slots_per_epoch`.
    pub fn current_epoch(&self) -> u64 {
        self.current_slot() / self.slots_per_epoch
    }

    /// Return the beacon genesis timestamp (seconds since UNIX epoch).
    ///
    /// Fetched from `/eth/v1/beacon/genesis` during client construction.
    pub const fn genesis_time(&self) -> u64 {
        self.genesis_time
    }

    /// Return the number of slots per beacon epoch.
    ///
    /// Fetched from `/eth/v1/config/spec` (`SLOTS_PER_EPOCH`) during client construction.
    pub const fn slots_per_epoch(&self) -> u64 {
        self.slots_per_epoch
    }

    /// Return the current slot's index within its beacon epoch, based on local
    /// wall-clock time.
    pub fn current_slot_in_epoch(&self) -> u64 {
        self.current_slot() % self.slots_per_epoch
    }
}

impl BeaconBlockResponse {
    /// Extract the execution-layer block number string from either the execution payload or its
    /// header (for blinded blocks).
    fn execution_block_number(&self) -> Option<&str> {
        self.data
            .message
            .body
            .execution_payload
            .as_ref()
            .map(|payload| payload.block_number.as_str())
            .or_else(|| {
                self.data
                    .message
                    .body
                    .execution_payload_header
                    .as_ref()
                    .map(|header| header.block_number.as_str())
            })
    }
}

/// [`match_blobs`] on the blocking thread pool: the first commitment loads the KZG trusted setup,
/// which takes seconds on a CPU-limited node and would otherwise stall the async runtime.
async fn match_blobs_off_runtime(
    slot: u64,
    blobs: Vec<Blob>,
    blob_hashes: &[B256],
) -> Result<Vec<BlobTransactionSidecar>, BlobDataError> {
    let blob_hashes = blob_hashes.to_vec();
    tokio::task::spawn_blocking(move || match_blobs(slot, &blobs, &blob_hashes))
        .await
        .map_err(|err| BlobDataError::Other(err.into()))?
}

/// Match fetched blobs to the requested versioned hashes by recomputing their KZG commitments,
/// returning one sidecar per requested hash in request order.
fn match_blobs(
    slot: u64,
    blobs: &[Blob],
    blob_hashes: &[B256],
) -> Result<Vec<BlobTransactionSidecar>, BlobDataError> {
    let mut by_hash = HashMap::with_capacity(blobs.len());
    for (index, blob) in blobs.iter().enumerate() {
        let commitment = compute_blob_commitment(blob)?;
        by_hash.insert(versioned_hash_from_commitment(&commitment), (index, commitment));
    }

    blob_hashes
        .iter()
        .map(|hash| {
            let &(index, commitment) = by_hash.get(hash).ok_or_else(|| {
                BlobDataError::Beacon(format!(
                    "beacon node did not return blob {hash} for slot {slot}"
                ))
            })?;
            Ok(BlobTransactionSidecar {
                // Slice copies go straight to the heap, keeping 128 KiB blobs off the stack.
                blobs: blobs[index..=index].to_vec(),
                commitments: vec![commitment],
                proofs: vec![Bytes48::default()],
            })
        })
        .collect()
}

/// Look up a required positive decimal `u64` value from the beacon `/eth/v1/config/spec` response.
fn parse_spec_positive_u64(spec: &serde_json::Value, key: &str) -> Result<u64, BlobDataError> {
    let value = spec
        .get(key)
        .and_then(|value| value.as_str())
        .ok_or_else(|| BlobDataError::Parse(format!("{key} missing in beacon spec")))?
        .parse::<u64>()
        .map_err(|err| BlobDataError::Parse(err.to_string()))?;
    if value == 0 {
        return Err(BlobDataError::Parse(format!("{key} must be greater than zero")));
    }
    Ok(value)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::{
        TestServer, assert_waits_for_blocking_pool, single_blocking_thread_runtime, start_beacon,
    };
    use alloy::primitives::hex;
    use hyper::{StatusCode, Uri};

    /// A canonical test blob, boxed to keep 128 KiB values out of the test futures, with its KZG
    /// commitment and versioned hash.
    struct TestBlob {
        blob: Box<Blob>,
        commitment: Bytes48,
        hash: B256,
    }

    impl TestBlob {
        fn new(byte: u8) -> Self {
            let blob = Box::new(Blob::repeat_byte(byte));
            let commitment = compute_blob_commitment(&blob).expect("test blob should be canonical");
            Self { blob, commitment, hash: versioned_hash_from_commitment(&commitment) }
        }
    }

    /// Encodes a blobs endpoint response serving `blobs`, in the given (block) order.
    fn blobs_body(blobs: &[&TestBlob]) -> String {
        let data: Vec<_> =
            blobs.iter().map(|blob| hex::encode_prefixed(blob.blob.as_slice())).collect();
        serde_json::json!({ "execution_optimistic": false, "finalized": true, "data": data })
            .to_string()
    }

    /// Starts a beacon node stub answering the blobs endpoint with `blobs`.
    async fn start_blob_beacon(blobs: (StatusCode, String)) -> TestServer {
        start_beacon(move |uri| {
            if uri.path().starts_with("/eth/v1/beacon/blobs/") {
                blobs.clone()
            } else {
                (StatusCode::NOT_FOUND, String::new())
            }
        })
        .await
    }

    /// Starts a beacon node stub with the provided timing values in its spec response.
    async fn start_metadata_beacon(seconds_per_slot: u64, slots_per_epoch: u64) -> TestServer {
        TestServer::start(move |uri| match uri.path() {
            "/eth/v1/beacon/genesis" => {
                (StatusCode::OK, r#"{"data":{"genesis_time":"0"}}"#.to_owned())
            }
            "/eth/v1/config/spec" => (
                StatusCode::OK,
                serde_json::json!({
                    "data": {
                        "SECONDS_PER_SLOT": seconds_per_slot.to_string(),
                        "SLOTS_PER_EPOCH": slots_per_epoch.to_string(),
                    }
                })
                .to_string(),
            ),
            _ => (StatusCode::NOT_FOUND, String::new()),
        })
        .await
    }

    #[tokio::test]
    async fn client_rejects_zero_seconds_per_slot() {
        let beacon = start_metadata_beacon(0, 32).await;

        let result = BeaconClient::new(beacon.endpoint()).await;

        assert!(
            matches!(result, Err(BlobDataError::Parse(ref message)) if message == "SECONDS_PER_SLOT must be greater than zero"),
            "got {result:?}"
        );
    }

    #[tokio::test]
    async fn client_rejects_zero_slots_per_epoch() {
        let beacon = start_metadata_beacon(12, 0).await;

        let result = BeaconClient::new(beacon.endpoint()).await;

        assert!(
            matches!(result, Err(BlobDataError::Parse(ref message)) if message == "SLOTS_PER_EPOCH must be greater than zero"),
            "got {result:?}"
        );
    }

    /// Paths of the `/eth/v1/beacon/blob*` requests `beacon` received, in order.
    fn blob_request_paths(beacon: &TestServer) -> Vec<String> {
        beacon
            .requests_with_prefix("/eth/v1/beacon/blob")
            .iter()
            .map(|uri| uri.path().to_owned())
            .collect()
    }

    /// Values of the `versioned_hashes` query parameter of `uri`, in order.
    fn versioned_hashes_query(uri: &Uri) -> Vec<String> {
        url::form_urlencoded::parse(uri.query().unwrap_or_default().as_bytes())
            .filter(|(key, _)| key == "versioned_hashes")
            .map(|(_, value)| value.into_owned())
            .collect()
    }

    /// Whether `sidecars` serve exactly `expected`, in order.
    fn serves(sidecars: &[BlobTransactionSidecar], expected: &[&TestBlob]) -> bool {
        sidecars.len() == expected.len() &&
            sidecars.iter().zip(expected).all(|(sidecar, blob)| {
                sidecar.blobs.as_slice() == std::slice::from_ref(&*blob.blob) &&
                    sidecar.commitments == [blob.commitment]
            })
    }

    #[tokio::test]
    async fn blobs_are_requested_by_versioned_hash_and_returned_in_request_order() {
        let first = TestBlob::new(0x11);
        let second = TestBlob::new(0x22);
        // The spec returns blobs in block order, whatever the order of the requested hashes.
        let beacon = start_blob_beacon((StatusCode::OK, blobs_body(&[&first, &second]))).await;
        let client =
            BeaconClient::new(beacon.endpoint()).await.expect("beacon client should build");

        // Timestamp 84 falls in slot 7 with genesis at 0 and 12-second slots.
        let sidecars = client
            .blobs_by_timestamp(84, &[second.hash, first.hash, second.hash])
            .await
            .expect("beacon node should serve the blobs");

        assert!(serves(&sidecars, &[&second, &first, &second]));
        let requests = beacon.requests_with_prefix("/eth/v1/beacon/blob");
        assert_eq!(requests.len(), 1);
        assert_eq!(requests[0].path(), "/eth/v1/beacon/blobs/7");
        assert_eq!(
            versioned_hashes_query(&requests[0]),
            vec![second.hash.to_string(), first.hash.to_string()]
        );
    }

    #[test]
    fn beacon_blobs_are_matched_on_the_blocking_pool() {
        single_blocking_thread_runtime().block_on(async {
            let blob = TestBlob::new(0x11);
            let beacon = start_blob_beacon((StatusCode::OK, blobs_body(&[&blob]))).await;
            let client =
                BeaconClient::new(beacon.endpoint()).await.expect("beacon client should build");

            assert_waits_for_blocking_pool(client.blobs_by_timestamp(0, &[blob.hash])).await;
        });
    }

    #[tokio::test]
    async fn blobs_without_versioned_hashes_send_no_request() {
        let beacon = start_blob_beacon((StatusCode::OK, blobs_body(&[]))).await;
        let client =
            BeaconClient::new(beacon.endpoint()).await.expect("beacon client should build");

        // Without versioned hashes the endpoint would return every blob in the block.
        let sidecars = client.blobs_by_timestamp(0, &[]).await.expect("no blobs are requested");

        assert!(sidecars.is_empty());
        assert!(blob_request_paths(&beacon).is_empty());
    }

    #[tokio::test]
    async fn blobs_reject_responses_without_the_requested_blobs() {
        /// Requests `hash` from a beacon node stub answering the blobs endpoint with `body`, and
        /// checks that nothing but the blobs endpoint is asked.
        async fn fetch(body: String, hash: B256) -> Result<usize, BlobDataError> {
            let beacon = start_blob_beacon((StatusCode::OK, body)).await;
            let client =
                BeaconClient::new(beacon.endpoint()).await.expect("beacon client should build");
            let result = client.blobs_by_timestamp(0, &[hash]).await.map(|sidecars| sidecars.len());
            assert_eq!(blob_request_paths(&beacon), vec!["/eth/v1/beacon/blobs/0"]);
            result
        }

        let requested = TestBlob::new(0x11);
        let other = TestBlob::new(0x22);
        // Every field element exceeds the BLS modulus, so no commitment can be computed.
        let non_canonical = hex::encode_prefixed([0xff; 131_072]);

        for body in [blobs_body(&[]), blobs_body(&[&other])] {
            let result = fetch(body, requested.hash).await;
            assert!(matches!(result, Err(BlobDataError::Beacon(_))), "got {result:?}");
        }
        for body in [r#"{"data":null}"#, r#"{"data":[null]}"#, r#"{"data":["0x0102"]}"#] {
            let result = fetch(body.to_owned(), requested.hash).await;
            assert!(matches!(result, Err(BlobDataError::Parse(_))), "{body}: got {result:?}");
        }
        let result = fetch(format!(r#"{{"data":["{non_canonical}"]}}"#), requested.hash).await;
        assert!(matches!(result, Err(BlobDataError::Other(_))), "non-canonical: got {result:?}");
    }

    #[tokio::test]
    async fn blobs_ignore_unrequested_and_repeated_blobs() {
        let requested = TestBlob::new(0x11);
        let other = TestBlob::new(0x22);
        // A node that ignores the filter, or lists a blob twice, still yields exactly the
        // requested blobs.
        let beacon =
            start_blob_beacon((StatusCode::OK, blobs_body(&[&other, &requested, &requested])))
                .await;
        let client =
            BeaconClient::new(beacon.endpoint()).await.expect("beacon client should build");

        let sidecars = client
            .blobs_by_timestamp(0, &[requested.hash])
            .await
            .expect("beacon node should serve the blob");

        assert!(serves(&sidecars, &[&requested]));
    }

    #[tokio::test]
    async fn blobs_report_error_statuses() {
        let blob = TestBlob::new(0x11);

        // Nodes answer 404 for a block they do not have, and 400 (Lighthouse, Lodestar, Grandine)
        // or 5xx for blobs they cannot serve. The error goes to the caller, which falls back to
        // the blob server.
        for status in [
            StatusCode::NOT_FOUND,
            StatusCode::BAD_REQUEST,
            StatusCode::INTERNAL_SERVER_ERROR,
            StatusCode::SERVICE_UNAVAILABLE,
        ] {
            let beacon = start_blob_beacon((status, String::new())).await;
            let client =
                BeaconClient::new(beacon.endpoint()).await.expect("beacon client should build");

            let result = client.blobs_by_timestamp(0, &[blob.hash]).await;

            assert!(
                matches!(result, Err(BlobDataError::HttpStatus { status: code }) if code == status.as_u16()),
                "{status}: expected the blobs endpoint status, got {:?}",
                result.map(|sidecars| sidecars.len())
            );
            assert_eq!(blob_request_paths(&beacon), vec!["/eth/v1/beacon/blobs/0"], "{status}");
        }
    }
}

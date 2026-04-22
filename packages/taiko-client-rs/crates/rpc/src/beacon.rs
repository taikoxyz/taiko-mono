//! Lightweight beacon client used for fetching blob sidecars.
//!
//! The Go driver first queries a beacon node for `eth/v1/beacon/blob_sidecars/<slot>` and only
//! falls back to the blob server if the beacon call fails. This module provides the same
//! functionality so the Rust driver mirrors the Go behaviour.

use std::time::{SystemTime, UNIX_EPOCH};

use alloy_eips::eip4844::Bytes48;
use reqwest::Client as HttpClient;
use serde::Deserialize;
use tracing::{debug, warn};
use url::Url;

use crate::{
    blob::{BlobDataError, parse_blob, parse_bytes48},
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

/// JSON payload returned by `/eth/v1/beacon/blob_sidecars/<slot>`.
#[derive(Debug, Deserialize)]
struct BlobSidecarsResponse {
    /// Blob sidecars for the queried slot.
    data: Vec<BeaconBlobSidecar>,
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

/// Serialized representation of a single blob sidecar returned by the beacon node.
#[derive(Debug, Deserialize)]
struct BeaconBlobSidecar {
    /// Hex-encoded blob body.
    blob: String,
    /// Hex-encoded KZG commitment.
    #[serde(rename = "kzg_commitment")]
    kzg_commitment: String,
    /// Optional hex-encoded KZG proof.
    #[serde(rename = "kzg_proof")]
    kzg_proof: Option<String>,
}

/// Internal representation of a beacon sidecar after decoding hex fields.
#[derive(Debug, Clone)]
pub struct BeaconSidecar {
    /// Blob body for this sidecar.
    pub blob: alloy_eips::eip4844::Blob,
    /// KZG commitment for `blob`.
    pub commitment: Bytes48,
    /// KZG proof for `blob`.
    pub proof: Bytes48,
}

/// Minimal beacon client capable of retrieving blob sidecars.
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
        let seconds_per_slot = parse_spec_u64(&spec.data, "SECONDS_PER_SLOT")?;
        let slots_per_epoch = parse_spec_u64(&spec.data, "SLOTS_PER_EPOCH")?;

        debug!(
            seconds_per_slot,
            slots_per_epoch, genesis_time, "initialised beacon client metadata"
        );

        Ok(Self { endpoint, http, genesis_time, seconds_per_slot, slots_per_epoch })
    }

    /// Fetch blob sidecars for the beacon slot that corresponds to the provided timestamp.
    ///
    /// If the beacon node returns an error status, the caller is expected to fall back to the blob
    /// server. This mirrors the Go driver's behaviour.
    pub async fn blobs_by_timestamp(
        &self,
        timestamp: u64,
    ) -> Result<Vec<BeaconSidecar>, BlobDataError> {
        let slot = self.timestamp_to_slot(timestamp)?;
        let sidecars_url = self
            .endpoint
            .join(&format!("/eth/v1/beacon/blob_sidecars/{slot}"))
            .map_err(|err| BlobDataError::Other(err.into()))?;
        debug!(timestamp, slot, url = sidecars_url.as_str(), "requesting beacon blob sidecars");

        let response = self
            .http
            .get(sidecars_url.clone())
            .send()
            .await
            .map_err(|err| BlobDataError::Other(err.into()))?;
        if !response.status().is_success() {
            warn!(
                status = response.status().as_u16(),
                url = sidecars_url.as_str(),
                "beacon blob_sidecars request failed"
            );
            return Err(BlobDataError::HttpStatus { status: response.status().as_u16() });
        }

        let payload: BlobSidecarsResponse =
            response.json().await.map_err(|err| BlobDataError::Parse(err.to_string()))?;

        let mut sidecars = Vec::with_capacity(payload.data.len());
        for (index, item) in payload.data.into_iter().enumerate() {
            let blob = parse_blob(&item.blob)?;
            let commitment = parse_bytes48(&item.kzg_commitment)?;
            let proof =
                item.kzg_proof.as_deref().map(parse_bytes48).transpose()?.unwrap_or_default();
            sidecars.push(BeaconSidecar { blob, commitment, proof });
            debug!(slot, index, "fetched beacon blob sidecar");
        }

        Ok(sidecars)
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
    pub fn current_slot(&self) -> u64 {
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

    /// Return configured slots per epoch from the beacon spec.
    pub const fn slots_per_epoch(&self) -> u64 {
        self.slots_per_epoch
    }

    /// Return the beacon genesis timestamp (seconds since UNIX epoch).
    ///
    /// Fetched from `/eth/v1/beacon/genesis` during client construction.
    pub const fn genesis_time(&self) -> u64 {
        self.genesis_time
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

/// Look up a required decimal `u64` value from the beacon `/eth/v1/config/spec` response.
fn parse_spec_u64(spec: &serde_json::Value, key: &str) -> Result<u64, BlobDataError> {
    spec.get(key)
        .and_then(|value| value.as_str())
        .ok_or_else(|| BlobDataError::Parse(format!("{key} missing in beacon spec")))?
        .parse::<u64>()
        .map_err(|err| BlobDataError::Parse(err.to_string()))
}

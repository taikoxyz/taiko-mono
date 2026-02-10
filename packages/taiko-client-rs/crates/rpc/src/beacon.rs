//! Lightweight beacon client used for fetching blob sidecars.
//!
//! The Go driver first queries a beacon node for `eth/v1/beacon/blob_sidecars/<slot>` and only
//! falls back to the blob server if the beacon call fails. This module provides the same
//! functionality so the Rust driver mirrors the Go behaviour.

use std::time::{SystemTime, UNIX_EPOCH};

use alloy::primitives::hex;
use alloy_eips::eip4844::{Blob, Bytes48};
use reqwest::Client as HttpClient;
use serde::Deserialize;
use tracing::{debug, warn};
use url::Url;

use crate::{blob::BlobDataError, client::DEFAULT_HTTP_TIMEOUT};

/// JSON payload returned by `/eth/v1/beacon/genesis`.
#[derive(Debug, Deserialize)]
struct GenesisResponse {
    data: GenesisData,
}

/// Inner data of the genesis response.
#[derive(Debug, Deserialize)]
struct GenesisData {
    #[serde(rename = "genesis_time")]
    genesis_time: String,
}

/// JSON payload returned by `/eth/v1/config/spec`.
#[derive(Debug, Deserialize)]
struct SpecResponse {
    data: serde_json::Value,
}

/// JSON payload returned by `/eth/v1/beacon/blob_sidecars/<slot>`.
#[derive(Debug, Deserialize)]
struct BlobSidecarsResponse {
    data: Vec<BeaconBlobSidecar>,
}

/// JSON payload returned by `/eth/v2/beacon/blocks/<slot>`.
#[derive(Debug, Deserialize)]
struct BeaconBlockResponse {
    data: BeaconBlockData,
}

/// Inner data of a beacon block response.
#[derive(Debug, Deserialize)]
struct BeaconBlockData {
    message: BeaconBlockMessage,
}

/// Beacon block message body.
#[derive(Debug, Deserialize)]
struct BeaconBlockMessage {
    body: BeaconBlockBody,
}

/// Beacon block body containing the execution payload or header.
#[derive(Debug, Deserialize)]
struct BeaconBlockBody {
    #[serde(rename = "execution_payload")]
    execution_payload: Option<ExecutionPayload>,
    #[serde(rename = "execution_payload_header")]
    execution_payload_header: Option<ExecutionPayloadHeader>,
}

/// Execution payload returned by the beacon node.
#[derive(Debug, Deserialize)]
struct ExecutionPayload {
    #[serde(rename = "block_number")]
    block_number: String,
}

/// Blinded execution payload header returned by the beacon node.
#[derive(Debug, Deserialize)]
struct ExecutionPayloadHeader {
    #[serde(rename = "block_number")]
    block_number: String,
}

/// Serialized representation of a single blob sidecar returned by the beacon node.
#[derive(Debug, Deserialize)]
struct BeaconBlobSidecar {
    blob: String,
    #[serde(rename = "kzg_commitment")]
    kzg_commitment: String,
    #[serde(rename = "kzg_proof")]
    kzg_proof: Option<String>,
}

/// Internal representation of a beacon sidecar after decoding hex fields.
#[derive(Debug, Clone)]
pub struct BeaconSidecar {
    pub blob: Blob,
    pub commitment: Bytes48,
    pub proof: Bytes48,
}

/// Minimal beacon client capable of retrieving blob sidecars.
#[derive(Debug)]
pub struct BeaconClient {
    endpoint: Url,
    http: HttpClient,
    genesis_time: u64,
    seconds_per_slot: u64,
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
        let seconds_per_slot = spec
            .data
            .get("SECONDS_PER_SLOT")
            .and_then(|value| value.as_str())
            .ok_or_else(|| BlobDataError::Parse("SECONDS_PER_SLOT missing in beacon spec".into()))?
            .parse::<u64>()
            .map_err(|err| BlobDataError::Parse(err.to_string()))?;
        let slots_per_epoch = spec
            .data
            .get("SLOTS_PER_EPOCH")
            .and_then(|value| value.as_str())
            .ok_or_else(|| BlobDataError::Parse("SLOTS_PER_EPOCH missing in beacon spec".into()))?
            .parse::<u64>()
            .map_err(|err| BlobDataError::Parse(err.to_string()))?;

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

        let mut sidecars = Vec::new();
        for (index, item) in payload.data.into_iter().enumerate() {
            let blob = parse_blob(&item.blob)?;
            let commitment = parse_bytes48(&item.kzg_commitment)?;
            let proof = if let Some(proof) = item.kzg_proof {
                parse_bytes48(&proof)?
            } else {
                Bytes48::default()
            };
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
                Err(BlobDataError::HttpStatus { status }) if status == 404 => {
                    if slot == 0 {
                        break;
                    }
                    debug!(slot, status, "beacon block not found for slot; trying previous slot");
                }
                Err(err) => return Err(err),
            }

            if slot == 0 {
                break;
            }
            slot = slot.saturating_sub(1);
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
}

fn parse_blob(value: &str) -> Result<Blob, BlobDataError> {
    let bytes = decode_hex(value)?;
    Blob::try_from(bytes.as_slice()).map_err(|err| BlobDataError::Parse(err.to_string()))
}

fn parse_bytes48(value: &str) -> Result<Bytes48, BlobDataError> {
    let decoded = decode_hex(value)?;
    Bytes48::try_from(decoded.as_slice())
        .map_err(|_| BlobDataError::Parse("invalid 48-byte value".into()))
}

fn decode_hex(value: &str) -> Result<Vec<u8>, BlobDataError> {
    let mut stripped = value.trim_start_matches("0x").to_owned();
    if stripped.len() % 2 == 1 {
        stripped.insert(0, '0');
    }
    hex::decode(stripped).map_err(|err| BlobDataError::Parse(err.to_string()))
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

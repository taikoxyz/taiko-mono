use std::time::Duration;

use alloy_primitives::{B256, FixedBytes};
use chrono::{DateTime, Utc};
use reqwest::{Client, StatusCode, Url};
use serde::Deserialize;

use crate::{
    errors::{BlobIndexerError, Result},
    models::{BeaconBlockSummary, BlobSidecar},
    utils::conversions::{decode_b256, decode_fixed_bytes, decode_hex_bytes},
};

#[derive(Clone)]
pub struct BeaconClient {
    base_url: Url,
    client: Client,
}

impl BeaconClient {
    pub fn new(base_url: Url, timeout: Duration) -> Result<Self> {
        let client = Client::builder().timeout(timeout).build()?;
        Ok(Self { base_url, client })
    }

    pub async fn get_block_summary(&self, slot: u64) -> Result<Option<BeaconBlockSummary>> {
        self.fetch_block_summary(&slot.to_string()).await
    }

    pub async fn get_block_summary_by_root(
        &self,
        root: &B256,
    ) -> Result<Option<BeaconBlockSummary>> {
        let block_id = format!("0x{}", hex::encode(root.as_slice()));
        self.fetch_block_summary(&block_id).await
    }

    pub async fn get_blob_sidecars(&self, block_root: &B256) -> Result<Vec<BlobSidecar>> {
        let url = self
            .base_url
            .join(&format!(
                "eth/v1/beacon/blob_sidecars/0x{}",
                hex::encode(block_root.as_slice())
            ))
            .map_err(|err| BlobIndexerError::InvalidData(err.to_string()))?;

        let response = self.client.get(url).send().await?;

        if response.status() == StatusCode::NOT_FOUND {
            return Ok(Vec::new());
        }

        let response: BlobSidecarsResponse = response.error_for_status()?.json().await?;

        let mut items = Vec::with_capacity(response.data.len());

        for sidecar in response.data {
            let slot = sidecar.slot.parse::<u64>().map_err(|err| {
                BlobIndexerError::InvalidData(format!(
                    "invalid slot '{}' in sidecar: {err}",
                    sidecar.slot
                ))
            })?;
            let block_root = decode_b256(&sidecar.block_root)?;
            let index = sidecar.index.parse::<u64>().map_err(|err| {
                BlobIndexerError::InvalidData(format!(
                    "invalid blob index '{}' in sidecar: {err}",
                    sidecar.index
                ))
            })?;
            let commitment = decode_fixed_bytes::<48>(&sidecar.kzg_commitment)?;
            let proof = decode_fixed_bytes::<48>(&sidecar.kzg_proof)?;
            let blob = decode_hex_bytes(&sidecar.blob)?;

            items.push(BlobSidecar {
                slot,
                block_root,
                index,
                commitment,
                proof,
                blob,
            });
        }

        Ok(items)
    }

    pub async fn get_head_slot(&self) -> Result<u64> {
        let url = self
            .base_url
            .join("eth/v1/beacon/headers/head")
            .map_err(|err| BlobIndexerError::InvalidData(err.to_string()))?;

        let response: BeaconHeaderResponse = self
            .client
            .get(url)
            .send()
            .await?
            .error_for_status()?
            .json()
            .await?;

        let slot = response
            .data
            .header
            .message
            .slot
            .parse::<u64>()
            .map_err(|err| {
                BlobIndexerError::InvalidData(format!(
                    "invalid head slot '{}' from beacon header: {err}",
                    response.data.header.message.slot
                ))
            })?;

        Ok(slot)
    }

    pub async fn get_finalized_slot(&self) -> Result<Option<u64>> {
        let url = self
            .base_url
            .join("eth/v1/beacon/states/head/finality_checkpoints")
            .map_err(|err| BlobIndexerError::InvalidData(err.to_string()))?;

        let response: FinalityCheckpointsResponse = self
            .client
            .get(url)
            .send()
            .await?
            .error_for_status()?
            .json()
            .await?;

        let slot = response.data.finalized.slot.parse::<u64>().map_err(|err| {
            BlobIndexerError::InvalidData(format!(
                "invalid finalized slot '{}' from beacon response: {err}",
                response.data.finalized.slot
            ))
        })?;

        Ok(Some(slot))
    }

    async fn fetch_block_summary(&self, block_id: &str) -> Result<Option<BeaconBlockSummary>> {
        let url = self
            .base_url
            .join(&format!("eth/v2/beacon/blocks/{block_id}"))
            .map_err(|err| BlobIndexerError::InvalidData(err.to_string()))?;

        let response = self.client.get(url).send().await?;

        if response.status() == StatusCode::NOT_FOUND {
            return Ok(None);
        }

        let response: BeaconBlockResponse = response.error_for_status()?.json().await?;

        let block_root = decode_b256(&response.data.root)?;
        let parent_root = decode_b256(&response.data.message.parent_root)?;
        let slot = response.data.message.slot.parse::<u64>().map_err(|err| {
            BlobIndexerError::InvalidData(format!(
                "invalid slot '{}' from beacon block response: {err}",
                response.data.message.slot
            ))
        })?;

        let timestamp = response
            .data
            .message
            .body
            .execution_payload
            .and_then(|payload| payload.timestamp.parse::<i64>().ok())
            .and_then(|ts| DateTime::<Utc>::from_timestamp(ts, 0));

        let blob_commitments = response
            .data
            .message
            .body
            .blob_kzg_commitments
            .iter()
            .map(|commitment| decode_fixed_bytes::<48>(commitment))
            .collect::<Result<Vec<FixedBytes<48>>>>()?;

        Ok(Some(BeaconBlockSummary {
            slot,
            block_root,
            parent_root,
            timestamp,
            blob_commitments,
        }))
    }
}

#[derive(Debug, Deserialize)]
struct BeaconBlockResponse {
    data: BeaconBlockResponseData,
}

#[derive(Debug, Deserialize)]
struct BeaconBlockResponseData {
    root: String,
    message: BeaconBlockMessage,
}

#[derive(Debug, Deserialize)]
struct BeaconBlockMessage {
    slot: String,
    parent_root: String,
    body: BeaconBlockBody,
}

#[derive(Debug, Deserialize)]
struct BeaconBlockBody {
    #[serde(default)]
    blob_kzg_commitments: Vec<String>,
    #[serde(default)]
    execution_payload: Option<ExecutionPayload>,
}

#[derive(Debug, Deserialize, Clone)]
struct ExecutionPayload {
    timestamp: String,
}

#[derive(Debug, Deserialize)]
struct BlobSidecarsResponse {
    data: Vec<BlobSidecarData>,
}

#[derive(Debug, Deserialize)]
struct BlobSidecarData {
    slot: String,
    block_root: String,
    index: String,
    #[serde(alias = "kzg_commitment")]
    kzg_commitment: String,
    #[serde(alias = "kzg_proof")]
    kzg_proof: String,
    blob: String,
}

#[derive(Debug, Deserialize)]
struct BeaconHeaderResponse {
    data: BeaconHeaderData,
}

#[derive(Debug, Deserialize)]
struct BeaconHeaderData {
    header: SignedBeaconBlockHeader,
}

#[derive(Debug, Deserialize)]
struct SignedBeaconBlockHeader {
    message: BeaconBlockHeader,
}

#[derive(Debug, Deserialize)]
struct BeaconBlockHeader {
    slot: String,
}

#[derive(Debug, Deserialize)]
struct FinalityCheckpointsResponse {
    data: FinalityData,
}

#[derive(Debug, Deserialize)]
struct FinalityData {
    finalized: FinalityCheckpoint,
}

#[derive(Debug, Deserialize)]
struct FinalityCheckpoint {
    slot: String,
}

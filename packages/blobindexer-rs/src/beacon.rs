use std::time::Duration;

use alloy_consensus::{Transaction, TxEnvelope};
use alloy_primitives::{Address, B256, FixedBytes};
use alloy_rlp::Decodable;
use chrono::{DateTime, Utc};
use reqwest::{Client, StatusCode, Url};
use serde::Deserialize;
use serde_json::Value;
use tracing::{debug, warn};

use crate::{
    errors::{BlobIndexerError, Result},
    models::{BeaconBlockSummary, BlobSidecar},
    utils::conversions::{decode_b256, decode_fixed_bytes, decode_hex_bytes},
};

const SLOTS_PER_EPOCH: u64 = 32;
const BODY_PREVIEW_LIMIT: usize = 512;

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

    pub async fn get_blob_sidecars(
        &self,
        query_root: &B256,
        fallback_slot: Option<u64>,
    ) -> Result<Vec<BlobSidecar>> {
        let url = self
            .base_url
            .join(&format!(
                "eth/v1/beacon/blob_sidecars/0x{}",
                hex::encode(query_root.as_slice())
            ))
            .map_err(|err| BlobIndexerError::InvalidData(err.to_string()))?;

        let label = format!("blob_sidecars:0x{}", hex::encode(query_root.as_slice()));
        let Some(body) = self.request_json(url, &label).await? else {
            debug!(label = %label, "blob sidecars not found");
            return Ok(Vec::new());
        };

        let response: BlobSidecarsResponse = serde_json::from_slice(body.as_slice())?;

        let mut items = Vec::with_capacity(response.data.len());

        for sidecar in response.data {
            let slot = match sidecar.slot {
                Some(ref slot_str) => slot_str.parse::<u64>().map_err(|err| {
                    BlobIndexerError::InvalidData(format!(
                        "invalid slot '{}' in sidecar: {err}",
                        slot_str
                    ))
                })?,
                None => {
                    let Some(fallback) = fallback_slot else {
                        return Err(BlobIndexerError::InvalidData(
                            "sidecar missing slot and no fallback provided".into(),
                        ));
                    };
                    debug!(slot = fallback, "sidecar omitted slot; using fallback");
                    fallback
                }
            };
            let sidecar_root = if let Some(ref root_hex) = sidecar.block_root {
                decode_b256(root_hex)?
            } else {
                debug!(
                    slot,
                    "sidecar omitted block root; using query root fallback"
                );
                *query_root
            };
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
                block_root: sidecar_root,
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

        let body = self
            .request_json(url, "headers:head")
            .await?
            .ok_or_else(|| BlobIndexerError::InvalidData("missing beacon header".into()))?;

        let response: BeaconHeaderResponse = serde_json::from_slice(body.as_slice())?;

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

        let Some(body) = self
            .request_json(url, "states:head:finality_checkpoints")
            .await?
        else {
            debug!("no finality checkpoints in response");
            return Ok(None);
        };

        let response: Value = serde_json::from_slice(body.as_slice())?;

        let finalized = response
            .get("data")
            .and_then(|data| data.get("finalized"))
            .or_else(|| response.get("finalized"));

        let Some(finalized) = finalized else {
            return Ok(None);
        };

        if let Some(slot) = finalized.get("slot").and_then(|value| value.as_str()) {
            let slot = slot.parse::<u64>().map_err(|err| {
                BlobIndexerError::InvalidData(format!(
                    "invalid finalized slot '{slot}' from beacon response: {err}"
                ))
            })?;
            return Ok(Some(slot));
        }

        let Some(epoch_str) = finalized.get("epoch").and_then(|value| value.as_str()) else {
            return Ok(None);
        };

        let epoch = epoch_str.parse::<u64>().map_err(|err| {
            BlobIndexerError::InvalidData(format!(
                "invalid finalized epoch '{epoch_str}' from beacon response: {err}"
            ))
        })?;

        let slot = epoch.checked_mul(SLOTS_PER_EPOCH).ok_or_else(|| {
            BlobIndexerError::InvalidData(format!(
                "finalized epoch {epoch} overflows slot calculation"
            ))
        })?;

        Ok(Some(slot))
    }

    async fn request_json(&self, url: Url, label: &str) -> Result<Option<Vec<u8>>> {
        debug!(label = %label, url = %url, "sending beacon request");

        let response = self.client.get(url.clone()).send().await?;
        let status = response.status();

        if status == StatusCode::NOT_FOUND {
            debug!(label = %label, url = %url, "beacon resource not found");
            return Ok(None);
        }

        if let Err(err) = response.error_for_status_ref() {
            let body = response
                .text()
                .await
                .unwrap_or_else(|_| "<failed to read body>".to_string());
            warn!(
                label = %label,
                url = %url,
                status = status.as_u16(),
                body_preview = %preview_body_str(&body),
                error = ?err,
                "beacon request errored"
            );
            return Err(err.into());
        }

        let bytes = response.bytes().await?;
        let preview = preview_body_bytes(bytes.as_ref());
        let body = bytes.to_vec();
        debug!(
            label = %label,
            url = %url,
            status = status.as_u16(),
            body_preview = %preview,
            "beacon response received"
        );

        Ok(Some(body))
    }

    async fn fetch_block_root(&self, block_id: &str) -> Result<Option<String>> {
        let url = self
            .base_url
            .join(&format!("eth/v1/beacon/headers/{block_id}"))
            .map_err(|err| BlobIndexerError::InvalidData(err.to_string()))?;

        let label = format!("headers:{block_id}");
        let Some(body) = self.request_json(url, &label).await? else {
            debug!(label = %label, "block header not found while retrieving root");
            return Ok(None);
        };

        let response: BeaconHeaderResponse = serde_json::from_slice(body.as_slice())?;
        Ok(Some(response.data.root))
    }

    async fn fetch_block_summary(&self, block_id: &str) -> Result<Option<BeaconBlockSummary>> {
        let url = self
            .base_url
            .join(&format!("eth/v2/beacon/blocks/{block_id}"))
            .map_err(|err| BlobIndexerError::InvalidData(err.to_string()))?;

        let label = format!("blocks:{block_id}");
        let Some(body) = self.request_json(url, &label).await? else {
            debug!(label = %label, "block summary not found");
            return Ok(None);
        };

        let response: BeaconBlockResponse = serde_json::from_slice(body.as_slice())?;

        let BeaconBlockResponse {
            root: top_level_root,
            data,
            ..
        } = response;
        let BeaconBlockResponseData { root, message, .. } = data;
        let BeaconBlockMessage {
            slot,
            parent_root,
            body,
        } = message;
        let BeaconBlockBody {
            blob_kzg_commitments,
            execution_payload,
        } = body;

        let block_root_hex = if let Some(root) = root.or(top_level_root) {
            root
        } else {
            debug!(label = %label, "block root missing; fetching header as fallback");
            let header_root = self.fetch_block_root(block_id).await?;
            header_root.ok_or_else(|| {
                BlobIndexerError::InvalidData(
                    "missing block root from beacon block response".to_string(),
                )
            })?
        };

        let block_root = decode_b256(&block_root_hex)?;
        let parent_root = decode_b256(&parent_root)?;
        let slot = slot.parse::<u64>().map_err(|err| {
            BlobIndexerError::InvalidData(format!(
                "invalid slot '{slot}' from beacon block response: {err}"
            ))
        })?;

        let timestamp = execution_payload
            .as_ref()
            .and_then(|payload| payload.timestamp.parse::<i64>().ok())
            .and_then(|ts| DateTime::<Utc>::from_timestamp(ts, 0));

        let blob_commitments = blob_kzg_commitments
            .iter()
            .map(|commitment| decode_fixed_bytes::<48>(commitment))
            .collect::<Result<Vec<FixedBytes<48>>>>()?;

        let blob_targets = map_blob_targets(execution_payload.as_ref(), blob_commitments.len())?;

        Ok(Some(BeaconBlockSummary {
            slot,
            block_root,
            parent_root,
            timestamp,
            blob_commitments,
            blob_targets,
        }))
    }
}

fn map_blob_targets(
    payload: Option<&ExecutionPayload>,
    blob_count: usize,
) -> Result<Vec<Option<Address>>> {
    let mut targets = vec![None; blob_count];

    let Some(payload) = payload else {
        return Ok(targets);
    };

    if blob_count == 0 {
        return Ok(targets);
    }

    let mut cursor = 0usize;

    for (tx_index, raw_tx) in payload.transactions.iter().enumerate() {
        let tx_bytes = decode_hex_bytes(raw_tx)?;
        if tx_bytes.is_empty() {
            continue;
        }

        let mut slice = tx_bytes.as_slice();
        let envelope = TxEnvelope::decode(&mut slice).map_err(|err| {
            BlobIndexerError::InvalidData(format!(
                "failed to decode transaction {tx_index} from execution payload: {err}"
            ))
        })?;

        let TxEnvelope::Eip4844(tx) = envelope else {
            continue;
        };

        let to = tx.to();
        let Some(blob_hashes) = tx.blob_versioned_hashes() else {
            continue;
        };

        for _ in 0..blob_hashes.len() {
            if cursor >= blob_count {
                tracing::warn!(
                    cursor,
                    blob_count,
                    "blob commitment mapping exceeded available commitments"
                );
                return Ok(targets);
            }
            targets[cursor] = to;
            cursor += 1;
        }
    }

    if cursor != blob_count {
        tracing::warn!(
            mapped = cursor,
            expected = blob_count,
            "blob commitment count did not match mapped transactions"
        );
    }

    Ok(targets)
}

#[derive(Debug, Deserialize)]
struct BeaconBlockResponse {
    #[serde(default)]
    root: Option<String>,
    data: BeaconBlockResponseData,
}

#[derive(Debug, Deserialize)]
struct BeaconBlockResponseData {
    #[serde(default)]
    root: Option<String>,
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
    #[serde(default)]
    transactions: Vec<String>,
}

#[derive(Debug, Deserialize)]
struct BlobSidecarsResponse {
    data: Vec<BlobSidecarData>,
}

#[derive(Debug, Deserialize)]
struct BlobSidecarData {
    #[serde(default)]
    slot: Option<String>,
    #[serde(default)]
    block_root: Option<String>,
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
    root: String,
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

fn preview_body_bytes(bytes: &[u8]) -> String {
    if bytes.is_empty() {
        return String::new();
    }

    let end = bytes.len().min(BODY_PREVIEW_LIMIT);
    let mut preview = String::from_utf8_lossy(&bytes[..end]).to_string();
    if bytes.len() > BODY_PREVIEW_LIMIT {
        preview.push('…');
    }

    preview
}

fn preview_body_str(body: &str) -> String {
    preview_body_bytes(body.as_bytes())
}

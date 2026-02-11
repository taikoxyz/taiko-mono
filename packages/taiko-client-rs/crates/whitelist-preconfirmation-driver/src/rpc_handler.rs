//! Whitelist preconfirmation RPC API handler implementation.

use std::{
    collections::HashMap,
    io::Read,
    sync::Arc,
    time::{Instant, SystemTime, UNIX_EPOCH},
};

use alethia_reth_primitives::payload::{
    attributes::{RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes},
    builder::payload_id_taiko,
};
use alloy_eips::{BlockId, BlockNumberOrTag};
use alloy_primitives::{Address, B256, Bloom, FixedBytes, U256};
use alloy_provider::Provider;
use alloy_rpc_types::SyncStatus;
use alloy_rpc_types_engine::{ExecutionPayloadV1, PayloadAttributes as EthPayloadAttributes};
use async_trait::async_trait;
use bindings::preconf_whitelist::PreconfWhitelist::PreconfWhitelistInstance;
use driver::{PreconfPayload, sync::event::EventSyncer};
use metrics::histogram;
use protocol::{
    shasta::{PAYLOAD_ID_VERSION_V2, calculate_shasta_difficulty, payload_id_to_bytes},
    signer::FixedKSigner,
};
use rpc::{beacon::BeaconClient, client::Client};
use tokio::sync::{Mutex, broadcast, mpsc};
use tracing::debug;

use crate::{
    codec::{WhitelistExecutionPayloadEnvelope, block_signing_hash, encode_envelope_ssz},
    error::{Result, WhitelistPreconfirmationDriverError},
    importer::{
        MAX_COMPRESSED_TX_LIST_BYTES, MAX_DECOMPRESSED_TX_LIST_BYTES,
        validate_execution_payload_for_preconf,
    },
    network::NetworkCommand,
    rpc::{
        WhitelistRpcApi,
        types::{
            BuildPreconfBlockRequest, BuildPreconfBlockResponse, EndOfSequencingNotification,
            HealthResponse, LookaheadStatus, SlotRange, WhitelistStatus,
        },
    },
};

/// Go default handover-skip slots used for sequencing window split.
const DEFAULT_HANDOVER_SKIP_SLOTS: u64 = 8;
/// Maximum number of pending EOS notifications retained for `/ws` subscribers.
const EOS_NOTIFICATION_CHANNEL_CAPACITY: usize = 128;

/// Implements the whitelist preconfirmation RPC API.
pub(crate) struct WhitelistRpcHandler<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Event syncer for L1 origin lookups.
    event_syncer: Arc<EventSyncer<P>>,
    /// RPC client for L1/L2 reads.
    rpc: Client<P>,
    /// Chain ID for signature domain separation.
    chain_id: u64,
    /// Deterministic signer for block signing.
    signer: FixedKSigner,
    /// Beacon client used to derive current epoch values for EOS requests.
    beacon_client: Arc<BeaconClient>,
    /// Channel to publish messages to the P2P network.
    network_command_tx: mpsc::Sender<NetworkCommand>,
    /// Local peer ID string.
    local_peer_id: String,
    /// Serializes build requests to avoid concurrent insertion/signing races.
    build_preconf_lock: Mutex<()>,
    /// Preconf whitelist contract used for operator checks.
    whitelist: PreconfWhitelistInstance<P>,
    /// Highest unsafe payload block ID tracked by this node.
    highest_unsafe_l2_payload_block_id: Mutex<u64>,
    /// End-of-sequencing hash cache keyed by epoch.
    end_of_sequencing_by_epoch: Mutex<HashMap<u64, B256>>,
    /// Broadcast channel for REST `/ws` end-of-sequencing notifications.
    eos_notification_tx: broadcast::Sender<EndOfSequencingNotification>,
}

impl<P> WhitelistRpcHandler<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Create a new RPC handler.
    pub(crate) fn new(
        event_syncer: Arc<EventSyncer<P>>,
        rpc: Client<P>,
        chain_id: u64,
        signer: FixedKSigner,
        beacon_client: Arc<BeaconClient>,
        whitelist_address: Address,
        initial_highest_unsafe_l2_payload_block_id: u64,
        network_command_tx: mpsc::Sender<NetworkCommand>,
        local_peer_id: String,
    ) -> Self {
        let whitelist = PreconfWhitelistInstance::new(whitelist_address, rpc.l1_provider.clone());
        let (eos_notification_tx, _) = broadcast::channel(EOS_NOTIFICATION_CHANNEL_CAPACITY);
        Self {
            event_syncer,
            rpc,
            chain_id,
            signer,
            beacon_client,
            whitelist,
            highest_unsafe_l2_payload_block_id: Mutex::new(
                initial_highest_unsafe_l2_payload_block_id,
            ),
            end_of_sequencing_by_epoch: Mutex::new(HashMap::new()),
            eos_notification_tx,
            network_command_tx,
            local_peer_id,
            build_preconf_lock: Mutex::new(()),
        }
    }

    /// Build driver payload attributes from the RPC request.
    fn build_driver_payload(
        &self,
        request: &BuildPreconfBlockRequest,
        prev_randao: B256,
        signature: [u8; 65],
    ) -> Result<TaikoPayloadAttributes> {
        let tx_list = decompress_tx_list(request.transactions.as_ref())?;

        let block_metadata = TaikoBlockMetadata {
            beneficiary: request.fee_recipient,
            gas_limit: request.gas_limit,
            timestamp: U256::from(request.timestamp),
            mix_hash: prev_randao,
            tx_list: Some(tx_list.into()),
            extra_data: request.extra_data.clone(),
        };

        let payload_attributes = EthPayloadAttributes {
            timestamp: request.timestamp,
            prev_randao,
            suggested_fee_recipient: request.fee_recipient,
            withdrawals: Some(Vec::new()),
            parent_beacon_block_root: None,
        };

        let mut payload = TaikoPayloadAttributes {
            payload_attributes,
            base_fee_per_gas: U256::from(request.base_fee_per_gas),
            block_metadata,
            l1_origin: RpcL1Origin {
                block_id: U256::from(request.block_number),
                l2_block_hash: B256::ZERO,
                l1_block_height: None,
                l1_block_hash: None,
                build_payload_args_id: [0u8; 8],
                is_forced_inclusion: request.is_forced_inclusion.unwrap_or(false),
                signature,
            },
            anchor_transaction: None,
        };

        let payload_id = payload_id_taiko(&request.parent_hash, &payload, PAYLOAD_ID_VERSION_V2);
        payload.l1_origin.build_payload_args_id = payload_id_to_bytes(payload_id);
        Ok(payload)
    }

    /// Build a 65-byte signature from a digest.
    fn sign_digest(&self, digest: B256) -> Result<[u8; 65]> {
        let sig_result = self
            .signer
            .sign_with_predefined_k(digest.as_ref())
            .map_err(|e| WhitelistPreconfirmationDriverError::Signing(e.to_string()))?;

        let mut sig_bytes = [0u8; 65];
        sig_bytes[..32].copy_from_slice(&sig_result.signature.r().to_be_bytes::<32>());
        sig_bytes[32..64].copy_from_slice(&sig_result.signature.s().to_be_bytes::<32>());
        sig_bytes[64] = sig_result.recovery_id;
        Ok(sig_bytes)
    }

    /// Derive the mix-hash / prev-randao from the parent block.
    async fn derive_prev_randao(&self, parent_hash: B256, block_number: u64) -> Result<B256> {
        let parent = self
            .rpc
            .l2_provider
            .get_block_by_hash(parent_hash)
            .await
            .map_err(provider_err)?
            .ok_or_else(|| {
                WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                    "parent block not found for hash {parent_hash}"
                ))
            })?;

        let expected_block_number = parent.header.number.saturating_add(1);
        if block_number != expected_block_number {
            return Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                "block number {block_number} must follow parent number {}",
                parent.header.number
            )));
        }

        let parent_difficulty = B256::from(parent.header.difficulty.to_be_bytes::<32>());
        Ok(calculate_shasta_difficulty(parent_difficulty, block_number))
    }

    /// Validate request payload shape before expensive insertion and signing operations.
    fn validate_request_payload(
        &self,
        request: &BuildPreconfBlockRequest,
        prev_randao: B256,
    ) -> Result<()> {
        let payload = ExecutionPayloadV1 {
            parent_hash: request.parent_hash,
            fee_recipient: request.fee_recipient,
            state_root: B256::ZERO,
            receipts_root: B256::ZERO,
            logs_bloom: Bloom::default(),
            prev_randao,
            block_number: request.block_number,
            gas_limit: request.gas_limit,
            gas_used: 0,
            timestamp: request.timestamp,
            extra_data: request.extra_data.clone(),
            base_fee_per_gas: U256::from(request.base_fee_per_gas),
            block_hash: B256::ZERO,
            transactions: vec![request.transactions.clone()],
        };

        validate_execution_payload_for_preconf(
            &payload,
            self.chain_id,
            *self.rpc.shasta.anchor.address(),
        )
    }

    /// Check fee recipient against current/next whitelist operator addresses.
    async fn ensure_fee_recipient_allowed(&self, fee_recipient: Address) -> Result<()> {
        let (current, next) = self.fetch_current_next_sequencers().await?;
        if fee_recipient == current || fee_recipient == next {
            return Ok(());
        }

        Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "fee recipient {fee_recipient} is not current ({current}) or next ({next}) operator"
        )))
    }

    /// Fetch current and next sequencer addresses pinned to a single L1 block number.
    async fn fetch_current_next_sequencers(&self) -> Result<(Address, Address)> {
        let latest_block = self
            .rpc
            .l1_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(provider_err)?
            .ok_or_else(|| {
                WhitelistPreconfirmationDriverError::WhitelistLookup(
                    "missing latest L1 block while fetching whitelist operators".to_string(),
                )
            })?;

        let block_id = BlockId::Number(latest_block.header.number.into());
        let current_proposer = self
            .whitelist
            .getOperatorForCurrentEpoch()
            .block(block_id.clone())
            .call()
            .await
            .map_err(provider_err)?;
        let next_proposer = self
            .whitelist
            .getOperatorForNextEpoch()
            .block(block_id.clone())
            .call()
            .await
            .map_err(provider_err)?;

        let current = self
            .whitelist
            .operators(current_proposer)
            .block(block_id.clone())
            .call()
            .await
            .map_err(provider_err)?
            .sequencerAddress;
        let next = self
            .whitelist
            .operators(next_proposer)
            .block(block_id)
            .call()
            .await
            .map_err(provider_err)?
            .sequencerAddress;

        if current == Address::ZERO || next == Address::ZERO {
            return Err(WhitelistPreconfirmationDriverError::WhitelistLookup(
                "received zero address while fetching whitelist operators".to_string(),
            ));
        }

        Ok((current, next))
    }

    /// Build best-effort Go-compatible lookahead status.
    async fn current_lookahead_status(&self) -> Option<LookaheadStatus> {
        let (curr_operator, next_operator) = self.fetch_current_next_sequencers().await.ok()?;
        let current_epoch = self.beacon_client.current_epoch();
        let slots_per_epoch = self.beacon_client.slots_per_epoch();
        let handover_skip_slots = DEFAULT_HANDOVER_SKIP_SLOTS.min(slots_per_epoch);
        let threshold = slots_per_epoch.saturating_sub(handover_skip_slots);
        let epoch_start = current_epoch.saturating_mul(slots_per_epoch);

        let curr_ranges =
            vec![SlotRange { start: epoch_start, end: epoch_start.saturating_add(threshold) }];
        let next_ranges = vec![SlotRange {
            start: epoch_start.saturating_add(threshold),
            end: epoch_start.saturating_add(slots_per_epoch),
        }];

        let updated_at =
            SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or_default();

        Some(LookaheadStatus {
            curr_operator,
            next_operator,
            curr_ranges,
            next_ranges,
            updated_at,
            last_updated_epoch: current_epoch,
        })
    }

    /// Update highest unsafe block tracking (mirrors Go's update on each insertion/reorg point).
    async fn update_highest_unsafe(&self, block_number: u64) {
        *self.highest_unsafe_l2_payload_block_id.lock().await = block_number;
    }
}

#[async_trait]
impl<P> WhitelistRpcApi for WhitelistRpcHandler<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    async fn build_preconf_block(
        &self,
        request: BuildPreconfBlockRequest,
    ) -> Result<BuildPreconfBlockResponse> {
        let started_at = Instant::now();
        let _build_guard = self.build_preconf_lock.lock().await;

        let sync_status = self.rpc.l2_provider.syncing().await.map_err(provider_err)?;
        if matches!(sync_status, SyncStatus::Info(_)) {
            return Err(WhitelistPreconfirmationDriverError::Driver(
                driver::DriverError::EngineSyncing(request.block_number),
            ));
        }

        self.ensure_fee_recipient_allowed(request.fee_recipient).await?;

        let prev_randao =
            self.derive_prev_randao(request.parent_hash, request.block_number).await?;
        self.validate_request_payload(&request, prev_randao)?;

        // Insert the preconfirmation payload locally first, mirroring the Go flow, to
        // obtain the canonical block hash before gossiping.
        let driver_payload = self.build_driver_payload(&request, prev_randao, [0u8; 65])?;
        self.event_syncer
            .submit_preconfirmation_payload(PreconfPayload::new(driver_payload))
            .await?;

        let inserted_block = self
            .rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Number(request.block_number))
            .await
            .map_err(provider_err)?
            .ok_or(WhitelistPreconfirmationDriverError::MissingInsertedBlock(
                request.block_number,
            ))?;

        if inserted_block.header.parent_hash != request.parent_hash {
            return Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                "inserted block parent hash mismatch at block {}: expected {}, got {}",
                request.block_number, request.parent_hash, inserted_block.header.parent_hash
            )));
        }
        if inserted_block.header.number != request.block_number {
            return Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
                "inserted block number mismatch: expected {}, got {}",
                request.block_number, inserted_block.header.number
            )));
        }

        let block_hash = inserted_block.header.hash;
        let block_number = inserted_block.header.number;
        let block_header = inserted_block.header.clone();
        let base_fee_per_gas =
            inserted_block.header.base_fee_per_gas.unwrap_or(request.base_fee_per_gas);
        let block_hash_signature =
            self.sign_digest(block_signing_hash(self.chain_id, block_hash.as_slice()))?;

        self.rpc
            .set_l1_origin_signature(
                U256::from(block_number),
                FixedBytes::<65>::from(block_hash_signature),
            )
            .await?;
        self.update_highest_unsafe(block_number).await;

        let execution_payload = ExecutionPayloadV1 {
            parent_hash: inserted_block.header.parent_hash,
            fee_recipient: inserted_block.header.beneficiary,
            state_root: inserted_block.header.state_root,
            receipts_root: inserted_block.header.receipts_root,
            logs_bloom: inserted_block.header.logs_bloom,
            prev_randao: inserted_block.header.mix_hash,
            block_number,
            gas_limit: inserted_block.header.gas_limit,
            gas_used: inserted_block.header.gas_used,
            timestamp: inserted_block.header.timestamp,
            extra_data: inserted_block.header.extra_data.clone(),
            base_fee_per_gas: U256::from(base_fee_per_gas),
            block_hash,
            transactions: vec![request.transactions.clone()],
        };

        let envelope = WhitelistExecutionPayloadEnvelope {
            end_of_sequencing: request.end_of_sequencing,
            is_forced_inclusion: request.is_forced_inclusion,
            parent_beacon_block_root: None,
            execution_payload,
            signature: Some(block_hash_signature),
        };

        // Wire signature for preconfBlocks topic is over full SSZ envelope bytes.
        let ssz_bytes = encode_envelope_ssz(&envelope);
        let wire_signature = self.sign_digest(block_signing_hash(self.chain_id, &ssz_bytes))?;

        debug!(
            block_number,
            block_hash = %block_hash,
            "publishing signed whitelist preconfirmation payload"
        );

        // Publish to gossipsub.
        self.network_command_tx
            .send(NetworkCommand::PublishUnsafePayload {
                signature: wire_signature,
                envelope: Arc::new(envelope),
            })
            .await
            .map_err(|e| {
                WhitelistPreconfirmationDriverError::P2p(format!(
                    "failed to send publish command: {e}"
                ))
            })?;

        // If end-of-sequencing, also publish the EOS request.
        if request.end_of_sequencing.unwrap_or(false) {
            let epoch = self.beacon_client.current_epoch();
            self.end_of_sequencing_by_epoch.lock().await.insert(epoch, block_hash);
            let _ = self.eos_notification_tx.send(EndOfSequencingNotification {
                current_epoch: epoch,
                end_of_sequencing: true,
            });
            self.network_command_tx
                .send(NetworkCommand::PublishEndOfSequencingRequest { epoch })
                .await
                .map_err(|e| {
                    WhitelistPreconfirmationDriverError::P2p(format!(
                        "failed to send end-of-sequencing command: {e}"
                    ))
                })?;
        }

        histogram!(
            crate::metrics::WhitelistPreconfirmationDriverMetrics::BUILD_PRECONF_BLOCK_DURATION_SECONDS
        )
        .record(started_at.elapsed().as_secs_f64());

        Ok(BuildPreconfBlockResponse { block_hash, block_number, block_header: Some(block_header) })
    }

    async fn get_status(&self) -> Result<WhitelistStatus> {
        let head_l1_origin_block_id =
            self.rpc.head_l1_origin().await?.map(|h| h.block_id.to::<u64>());
        let highest_unsafe = *self.highest_unsafe_l2_payload_block_id.lock().await;
        let current_epoch = self.beacon_client.current_epoch();
        let end_of_sequencing_block_hash = self
            .end_of_sequencing_by_epoch
            .lock()
            .await
            .get(&current_epoch)
            .copied()
            .map(|hash| hash.to_string());
        let sync_ready = head_l1_origin_block_id.is_some();

        Ok(WhitelistStatus {
            head_l1_origin_block_id,
            highest_unsafe_block_number: Some(highest_unsafe),
            peer_id: self.local_peer_id.clone(),
            sync_ready,
            lookahead: self.current_lookahead_status().await,
            total_cached: Some(0),
            highest_unsafe_l2_payload_block_id: Some(highest_unsafe),
            end_of_sequencing_block_hash,
        })
    }

    async fn healthz(&self) -> Result<HealthResponse> {
        Ok(HealthResponse { ok: true })
    }

    fn subscribe_end_of_sequencing(&self) -> broadcast::Receiver<EndOfSequencingNotification> {
        self.eos_notification_tx.subscribe()
    }
}

/// Decompress a zlib-compressed transaction list.
fn decompress_tx_list(bytes: &[u8]) -> Result<Vec<u8>> {
    if bytes.len() > MAX_COMPRESSED_TX_LIST_BYTES {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "compressed tx list exceeds maximum size: {} > {}",
            bytes.len(),
            MAX_COMPRESSED_TX_LIST_BYTES
        )));
    }

    let decoder = flate2::read::ZlibDecoder::new(bytes);
    let mut out = Vec::new();
    let read_cap = MAX_DECOMPRESSED_TX_LIST_BYTES.saturating_add(1) as u64;
    decoder.take(read_cap).read_to_end(&mut out).map_err(|err| {
        WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "failed to decompress tx list from payload: {err}"
        ))
    })?;

    if out.len() > MAX_DECOMPRESSED_TX_LIST_BYTES {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "decompressed tx list exceeds maximum size: {} > {}",
            out.len(),
            MAX_DECOMPRESSED_TX_LIST_BYTES
        )));
    }

    if out.is_empty() {
        return Err(WhitelistPreconfirmationDriverError::InvalidPayload(
            "decompressed tx list is empty".to_string(),
        ));
    }

    Ok(out)
}

/// Convert a provider error into a driver error.
fn provider_err(err: impl std::fmt::Display) -> WhitelistPreconfirmationDriverError {
    WhitelistPreconfirmationDriverError::Rpc(rpc::RpcClientError::Provider(err.to_string()))
}

#[cfg(test)]
mod tests {
    use std::io::Write;

    use flate2::{Compression, write::ZlibEncoder};

    use super::*;

    fn compress(payload: &[u8]) -> Vec<u8> {
        let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
        encoder.write_all(payload).expect("write zlib payload");
        encoder.finish().expect("finish zlib encoding")
    }

    #[test]
    fn decompress_tx_list_rejects_oversized_compressed_payload() {
        let oversized = vec![0u8; MAX_COMPRESSED_TX_LIST_BYTES + 1];
        let err =
            decompress_tx_list(&oversized).expect_err("oversized compressed payload must fail");
        assert!(matches!(
            err,
            WhitelistPreconfirmationDriverError::InvalidPayload(msg)
                if msg.contains("compressed tx list exceeds maximum size")
        ));
    }

    #[test]
    fn decompress_tx_list_rejects_oversized_decompressed_payload() {
        let oversized = vec![0x11u8; MAX_DECOMPRESSED_TX_LIST_BYTES + 1];
        let compressed = compress(&oversized);
        let err = decompress_tx_list(&compressed)
            .expect_err("oversized decompressed payload must fail before use");
        assert!(matches!(
            err,
            WhitelistPreconfirmationDriverError::InvalidPayload(msg)
                if msg.contains("decompressed tx list exceeds maximum size")
        ));
    }

    #[test]
    fn decompress_tx_list_accepts_non_empty_payload_within_limits() {
        let expected = vec![0xAA, 0xBB, 0xCC];
        let compressed = compress(&expected);
        let decoded = decompress_tx_list(&compressed).expect("valid payload should decode");
        assert_eq!(decoded, expected);
    }
}

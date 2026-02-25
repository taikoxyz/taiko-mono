//! Whitelist preconfirmation REST/WS API handler implementation.

use std::{
    io::Read,
    sync::Arc,
    time::Instant,
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
use tokio::sync::{Mutex, RwLock, broadcast, mpsc};
use tracing::{debug, warn};

use crate::{
    cache::SharedPreconfCacheState,
    codec::{WhitelistExecutionPayloadEnvelope, block_signing_hash, encode_envelope_ssz},
    error::{Result, WhitelistPreconfirmationDriverError},
    importer::{
        MAX_COMPRESSED_TX_LIST_BYTES, MAX_DECOMPRESSED_TX_LIST_BYTES,
        validate_execution_payload_for_preconf,
    },
    network::NetworkCommand,
    rest::{
        WhitelistRestApi,
        types::{
            BuildPreconfBlockRequest, BuildPreconfBlockResponse, EndOfSequencingNotification,
            LookaheadStatus, SlotRange, WhitelistStatus,
        },
    },
};

/// Go default handover-skip slots used for sequencing window split.
const DEFAULT_HANDOVER_SKIP_SLOTS: u64 = 8;
/// Maximum number of pending EOS notifications retained for `/ws` subscribers.
const EOS_NOTIFICATION_CHANNEL_CAPACITY: usize = 128;
/// Implements the whitelist preconfirmation REST/WS API.
pub(crate) struct WhitelistRestHandler<P>
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
    /// Serializes build requests to avoid concurrent insertion/signing races.
    build_preconf_lock: Mutex<()>,
    /// Preconf whitelist contract used for operator checks.
    whitelist: PreconfWhitelistInstance<P>,
    /// Local peer ID string.
    local_peer_id: String,
    /// Highest unsafe payload block ID tracked by this node (shared with importer).
    highest_unsafe_l2_payload_block_id: Arc<Mutex<u64>>,
    /// Cached lookahead status used for fee-recipient validation.
    lookahead_status: RwLock<Option<LookaheadStatus>>,
    /// Shared cache state used to back `/status` and EOS visibility.
    cache_state: SharedPreconfCacheState,
    /// Broadcast channel for REST `/ws` end-of-sequencing notifications.
    eos_notification_tx: broadcast::Sender<EndOfSequencingNotification>,
}

/// Dependency bundle for constructing `WhitelistRestHandler`.
pub(crate) struct WhitelistRestHandlerParams<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Shared event syncer used to read the current L1 origin.
    pub(crate) event_syncer: Arc<EventSyncer<P>>,
    /// L1/L2 RPC client.
    pub(crate) rpc: Client<P>,
    /// Chain ID used for signing and payload hashing.
    pub(crate) chain_id: u64,
    /// Signer used for block signing operations.
    pub(crate) signer: FixedKSigner,
    /// Beacon client used for epoch calculations.
    pub(crate) beacon_client: Arc<BeaconClient>,
    /// Whitelist contract address for allowlist checks.
    pub(crate) whitelist_address: Address,
    /// Shared highest unsafe payload block ID (also updated by importer on P2P import).
    pub(crate) highest_unsafe_l2_payload_block_id: Arc<Mutex<u64>>,
    /// Network command sender for gossip publishing.
    pub(crate) network_command_tx: mpsc::Sender<NetworkCommand>,
    /// Shared preconfirmation cache state.
    pub(crate) cache_state: SharedPreconfCacheState,
    /// Local peer ID string.
    pub(crate) local_peer_id: String,
}

impl<P> WhitelistRestHandler<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Create a new REST/WS handler.
    pub(crate) fn new(
        WhitelistRestHandlerParams {
            event_syncer,
            rpc,
            chain_id,
            signer,
            beacon_client,
            whitelist_address,
            highest_unsafe_l2_payload_block_id,
            network_command_tx,
            cache_state,
            local_peer_id,
        }: WhitelistRestHandlerParams<P>,
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
            local_peer_id,
            highest_unsafe_l2_payload_block_id,
            lookahead_status: RwLock::new(None),
            cache_state,
            eos_notification_tx,
            network_command_tx,
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

    /// Check fee recipient against current/next operator sequencing ranges.
    async fn ensure_fee_recipient_allowed(&self, fee_recipient: Address) -> Result<()> {
        let current_slot = self.beacon_client.current_slot();
        self.ensure_fee_recipient_allowed_for_slot(fee_recipient, current_slot).await
    }

    /// Check fee recipient against a specific slot's sequencing ranges.
    async fn ensure_fee_recipient_allowed_for_slot(
        &self,
        fee_recipient: Address,
        current_slot: u64,
    ) -> Result<()> {
        let mut lookahead = {
            let cached_lookahead = self.lookahead_status.read().await;
            if let Some(lookahead) = cached_lookahead.as_ref() {
                if Self::lookahead_slot_covers(current_slot, lookahead) {
                    Some(lookahead.clone())
                } else {
                    None
                }
            } else {
                None
            }
        };

        if lookahead.is_none() {
            let fresh = self.compute_lookahead_status().await?;
            *self.lookahead_status.write().await = Some(fresh.clone());
            lookahead = Some(fresh);
        }

        let lookahead = lookahead.expect("lookahead cache must be initialized");

        if lookahead.curr_ranges.is_empty() && lookahead.next_ranges.is_empty() {
            return Err(WhitelistPreconfirmationDriverError::InvalidPayload(
                "lookahead metadata missing operator ranges".to_string(),
            ));
        }

        if is_fee_recipient_allowed_for_slot(fee_recipient, current_slot, &lookahead) {
            return Ok(());
        }

        let reason = if slot_matches_range(current_slot, &lookahead.curr_ranges) {
            "current"
        } else if slot_matches_range(current_slot, &lookahead.next_ranges) {
            "next"
        } else {
            "current or next"
        };

        Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
            "fee recipient {fee_recipient} is not allowed as the {reason} operator for slot {current_slot}"
        )))
    }

    /// Check whether the given slot falls within any current or next lookahead range.
    fn lookahead_slot_covers(slot: u64, lookahead: &LookaheadStatus) -> bool {
        slot_matches_range(slot, &lookahead.curr_ranges) ||
            slot_matches_range(slot, &lookahead.next_ranges)
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
            .block(block_id)
            .call()
            .await
            .map_err(provider_err)?;
        let next_proposer = self
            .whitelist
            .getOperatorForNextEpoch()
            .block(block_id)
            .call()
            .await
            .map_err(provider_err)?;

        let current = self
            .whitelist
            .operators(current_proposer)
            .block(block_id)
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
    async fn compute_lookahead_status(&self) -> Result<LookaheadStatus> {
        let current_epoch = self.beacon_client.current_epoch();
        let slots_per_epoch = self.beacon_client.slots_per_epoch();
        let handover_skip_slots = DEFAULT_HANDOVER_SKIP_SLOTS.min(slots_per_epoch);
        let threshold = slots_per_epoch.saturating_sub(handover_skip_slots);
        let epoch_start = current_epoch.saturating_mul(slots_per_epoch);

        let (curr_operator, next_operator) =
            self.fetch_current_next_sequencers().await.inspect_err(|err| {
                warn!(
                    error = %err,
                    current_epoch,
                    "failed to fetch lookahead operator metadata"
                );
            })?;
        let curr_ranges =
            vec![SlotRange { start: epoch_start, end: epoch_start.saturating_add(threshold) }];
        let next_ranges = vec![SlotRange {
            start: epoch_start.saturating_add(threshold),
            end: epoch_start.saturating_add(slots_per_epoch),
        }];

        Ok(LookaheadStatus { curr_operator, next_operator, curr_ranges, next_ranges })
    }

    /// Update highest unsafe block tracking (mirrors Go's update on each insertion/reorg point).
    async fn update_highest_unsafe(&self, block_number: u64) {
        *self.highest_unsafe_l2_payload_block_id.lock().await = block_number;
    }
}

/// Check if a slot is contained by any of the allowed ranges.
fn slot_matches_range(slot: u64, ranges: &[SlotRange]) -> bool {
    ranges.iter().any(|range| slot >= range.start && slot < range.end)
}

/// Return true when fee recipient matches any operator for current/next range.
fn is_fee_recipient_allowed_for_slot(
    fee_recipient: Address,
    current_slot: u64,
    lookahead: &LookaheadStatus,
) -> bool {
    (fee_recipient == lookahead.curr_operator &&
        slot_matches_range(current_slot, &lookahead.curr_ranges)) ||
        (fee_recipient == lookahead.next_operator &&
            slot_matches_range(current_slot, &lookahead.next_ranges))
}

#[async_trait]
impl<P> WhitelistRestApi for WhitelistRestHandler<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    async fn build_preconf_block(
        &self,
        request: BuildPreconfBlockRequest,
    ) -> Result<BuildPreconfBlockResponse> {
        let started_at = Instant::now();
        let _build_guard = self.build_preconf_lock.lock().await;

        // Guard against building on a genuinely syncing node, but tolerate the false-
        // positive that taiko-geth emits on genesis chains (currentBlock == highestBlock
        // == 0, txIndexRemainingBlocks = 1).  When current == highest the node is not
        // actually catching up to a remote peer, so we allow the build to proceed.
        let sync_status = self.rpc.l2_provider.syncing().await.map_err(provider_err)?;
        if let SyncStatus::Info(ref info) = sync_status &&
            info.current_block < info.highest_block
        {
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
            self.cache_state.record_end_of_sequencing(epoch, block_hash).await;
            if let Err(err) = self
                .eos_notification_tx
                .send(EndOfSequencingNotification { current_epoch: epoch, end_of_sequencing: true })
            {
                warn!(
                    error = %err,
                    current_epoch = epoch,
                    "failed to deliver end-of-sequencing websocket notification"
                );
            }
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

        Ok(BuildPreconfBlockResponse { block_header: Some(block_header) })
    }

    async fn get_status(&self) -> Result<WhitelistStatus> {
        let head_l1_origin = self.rpc.head_l1_origin().await?;
        let highest_unsafe = *self.highest_unsafe_l2_payload_block_id.lock().await;
        let current_epoch = self.beacon_client.current_epoch();
        let end_of_sequencing_block_hash = self
            .cache_state
            .end_of_sequencing_for_epoch(current_epoch)
            .await
            .map(|hash| hash.to_string());
        // sync_ready reflects ingress readiness, which already includes the confirmed-sync
        // and scanner-live checks required by the event syncer.
        let sync_ready = self.event_syncer.is_preconf_ingress_ready();

        Ok(WhitelistStatus {
            head_l1_origin_block_id: head_l1_origin.as_ref().map(|o| o.block_id.to::<u64>()),
            highest_unsafe_block_number: highest_unsafe,
            peer_id: self.local_peer_id.clone(),
            sync_ready,
            highest_unsafe_l2_payload_block_id: highest_unsafe,
            end_of_sequencing_block_hash,
        })
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

    #[test]
    fn slot_matches_range_checks_slot_bounds() {
        let ranges = vec![SlotRange { start: 10, end: 20 }, SlotRange { start: 30, end: 40 }];

        assert!(slot_matches_range(10, &ranges));
        assert!(slot_matches_range(19, &ranges));
        assert!(!slot_matches_range(20, &ranges));
        assert!(!slot_matches_range(25, &ranges));
        assert!(slot_matches_range(30, &ranges));
        assert!(!slot_matches_range(40, &ranges));
    }

    #[test]
    fn fee_recipient_allowed_for_slot_matches_only_assigned_operator() {
        let lookahead = LookaheadStatus {
            curr_operator: Address::from([0x11u8; 20]),
            next_operator: Address::from([0x22u8; 20]),
            curr_ranges: vec![SlotRange { start: 10, end: 20 }],
            next_ranges: vec![SlotRange { start: 20, end: 30 }],
        };

        assert!(is_fee_recipient_allowed_for_slot(Address::from([0x11u8; 20]), 15, &lookahead));
        assert!(is_fee_recipient_allowed_for_slot(Address::from([0x22u8; 20]), 25, &lookahead));
        assert!(!is_fee_recipient_allowed_for_slot(Address::from([0x33u8; 20]), 15, &lookahead));
        assert!(!is_fee_recipient_allowed_for_slot(Address::from([0x11u8; 20]), 25, &lookahead));
        assert!(!is_fee_recipient_allowed_for_slot(Address::from([0x22u8; 20]), 15, &lookahead));
    }
}

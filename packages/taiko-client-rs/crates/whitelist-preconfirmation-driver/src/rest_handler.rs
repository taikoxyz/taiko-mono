//! Whitelist preconfirmation REST/WS API handler implementation.

use std::{
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
use tracing::{debug, warn};

use crate::{
    codec::{WhitelistExecutionPayloadEnvelope, block_signing_hash, encode_envelope_ssz},
    error::{Result, WhitelistPreconfirmationDriverError},
    importer::{decompress_tx_list, validate_execution_payload_for_preconf_with_tx_list},
    network::NetworkCommand,
    rest::{
        WhitelistRestApi,
        types::{
            BuildPreconfBlockRequest, BuildPreconfBlockResponse, EndOfSequencingNotification,
            LookaheadStatus, SlotRange, WhitelistStatus,
        },
    },
    runtime_state::RuntimeStatusState,
};

alloy::sol! {
    #[sol(rpc)]
    interface TaikoWrapperConfigReader {
        function preconfRouter() external view returns (address router_);
    }

    #[sol(rpc)]
    interface PreconfRouterConfigReader {
        struct Config {
            uint256 handOverSlots;
        }

        function getConfig() external view returns (Config memory config_);
    }
}

#[derive(Debug)]
struct HandoverConfigState {
    /// Cached handover skip slots currently used by validation.
    handover_skip_slots: u64,
    /// Last beacon epoch where on-chain refresh was attempted.
    last_refresh_epoch: Option<u64>,
    /// Cached preconfirmation router address resolved from TaikoWrapper.
    preconf_router_address: Option<Address>,
}

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
    /// Local peer ID string.
    local_peer_id: String,
    /// Shared runtime state for status and EOS notifications.
    runtime_state: Arc<RuntimeStatusState>,
    /// Optional TaikoWrapper contract used to discover PreconfRouter config.
    taiko_wrapper_address: Option<Address>,
    /// Mutable cached handover configuration refreshed once per epoch.
    handover_config: Mutex<HandoverConfigState>,
    /// Serializes build requests to avoid concurrent insertion/signing races.
    build_preconf_lock: Mutex<()>,
    /// Preconf whitelist contract used for operator checks.
    whitelist: PreconfWhitelistInstance<P>,
}

impl<P> WhitelistRestHandler<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Create a new REST/WS handler.
    #[allow(clippy::too_many_arguments)]
    pub(crate) fn new(
        event_syncer: Arc<EventSyncer<P>>,
        rpc: Client<P>,
        chain_id: u64,
        signer: FixedKSigner,
        beacon_client: Arc<BeaconClient>,
        whitelist_address: Address,
        runtime_state: Arc<RuntimeStatusState>,
        network_command_tx: mpsc::Sender<NetworkCommand>,
        local_peer_id: String,
        fallback_handover_skip_slots: u64,
        taiko_wrapper_address: Option<Address>,
    ) -> Self {
        let whitelist = PreconfWhitelistInstance::new(whitelist_address, rpc.l1_provider.clone());
        Self {
            event_syncer,
            rpc,
            chain_id,
            signer,
            beacon_client,
            runtime_state,
            whitelist,
            network_command_tx,
            local_peer_id,
            taiko_wrapper_address,
            handover_config: Mutex::new(HandoverConfigState {
                handover_skip_slots: fallback_handover_skip_slots,
                last_refresh_epoch: None,
                preconf_router_address: None,
            }),
            build_preconf_lock: Mutex::new(()),
        }
    }

    /// Build driver payload attributes from the RPC request.
    fn build_driver_payload(
        &self,
        request: &BuildPreconfBlockRequest,
        prev_randao: B256,
        signature: [u8; 65],
        tx_list: Vec<u8>,
    ) -> Result<TaikoPayloadAttributes> {
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
    ) -> Result<Vec<u8>> {
        let tx_list = decompress_tx_list(request.transactions.as_ref())?;
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

        validate_execution_payload_for_preconf_with_tx_list(
            &payload,
            &tx_list,
            self.chain_id,
            *self.rpc.shasta.anchor.address(),
        )?;

        Ok(tx_list)
    }

    /// Check fee recipient against current/next whitelist operators and slot handover window.
    async fn ensure_fee_recipient_allowed(&self, fee_recipient: Address) -> Result<()> {
        let (current, next) = self.fetch_current_next_sequencers().await?;
        let current_slot = self.beacon_client.current_slot();
        let slots_per_epoch = self.beacon_client.slots_per_epoch();
        let current_epoch = if slots_per_epoch == 0 { 0 } else { current_slot / slots_per_epoch };
        let handover_skip_slots = self.handover_skip_slots_for_epoch(current_epoch).await;
        validate_fee_recipient_for_slot(
            fee_recipient,
            current,
            next,
            current_slot,
            slots_per_epoch,
            handover_skip_slots,
        )
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
    async fn current_lookahead_status(&self) -> Option<LookaheadStatus> {
        let (curr_operator, next_operator) = self.fetch_current_next_sequencers().await.ok()?;
        let current_epoch = self.beacon_client.current_epoch();
        let slots_per_epoch = self.beacon_client.slots_per_epoch();
        let handover_skip_slots = self.handover_skip_slots_for_epoch(current_epoch).await;
        let (curr_range, next_range) =
            sequencing_window_ranges(current_epoch, slots_per_epoch, handover_skip_slots);
        let curr_ranges = vec![curr_range];
        let next_ranges = vec![next_range];

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
        self.runtime_state.set_highest_unsafe_l2_payload_block_id(block_number);
    }

    /// Insert end-of-sequencing hash indexed by beacon epoch with bounded retention.
    async fn cache_end_of_sequencing_hash(&self, epoch: u64, block_hash: B256) {
        self.runtime_state.set_end_of_sequencing_block_hash(epoch, block_hash).await;
    }

    /// Load handover skip slots from PreconfRouter config once per epoch.
    ///
    /// Falls back to the configured static value when router discovery/config read is unavailable.
    async fn handover_skip_slots_for_epoch(&self, epoch: u64) -> u64 {
        {
            let state = self.handover_config.lock().await;
            if state.last_refresh_epoch == Some(epoch) {
                return state.handover_skip_slots;
            }
        }

        let (mut preconf_router_address, mut handover_skip_slots) = {
            let state = self.handover_config.lock().await;
            (state.preconf_router_address, state.handover_skip_slots)
        };

        if preconf_router_address.is_none() &&
            let Some(taiko_wrapper_address) = self.taiko_wrapper_address
        {
            let wrapper =
                TaikoWrapperConfigReader::new(taiko_wrapper_address, self.rpc.l1_provider.clone());
            match wrapper.preconfRouter().call().await {
                Ok(router_address) => {
                    if router_address == Address::ZERO {
                        warn!(
                            taiko_wrapper = %taiko_wrapper_address,
                            "resolved zero preconf router address; keeping configured handover skip slots"
                        );
                    } else {
                        preconf_router_address = Some(router_address);
                    }
                }
                Err(err) => {
                    warn!(
                        taiko_wrapper = %taiko_wrapper_address,
                        error = %err,
                        "failed to resolve preconf router address from TaikoWrapper; keeping configured handover skip slots"
                    );
                }
            }
        }

        if let Some(router_address) = preconf_router_address {
            let router =
                PreconfRouterConfigReader::new(router_address, self.rpc.l1_provider.clone());
            match router.getConfig().call().await {
                Ok(config) => match u64::try_from(config.handOverSlots) {
                    Ok(updated) => {
                        handover_skip_slots = updated;
                    }
                    Err(_) => {
                        warn!(
                            preconf_router = %router_address,
                            handover_skip_slots = %config.handOverSlots,
                            "preconf router handover slots exceed u64; keeping previous value"
                        );
                    }
                },
                Err(err) => {
                    warn!(
                        preconf_router = %router_address,
                        error = %err,
                        "failed to read preconf router config; keeping previous handover skip slots"
                    );
                }
            }
        }

        let mut state = self.handover_config.lock().await;
        state.last_refresh_epoch = Some(epoch);
        state.preconf_router_address = preconf_router_address;
        state.handover_skip_slots = handover_skip_slots;
        state.handover_skip_slots
    }
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

        let sync_status = self.rpc.l2_provider.syncing().await.map_err(provider_err)?;
        if matches!(sync_status, SyncStatus::Info(_)) {
            return Err(WhitelistPreconfirmationDriverError::Driver(
                driver::DriverError::EngineSyncing(request.block_number),
            ));
        }

        self.ensure_fee_recipient_allowed(request.fee_recipient).await?;

        let prev_randao =
            self.derive_prev_randao(request.parent_hash, request.block_number).await?;
        let tx_list = self.validate_request_payload(&request, prev_randao)?;

        // Insert the preconfirmation payload locally first, mirroring the Go flow, to
        // obtain the canonical block hash before gossiping.
        let driver_payload =
            self.build_driver_payload(&request, prev_randao, [0u8; 65], tx_list)?;
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
            self.cache_end_of_sequencing_hash(epoch, block_hash).await;
            self.runtime_state.notify_end_of_sequencing(epoch);
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
        let highest_unsafe = self.runtime_state.highest_unsafe_l2_payload_block_id();
        let current_epoch = self.beacon_client.current_epoch();
        let end_of_sequencing_block_hash = self
            .runtime_state
            .end_of_sequencing_block_hash(current_epoch)
            .await
            .map(|h| h.to_string());
        let sync_ready = head_l1_origin_block_id.is_some();

        Ok(WhitelistStatus {
            head_l1_origin_block_id,
            highest_unsafe_block_number: Some(highest_unsafe),
            peer_id: self.local_peer_id.clone(),
            sync_ready,
            lookahead: self.current_lookahead_status().await,
            total_cached: Some(self.runtime_state.total_cached()),
            highest_unsafe_l2_payload_block_id: Some(highest_unsafe),
            end_of_sequencing_block_hash,
        })
    }

    fn subscribe_end_of_sequencing(&self) -> broadcast::Receiver<EndOfSequencingNotification> {
        self.runtime_state.subscribe_end_of_sequencing()
    }
}

/// Return the current-operator handover split threshold in slots.
fn handover_threshold(slots_per_epoch: u64, handover_skip_slots: u64) -> u64 {
    let handover_skip_slots = handover_skip_slots.min(slots_per_epoch);
    slots_per_epoch.saturating_sub(handover_skip_slots)
}

/// Build current/next operator sequencing windows for one epoch.
fn sequencing_window_ranges(
    current_epoch: u64,
    slots_per_epoch: u64,
    handover_skip_slots: u64,
) -> (SlotRange, SlotRange) {
    let threshold = handover_threshold(slots_per_epoch, handover_skip_slots);
    let epoch_start = current_epoch.saturating_mul(slots_per_epoch);
    (
        SlotRange { start: epoch_start, end: epoch_start.saturating_add(threshold) },
        SlotRange {
            start: epoch_start.saturating_add(threshold),
            end: epoch_start.saturating_add(slots_per_epoch),
        },
    )
}

/// Return true when the absolute slot is inside the half-open range.
fn slot_in_range(slot: u64, range: &SlotRange) -> bool {
    slot >= range.start && slot < range.end
}

/// Validate fee recipient against slot-aware current/next operator handover windows.
///
/// This is intentionally strict for Go parity in whitelist preconfirmation handover:
/// before threshold only current operator is accepted, and at/after threshold only next
/// operator is accepted.
fn validate_fee_recipient_for_slot(
    fee_recipient: Address,
    current_operator: Address,
    next_operator: Address,
    current_slot: u64,
    slots_per_epoch: u64,
    handover_skip_slots: u64,
) -> Result<()> {
    if slots_per_epoch == 0 {
        return Err(WhitelistPreconfirmationDriverError::WhitelistLookup(
            "invalid beacon config: slots_per_epoch is zero".to_string(),
        ));
    }

    let current_epoch = current_slot / slots_per_epoch;
    let (curr_range, next_range) =
        sequencing_window_ranges(current_epoch, slots_per_epoch, handover_skip_slots);
    let in_curr_window = slot_in_range(current_slot, &curr_range);
    let in_next_window = slot_in_range(current_slot, &next_range);

    if fee_recipient == current_operator && in_curr_window {
        return Ok(());
    }

    if fee_recipient == next_operator && in_next_window {
        return Ok(());
    }

    let (expected_label, expected_operator) = if in_curr_window {
        ("current", current_operator)
    } else if in_next_window {
        ("next", next_operator)
    } else {
        ("none", Address::ZERO)
    };

    Err(WhitelistPreconfirmationDriverError::InvalidPayload(format!(
        "fee recipient {fee_recipient} is not allowed at slot {current_slot}; expected {expected_label} operator \
         {expected_operator} (current range: [{}..{}), next range: [{}..{}))",
        curr_range.start, curr_range.end, next_range.start, next_range.end
    )))
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
    use crate::importer::{MAX_COMPRESSED_TX_LIST_BYTES, MAX_DECOMPRESSED_TX_LIST_BYTES};
    const TEST_HANDOVER_SKIP_SLOTS: u64 = 8;

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
    fn validate_fee_recipient_for_slot_allows_current_before_handover() {
        let current = Address::from([0x11; 20]);
        let next = Address::from([0x22; 20]);
        // slots_per_epoch=32 and handover_skip_slots=8 => threshold=24
        validate_fee_recipient_for_slot(current, current, next, 23, 32, TEST_HANDOVER_SKIP_SLOTS)
            .expect("current operator must be allowed before handover threshold");
    }

    #[test]
    fn validate_fee_recipient_for_slot_allows_next_at_handover_or_later() {
        let current = Address::from([0x11; 20]);
        let next = Address::from([0x22; 20]);
        validate_fee_recipient_for_slot(next, current, next, 24, 32, TEST_HANDOVER_SKIP_SLOTS)
            .expect("next operator must be allowed at handover threshold");
        validate_fee_recipient_for_slot(next, current, next, 31, 32, TEST_HANDOVER_SKIP_SLOTS)
            .expect("next operator must be allowed after handover threshold");
    }

    #[test]
    fn validate_fee_recipient_for_slot_rejects_wrong_operator_for_window() {
        let current = Address::from([0x11; 20]);
        let next = Address::from([0x22; 20]);
        let err =
            validate_fee_recipient_for_slot(next, current, next, 10, 32, TEST_HANDOVER_SKIP_SLOTS)
                .expect_err("next operator should not be allowed before handover threshold");
        assert!(matches!(
            err,
            WhitelistPreconfirmationDriverError::InvalidPayload(msg)
                if msg.contains("expected current operator")
        ));

        let err = validate_fee_recipient_for_slot(
            current,
            current,
            next,
            30,
            32,
            TEST_HANDOVER_SKIP_SLOTS,
        )
        .expect_err("current operator should not be allowed during next-operator window");
        assert!(matches!(
            err,
            WhitelistPreconfirmationDriverError::InvalidPayload(msg)
                if msg.contains("expected next operator")
        ));
    }

    #[test]
    fn validate_fee_recipient_for_slot_allows_same_operator_across_windows() {
        let same = Address::from([0x44; 20]);
        validate_fee_recipient_for_slot(same, same, same, 1, 32, TEST_HANDOVER_SKIP_SLOTS)
            .expect("same operator should be allowed in current window");
        validate_fee_recipient_for_slot(same, same, same, 31, 32, TEST_HANDOVER_SKIP_SLOTS)
            .expect("same operator should be allowed in next window");
    }

    #[test]
    fn validate_fee_recipient_for_slot_rejects_zero_slots_per_epoch() {
        let operator = Address::from([0x11; 20]);
        let err = validate_fee_recipient_for_slot(
            operator,
            operator,
            operator,
            0,
            0,
            TEST_HANDOVER_SKIP_SLOTS,
        )
        .expect_err("zero slots_per_epoch must fail");
        assert!(matches!(
            err,
            WhitelistPreconfirmationDriverError::WhitelistLookup(msg)
                if msg.contains("slots_per_epoch is zero")
        ));
    }
}

//! Whitelist preconfirmation envelope importer.

use std::{sync::Arc, time::Instant};

use alloy_eips::BlockNumberOrTag;
use alloy_primitives::{Address, B256};
use alloy_provider::Provider;
use bindings::preconf_whitelist::PreconfWhitelist::PreconfWhitelistInstance;
use driver::sync::event::EventSyncer;
use hashlink::LinkedHashMap;
use libp2p::PeerId;
use rpc::{beacon::BeaconClient, client::Client};
use tokio::sync::mpsc;
use tracing::{debug, info, warn};

use crate::{
    cache::{
        EnvelopeCache, L1_EPOCH_DURATION_SECS, RecentEnvelopeCache, RequestThrottle,
        WhitelistSequencerCache,
    },
    codec::WhitelistExecutionPayloadEnvelope,
    error::{Result, WhitelistPreconfirmationDriverError},
    metrics::WhitelistPreconfirmationDriverMetrics,
    network::{NetworkCommand, NetworkEvent, PRECONF_RESPONSE_SEEN_WINDOW},
    runtime_state::RuntimeStatusState,
};

mod cache_import;
mod ingress;
mod payload;
mod response;
mod signer;
mod tx_list;
mod validation;

#[cfg(test)]
mod tests;

pub(crate) use tx_list::decompress_tx_list;
pub(crate) use validation::validate_execution_payload_for_preconf_with_tx_list;

/// Maximum compressed tx-list size accepted from a preconfirmation payload.
pub(crate) const MAX_COMPRESSED_TX_LIST_BYTES: usize = 131_072 * 6;
/// Maximum decompressed tx-list size accepted from a preconfirmation payload.
///
/// Align with the preconfirmation tx-list cap to avoid zlib bomb expansion on untrusted payloads.
pub(crate) const MAX_DECOMPRESSED_TX_LIST_BYTES: usize = 8 * 1024 * 1024;
/// Maximum hashes retained for response-seen dedup checks.
const RESPONSE_SEEN_CACHE_CAPACITY: usize = 1024;
/// Imports whitelist preconfirmation payloads into the driver after event sync catches up.
pub(crate) struct WhitelistPreconfirmationImporter<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Event syncer used to submit validated preconfirmation payloads.
    event_syncer: Arc<EventSyncer<P>>,
    /// RPC client used for L1/L2 reads and head-origin updates.
    rpc: Client<P>,
    /// On-chain whitelist contract instance used to validate sequencer signers.
    whitelist: PreconfWhitelistInstance<P>,
    /// Chain id used for preconfirmation signature domain separation.
    chain_id: u64,
    /// Out-of-order payload cache waiting for parent availability.
    cache: EnvelopeCache,
    /// Recently accepted envelopes that can be served over response topic requests.
    recent_cache: RecentEnvelopeCache,
    /// Cooldown gate for repeated missing-parent requests.
    request_throttle: RequestThrottle,
    /// TTL cache for current/next whitelist sequencer addresses.
    sequencer_cache: WhitelistSequencerCache,
    /// Command channel used to publish P2P requests/responses.
    network_command_tx: mpsc::Sender<NetworkCommand>,
    /// Optional beacon metadata client used to derive EOS epoch from payload timestamps.
    beacon_client: Option<Arc<BeaconClient>>,
    /// Outbound response suppression cache.
    ///
    /// Network-edge validation already dedups inbound response gossip. This cache is an additional
    /// importer-level guard to avoid publishing duplicate responses when requests race against
    /// recently observed or locally-published responses.
    response_seen_cache: LinkedHashMap<B256, Instant>,
    /// Local libp2p peer identity used to de-correlate deterministic response jitter across nodes.
    local_peer_id: PeerId,
    /// Latched flag indicating event sync has exposed a head L1 origin.
    sync_ready: bool,
    /// Shasta anchor contract address used to validate the first transaction.
    anchor_address: Address,
    /// Shared runtime state for status and EOS websocket notifications.
    runtime_state: Arc<RuntimeStatusState>,
}

impl<P> WhitelistPreconfirmationImporter<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Build an importer.
    pub(crate) fn new(
        event_syncer: Arc<EventSyncer<P>>,
        rpc: Client<P>,
        whitelist_address: Address,
        chain_id: u64,
        beacon_client: Option<Arc<BeaconClient>>,
        network_command_tx: mpsc::Sender<NetworkCommand>,
        local_peer_id: PeerId,
        runtime_state: Arc<RuntimeStatusState>,
    ) -> Self {
        let whitelist = PreconfWhitelistInstance::new(whitelist_address, rpc.l1_provider.clone());
        let anchor_address = *rpc.shasta.anchor.address();

        let importer = Self {
            event_syncer,
            rpc,
            whitelist,
            chain_id,
            cache: EnvelopeCache::default(),
            recent_cache: RecentEnvelopeCache::default(),
            request_throttle: RequestThrottle::default(),
            sequencer_cache: WhitelistSequencerCache::default(),
            network_command_tx,
            beacon_client,
            response_seen_cache: LinkedHashMap::with_capacity(RESPONSE_SEEN_CACHE_CAPACITY),
            local_peer_id,
            sync_ready: false,
            anchor_address,
            runtime_state,
        };
        importer.update_cache_gauges();
        importer
    }

    /// Handle one network event.
    pub(crate) async fn handle_event(&mut self, event: NetworkEvent) -> Result<()> {
        match event {
            NetworkEvent::UnsafePayload { from, payload } => {
                match self.handle_unsafe_payload(payload).await {
                    Ok(()) => metrics::counter!(
                        WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
                        "event_type" => "unsafe_payload",
                        "result" => "accepted",
                    )
                    .increment(1),
                    Err(err) => {
                        warn!(peer = %from, error = %err, "dropping invalid whitelist preconfirmation payload");
                        metrics::counter!(
                            WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
                            "event_type" => "unsafe_payload",
                            "result" => "dropped",
                        )
                        .increment(1);
                    }
                }
            }
            NetworkEvent::UnsafeResponse { from, envelope } => {
                match self.handle_unsafe_response(envelope).await {
                    Ok(()) => metrics::counter!(
                        WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
                        "event_type" => "unsafe_response",
                        "result" => "accepted",
                    )
                    .increment(1),
                    Err(err) => {
                        warn!(peer = %from, error = %err, "dropping invalid whitelist preconfirmation response");
                        metrics::counter!(
                            WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
                            "event_type" => "unsafe_response",
                            "result" => "dropped",
                        )
                        .increment(1);
                    }
                }
            }
            NetworkEvent::UnsafeRequest { from, hash } => {
                if let Err(err) = self.handle_unsafe_request(from, hash).await {
                    warn!(
                        peer = %from,
                        hash = %hash,
                        error = %err,
                        "failed to handle whitelist preconfirmation request"
                    );
                    metrics::counter!(
                        WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
                        "event_type" => "unsafe_request",
                        "result" => "error",
                    )
                    .increment(1);
                } else {
                    metrics::counter!(
                        WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
                        "event_type" => "unsafe_request",
                        "result" => "handled",
                    )
                    .increment(1);
                }
            }
            NetworkEvent::EndOfSequencingRequest { from, epoch } => {
                if let Some(envelope) = self.recent_cache.end_of_sequencing_for_epoch(epoch) {
                    debug!(
                        peer = %from,
                        epoch,
                        hash = %envelope.execution_payload.block_hash,
                        "serving end-of-sequencing whitelist preconfirmation response from recent cache"
                    );
                    let hash = envelope.execution_payload.block_hash;
                    if self.publish_unsafe_response(envelope).await {
                        self.mark_response_seen(hash, Instant::now());
                    }
                    metrics::counter!(
                        WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
                        "event_type" => "end_of_sequencing_request",
                        "result" => "served",
                    )
                    .increment(1);
                } else if self.beacon_client.is_none() {
                    if let Some(envelope) = self.recent_cache.latest_end_of_sequencing() {
                        debug!(
                            peer = %from,
                            epoch,
                            hash = %envelope.execution_payload.block_hash,
                            "serving latest end-of-sequencing response without epoch index because beacon metadata is unavailable"
                        );
                        let hash = envelope.execution_payload.block_hash;
                        if self.publish_unsafe_response(envelope).await {
                            self.mark_response_seen(hash, Instant::now());
                        }
                        metrics::counter!(
                            WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
                            "event_type" => "end_of_sequencing_request",
                            "result" => "served_without_beacon_epoch",
                        )
                        .increment(1);
                    } else {
                        debug!(
                            peer = %from,
                            epoch,
                            "no end-of-sequencing envelope found while beacon metadata is unavailable"
                        );
                        metrics::counter!(
                            WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
                            "event_type" => "end_of_sequencing_request",
                            "result" => "miss",
                        )
                        .increment(1);
                    }
                } else {
                    debug!(
                        peer = %from,
                        epoch,
                        "no end-of-sequencing envelope found for requested epoch"
                    );
                    metrics::counter!(
                        WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
                        "event_type" => "end_of_sequencing_request",
                        "result" => "miss",
                    )
                    .increment(1);
                }
            }
        }

        self.maybe_import_from_cache().await
    }

    /// Event-sync progress signal.
    ///
    /// Drop cached sequencers only after crossing an epoch boundary to avoid unnecessary
    /// re-fetches while still preventing stale signer acceptance across epochs.
    pub(crate) async fn on_sync_ready_signal(&mut self) -> Result<()> {
        if !self.refresh_sync_ready().await? {
            return Ok(());
        }

        if self.sequencer_cache.current_epoch_start_timestamp().is_some() {
            let latest_l1_timestamp = self.latest_l1_block_timestamp().await?;
            if self
                .sequencer_cache
                .should_invalidate_for_l1_timestamp(latest_l1_timestamp, L1_EPOCH_DURATION_SECS)
            {
                self.sequencer_cache.invalidate();
            }
        }

        if self.cache.is_empty() {
            return Ok(());
        }

        self.import_from_cache().await.inspect_err(|_err| {
            metrics::counter!(
                WhitelistPreconfirmationDriverMetrics::SYNC_READY_IMPORT_FAILURES_TOTAL
            )
            .increment(1);
        })
    }

    /// Refresh whether sync is ready.
    pub(super) async fn refresh_sync_ready(&mut self) -> Result<bool> {
        let ready = self.head_l1_origin_block_id().await?.is_some();
        let became_ready = sync_ready_transition(self.sync_ready, ready);
        if became_ready {
            metrics::counter!(WhitelistPreconfirmationDriverMetrics::SYNC_READY_TRANSITIONS_TOTAL)
                .increment(1);
            info!(
                "event sync established head l1 origin; enabling whitelist preconfirmation imports"
            );
        }
        self.sync_ready = ready;
        Ok(became_ready)
    }

    /// Get the block ID of the head L1 origin.
    pub(super) async fn head_l1_origin_block_id(&self) -> Result<Option<u64>> {
        Ok(self.rpc.head_l1_origin().await?.map(|head| head.block_id.to::<u64>()))
    }

    /// Read latest L1 block timestamp.
    pub(super) async fn latest_l1_block_timestamp(&self) -> Result<u64> {
        self.rpc
            .l1_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(provider_err)?
            .map(|block| block.header.timestamp)
            .ok_or_else(|| {
                WhitelistPreconfirmationDriverError::WhitelistLookup(
                    "missing latest L1 block while updating sequencer cache".to_string(),
                )
            })
    }

    /// Get the block hash by block number.
    pub(super) async fn block_hash_by_number(&self, block_number: u64) -> Result<Option<B256>> {
        self.rpc
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Number(block_number))
            .await
            .map(|opt| opt.map(|block| block.hash()))
            .map_err(provider_err)
    }

    /// Update cache gauges after cache mutations.
    pub(super) fn update_cache_gauges(&self) {
        metrics::gauge!(WhitelistPreconfirmationDriverMetrics::CACHE_PENDING_COUNT)
            .set(self.cache.len() as f64);
        metrics::gauge!(WhitelistPreconfirmationDriverMetrics::CACHE_RECENT_COUNT)
            .set(self.recent_cache.len() as f64);
    }

    /// Insert/refresh an accepted envelope in pending+recent caches and track total-cached.
    pub(super) fn cache_accepted_envelope(
        &mut self,
        envelope: Arc<WhitelistExecutionPayloadEnvelope>,
        eos_epoch: Option<u64>,
    ) {
        let hash = envelope.execution_payload.block_hash;
        let is_new = self.cache.get(&hash).is_none();
        self.cache.insert(envelope.clone());
        self.recent_cache.insert_recent_with_epoch_hint(envelope, eos_epoch);
        if is_new {
            self.runtime_state.increment_total_cached();
        }
        self.update_cache_gauges();
    }

    /// Return true when a response for `hash` has been seen recently.
    pub(super) fn response_seen_recently(&mut self, hash: B256, now: Instant) -> bool {
        self.prune_response_seen(now);
        self.response_seen_cache.get(&hash).is_some_and(|seen_at| {
            now.saturating_duration_since(*seen_at) < PRECONF_RESPONSE_SEEN_WINDOW
        })
    }

    /// Record a response hash as observed/published now.
    pub(super) fn mark_response_seen(&mut self, hash: B256, now: Instant) {
        self.prune_response_seen(now);
        self.response_seen_cache.remove(&hash);
        self.response_seen_cache.insert(hash, now);
        while self.response_seen_cache.len() > RESPONSE_SEEN_CACHE_CAPACITY {
            let _ = self.response_seen_cache.pop_front();
        }
    }

    /// Drop expired response-seen entries.
    fn prune_response_seen(&mut self, now: Instant) {
        while let Some((_, seen_at)) = self.response_seen_cache.iter().next() {
            if now.saturating_duration_since(*seen_at) < PRECONF_RESPONSE_SEEN_WINDOW {
                break;
            }
            let _ = self.response_seen_cache.pop_front();
        }
    }
}

/// Convert a provider error into a driver error.
pub(super) fn provider_err(err: impl std::fmt::Display) -> WhitelistPreconfirmationDriverError {
    WhitelistPreconfirmationDriverError::Rpc(rpc::RpcClientError::Provider(err.to_string()))
}

/// Returns true only when sync readiness transitions from disabled to enabled.
fn sync_ready_transition(was_ready: bool, is_ready: bool) -> bool {
    !was_ready && is_ready
}

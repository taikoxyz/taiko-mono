//! Whitelist preconfirmation envelope importer.

use std::sync::{Arc, atomic::AtomicU64};

use alloy_primitives::{Address, B256};
use alloy_provider::Provider;
use driver::sync::event::EventSyncer;
use rpc::{beacon::BeaconClient, client::Client};
use tokio::sync::mpsc;
use tracing::{debug, info, warn};

use crate::{
    cache::{EnvelopeCache, RecentEnvelopeCache, RequestThrottle, SharedPreconfCacheState},
    error::{Result, WhitelistPreconfirmationDriverError},
    metrics::WhitelistPreconfirmationDriverMetrics,
    network::{
        NetworkCommand, NetworkEvent,
        inbound::{PeerHashTracker, RateLimiter},
    },
    whitelist_fetcher::WhitelistSequencerFetcher,
};

/// Cache re-import flow for out-of-order envelopes once parents arrive.
mod cache_import;
/// Ingress entrypoints for unsafe payload handling.
mod ingress;
/// Payload normalization helpers.
mod payload;
/// Response serving helpers for request/response gossip.
mod response;
/// Whitelist signer validation and sequencer snapshot cache.
mod signer;
/// Payload-level validation helpers.
mod validation;

#[cfg(test)]
mod tests;

pub(crate) use validation::validate_execution_payload_for_preconf;
/// Dependency bundle for constructing [`WhitelistPreconfirmationImporter`].
pub(crate) struct WhitelistPreconfirmationImporterParams<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Event syncer used to submit validated preconfirmation payloads.
    pub(crate) event_syncer: Arc<EventSyncer<P>>,
    /// RPC client used for L1/L2 reads and head-origin updates.
    pub(crate) rpc: Client<P>,
    /// Whitelist contract address used for signer validation.
    pub(crate) whitelist_address: Address,
    /// Chain id used for preconfirmation signature domain separation.
    pub(crate) chain_id: u64,
    /// Command channel used to publish P2P requests/responses.
    pub(crate) network_command_tx: mpsc::Sender<NetworkCommand>,
    /// Shared cache state used by status and EOS signaling.
    pub(crate) cache_state: SharedPreconfCacheState,
    /// Beacon client used for EOS epoch validation.
    pub(crate) beacon_client: Arc<BeaconClient>,
    /// Shared highest unsafe L2 payload block ID (updated on P2P import when REST server enabled).
    pub(crate) highest_unsafe_l2_payload_block_id: Option<Arc<AtomicU64>>,
}

/// Imports whitelist preconfirmation payloads into the driver after event sync catches up.
pub(crate) struct WhitelistPreconfirmationImporter<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Event syncer used to submit validated preconfirmation payloads.
    event_syncer: Arc<EventSyncer<P>>,
    /// RPC client used for L1/L2 reads and head-origin updates.
    rpc: Client<P>,
    /// Chain id used for preconfirmation signature domain separation.
    chain_id: u64,
    /// Shared cache state used by status and EOS signaling.
    cache_state: SharedPreconfCacheState,
    /// Beacon client used for EOS epoch validation.
    beacon_client: Arc<BeaconClient>,
    /// Out-of-order payload cache waiting for parent availability.
    cache: EnvelopeCache,
    /// Recently accepted envelopes that can be served over response topic requests.
    recent_cache: RecentEnvelopeCache,
    /// Cooldown gate for repeated missing-parent requests.
    request_throttle: RequestThrottle,
    /// Per-peer rate limiter for inbound direct req/resp requests.
    direct_request_rate: RateLimiter,
    /// Per-(peer, hash) dedup tracker for inbound direct req/resp requests.
    direct_request_seen: PeerHashTracker,
    /// Shared sequencer fetcher for whitelist validation and epoch cache management.
    sequencer_fetcher: WhitelistSequencerFetcher<P>,
    /// Command channel used to publish P2P requests/responses.
    network_command_tx: mpsc::Sender<NetworkCommand>,
    /// Shared highest unsafe L2 payload block ID (updated on P2P import when REST server enabled).
    highest_unsafe_l2_payload_block_id: Option<Arc<AtomicU64>>,
    /// Latched flag indicating event sync has exposed a head L1 origin.
    sync_ready: bool,
    /// Shasta anchor contract address used to validate the first transaction.
    anchor_address: Address,
}

impl<P> WhitelistPreconfirmationImporter<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Build an importer.
    pub(crate) fn new(params: WhitelistPreconfirmationImporterParams<P>) -> Self {
        let WhitelistPreconfirmationImporterParams {
            event_syncer,
            rpc,
            whitelist_address,
            chain_id,
            network_command_tx,
            cache_state,
            beacon_client,
            highest_unsafe_l2_payload_block_id,
        } = params;
        let sequencer_fetcher =
            WhitelistSequencerFetcher::new(whitelist_address, rpc.l1_provider.clone());
        let anchor_address = *rpc.shasta.anchor.address();

        let importer = Self {
            event_syncer,
            rpc,
            chain_id,
            cache_state,
            beacon_client,
            cache: EnvelopeCache::default(),
            recent_cache: RecentEnvelopeCache::default(),
            request_throttle: RequestThrottle::default(),
            direct_request_rate: RateLimiter::default(),
            direct_request_seen: PeerHashTracker::default(),
            sequencer_fetcher,
            network_command_tx,
            highest_unsafe_l2_payload_block_id,
            sync_ready: false,
            anchor_address,
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
            NetworkEvent::DirectResponse { from, hash, envelope } => {
                if let Some(envelope) = envelope {
                    if envelope.execution_payload.block_hash != hash {
                        warn!(
                            peer = %from,
                            requested = %hash,
                            received = %envelope.execution_payload.block_hash,
                            "dropping direct response with mismatched block hash"
                        );
                        metrics::counter!(
                            WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
                            "event_type" => "direct_response",
                            "result" => "hash_mismatch",
                        )
                        .increment(1);
                        return Ok(());
                    }

                    match self.handle_unsafe_response(envelope).await {
                        Ok(()) => metrics::counter!(
                            WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
                            "event_type" => "direct_response",
                            "result" => "accepted",
                        )
                        .increment(1),
                        Err(err) => {
                            warn!(peer = %from, error = %err, "dropping invalid direct response");
                            metrics::counter!(
                                WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
                                "event_type" => "direct_response",
                                "result" => "dropped",
                            )
                            .increment(1);
                        }
                    }
                } else {
                    debug!(
                        peer = %from,
                        hash = %hash,
                        "direct response returned empty (block not found by peer)"
                    );
                    metrics::counter!(
                        WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
                        "event_type" => "direct_response",
                        "result" => "empty",
                    )
                    .increment(1);
                    // No explicit gossip fallback needed here — gossip was already
                    // published alongside the direct request in the network layer.
                }
            }
            NetworkEvent::DirectRequest { from, hash, request_id } => {
                if let Err(err) = self.handle_direct_request(from, hash, request_id).await {
                    warn!(
                        peer = %from,
                        hash = %hash,
                        ?request_id,
                        error = %err,
                        "failed to handle direct block request"
                    );
                    // If handle_direct_request returns Err, no response was sent yet
                    // (errors come from lookup_block_for_serving or send_direct_response).
                    // Send an empty response so the peer gets a prompt "not found"
                    // rather than waiting for the protocol timeout.
                    if let Err(send_err) = self.send_direct_response(request_id, Vec::new()).await {
                        warn!(
                            peer = %from,
                            ?request_id,
                            error = %send_err,
                            "failed to send empty direct response after request error"
                        );
                    }
                    metrics::counter!(
                        WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
                        "event_type" => "direct_request",
                        "result" => "error",
                    )
                    .increment(1);
                } else {
                    metrics::counter!(
                        WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
                        "event_type" => "direct_request",
                        "result" => "handled",
                    )
                    .increment(1);
                }
            }
            NetworkEvent::EndOfSequencingRequest { from, epoch } => {
                if let Some(hash) = self.cache_state.end_of_sequencing_for_epoch(epoch).await {
                    if let Some(envelope) = self.recent_cache.get_recent(&hash) {
                        debug!(
                            peer = %from,
                            epoch,
                            hash = %envelope.execution_payload.block_hash,
                            "serving end-of-sequencing whitelist preconfirmation response from recent cache"
                        );
                        self.publish_unsafe_response(envelope).await;
                        metrics::counter!(
                            WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
                            "event_type" => "end_of_sequencing_request",
                            "result" => "served",
                        )
                        .increment(1);
                    } else {
                        debug!(
                            peer = %from,
                            epoch,
                            hash = %hash,
                            "end-of-sequencing hash known for epoch but envelope not in recent cache; rebuilding from L2"
                        );

                        if let Some(mut envelope) =
                            self.build_response_envelope_from_l2(hash).await?
                        {
                            envelope.end_of_sequencing = Some(true);
                            let envelope = Arc::new(envelope);
                            self.recent_cache.insert_recent(envelope.clone());
                            self.update_cache_gauges();
                            self.publish_unsafe_response(envelope).await;
                            metrics::counter!(
                                WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
                                "event_type" => "end_of_sequencing_request",
                                "result" => "served_l2_fallback",
                            )
                            .increment(1);
                        } else {
                            debug!(
                                peer = %from,
                                epoch,
                                hash = %hash,
                                "end-of-sequencing hash known for epoch but unavailable from recent cache and L2"
                            );
                            metrics::counter!(
                                WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
                                "event_type" => "end_of_sequencing_request",
                                "result" => "miss",
                            )
                            .increment(1);
                        }
                    }
                } else {
                    debug!(peer = %from, epoch, "no end-of-sequencing block found for epoch");
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

    /// Invalidate the sequencer cache if the L1 head has crossed an epoch boundary.
    pub(crate) async fn maybe_invalidate_sequencer_cache_for_epoch(&mut self) {
        if let Err(err) = self.sequencer_fetcher.maybe_invalidate_for_epoch_advance().await {
            warn!(
                error = %err,
                "failed to check epoch boundary for sequencer cache invalidation"
            );
        }
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

    /// Get the block hash by block number.
    pub(super) async fn block_hash_by_number(&self, block_number: u64) -> Result<Option<B256>> {
        self.rpc
            .l2_provider
            .get_block_by_number(alloy_eips::BlockNumberOrTag::Number(block_number))
            .await
            .map(|opt| opt.map(|block| block.hash()))
            .map_err(WhitelistPreconfirmationDriverError::provider)
    }

    /// Update cache gauges after cache mutations.
    pub(super) fn update_cache_gauges(&self) {
        metrics::gauge!(WhitelistPreconfirmationDriverMetrics::CACHE_PENDING_COUNT)
            .set(self.cache.len() as f64);
        metrics::gauge!(WhitelistPreconfirmationDriverMetrics::CACHE_RECENT_COUNT)
            .set(self.recent_cache.len() as f64);
    }
}

/// Returns true only when sync readiness transitions from disabled to enabled.
fn sync_ready_transition(was_ready: bool, is_ready: bool) -> bool {
    !was_ready && is_ready
}

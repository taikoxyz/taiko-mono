//! Whitelist preconfirmation envelope importer.

use std::sync::Arc;

use alloy_primitives::{Address, B256};
use alloy_provider::Provider;
use driver::sync::event::EventSyncer;
use rpc::{beacon::BeaconClient, client::Client};
use tokio::sync::{Mutex, mpsc};
use tracing::{info, warn};

use crate::{
    cache::{EnvelopeCache, RecentEnvelopeCache, RequestThrottle, SharedPreconfCacheState},
    error::{Result, WhitelistPreconfirmationDriverError},
    metrics::WhitelistPreconfirmationDriverMetrics,
    network::{NetworkCommand, NetworkEvent},
    operator_set::SharedOperatorSet,
};

/// Cache re-import flow for out-of-order envelopes once parents arrive.
mod cache_import;
/// Ingress entrypoints for unsafe payload handling.
mod ingress;
/// Payload normalization helpers.
mod payload;
/// Response serving helpers for request/response gossip.
mod response;
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
    /// Shared operator set for signer validation.
    pub(crate) operator_set: SharedOperatorSet,
    /// Chain id used for preconfirmation signature domain separation.
    pub(crate) chain_id: u64,
    /// Command channel used to publish P2P requests/responses.
    pub(crate) network_command_tx: mpsc::Sender<NetworkCommand>,
    /// Shared cache state used by status and EOS signaling.
    pub(crate) cache_state: SharedPreconfCacheState,
    /// Beacon client used for EOS epoch validation.
    pub(crate) beacon_client: Arc<BeaconClient>,
    /// Shared highest unsafe L2 payload block ID (updated on P2P import when REST server enabled).
    pub(crate) highest_unsafe_l2_payload_block_id: Option<Arc<Mutex<u64>>>,
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
    /// Lock-free shared set of allowed sequencer addresses, refreshed by background poller.
    operator_set: SharedOperatorSet,
    /// Command channel used to publish P2P requests/responses.
    network_command_tx: mpsc::Sender<NetworkCommand>,
    /// Shared highest unsafe L2 payload block ID (updated on P2P import when REST server enabled).
    highest_unsafe_l2_payload_block_id: Option<Arc<Mutex<u64>>>,
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
            operator_set,
            chain_id,
            network_command_tx,
            cache_state,
            beacon_client,
            highest_unsafe_l2_payload_block_id,
        } = params;
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
            operator_set,
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
                if let Err(err) = self.handle_unsafe_payload(payload).await {
                    warn!(peer = %from, error = %err, "dropping invalid whitelist preconfirmation payload");
                    record_importer_event("unsafe_payload", "dropped");
                } else {
                    record_importer_event("unsafe_payload", "accepted");
                }
            }
            NetworkEvent::UnsafeResponse { from, envelope } => {
                if let Err(err) = self.handle_unsafe_response(envelope).await {
                    warn!(peer = %from, error = %err, "dropping invalid whitelist preconfirmation response");
                    record_importer_event("unsafe_response", "dropped");
                } else {
                    record_importer_event("unsafe_response", "accepted");
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
                    record_importer_event("unsafe_request", "error");
                } else {
                    record_importer_event("unsafe_request", "handled");
                }
            }
            NetworkEvent::EndOfSequencingRequest { from, epoch } => {
                self.handle_eos_request(from, epoch).await?;
            }
        }

        self.maybe_import_from_cache().await
    }

    /// Handle an incoming end-of-sequencing request by serving from the recent
    /// cache, falling back to an L2 rebuild, or recording a miss.
    async fn handle_eos_request(&mut self, _from: libp2p::PeerId, epoch: u64) -> Result<()> {
        let Some(hash) = self.cache_state.end_of_sequencing_for_epoch(epoch).await else {
            record_importer_event("end_of_sequencing_request", "miss");
            return Ok(());
        };

        // Fast path: envelope still lives in the recent cache.
        if let Some(envelope) = self.recent_cache.get_recent(&hash) {
            self.publish_unsafe_response(envelope).await;
            record_importer_event("end_of_sequencing_request", "served");
            return Ok(());
        }

        // Slow path: rebuild from local L2 state.
        let Some(mut envelope) = self.build_response_envelope_from_l2(hash).await? else {
            record_importer_event("end_of_sequencing_request", "miss");
            return Ok(());
        };

        envelope.end_of_sequencing = Some(true);
        let envelope = Arc::new(envelope);
        self.recent_cache.insert_recent(envelope.clone());
        self.update_cache_gauges();
        self.publish_unsafe_response(envelope).await;
        record_importer_event("end_of_sequencing_request", "served");
        Ok(())
    }

    /// Validate that the recovered signer is present in the shared operator set.
    pub(super) fn ensure_signer_allowed(&self, signer: Address) -> Result<()> {
        if self.operator_set.load().contains(&signer) {
            Ok(())
        } else {
            Err(WhitelistPreconfirmationDriverError::invalid_signature(format!(
                "signer {signer} is not a registered operator"
            )))
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

/// Record one importer event outcome for the given event type and result.
fn record_importer_event(event_type: &'static str, result: &'static str) {
    metrics::counter!(
        WhitelistPreconfirmationDriverMetrics::IMPORTER_EVENTS_TOTAL,
        "event_type" => event_type,
        "result" => result,
    )
    .increment(1);
}

/// Returns true only when sync readiness transitions from disabled to enabled.
fn sync_ready_transition(was_ready: bool, is_ready: bool) -> bool {
    !was_ready && is_ready
}

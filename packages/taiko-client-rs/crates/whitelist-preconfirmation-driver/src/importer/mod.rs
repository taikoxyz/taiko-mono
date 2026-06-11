//! Whitelist preconfirmation envelope importer.

use std::sync::Arc;

use alloy_primitives::{Address, B256};
use alloy_provider::Provider;
use driver::sync::event::EventSyncer;
use rpc::{beacon::BeaconClient, client::Client};
use tokio::sync::mpsc;
use tracing::{info, warn};

use crate::{
    cache::{EnvelopeCache, PENDING_ENVELOPE_CAPACITY, RequestThrottle, SharedPreconfState},
    error::{Result, WhitelistPreconfirmationDriverError},
    metrics::WhitelistPreconfirmationDriverMetrics,
    network::{NetworkCommand, NetworkEvent},
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
    /// Chain id used for preconfirmation signature domain separation.
    pub(crate) chain_id: u64,
    /// Command channel used to publish P2P requests/responses.
    pub(crate) network_command_tx: mpsc::Sender<NetworkCommand>,
    /// Shared driver state (recent envelopes, EOS markers, highest unsafe block id).
    pub(crate) state: SharedPreconfState,
    /// Beacon client used for EOS epoch validation.
    pub(crate) beacon_client: Arc<BeaconClient>,
}

/// Imports whitelist preconfirmation payloads into the driver after event sync catches up.
///
/// Signature authenticity and operator-set membership of inbound gossip are
/// enforced once, at gossip acceptance time in
/// [`crate::network`]'s inbound validation state, before events reach this
/// importer. The importer performs payload-level validation only.
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
    /// Shared driver state (recent envelopes, EOS markers, highest unsafe block id).
    state: SharedPreconfState,
    /// Beacon client used for EOS epoch validation.
    beacon_client: Arc<BeaconClient>,
    /// Out-of-order payload cache waiting for parent availability.
    cache: EnvelopeCache,
    /// Cooldown gate for repeated missing-parent requests.
    request_throttle: RequestThrottle,
    /// Command channel used to publish P2P requests/responses.
    network_command_tx: mpsc::Sender<NetworkCommand>,
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
            chain_id,
            network_command_tx,
            state,
            beacon_client,
        } = params;
        let anchor_address = *rpc.shasta.anchor.address();

        let importer = Self {
            event_syncer,
            rpc,
            chain_id,
            state,
            beacon_client,
            cache: EnvelopeCache::with_capacity(PENDING_ENVELOPE_CAPACITY),
            request_throttle: RequestThrottle::default(),
            network_command_tx,
            sync_ready: false,
            anchor_address,
        };
        importer.update_pending_cache_gauge();
        importer
    }

    /// Handle one network event.
    pub(crate) async fn handle_event(&mut self, event: NetworkEvent) -> Result<()> {
        match event {
            NetworkEvent::UnsafePayload { from, payload } => {
                if let Err(err) = self.handle_unsafe_payload(payload).await {
                    warn!(peer = %from, error = %err, "dropping invalid whitelist preconfirmation payload");
                    WhitelistPreconfirmationDriverMetrics::inc_importer_event(
                        "unsafe_payload",
                        "dropped",
                    );
                } else {
                    WhitelistPreconfirmationDriverMetrics::inc_importer_event(
                        "unsafe_payload",
                        "accepted",
                    );
                }
            }
            NetworkEvent::UnsafeResponse { from, envelope } => {
                if let Err(err) = self.handle_unsafe_response(envelope).await {
                    warn!(peer = %from, error = %err, "dropping invalid whitelist preconfirmation response");
                    WhitelistPreconfirmationDriverMetrics::inc_importer_event(
                        "unsafe_response",
                        "dropped",
                    );
                } else {
                    WhitelistPreconfirmationDriverMetrics::inc_importer_event(
                        "unsafe_response",
                        "accepted",
                    );
                }
            }
            NetworkEvent::UnsafeRequest { from, hash } => {
                if let Err(err) = self.handle_unsafe_request(hash).await {
                    warn!(
                        peer = %from,
                        hash = %hash,
                        error = %err,
                        "failed to handle whitelist preconfirmation request"
                    );
                    WhitelistPreconfirmationDriverMetrics::inc_importer_event(
                        "unsafe_request",
                        "error",
                    );
                } else {
                    WhitelistPreconfirmationDriverMetrics::inc_importer_event(
                        "unsafe_request",
                        "handled",
                    );
                }
            }
            NetworkEvent::EndOfSequencingRequest { from, epoch } => {
                if let Err(err) = self.handle_eos_request(epoch).await {
                    warn!(
                        peer = %from,
                        epoch,
                        error = %err,
                        "failed to handle whitelist preconfirmation end-of-sequencing request"
                    );
                    WhitelistPreconfirmationDriverMetrics::inc_importer_event(
                        "end_of_sequencing_request",
                        "error",
                    );
                }
            }
        }

        self.maybe_import_from_cache().await
    }

    /// Handle an incoming end-of-sequencing request by serving from the recent
    /// cache, falling back to an L2 rebuild, or recording a miss.
    async fn handle_eos_request(&mut self, epoch: u64) -> Result<()> {
        let Some(hash) = self.state.end_of_sequencing_for_epoch(epoch).await else {
            WhitelistPreconfirmationDriverMetrics::inc_importer_event(
                "end_of_sequencing_request",
                "miss",
            );
            return Ok(());
        };

        // Fast path: envelope still lives in the recent cache.
        if let Some(envelope) = self.state.get_recent(&hash).await {
            self.publish_unsafe_response(envelope).await;
            WhitelistPreconfirmationDriverMetrics::inc_importer_event(
                "end_of_sequencing_request",
                "served",
            );
            return Ok(());
        }

        // Slow path: rebuild from local L2 state.
        let Some(mut envelope) = self.build_response_envelope_from_l2(hash).await? else {
            WhitelistPreconfirmationDriverMetrics::inc_importer_event(
                "end_of_sequencing_request",
                "miss",
            );
            return Ok(());
        };

        envelope.end_of_sequencing = Some(true);
        let envelope = Arc::new(envelope);
        self.state.insert_recent(envelope.clone()).await;
        self.publish_unsafe_response(envelope).await;
        WhitelistPreconfirmationDriverMetrics::inc_importer_event(
            "end_of_sequencing_request",
            "served",
        );
        Ok(())
    }

    /// Refresh whether sync is ready.
    ///
    /// Ready when the confirmed head-origin pointer is written, or — at genesis only —
    /// when no real proposal exists yet (`nextProposalId == 1`). Core state is read lazily,
    /// only while the origin pointer is absent. During beacon-sync custom-table gaps
    /// (`nextProposalId > 1`, origin unwritten) this stays fail-closed (WLP-INV-002).
    pub(super) async fn refresh_sync_ready(&mut self) -> Result<()> {
        let head_written = self.head_l1_origin_block_id().await?.is_some();
        let next_proposal_id =
            if head_written { None } else { Some(self.next_proposal_id().await?) };
        let ready = should_enable_preconf_imports(head_written, next_proposal_id);
        if sync_ready_transition(self.sync_ready, ready) {
            info!("event sync ready; enabling whitelist preconfirmation imports");
        }
        self.sync_ready = ready;
        Ok(())
    }

    /// Get the block ID of the head L1 origin.
    pub(super) async fn head_l1_origin_block_id(&self) -> Result<Option<u64>> {
        Ok(self.rpc.head_l1_origin().await?.map(|head| head.block_id.to::<u64>()))
    }

    /// Read `nextProposalId` from inbox core state.
    pub(super) async fn next_proposal_id(&self) -> Result<u64> {
        let core_state = self
            .rpc
            .shasta
            .inbox
            .getCoreState()
            .call()
            .await
            .map_err(WhitelistPreconfirmationDriverError::provider)?;
        Ok(core_state.nextProposalId.to::<u64>())
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

    /// Update the pending-cache gauge after pending-cache mutations.
    pub(super) fn update_pending_cache_gauge(&self) {
        WhitelistPreconfirmationDriverMetrics::set_cache_pending_count(self.cache.len());
    }
}

/// Returns true only when sync readiness transitions from disabled to enabled.
fn sync_ready_transition(was_ready: bool, is_ready: bool) -> bool {
    !was_ready && is_ready
}

/// Whether preconf imports may be enabled after event sync.
///
/// Ready when the confirmed head-origin pointer is written, or when no real proposal exists
/// yet (`nextProposalId == 1`, the from-genesis cold-start window). The genesis case is the
/// only safe place to admit blocks without an origin: there is no event-confirmed proposal
/// range to violate. When proposals exist but the origin is unwritten (beacon-sync
/// custom-table gap), this stays fail-closed.
fn should_enable_preconf_imports(
    head_l1_origin_written: bool,
    next_proposal_id: Option<u64>,
) -> bool {
    head_l1_origin_written || next_proposal_id == Some(1)
}

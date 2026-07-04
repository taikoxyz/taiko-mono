//! Whitelist preconfirmation envelope importer.

use std::sync::Arc;

use alloy_primitives::{Address, B256};
use alloy_provider::Provider;
use driver::sync::event::EventSyncer;
use rpc::{
    beacon::BeaconClient,
    client::{Client, DefaultProvider},
};
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
/// Ingress entrypoints for unsafe payload handling and request/response serving.
mod ingress;
/// Payload-level validation helpers.
mod validation;

#[cfg(test)]
mod tests;

pub(crate) use validation::validate_execution_payload_for_preconf;
/// Dependency bundle for constructing [`WhitelistPreconfirmationImporter`].
pub(crate) struct WhitelistPreconfirmationImporterParams {
    /// Event syncer used to submit validated preconfirmation payloads.
    pub(crate) event_syncer: Arc<EventSyncer<DefaultProvider>>,
    /// RPC client used for L1/L2 reads and head-origin updates.
    pub(crate) rpc: Client<DefaultProvider>,
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
pub(crate) struct WhitelistPreconfirmationImporter {
    /// Event syncer used to submit validated preconfirmation payloads.
    event_syncer: Arc<EventSyncer<DefaultProvider>>,
    /// RPC client used for L1/L2 reads and head-origin updates.
    rpc: Client<DefaultProvider>,
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
    /// Latched once the head L1 origin row has been observed. The row is never deleted,
    /// so readiness derived from it is permanent and needs no further RPC re-checks.
    head_origin_written: bool,
    /// Shasta anchor contract address used to validate the first transaction.
    anchor_address: Address,
}

impl WhitelistPreconfirmationImporter {
    /// Build an importer.
    pub(crate) fn new(params: WhitelistPreconfirmationImporterParams) -> Self {
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
            head_origin_written: false,
            anchor_address,
        };
        importer.update_pending_cache_gauge();
        importer
    }

    /// Record an importer event outcome metric based on a handler result.
    ///
    /// Increments `event_type` with `ok_label` on success or `fail_label` on error.
    fn record_event_result(
        event_type: &str,
        result: &Result<()>,
        ok_label: &str,
        fail_label: &str,
    ) {
        let label = if result.is_ok() { ok_label } else { fail_label };
        WhitelistPreconfirmationDriverMetrics::inc_importer_event(event_type, label);
    }

    /// Handle one network event.
    pub(crate) async fn handle_event(&mut self, event: NetworkEvent) -> Result<()> {
        match event {
            NetworkEvent::UnsafePayload { from, payload } => {
                let result = self.handle_unsafe_payload(payload).await;
                if let Err(err) = &result {
                    warn!(peer = %from, error = %err, "dropping invalid whitelist preconfirmation payload");
                }
                Self::record_event_result("unsafe_payload", &result, "accepted", "dropped");
            }
            NetworkEvent::UnsafeResponse { from, envelope } => {
                let result = self.handle_unsafe_response(envelope).await;
                if let Err(err) = &result {
                    warn!(peer = %from, error = %err, "dropping invalid whitelist preconfirmation response");
                }
                Self::record_event_result("unsafe_response", &result, "accepted", "dropped");
            }
            NetworkEvent::UnsafeRequest { from, hash } => {
                let result = self.handle_unsafe_request(hash).await;
                if let Err(err) = &result {
                    warn!(
                        peer = %from,
                        hash = %hash,
                        error = %err,
                        "failed to handle whitelist preconfirmation request"
                    );
                }
                Self::record_event_result("unsafe_request", &result, "handled", "error");
            }
            NetworkEvent::EndOfSequencingRequest { from, epoch } => {
                // Asymmetric: the success metric is recorded inside `handle_eos_request`,
                // so only the error case is counted here.
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

    /// Handle an incoming end-of-sequencing request by serving the recorded
    /// envelope for the epoch from the recent cache or an L2 rebuild.
    async fn handle_eos_request(&mut self, epoch: u64) -> Result<()> {
        let served = match self.state.end_of_sequencing_for_epoch(epoch).await {
            Some(hash) => self.serve_envelope_by_hash(hash, true).await?.is_some(),
            None => false,
        };
        WhitelistPreconfirmationDriverMetrics::inc_importer_event(
            "end_of_sequencing_request",
            if served { "served" } else { "miss" },
        );
        Ok(())
    }

    /// Refresh whether sync is ready.
    ///
    /// Ready when the confirmed head-origin pointer is written, or — at genesis only —
    /// when no real proposal exists yet (`nextProposalId == 1`). Core state is read lazily,
    /// only while the origin pointer is absent. During beacon-sync custom-table gaps
    /// (`nextProposalId > 1`, origin unwritten) this stays fail-closed (WLP-INV-002).
    ///
    /// Once the origin pointer has been observed the gate is latched open without further
    /// RPCs: the row is never deleted, so recomputing it cannot change the outcome. Only
    /// the genesis window keeps re-checking on every call.
    pub(super) async fn refresh_sync_ready(&mut self) -> Result<()> {
        if self.head_origin_written {
            return Ok(());
        }

        let head_written = self.head_l1_origin_block_id().await?.is_some();
        self.head_origin_written = head_written;
        let next_proposal_id =
            if head_written { None } else { Some(self.next_proposal_id().await?) };
        let ready = should_enable_preconf_imports(head_written, next_proposal_id);
        if !self.sync_ready && ready {
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

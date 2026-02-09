//! Whitelist preconfirmation envelope importer.

use std::sync::Arc;

use alloy_eips::BlockNumberOrTag;
use alloy_primitives::{Address, B256};
use alloy_provider::Provider;
use bindings::preconf_whitelist::PreconfWhitelist::PreconfWhitelistInstance;
use driver::sync::event::EventSyncer;
use rpc::client::Client;
use tokio::sync::mpsc;
use tracing::{debug, info, warn};

use crate::{
    cache::{EnvelopeCache, RecentEnvelopeCache, RequestThrottle, WhitelistSequencerCache},
    error::{Result, WhitelistPreconfirmationDriverError},
    network::{NetworkCommand, NetworkEvent},
};

mod cache_import;
mod ingress;
mod payload;
mod response;
mod signer;
mod validation;

#[cfg(test)]
mod tests;

/// Maximum compressed tx-list size accepted from a preconfirmation payload.
pub(super) const MAX_COMPRESSED_TX_LIST_BYTES: usize = 131_072 * 6;
/// Maximum decompressed tx-list size accepted from a preconfirmation payload.
///
/// Align with the preconfirmation tx-list cap to avoid zlib bomb expansion on untrusted payloads.
pub(super) const MAX_DECOMPRESSED_TX_LIST_BYTES: usize = 8 * 1024 * 1024;

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
    pub(crate) fn new(
        event_syncer: Arc<EventSyncer<P>>,
        rpc: Client<P>,
        whitelist_address: Address,
        chain_id: u64,
        network_command_tx: mpsc::Sender<NetworkCommand>,
    ) -> Self {
        let whitelist = PreconfWhitelistInstance::new(whitelist_address, rpc.l1_provider.clone());
        let anchor_address = *rpc.shasta.anchor.address();

        Self {
            event_syncer,
            rpc,
            whitelist,
            chain_id,
            cache: EnvelopeCache::default(),
            recent_cache: RecentEnvelopeCache::default(),
            request_throttle: RequestThrottle::default(),
            sequencer_cache: WhitelistSequencerCache::default(),
            network_command_tx,
            sync_ready: false,
            anchor_address,
        }
    }

    /// Handle one network event.
    pub(crate) async fn handle_event(&mut self, event: NetworkEvent) -> Result<()> {
        match event {
            NetworkEvent::UnsafePayload { from, payload } => {
                if let Err(err) = self.handle_unsafe_payload(payload).await {
                    warn!(peer = %from, error = %err, "dropping invalid whitelist preconfirmation payload");
                }
            }
            NetworkEvent::UnsafeResponse { from, envelope } => {
                if let Err(err) = self.handle_unsafe_response(envelope).await {
                    warn!(peer = %from, error = %err, "dropping invalid whitelist preconfirmation response");
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
                }
            }
            NetworkEvent::EndOfSequencingRequest { from, epoch } => {
                if let Some(envelope) = self.recent_cache.latest_end_of_sequencing() {
                    debug!(
                        peer = %from,
                        epoch,
                        hash = %envelope.execution_payload.block_hash,
                        "serving end-of-sequencing whitelist preconfirmation response from recent cache"
                    );
                    self.publish_unsafe_response(envelope).await;
                } else {
                    debug!(peer = %from, epoch, "no recent end-of-sequencing envelope to serve");
                }
            }
        }

        self.maybe_import_from_cache().await
    }

    /// Event-sync progress signal.
    ///
    /// Any L1 progress can include an epoch boundary, so drop cached whitelist sequencers here to
    /// avoid accepting a rotated-out signer until the TTL elapses.
    pub(crate) async fn on_sync_ready_signal(&mut self) -> Result<()> {
        self.sequencer_cache.invalidate();

        if !self.refresh_sync_ready().await? || self.cache.is_empty() {
            return Ok(());
        }

        self.import_from_cache().await
    }

    /// Refresh whether sync is ready.
    pub(super) async fn refresh_sync_ready(&mut self) -> Result<bool> {
        let ready = self.head_l1_origin_block_id().await?.is_some();
        let became_ready = sync_ready_transition(self.sync_ready, ready);
        if became_ready {
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
            .get_block_by_number(BlockNumberOrTag::Number(block_number))
            .await
            .map(|opt| opt.map(|block| block.hash()))
            .map_err(provider_err)
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

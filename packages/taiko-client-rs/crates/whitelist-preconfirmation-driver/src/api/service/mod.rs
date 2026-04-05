//! Whitelist preconfirmation API service implementation.

use std::sync::Arc;

use alethia_reth_primitives::payload::{
    attributes::{RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes},
    builder::payload_id_taiko,
};
use alloy_eips::BlockNumberOrTag;
use alloy_primitives::{Address, B256, Bloom, FixedBytes, U256};
use alloy_provider::Provider;
use alloy_rpc_types::SyncStatus;
use alloy_rpc_types_engine::{ExecutionPayloadV1, PayloadAttributes as EthPayloadAttributes};
use async_trait::async_trait;
use driver::{PreconfPayload, sync::event::EventSyncer};
use protocol::{
    shasta::{PAYLOAD_ID_VERSION_V2, calculate_shasta_difficulty, payload_id_to_bytes},
    signer::FixedKSigner,
};
use rpc::{beacon::BeaconClient, client::Client};
use tokio::sync::{Mutex, broadcast, mpsc};
use tracing::warn;

use crate::{
    api::{
        WhitelistApi,
        types::{
            BuildPreconfBlockRequest, BuildPreconfBlockResponse, EndOfSequencingNotification,
            WhitelistStatus,
        },
    },
    core::{
        authority::WhitelistSignerAuthority,
        build::{PreconfBuildRuntime, PreconfBuildService},
        state::SharedDriverState,
    },
    error::{Result, WhitelistPreconfirmationDriverError},
    importer::validate_execution_payload_for_preconf,
    network::NetworkCommand,
};

mod api_impl;
mod lookahead;
mod payload_build;
mod status;

#[cfg(test)]
mod tests;

/// Maximum number of pending EOS notifications retained for `/ws` subscribers.
const EOS_NOTIFICATION_CHANNEL_CAPACITY: usize = 128;

/// Implements whitelist preconfirmation API business logic.
pub(crate) struct WhitelistApiService<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Event syncer for L1 origin lookups.
    event_syncer: Arc<EventSyncer<P>>,
    /// RPC client for L1/L2 reads.
    rpc: Client<P>,
    /// Beacon client used to derive current epoch values for EOS requests.
    beacon_client: Arc<BeaconClient>,
    /// Shared build-path orchestration extracted out of the API facade.
    build_service: PreconfBuildService<P>,
    /// Serializes build requests to avoid concurrent insertion/signing races.
    build_preconf_lock: Mutex<()>,
    /// Local peer ID string.
    local_peer_id: String,
    /// Shared runtime state used by build/status flows.
    shared_state: SharedDriverState,
    /// Broadcast channel for API `/ws` end-of-sequencing notifications.
    eos_notification_tx: broadcast::Sender<EndOfSequencingNotification>,
}

/// API-specific runtime adapter that supplies the shared build service dependencies.
pub(super) struct ApiBuildRuntime<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Event syncer used to submit preconfirmation payloads for local insertion.
    event_syncer: Arc<EventSyncer<P>>,
    /// RPC client for L1/L2 reads and signature persistence.
    rpc: Client<P>,
    /// Chain ID for signature domain separation.
    chain_id: u64,
    /// Deterministic signer for block signing.
    signer: FixedKSigner,
    /// Beacon client used to derive current epoch values for EOS requests.
    beacon_client: Arc<BeaconClient>,
    /// Channel to publish messages to the P2P network.
    network_command_tx: mpsc::Sender<NetworkCommand>,
    /// Shared authority used for signer and fee-recipient validation.
    authority: Arc<WhitelistSignerAuthority<P>>,
    /// Shared runtime state used by build/status flows.
    shared_state: SharedDriverState,
    /// Broadcast channel for API `/ws` end-of-sequencing notifications.
    eos_notification_tx: broadcast::Sender<EndOfSequencingNotification>,
}

/// Dependency bundle for constructing `WhitelistApiService`.
pub(crate) struct WhitelistApiServiceParams<P>
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
    /// Shared authority for signer and fee-recipient validation.
    pub(crate) authority: Arc<WhitelistSignerAuthority<P>>,
    /// Network command sender for gossip publishing.
    pub(crate) network_command_tx: mpsc::Sender<NetworkCommand>,
    /// Shared runtime state used by build/status flows.
    pub(crate) shared_state: SharedDriverState,
    /// Local peer ID string.
    pub(crate) local_peer_id: String,
}

impl<P> WhitelistApiService<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Create a new API service instance.
    pub(crate) fn new(
        WhitelistApiServiceParams {
            event_syncer,
            rpc,
            chain_id,
            signer,
            beacon_client,
            authority,
            network_command_tx,
            shared_state,
            local_peer_id,
        }: WhitelistApiServiceParams<P>,
    ) -> Self {
        let (eos_notification_tx, _) = broadcast::channel(EOS_NOTIFICATION_CHANNEL_CAPACITY);
        let build_service = PreconfBuildService::new(Arc::new(ApiBuildRuntime {
            event_syncer: Arc::clone(&event_syncer),
            rpc: rpc.clone(),
            chain_id,
            signer,
            beacon_client: Arc::clone(&beacon_client),
            network_command_tx,
            authority,
            shared_state: shared_state.clone(),
            eos_notification_tx: eos_notification_tx.clone(),
        }));
        Self {
            event_syncer,
            rpc,
            beacon_client,
            build_service,
            local_peer_id,
            shared_state,
            eos_notification_tx,
            build_preconf_lock: Mutex::new(()),
        }
    }
}

//! Whitelist preconfirmation API service implementation.

use std::{
    sync::Arc,
    time::{Duration, Instant},
};

use alethia_reth_primitives::payload::{
    attributes::{RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes},
    builder::payload_id_taiko,
};
use alloy_eips::BlockNumberOrTag;
use alloy_primitives::{B256, Bloom, FixedBytes, U256};
use alloy_provider::Provider;
use alloy_rpc_types::SyncStatus;
use alloy_rpc_types_engine::ExecutionPayloadV1;
use alloy_rpc_types_engine_2::PayloadAttributes as EthPayloadAttributes;
use async_trait::async_trait;
use driver::{PreconfPayload, sync::event::EventSyncer};
use metrics::histogram;
use protocol::{
    shasta::{PAYLOAD_ID_VERSION_V2, calculate_shasta_mix_hash, payload_id_to_bytes},
    signer::FixedKSigner,
};
use rpc::{beacon::BeaconClient, client::Client};
use tokio::sync::{Mutex, broadcast, mpsc};
use tracing::{debug, warn};

use crate::{
    api::{
        WhitelistApi,
        types::{
            BuildPreconfBlockRequest, BuildPreconfBlockResponse, EndOfSequencingNotification,
            WhitelistStatus,
        },
    },
    cache::SharedPreconfCacheState,
    codec::{WhitelistExecutionPayloadEnvelope, block_signing_hash, encode_envelope_ssz},
    error::{Result, WhitelistPreconfirmationDriverError},
    importer::validate_execution_payload_for_preconf,
    network::NetworkCommand,
    operator_set::SharedOperatorSet,
};

mod handlers;
mod payload_build;
mod status;

#[cfg(test)]
mod tests;

/// Maximum number of pending EOS notifications retained for `/ws` subscribers.
const EOS_NOTIFICATION_CHANNEL_CAPACITY: usize = 128;

/// Number of L1 slots in the preconfer hand-over window. Doubled relative to
/// the Go client's default `handover_slots = 4` because the Rust whitelist
/// driver lacks lookahead-aware logic and must rely on a coarser time-based
/// heuristic. See PR #21648 for the Go counterpart.
const HAND_OVER_WINDOW_SLOTS: u64 = 8;

/// L1 slot duration in seconds (Ethereum mainnet).
const SECONDS_PER_SLOT: u64 = 12;

/// Duration during which a recently received `build_preconf_block` request
/// blocks pod shutdown. Computed as `1.5 × HAND_OVER_WINDOW_SLOTS ×
/// SECONDS_PER_SLOT`, expressed as integer math (`× 3 / 2`) so the result is
/// `const`-evaluable. Equals 144 s.
const SHUTDOWN_BLOCK_WINDOW: Duration =
    Duration::from_secs(HAND_OVER_WINDOW_SLOTS * SECONDS_PER_SLOT * 3 / 2);

/// Pure helper deciding whether the pod is safe to shut down given the time
/// of the most recent `build_preconf_block` invocation. Returns `true` when
/// no invocation has been recorded or when the elapsed time meets or exceeds
/// `SHUTDOWN_BLOCK_WINDOW`.
fn can_shutdown_for(last_preconf_request: Option<Instant>) -> bool {
    match last_preconf_request {
        None => true,
        Some(at) => at.elapsed() >= SHUTDOWN_BLOCK_WINDOW,
    }
}

/// Implements whitelist preconfirmation API business logic.
pub(crate) struct WhitelistApiService<P>
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
    /// Lock-free shared set of whitelisted sequencer addresses; used to refuse
    /// build requests when this node's own P2P signer has been deregistered on-chain.
    operator_set: SharedOperatorSet,
    /// Local peer ID string.
    local_peer_id: String,
    /// Highest unsafe payload block ID tracked by this node (shared with importer).
    highest_unsafe_l2_payload_block_id: Arc<Mutex<u64>>,
    /// Shared cache state used to back `/status` and EOS visibility.
    cache_state: SharedPreconfCacheState,
    /// Broadcast channel for API `/ws` end-of-sequencing notifications.
    eos_notification_tx: broadcast::Sender<EndOfSequencingNotification>,
    /// Wall-clock instant of the most recent `build_preconf_block` invocation,
    /// regardless of the request's outcome. `None` until the first request
    /// arrives. Read by `/status` to compute `can_shutdown`.
    last_preconf_request_at: Mutex<Option<Instant>>,
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
    /// Shared operator set used to gate the build API on the node's own whitelist status.
    pub(crate) operator_set: SharedOperatorSet,
    /// Shared highest unsafe payload block ID (also updated by importer on P2P import).
    pub(crate) highest_unsafe_l2_payload_block_id: Arc<Mutex<u64>>,
    /// Network command sender for gossip publishing.
    pub(crate) network_command_tx: mpsc::Sender<NetworkCommand>,
    /// Shared preconfirmation cache state.
    pub(crate) cache_state: SharedPreconfCacheState,
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
            operator_set,
            highest_unsafe_l2_payload_block_id,
            network_command_tx,
            cache_state,
            local_peer_id,
        }: WhitelistApiServiceParams<P>,
    ) -> Self {
        let (eos_notification_tx, _) = broadcast::channel(EOS_NOTIFICATION_CHANNEL_CAPACITY);
        Self {
            event_syncer,
            rpc,
            chain_id,
            signer,
            beacon_client,
            operator_set,
            local_peer_id,
            highest_unsafe_l2_payload_block_id,
            cache_state,
            eos_notification_tx,
            network_command_tx,
            build_preconf_lock: Mutex::new(()),
            last_preconf_request_at: Mutex::new(None),
        }
    }

    /// Record that a `build_preconf_block` request has been received.
    /// Called at the top of the request handler so that even rejected
    /// requests count toward shutdown-safety.
    pub(super) async fn mark_preconf_request_received(&self) {
        *self.last_preconf_request_at.lock().await = Some(Instant::now());
    }

    /// Returns `true` when no `build_preconf_block` request has been received
    /// within the last `SHUTDOWN_BLOCK_WINDOW`.
    pub(super) async fn compute_can_shutdown(&self) -> bool {
        can_shutdown_for(*self.last_preconf_request_at.lock().await)
    }
}

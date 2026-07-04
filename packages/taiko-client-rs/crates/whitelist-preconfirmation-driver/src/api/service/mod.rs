//! Whitelist preconfirmation API service implementation.

use std::{
    sync::Arc,
    time::{Duration, Instant},
};

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_eips::BlockNumberOrTag;
use alloy_primitives::{B256, Bloom, FixedBytes, U256};
use alloy_provider::Provider;
use alloy_rpc_types::SyncStatus;
use alloy_rpc_types_engine::ExecutionPayloadV1;
use async_trait::async_trait;
use driver::{PreconfPayload, sync::event::EventSyncer};
use protocol::{shasta::calculate_shasta_mix_hash, signer::FixedKSigner};
use rpc::{
    beacon::BeaconClient,
    client::{Client, DefaultProvider},
};
use tokio::sync::{Mutex, broadcast, mpsc};
use tracing::{debug, warn};

use crate::{
    api::{
        WhitelistApi,
        types::{
            ApiStatus, BuildPreconfBlockRequest, BuildPreconfBlockResponse,
            EndOfSequencingNotification, ExecutableData,
        },
    },
    cache::SharedPreconfState,
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

/// Report `head` whenever it is known; fall back to `tracked` when it is `None`.
///
/// The tracked value only moves on preconfirmation imports and local builds, so it can
/// drift from the head in both directions: an L1 reorg rewinds the head below the
/// counter, while canonical L1 derivation with no gossip traffic advances the head past
/// it. Every canonical block was inserted by this driver, so the head is always an
/// honest answer — and the Catalyst sidecar's sync gate requires the reported value to
/// equal the execution head exactly before it starts (or resumes) preconfirming. A
/// permanently lagging report would wedge the operator in a restart loop that only a
/// driver restart clears.
fn reconcile_highest_unsafe(tracked: u64, head: Option<u64>) -> u64 {
    head.unwrap_or(tracked)
}

/// Implements whitelist preconfirmation API business logic.
pub(crate) struct WhitelistApiService {
    /// Event syncer for L1 origin lookups.
    event_syncer: Arc<EventSyncer<DefaultProvider>>,
    /// RPC client for L1/L2 reads.
    rpc: Client<DefaultProvider>,
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
    /// Shared driver state (recent envelopes, EOS markers, highest unsafe block id).
    state: SharedPreconfState,
    /// Broadcast channel for API `/ws` end-of-sequencing notifications.
    eos_notification_tx: broadcast::Sender<EndOfSequencingNotification>,
    /// Wall-clock instant of the most recent `build_preconf_block` invocation,
    /// regardless of the request's outcome. `None` until the first request
    /// arrives. Read by `/status` to compute `can_shutdown`.
    last_preconf_request_at: Mutex<Option<Instant>>,
}

/// Dependency bundle for constructing `WhitelistApiService`.
pub(crate) struct WhitelistApiServiceParams {
    /// Shared event syncer used to read the current L1 origin.
    pub(crate) event_syncer: Arc<EventSyncer<DefaultProvider>>,
    /// L1/L2 RPC client.
    pub(crate) rpc: Client<DefaultProvider>,
    /// Chain ID used for signing and payload hashing.
    pub(crate) chain_id: u64,
    /// Signer used for block signing operations.
    pub(crate) signer: FixedKSigner,
    /// Beacon client used for epoch calculations.
    pub(crate) beacon_client: Arc<BeaconClient>,
    /// Shared operator set used to gate the build API on the node's own whitelist status.
    pub(crate) operator_set: SharedOperatorSet,
    /// Shared driver state (recent envelopes, EOS markers, highest unsafe block id).
    pub(crate) state: SharedPreconfState,
    /// Network command sender for gossip publishing.
    pub(crate) network_command_tx: mpsc::Sender<NetworkCommand>,
}

impl WhitelistApiService {
    /// Create a new API service instance.
    pub(crate) fn new(
        WhitelistApiServiceParams {
            event_syncer,
            rpc,
            chain_id,
            signer,
            beacon_client,
            operator_set,
            state,
            network_command_tx,
        }: WhitelistApiServiceParams,
    ) -> Self {
        let (eos_notification_tx, _) = broadcast::channel(EOS_NOTIFICATION_CHANNEL_CAPACITY);
        Self {
            event_syncer,
            rpc,
            chain_id,
            signer,
            beacon_client,
            operator_set,
            state,
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

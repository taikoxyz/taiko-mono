//! Whitelist preconfirmation API service implementation.

use std::{
    fmt::Display,
    future::Future,
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
use driver::{
    PreconfPayload, PreconfSubmissionOutcome,
    sync::event::{CanonicalPreconfSubmission, EventSyncer},
};
use protocol::{shasta::calculate_shasta_mix_hash, signer::FixedKSigner};
use rpc::{beacon::BeaconClient, client::Client};
use tokio::{
    sync::{Mutex, broadcast, mpsc, oneshot},
    time::sleep,
};
use tracing::{debug, error, warn};

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

/// Implements whitelist preconfirmation API business logic.
#[derive(Clone)]
pub(crate) struct WhitelistApiService {
    /// Event syncer for L1 origin lookups.
    event_syncer: Arc<EventSyncer>,
    /// RPC client for L1/L2 reads.
    rpc: Client,
    /// Chain ID for signature domain separation.
    chain_id: u64,
    /// Deterministic signer for block signing.
    signer: FixedKSigner,
    /// Beacon client used to derive current epoch values for EOS requests.
    beacon_client: Arc<BeaconClient>,
    /// Channel to publish messages to the P2P network.
    network_command_tx: mpsc::Sender<NetworkCommand>,
    /// Notifies the runner when an inserted block cannot be finalized safely.
    fatal_build_tx: mpsc::UnboundedSender<String>,
    /// Serializes build requests to avoid concurrent insertion/signing races.
    build_preconf_lock: Arc<Mutex<()>>,
    /// Lock-free shared set of whitelisted sequencer addresses; used to refuse
    /// build requests when this node's own P2P signer has been deregistered on-chain.
    operator_set: SharedOperatorSet,
    /// Shared driver state (recent envelopes, EOS markers, last reported L2 head).
    state: SharedPreconfState,
    /// Broadcast channel for API `/ws` end-of-sequencing notifications.
    eos_notification_tx: broadcast::Sender<EndOfSequencingNotification>,
    /// Wall-clock instant of the most recent `build_preconf_block` invocation,
    /// regardless of the request's outcome. `None` until the first request
    /// arrives. Read by `/status` to compute `can_shutdown`.
    last_preconf_request_at: Arc<Mutex<Option<Instant>>>,
}

/// Dependency bundle for constructing `WhitelistApiService`.
pub(crate) struct WhitelistApiServiceParams {
    /// Shared event syncer used to read the current L1 origin.
    pub(crate) event_syncer: Arc<EventSyncer>,
    /// L1/L2 RPC client.
    pub(crate) rpc: Client,
    /// Chain ID used for signing and payload hashing.
    pub(crate) chain_id: u64,
    /// Signer used for block signing operations.
    pub(crate) signer: FixedKSigner,
    /// Beacon client used for epoch calculations.
    pub(crate) beacon_client: Arc<BeaconClient>,
    /// Shared operator set used to gate the build API on the node's own whitelist status.
    pub(crate) operator_set: SharedOperatorSet,
    /// Shared driver state (recent envelopes, EOS markers, last reported L2 head).
    pub(crate) state: SharedPreconfState,
    /// Network command sender for gossip publishing.
    pub(crate) network_command_tx: mpsc::Sender<NetworkCommand>,
    /// Runner notification channel for fail-closed local build failures.
    pub(crate) fatal_build_tx: mpsc::UnboundedSender<String>,
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
            fatal_build_tx,
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
            fatal_build_tx,
            build_preconf_lock: Arc::new(Mutex::new(())),
            last_preconf_request_at: Arc::new(Mutex::new(None)),
        }
    }

    /// Record that a `build_preconf_block` request has been received.
    /// Called at the top of the request handler so that even rejected
    /// requests count toward shutdown-safety.
    pub(super) async fn mark_preconf_request_received(&self) {
        *self.last_preconf_request_at.lock().await = Some(Instant::now());
    }

    /// Returns `true` when no `build_preconf_block` request has been received
    /// within the last `SHUTDOWN_BLOCK_WINDOW` and no serialized build is active.
    pub(super) async fn compute_can_shutdown(&self) -> bool {
        can_shutdown_for(*self.last_preconf_request_at.lock().await) &&
            self.build_preconf_lock.try_lock().is_ok()
    }

    /// Wait until every serialized local build accepted before shutdown has finished.
    pub(crate) async fn wait_for_active_build(&self) {
        wait_for_serialized_build(Arc::clone(&self.build_preconf_lock)).await;
    }

    /// Ask the runner to restart after halting production on an unsafe finalization failure.
    fn report_fatal_build_failure(&self, reason: String) {
        if self.fatal_build_tx.send(reason.clone()).is_err() {
            error!(%reason, "failed to notify runner about fatal local build failure");
        }
    }
}

/// Run a local build workflow in a service-owned task that survives requester cancellation.
///
/// The detached task owns the entire build, signature persistence, cache, and gossip sequence.
/// Dropping the caller only closes the response channel; it cannot leave an engine-inserted block
/// without the metadata and envelope needed for peer recovery.
async fn run_drop_resistant_build<T>(
    build: impl Future<Output = Result<T>> + Send + 'static,
) -> Result<T>
where
    T: Send + 'static,
{
    let (result_tx, result_rx) = oneshot::channel();
    tokio::spawn(async move {
        let result = build.await;
        if let Err(orphaned_result) = result_tx.send(result) {
            match orphaned_result {
                Ok(_) => debug!("local preconfirmation build completed after requester dropped"),
                Err(err) => error!(
                    error = %err,
                    "local preconfirmation build failed after requester dropped"
                ),
            }
        }
    });

    result_rx.await.map_err(|_| {
        WhitelistPreconfirmationDriverError::NodeTaskFailed(
            "local preconfirmation build task exited without a result".to_string(),
        )
    })?
}

/// Wait for the shared build lock while caller cancellation is still allowed, then detach.
///
/// A requester dropped while waiting for the lock never creates a background build. Once the
/// owned guard is acquired, the complete workflow becomes drop-resistant and retains the guard
/// until it reaches a terminal result.
async fn run_serialized_drop_resistant_build<T, F, Fut>(
    build_lock: Arc<Mutex<()>>,
    build: F,
) -> Result<T>
where
    T: Send + 'static,
    F: FnOnce() -> Fut + Send + 'static,
    Fut: Future<Output = Result<T>> + Send + 'static,
{
    let build_guard = build_lock.lock_owned().await;
    run_drop_resistant_build(async move {
        let result = build().await;
        drop(build_guard);
        result
    })
    .await
}

/// Join the serialized build lane without cancelling a detached in-flight finalization task.
async fn wait_for_serialized_build(build_lock: Arc<Mutex<()>>) {
    drop(build_lock.lock_owned().await);
}

/// Retry one post-insertion finalization step for a bounded recovery window.
///
/// Once the engine has accepted a block, returning a transient error would strand a canonical
/// block without the signature/cache state peers need to recover it. Retrying under the serialized
/// build guard fails closed: no same-height retry can race the unfinished finalization.
async fn retry_post_insert_step<T, E, F, Fut>(
    block_number: u64,
    step: &'static str,
    operation: F,
) -> std::result::Result<T, E>
where
    E: Display,
    F: FnMut() -> Fut,
    Fut: Future<Output = std::result::Result<T, E>>,
{
    retry_post_insert_step_with_backoff(
        block_number,
        step,
        Duration::from_secs(1),
        Duration::from_secs(30),
        6,
        operation,
    )
    .await
}

/// Retry a post-insertion step using caller-provided exponential-backoff bounds.
async fn retry_post_insert_step_with_backoff<T, E, F, Fut>(
    block_number: u64,
    step: &'static str,
    initial_retry_delay: Duration,
    max_retry_delay: Duration,
    max_attempts: usize,
    mut operation: F,
) -> std::result::Result<T, E>
where
    E: Display,
    F: FnMut() -> Fut,
    Fut: Future<Output = std::result::Result<T, E>>,
{
    let mut retry_delay = initial_retry_delay;
    assert!(max_attempts > 0, "post-insert retry requires at least one attempt");
    for attempt in 1..=max_attempts {
        match operation().await {
            Ok(value) => return Ok(value),
            Err(err) => {
                if attempt == max_attempts {
                    error!(
                        block_number,
                        step,
                        error = %err,
                        attempt,
                        "post-insertion preconfirmation finalization exhausted retries"
                    );
                    return Err(err)
                }
                error!(
                    block_number,
                    step,
                    error = %err,
                    attempt,
                    retry_delay_ms = retry_delay.as_millis() as u64,
                    "post-insertion preconfirmation finalization failed; retrying"
                );
                sleep(retry_delay).await;
                retry_delay = retry_delay.saturating_mul(2).min(max_retry_delay);
            }
        }
    }
    unreachable!("positive retry attempt count must return from loop")
}

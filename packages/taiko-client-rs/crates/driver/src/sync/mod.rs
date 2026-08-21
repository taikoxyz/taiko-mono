//! Synchronization primitives for the driver.

use std::sync::Arc;

/// Geth error message returned when no finalized block exists yet (e.g. fresh devnets).
pub(crate) const FINALIZED_BLOCK_NOT_FOUND: &str = "finalized block not found";

/// Geth error fragment returned when a node cannot serve state at the requested block.
///
/// Path-scheme geth keeps only ~128 recent blocks of live state and answers older state reads
/// with "historical state <root> is not available" unless state-history indexing
/// (`--gcmode archive`) is enabled, so finalized-block reads hit this whenever L1 finality
/// lags beyond that window.
pub(crate) const HISTORICAL_STATE_UNAVAILABLE: &str = "historical state";

/// Hash-scheme geth error fragment for state pruned below the recent-trie window.
pub(crate) const MISSING_TRIE_NODE: &str = "missing trie node";

/// Whether an RPC error message indicates the endpoint cannot serve state at the requested
/// block (a non-archive node asked below its retained-state window), rather than a transport
/// or endpoint failure.
pub(crate) fn is_historical_state_unavailable(message: &str) -> bool {
    message.contains(HISTORICAL_STATE_UNAVAILABLE) || message.contains(MISSING_TRIE_NODE)
}

use async_trait::async_trait;
use rpc::client::Client;
use tracing::{info, instrument};

use crate::{
    config::DriverConfig,
    error::DriverError,
    sync::{
        beacon::BeaconSyncer, checkpoint_resume_head::CheckpointResumeHead, event::EventSyncer,
    },
};

pub mod beacon;
pub mod checkpoint_resume_head;
pub mod confirmed_sync;
pub mod engine;
pub mod error;
pub mod event;

pub use confirmed_sync::{ConfirmedSyncSnapshot, build_confirmed_sync_snapshot};
pub use error::SyncError;

/// High level trait to represent a driver sync stage.
#[async_trait]
pub trait SyncStage {
    /// Run the stage until completion or failure.
    async fn run(&self) -> Result<(), SyncError>;
}

/// Classify a recurring-poll failure against the fail-closed startup rule.
///
/// Before the polled endpoint has answered successfully once, failures indicate a misconfigured
/// or unreachable endpoint and must fail fast (`Err`). After the first success the same failures
/// are transient (`Ok`), so callers log the returned error and retry on the next attempt.
pub(crate) fn retryable_after_first_success<E>(seen_once: bool, error: E) -> Result<E, E> {
    if seen_once { Ok(error) } else { Err(error) }
}

/// Factory helper assembling both sync stages.
///
/// Runs the beacon syncer first to catch up via checkpoint sync,
/// then hands off to the event syncer for real-time L1 event processing.
pub struct SyncPipeline {
    /// Beacon syncer for checkpoint-based catch-up.
    beacon: BeaconSyncer,
    /// Event syncer for following L1 inbox proposals in real time.
    event: Arc<EventSyncer>,
}

impl SyncPipeline {
    /// Construct a new pipeline from the runtime configuration.
    #[instrument(skip(cfg, rpc), name = "sync_pipeline_new")]
    pub async fn new(cfg: DriverConfig, rpc: Client) -> Result<Self, DriverError> {
        // Shared cross-stage state: beacon sync writes the checkpoint head it caught up to,
        // event sync consumes that head as its resume anchor when checkpoint mode is enabled.
        let checkpoint_resume_head = Arc::new(CheckpointResumeHead::default());
        let beacon = BeaconSyncer::new(&cfg, rpc.clone(), checkpoint_resume_head.clone());
        let event = Arc::new(
            EventSyncer::new_with_checkpoint_resume_head(&cfg, rpc, checkpoint_resume_head).await?,
        );
        Ok(Self { beacon, event })
    }

    /// Access the event syncer instance.
    pub fn event_syncer(&self) -> Arc<EventSyncer> {
        self.event.clone()
    }

    /// Start both syncers in order.
    #[instrument(skip(self), name = "sync_pipeline_run")]
    pub async fn run(self) -> Result<(), DriverError> {
        info!("beginning sync pipeline run");
        self.beacon.run().await?;
        info!("beacon syncer completed");
        self.event.run().await?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::{is_historical_state_unavailable, retryable_after_first_success};

    #[test]
    fn poll_errors_fail_fast_only_before_first_success() {
        assert_eq!(retryable_after_first_success(false, "boom"), Err("boom"));
        assert_eq!(retryable_after_first_success(true, "boom"), Ok("boom"));
    }

    #[test]
    fn historical_state_matcher_covers_both_geth_state_schemes() {
        assert!(is_historical_state_unavailable(
            "server returned an error response: error code -32000: historical state \
             0xdeadbeef is not available"
        ));
        assert!(is_historical_state_unavailable(
            "missing trie node 0xdeadbeef (path 0x01) not found"
        ));
        assert!(!is_historical_state_unavailable("finalized block not found"));
        assert!(!is_historical_state_unavailable("connection refused"));
    }
}

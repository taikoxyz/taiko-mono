//! Synchronization primitives for the driver.

use std::sync::Arc;

use alloy_contract::Error as ContractError;

/// Geth JSON-RPC server error code used for chain-data availability errors.
const GETH_SERVER_ERROR_CODE: i64 = -32000;

/// Geth error message returned when no finalized block exists yet (e.g. fresh devnets).
pub(crate) const FINALIZED_BLOCK_NOT_FOUND: &str = "finalized block not found";

/// Return whether a structured RPC error is geth's explicit pre-first-finality response.
pub(crate) fn is_finalized_block_not_found(code: i64, message: &str) -> bool {
    code == GETH_SERVER_ERROR_CODE && message == FINALIZED_BLOCK_NOT_FOUND
}

/// Extract the structured JSON-RPC code and message from an Alloy contract-call error.
pub(crate) fn contract_rpc_error(error: &ContractError) -> Option<(i64, &str)> {
    let ContractError::TransportError(error) = error else {
        return None;
    };
    error.as_error_resp().map(|payload| (payload.code, payload.message.as_ref()))
}

/// Return whether a structured RPC error is one of geth's known historical-state failures.
///
/// Geth has emitted both a state-path form and a re-execution form across versions. Some RPC
/// deployments also include the requested state root between `historical state` and
/// `is not available`. The root-bearing form is accepted only when the middle token is exactly a
/// 32-byte hexadecimal root so unrelated errors mentioning historical state remain fail-fast.
pub(crate) fn is_historical_state_unavailable(code: i64, message: &str) -> bool {
    if code != GETH_SERVER_ERROR_CODE {
        return false;
    }
    if message == "historical state is not available" {
        return true;
    }

    const REEXEC_PREFIX: &str = "required historical state unavailable (reexec=";
    if let Some(reexec) =
        message.strip_prefix(REEXEC_PREFIX).and_then(|rest| rest.strip_suffix(')'))
    {
        return !reexec.is_empty() && reexec.bytes().all(|byte| byte.is_ascii_digit());
    }

    const ROOT_PREFIX: &str = "historical state ";
    const ROOT_SUFFIX: &str = " is not available";
    let Some(root) = message
        .strip_prefix(ROOT_PREFIX)
        .and_then(|rest| rest.strip_suffix(ROOT_SUFFIX))
        .and_then(|root| root.strip_prefix("0x"))
    else {
        return false;
    };
    root.len() == 64 && root.bytes().all(|byte| byte.is_ascii_hexdigit())
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
    use super::{
        FINALIZED_BLOCK_NOT_FOUND, GETH_SERVER_ERROR_CODE, is_finalized_block_not_found,
        is_historical_state_unavailable, retryable_after_first_success,
    };

    #[test]
    fn poll_errors_fail_fast_only_before_first_success() {
        assert_eq!(retryable_after_first_success(false, "boom"), Err("boom"));
        assert_eq!(retryable_after_first_success(true, "boom"), Ok("boom"));
    }

    #[test]
    fn historical_state_error_matcher_is_allowlist_only() {
        let is_unavailable =
            |message| is_historical_state_unavailable(GETH_SERVER_ERROR_CODE, message);

        assert!(is_unavailable("historical state is not available"));
        assert!(is_unavailable("required historical state unavailable (reexec=128)"));
        assert!(is_unavailable(concat!(
            "historical state 0x",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            " is not available"
        )));
        assert!(!is_historical_state_unavailable(-32603, "historical state is not available"));
        assert!(!is_unavailable("historical state database is not available"));
        assert!(!is_unavailable("historical state 0x1234 is not available"));
        assert!(!is_unavailable("execution reverted: historical state is not available"));
        assert!(!is_unavailable("required historical state unavailable (reexec=abc)"));
        assert!(!is_unavailable("required historical state unavailable (reexec=128) extra"));
        assert!(!is_unavailable("missing trie node"));
    }

    #[test]
    fn finalized_block_not_found_matcher_requires_exact_structured_error() {
        assert!(is_finalized_block_not_found(GETH_SERVER_ERROR_CODE, FINALIZED_BLOCK_NOT_FOUND));
        assert!(!is_finalized_block_not_found(-32603, FINALIZED_BLOCK_NOT_FOUND));
        assert!(!is_finalized_block_not_found(
            GETH_SERVER_ERROR_CODE,
            "proxy: finalized block not found"
        ));
    }
}

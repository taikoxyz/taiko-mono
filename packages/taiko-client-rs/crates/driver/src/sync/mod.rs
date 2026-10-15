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
/// Geth has emitted state-path, re-execution, state-index backfill, and root-bearing forms across
/// versions. `%x` formats the root without `0x`, while some deployments add the prefix. The
/// root-bearing form is accepted only when the middle token is exactly a 32-byte hexadecimal root
/// so unrelated errors mentioning historical state remain fail-fast.
pub(crate) fn is_historical_state_unavailable(code: i64, message: &str) -> bool {
    if code != GETH_SERVER_ERROR_CODE {
        return false;
    }
    if message == "historical state is not available" {
        return true;
    }
    if message == "state histories haven't been fully indexed yet" {
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
    let Some(root) =
        message.strip_prefix(ROOT_PREFIX).and_then(|rest| rest.strip_suffix(ROOT_SUFFIX))
    else {
        return false;
    };
    let root = root.strip_prefix("0x").unwrap_or(root);
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
    ///
    /// Refuses to start when the execution engine lacks the Osaka Engine API or its L2 head
    /// contradicts the client's Etna fork schedule ([`Client::check_execution_engine`]); this
    /// covers both the driver and the whitelist preconfirmation driver.
    #[instrument(skip(cfg, rpc), name = "sync_pipeline_new")]
    pub async fn new(cfg: DriverConfig, rpc: Client) -> Result<Self, DriverError> {
        rpc.check_execution_engine().await?;

        // Shared cross-stage state: beacon sync writes the checkpoint head it caught up to,
        // event sync consumes that head as its resume anchor when checkpoint mode is enabled.
        let checkpoint_resume_head = Arc::new(CheckpointResumeHead::default());
        let beacon = BeaconSyncer::new(&cfg, rpc.clone(), checkpoint_resume_head.clone())?;
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
    use std::{path::PathBuf, time::Duration};

    use alloy::{
        rpc::types::{Block as RpcBlock, Transaction as RpcTransaction},
        transports::http::reqwest::Url,
    };
    use alloy_primitives::{Address, B256, Bytes};
    use alloy_transport::mock::Asserter;
    use protocol::shasta::constants::TAIKO_DEVNET_CHAIN_ID;
    use rpc::{
        RpcClientError, SubscriptionSource, auth::REQUIRED_ENGINE_METHODS, client::ClientConfig,
    };

    use super::{
        FINALIZED_BLOCK_NOT_FOUND, GETH_SERVER_ERROR_CODE, SyncPipeline,
        is_finalized_block_not_found, is_historical_state_unavailable,
        retryable_after_first_success,
    };
    use crate::{
        config::DriverConfig, error::DriverError, test_support::mock_client_with_asserters,
    };

    /// Driver config whose endpoints are never dialled: the startup checks run on the mocked
    /// client handed to [`SyncPipeline::new`].
    fn unused_driver_config() -> DriverConfig {
        let url = Url::parse("http://localhost:8545").expect("valid http url");
        let client = ClientConfig {
            l1_provider_source: SubscriptionSource::Http(url.clone()),
            l2_provider_url: url.clone(),
            l2_auth_provider_url: url.clone(),
            jwt_secret: PathBuf::from("/dev/null"),
            inbox_address: Address::ZERO,
        };
        DriverConfig::new(client, Duration::from_secs(1), url, None, None, false)
    }

    /// Start a devnet sync pipeline (Etna never scheduled) on an engine advertising `methods`
    /// whose L2 `latest` head is `head`, if the capability check lets it be read.
    async fn start_pipeline(methods: &[&str], head: Option<RpcBlock>) -> Option<DriverError> {
        let l2 = Asserter::new();
        if let Some(head) = head {
            l2.push_success(&Some(head));
        }
        let l2_auth = Asserter::new();
        l2_auth.push_success(&methods);
        let mut client = mock_client_with_asserters(Asserter::new(), l2, l2_auth, Address::ZERO);
        client.chain_id = TAIKO_DEVNET_CHAIN_ID;
        SyncPipeline::new(unused_driver_config(), client).await.err()
    }

    #[tokio::test]
    async fn sync_pipeline_refuses_an_engine_without_the_osaka_methods() {
        let v2 = ["engine_forkchoiceUpdatedV2", "engine_getPayloadV2", "engine_newPayloadV2"];
        let err = start_pipeline(&v2, None).await.expect("a V2-only engine is refused");
        assert!(
            matches!(err, DriverError::Rpc(RpcClientError::EngineMethodsUnsupported { .. })),
            "unexpected error: {err:?}"
        );
    }

    #[tokio::test]
    async fn sync_pipeline_refuses_a_head_that_contradicts_the_etna_schedule() {
        let mut etna_head = RpcBlock::<RpcTransaction>::default();
        etna_head.header.inner.number = 5;
        etna_head.header.inner.parent_beacon_block_root = Some(B256::with_last_byte(1));
        etna_head.header.inner.extra_data = Bytes::from(vec![0u8; 13]);

        let err = start_pipeline(&REQUIRED_ENGINE_METHODS, Some(etna_head))
            .await
            .expect("an Etna head is refused while Etna is unscheduled");
        assert!(
            matches!(err, DriverError::Rpc(RpcClientError::EtnaScheduleMismatch { .. })),
            "unexpected error: {err:?}"
        );
    }

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
    fn historical_state_error_matcher_accepts_geth_bare_state_root() {
        assert!(is_historical_state_unavailable(
            GETH_SERVER_ERROR_CODE,
            concat!(
                "historical state ",
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                " is not available"
            ),
        ));
    }

    #[test]
    fn historical_state_error_matcher_accepts_geth_state_history_backfill() {
        assert!(is_historical_state_unavailable(
            GETH_SERVER_ERROR_CODE,
            "state histories haven't been fully indexed yet",
        ));
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

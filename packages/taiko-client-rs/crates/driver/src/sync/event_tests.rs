use std::{
    collections::HashSet,
    path::PathBuf,
    sync::{Arc as StdArc, Mutex},
    time::Duration,
};

use super::*;
use alethia_reth_primitives::payload::attributes::RpcL1Origin;
use alloy::{
    primitives::{
        Address, B256, Bytes, FixedBytes, U256,
        aliases::{U24, U48},
    },
    transports::http::reqwest::Url,
};
use alloy_provider::{ProviderBuilder, RootProvider};
use alloy_rpc_types_engine::PayloadId;
use alloy_transport::mock::Asserter;
use async_trait::async_trait;
use bindings::{
    anchor::Anchor::AnchorInstance,
    inbox::{
        IInbox::{CoreState, DerivationSource},
        Inbox::{InboxInstance, getCoreStateCall},
        LibBlobs::BlobSlice,
    },
};
use rpc::{
    SubscriptionSource,
    blob::BlobDataSource,
    client::{Client, ClientConfig, ShastaProtocolInstance},
};

use crate::{
    production::{BlockProductionPath, ProductionInput, ProductionRouter},
    sync::engine::EngineBlockOutcome,
};

fn mock_client() -> Client<RootProvider> {
    mock_client_with_l1_asserter(Asserter::new())
}

async fn build_syncer() -> EventSyncer<RootProvider> {
    let client_config = ClientConfig {
        l1_provider_source: SubscriptionSource::Http(
            Url::parse("http://localhost:8545").expect("valid http url"),
        ),
        l2_provider_url: Url::parse("http://localhost:8545").expect("valid http url"),
        l2_auth_provider_url: Url::parse("http://localhost:8551").expect("valid http url"),
        jwt_secret: PathBuf::from("/dev/null"),
        inbox_address: Address::ZERO,
    };
    let mut cfg = DriverConfig::new(
        client_config,
        Duration::from_secs(1),
        Url::parse("http://localhost:5052").expect("valid beacon url"),
        None,
        None,
    );
    cfg.preconfirmation_enabled = true;

    let (preconf_tx, preconf_rx) = mpsc::channel(PRECONF_CHANNEL_CAPACITY);
    let blob_source =
        BlobDataSource::new(None, None, true).await.expect("blob data source should build");
    EventSyncer {
        rpc: mock_client(),
        cfg,
        checkpoint_resume_head: Arc::new(CheckpointResumeHead::default()),
        blob_source: Arc::new(blob_source),
        preconf_tx: Some(preconf_tx),
        preconf_rx: Mutex::new(Some(preconf_rx)),
        preconf_ingress_ready: Arc::new(AtomicBool::new(false)),
        preconf_ingress_notify: Arc::new(Notify::new()),
    }
}

fn sample_event_log_with_block_hash(block_hash: B256) -> Log {
    Log {
        inner: alloy::primitives::Log::empty(),
        block_hash: Some(block_hash),
        block_number: Some(1),
        block_timestamp: None,
        transaction_hash: Some(B256::from([9u8; 32])),
        transaction_index: Some(0),
        log_index: Some(0),
        removed: false,
    }
}

fn sample_derivation_source() -> DerivationSource {
    DerivationSource {
        isForcedInclusion: false,
        blobSlice: BlobSlice {
            blobHashes: vec![FixedBytes::ZERO],
            offset: U24::ZERO,
            timestamp: U48::ZERO,
        },
    }
}

fn sample_proposed_log(proposal_id: u64, block_hash: B256, transaction_hash: B256) -> Log {
    let proposed = Proposed {
        id: U48::from(proposal_id),
        proposer: Address::from([proposal_id as u8; 20]),
        parentProposalHash: FixedBytes::from([proposal_id as u8; 32]),
        endOfSubmissionWindowTimestamp: U48::from(1u64),
        basefeeSharingPctg: 0,
        sources: vec![sample_derivation_source()],
    };

    Log {
        inner: alloy::primitives::Log::new_from_event_unchecked(Address::ZERO, proposed)
            .reserialize(),
        block_hash: Some(block_hash),
        block_number: Some(proposal_id),
        block_timestamp: None,
        transaction_hash: Some(transaction_hash),
        transaction_index: Some(0),
        log_index: Some(0),
        removed: false,
    }
}

fn sample_engine_outcome(block_number: u64) -> EngineBlockOutcome {
    let mut block = RpcBlock::<TxEnvelope>::default();
    block.header.number = block_number;
    block.header.hash = B256::from([block_number as u8; 32]);
    EngineBlockOutcome { block, payload_id: PayloadId::new([block_number as u8; 8]) }
}

fn sample_core_state(next_proposal_id: u64) -> CoreState {
    CoreState {
        nextProposalId: U48::from(next_proposal_id),
        lastProposalBlockId: U48::ZERO,
        lastFinalizedProposalId: U48::ZERO,
        lastFinalizedTimestamp: U48::ZERO,
        lastCheckpointTimestamp: U48::ZERO,
        lastFinalizedBlockHash: FixedBytes::ZERO,
    }
}

#[derive(Clone)]
struct MockBatchPath {
    orphaned_tx_hashes: StdArc<HashSet<B256>>,
    seen_tx_hashes: StdArc<Mutex<Vec<B256>>>,
}

impl MockBatchPath {
    fn new(orphaned_tx_hashes: impl IntoIterator<Item = B256>) -> Self {
        Self {
            orphaned_tx_hashes: StdArc::new(orphaned_tx_hashes.into_iter().collect()),
            seen_tx_hashes: StdArc::new(Mutex::new(Vec::new())),
        }
    }

    fn seen_tx_hashes(&self) -> Vec<B256> {
        self.seen_tx_hashes.lock().expect("seen tx hashes mutex should not be poisoned").clone()
    }
}

#[async_trait]
impl BlockProductionPath for MockBatchPath {
    async fn produce(
        &self,
        input: ProductionInput,
    ) -> Result<Vec<EngineBlockOutcome>, DriverError> {
        let ProductionInput::L1ProposalLog(log) = input else {
            panic!("mock batch path only supports L1 proposal logs");
        };

        let tx_hash =
            log.transaction_hash.expect("test proposal log should always include tx hash");
        self.seen_tx_hashes
            .lock()
            .expect("seen tx hashes mutex should not be poisoned")
            .push(tx_hash);

        if self.orphaned_tx_hashes.contains(&tx_hash) {
            return Err(DriverError::Other(anyhow!("mock orphaned proposal failure")));
        }

        Ok(vec![sample_engine_outcome(
            log.block_number.expect("test proposal log should always include block number"),
        )])
    }
}

#[derive(Clone)]
struct MockRetryBatchPath {
    fail_once_tx_hashes: StdArc<Mutex<HashSet<B256>>>,
    seen_tx_hashes: StdArc<Mutex<Vec<B256>>>,
}

impl MockRetryBatchPath {
    fn new(fail_once_tx_hashes: impl IntoIterator<Item = B256>) -> Self {
        Self {
            fail_once_tx_hashes: StdArc::new(Mutex::new(fail_once_tx_hashes.into_iter().collect())),
            seen_tx_hashes: StdArc::new(Mutex::new(Vec::new())),
        }
    }

    fn seen_tx_hashes(&self) -> Vec<B256> {
        self.seen_tx_hashes.lock().expect("seen tx hashes mutex should not be poisoned").clone()
    }
}

#[async_trait]
impl BlockProductionPath for MockRetryBatchPath {
    async fn produce(
        &self,
        input: ProductionInput,
    ) -> Result<Vec<EngineBlockOutcome>, DriverError> {
        let ProductionInput::L1ProposalLog(log) = input else {
            panic!("mock retry batch path only supports L1 proposal logs");
        };

        let tx_hash =
            log.transaction_hash.expect("test proposal log should always include tx hash");
        self.seen_tx_hashes
            .lock()
            .expect("seen tx hashes mutex should not be poisoned")
            .push(tx_hash);

        if self
            .fail_once_tx_hashes
            .lock()
            .expect("fail-once tx hashes mutex should not be poisoned")
            .remove(&tx_hash)
        {
            return Err(DriverError::Other(anyhow!("mock retryable proposal failure")));
        }

        Ok(vec![sample_engine_outcome(
            log.block_number.expect("test proposal log should always include block number"),
        )])
    }
}

fn mock_client_with_l1_asserter(l1_asserter: Asserter) -> Client<RootProvider> {
    mock_client_with_asserters(l1_asserter, Asserter::new())
}

/// Build a client whose public L2 provider serves queued responses. Both
/// `l1_origin_by_id` (materialization pre-check) and `head_l1_origin` (staleness boundary)
/// route through the public L2 provider, so the ingress-job tests queue their answers on
/// this asserter.
fn mock_client_with_l2_asserter(l2_asserter: Asserter) -> Client<RootProvider> {
    let l1_provider =
        ProviderBuilder::new().disable_recommended_fillers().connect_mocked_client(Asserter::new());
    let l2_provider =
        ProviderBuilder::new().disable_recommended_fillers().connect_mocked_client(l2_asserter);
    let l2_auth_provider =
        ProviderBuilder::new().disable_recommended_fillers().connect_mocked_client(Asserter::new());
    let inbox = InboxInstance::new(Address::ZERO, l1_provider.clone());
    let anchor = AnchorInstance::new(Address::ZERO, l2_auth_provider.clone());
    let shasta = ShastaProtocolInstance { inbox, anchor };

    Client { chain_id: 0, l1_provider, l2_provider, l2_auth_provider, shasta }
}

/// Queue an L2 asserter so a `process_preconf_job` call reads a fresh (unmaterialized) payload
/// and a `head_l1_origin` boundary of `head_l1_origin`.
///
/// Materialization short-circuits on the first `taiko_l1OriginByID` when it returns `None`, so
/// a single `None` covers the pre-check; the following value answers `taiko_headL1Origin`.
/// `None` there is read by the loop as a genesis boundary of 0.
fn queue_ingress_job_rpc(asserter: &Asserter, head_l1_origin: Option<u64>) {
    // taiko_l1OriginByID -> not materialized.
    asserter.push_success(&Option::<RpcL1Origin>::None);
    // taiko_headL1Origin -> confirmed boundary (None => genesis 0).
    let head = head_l1_origin.map(|block_id| RpcL1Origin {
        block_id: U256::from(block_id),
        l2_block_hash: B256::ZERO,
        l1_block_height: None,
        l1_block_hash: None,
        build_payload_args_id: [0u8; 8],
        is_forced_inclusion: false,
        signature: [0u8; 65],
    });
    asserter.push_success(&head);
}

/// Preconfirmation production path that counts `produce` calls and optionally fails for a fixed
/// set of block numbers. Modeled on `production/path.rs`'s call-counting `MockPath`.
#[derive(Clone, Default)]
struct CountingPreconfPath {
    calls: StdArc<Mutex<u64>>,
    fail_block_numbers: StdArc<HashSet<u64>>,
}

impl CountingPreconfPath {
    /// A path whose `produce` always succeeds.
    fn always_ok() -> Self {
        Self::default()
    }

    /// A path whose `produce` fails for the given block numbers and succeeds otherwise.
    fn failing_for(block_numbers: impl IntoIterator<Item = u64>) -> Self {
        Self {
            calls: StdArc::new(Mutex::new(0)),
            fail_block_numbers: StdArc::new(block_numbers.into_iter().collect()),
        }
    }

    fn calls(&self) -> u64 {
        *self.calls.lock().expect("counting path mutex should not be poisoned")
    }
}

#[async_trait]
impl BlockProductionPath for CountingPreconfPath {
    async fn produce(
        &self,
        input: ProductionInput,
    ) -> Result<Vec<EngineBlockOutcome>, DriverError> {
        let ProductionInput::Preconfirmation(payload) = input else {
            panic!("counting preconf path only supports preconfirmation inputs");
        };
        *self.calls.lock().expect("counting path mutex should not be poisoned") += 1;

        let block_number = payload.block_number();
        if self.fail_block_numbers.contains(&block_number) {
            return Err(DriverError::Other(anyhow!("mock preconf failure")));
        }
        Ok(vec![sample_engine_outcome(block_number)])
    }
}

/// Wrap a preconfirmation path in a router. The canonical path is a never-called stub because
/// these tests only drive the preconfirmation branch.
fn router_with_preconf_path(preconf: CountingPreconfPath) -> Arc<AsyncMutex<ProductionRouter>> {
    let canonical: Arc<dyn BlockProductionPath + Send + Sync> =
        Arc::new(CountingPreconfPath::always_ok());
    let preconf: Arc<dyn BlockProductionPath + Send + Sync> = Arc::new(preconf);
    Arc::new(AsyncMutex::new(ProductionRouter::new(canonical, Some(preconf))))
}

/// One failing payload must fail ONLY its own submitter; the loop keeps processing subsequent
/// jobs. This is the "one bad payload must not freeze the head" invariant from the 2026-06/07
/// mainnet incident.
#[tokio::test]
async fn ingress_job_failure_is_isolated_to_its_submitter() {
    let preconf = CountingPreconfPath::failing_for([1]);
    let router = router_with_preconf_path(preconf.clone());
    let asserter = Asserter::new();
    // Two jobs, each: materialization not-materialized + head_l1_origin genesis (0, not stale).
    queue_ingress_job_rpc(&asserter, None);
    queue_ingress_job_rpc(&asserter, None);
    let rpc = mock_client_with_l2_asserter(asserter);

    let (tx1, rx1) = oneshot::channel();
    let (tx2, rx2) = oneshot::channel();
    EventSyncer::process_preconf_job(
        &router,
        &rpc,
        PreconfJob {
            payload: Arc::new(PreconfPayload::new(crate::test_support::sample_payload(1))),
            respond_to: tx1,
        },
    )
    .await;
    EventSyncer::process_preconf_job(
        &router,
        &rpc,
        PreconfJob {
            payload: Arc::new(PreconfPayload::new(crate::test_support::sample_payload(2))),
            respond_to: tx2,
        },
    )
    .await;

    assert!(rx1.await.expect("responded").is_err(), "failing job reports its error");
    assert!(rx2.await.expect("responded").is_ok(), "next job unaffected");
    assert_eq!(preconf.calls(), 2, "both jobs reached the engine");
}

/// The load-bearing design decision behind the mpsc+oneshot ingress channel: a submitter future
/// dropped mid-await (e.g. an axum handler cancelled by a client disconnect) must NOT cancel an
/// in-flight engine injection. Pinned here mechanically: the job runs to completion even though
/// its receiver is already gone.
#[tokio::test]
async fn dropped_submitter_does_not_cancel_in_flight_injection() {
    let preconf = CountingPreconfPath::always_ok();
    let router = router_with_preconf_path(preconf.clone());
    let asserter = Asserter::new();
    queue_ingress_job_rpc(&asserter, None);
    let rpc = mock_client_with_l2_asserter(asserter);

    let (tx, rx) = oneshot::channel::<Result<(), DriverError>>();
    drop(rx); // submitter went away before the job ran
    EventSyncer::process_preconf_job(
        &router,
        &rpc,
        PreconfJob {
            payload: Arc::new(PreconfPayload::new(crate::test_support::sample_payload(1))),
            respond_to: tx,
        },
    )
    .await;

    assert_eq!(preconf.calls(), 1, "injection ran to completion");
    // and no panic from the dead oneshot: reaching this line is the assert.
}

/// A payload at/below the confirmed L1-origin boundary is acknowledged Ok (idempotent) but
/// never re-injected.
#[tokio::test]
async fn stale_preconf_payload_is_acked_without_injection() {
    let preconf = CountingPreconfPath::always_ok();
    let router = router_with_preconf_path(preconf.clone());
    let asserter = Asserter::new();
    // head_l1_origin boundary at 5; payload block 5 is stale (block <= boundary).
    queue_ingress_job_rpc(&asserter, Some(5));
    let rpc = mock_client_with_l2_asserter(asserter);

    let (tx, rx) = oneshot::channel();
    EventSyncer::process_preconf_job(
        &router,
        &rpc,
        PreconfJob {
            payload: Arc::new(PreconfPayload::new(crate::test_support::sample_payload(5))),
            respond_to: tx,
        },
    )
    .await;

    assert!(rx.await.expect("responded").is_ok(), "stale payload acked Ok");
    assert_eq!(preconf.calls(), 0, "stale payload never reaches the engine");
}

fn mock_client_with_asserters(
    l1_asserter: Asserter,
    l2_auth_asserter: Asserter,
) -> Client<RootProvider> {
    let l1_provider =
        ProviderBuilder::new().disable_recommended_fillers().connect_mocked_client(l1_asserter);
    let l2_provider =
        ProviderBuilder::new().disable_recommended_fillers().connect_mocked_client(Asserter::new());
    let l2_auth_provider = ProviderBuilder::new()
        .disable_recommended_fillers()
        .connect_mocked_client(l2_auth_asserter);
    let inbox = InboxInstance::new(Address::ZERO, l1_provider.clone());
    let anchor = AnchorInstance::new(Address::ZERO, l2_auth_provider.clone());
    let shasta = ShastaProtocolInstance { inbox, anchor };

    Client { chain_id: 0, l1_provider, l2_provider, l2_auth_provider, shasta }
}

#[tokio::test]
async fn orphaned_proposal_log_is_permanent_when_l1_block_is_missing() {
    let asserter = Asserter::new();
    let syncer =
        EventSyncer { rpc: mock_client_with_l1_asserter(asserter.clone()), ..build_syncer().await };
    asserter.push_success(&Option::<RpcBlock<TxEnvelope>>::None);
    asserter.push_success(&1u64);

    let log = sample_event_log_with_block_hash(B256::from([1u8; 32]));
    let is_orphaned = syncer
        .is_permanently_orphaned_proposal_log(
            log.block_hash.expect("test log should include block hash"),
            log.block_number,
        )
        .await
        .expect("block lookup should succeed");

    assert!(is_orphaned);
}

#[tokio::test]
async fn proposal_log_is_retryable_when_chain_head_is_behind_missing_block() {
    let asserter = Asserter::new();
    let syncer =
        EventSyncer { rpc: mock_client_with_l1_asserter(asserter.clone()), ..build_syncer().await };
    asserter.push_success(&Option::<RpcBlock<TxEnvelope>>::None);
    asserter.push_success(&0u64);

    let log = sample_event_log_with_block_hash(B256::from([5u8; 32]));
    let is_orphaned = syncer
        .is_permanently_orphaned_proposal_log(
            log.block_hash.expect("test log should include block hash"),
            log.block_number,
        )
        .await
        .expect("block lookup should succeed");

    assert!(!is_orphaned);
}

#[tokio::test]
async fn proposal_log_is_retryable_when_l1_block_still_exists() {
    let asserter = Asserter::new();
    let syncer =
        EventSyncer { rpc: mock_client_with_l1_asserter(asserter.clone()), ..build_syncer().await };
    asserter.push_success(&Some(RpcBlock::<TxEnvelope>::default()));

    let log = sample_event_log_with_block_hash(B256::from([2u8; 32]));
    let is_orphaned = syncer
        .is_permanently_orphaned_proposal_log(
            log.block_hash.expect("test log should include block hash"),
            log.block_number,
        )
        .await
        .expect("block lookup should succeed");

    assert!(!is_orphaned);
}

#[tokio::test]
async fn proposal_log_reorg_check_is_transient_on_rpc_error() {
    let asserter = Asserter::new();
    let syncer =
        EventSyncer { rpc: mock_client_with_l1_asserter(asserter.clone()), ..build_syncer().await };
    asserter.push_failure_msg("boom");

    let log = sample_event_log_with_block_hash(B256::from([3u8; 32]));
    let err = syncer
        .is_permanently_orphaned_proposal_log(
            log.block_hash.expect("test log should include block hash"),
            log.block_number,
        )
        .await
        .expect_err("rpc lookup failure should be surfaced");

    assert!(matches!(err, SyncError::Rpc(RpcClientError::Provider(_))));
}

// Paused clock: the impl retries with a real tokio `ExponentialBackoff` (tokio-retry uses
// `tokio::time::sleep`), so under `start_paused` tokio auto-advances the timer when idle and the
// virtual 60s wrapper resolves instantly and deterministically. Attempt-count is the real contract.
#[tokio::test(start_paused = true)]
async fn process_log_batch_skips_orphaned_proposal_log_and_continues_batch() {
    let orphaned_block_hash = B256::from([0x11; 32]);
    let orphaned_tx_hash = B256::from([0x21; 32]);
    let later_tx_hash = B256::from([0x22; 32]);
    let asserter = Asserter::new();
    asserter.push_success(&Option::<RpcBlock<TxEnvelope>>::None);
    asserter.push_success(&2u64);

    let syncer =
        EventSyncer { rpc: mock_client_with_l1_asserter(asserter), ..build_syncer().await };
    let path = MockBatchPath::new([orphaned_tx_hash]);
    let router = Arc::new(AsyncMutex::new(ProductionRouter::new(Arc::new(path.clone()), None)));

    let result = timeout(
        Duration::from_secs(60),
        syncer.process_log_batch(
            router,
            vec![
                sample_proposed_log(1, orphaned_block_hash, orphaned_tx_hash),
                sample_proposed_log(2, B256::from([0x12; 32]), later_tx_hash),
            ],
        ),
    )
    .await;

    assert!(
        matches!(result, Ok(Ok(()))),
        "orphaned log should be skipped so a later log in the same batch still processes",
    );
    assert_eq!(path.seen_tx_hashes(), vec![orphaned_tx_hash, later_tx_hash]);
}

#[tokio::test]
async fn process_log_batch_fails_when_proposal_log_missing_block_hash() {
    let syncer =
        EventSyncer { rpc: mock_client_with_l1_asserter(Asserter::new()), ..build_syncer().await };
    let path = MockBatchPath::new([]);
    let router = Arc::new(AsyncMutex::new(ProductionRouter::new(Arc::new(path.clone()), None)));
    let mut log = sample_proposed_log(1, B256::from([0x31; 32]), B256::from([0x41; 32]));
    log.block_hash = None;

    let err = syncer
        .process_log_batch(router, vec![log])
        .await
        .expect_err("missing block hash should fail the batch");

    assert!(matches!(
        err,
        SyncError::MissingProposalLogBlockHash { tx_hash: Some(_), block_number: Some(1) }
    ));
    assert!(path.seen_tx_hashes().is_empty());
}

// Paused clock: see `process_log_batch_skips_orphaned_proposal_log_and_continues_batch`. The
// virtual 60s wrapper resolves instantly since tokio-retry's backoff sleeps on a tokio timer.
#[tokio::test(start_paused = true)]
async fn process_log_batch_retries_when_orphan_recheck_errors() {
    let retry_block_hash = B256::from([0x51; 32]);
    let retry_tx_hash = B256::from([0x61; 32]);
    let asserter = Asserter::new();
    asserter.push_failure_msg("boom");

    let syncer =
        EventSyncer { rpc: mock_client_with_l1_asserter(asserter), ..build_syncer().await };
    let path = MockRetryBatchPath::new([retry_tx_hash]);
    let router = Arc::new(AsyncMutex::new(ProductionRouter::new(Arc::new(path.clone()), None)));

    let result = timeout(
        Duration::from_secs(60),
        syncer.process_log_batch(
            router,
            vec![sample_proposed_log(1, retry_block_hash, retry_tx_hash)],
        ),
    )
    .await;

    assert!(
        matches!(result, Ok(Ok(()))),
        "recheck rpc errors should keep the log retryable until a later attempt succeeds",
    );
    assert_eq!(path.seen_tx_hashes(), vec![retry_tx_hash, retry_tx_hash]);
}

#[tokio::test]
async fn preconf_submit_rejected_before_first_event_sync_gate() {
    let syncer = build_syncer().await;
    let payload = PreconfPayload::new(crate::test_support::sample_payload(1));
    let err = syncer
        .submit_preconfirmation_payload_with_timeout(payload, Duration::from_millis(10))
        .await
        .expect_err("expected ingress not ready error");

    assert!(matches!(err, DriverError::PreconfIngressNotReady));
}

#[test]
fn confirmed_sync_probe_rearms_when_ingress_gate_closes_after_spawn() {
    assert!(should_probe_confirmed_sync(true, true, false, true));
    assert!(!should_probe_confirmed_sync(true, true, true, true));
    assert!(should_probe_confirmed_sync(true, false, false, true));
    assert!(!should_probe_confirmed_sync(true, false, false, false));
    assert!(!should_probe_confirmed_sync(false, true, false, true));
}

#[test]
fn confirmed_sync_probe_success_reflects_snapshot_readiness() {
    let ready = resolve_confirmed_sync_probe(Ok(ConfirmedSyncSnapshot::new(0, None, None)));
    assert!(ready, "successful probe should defer to snapshot readiness");
}

#[test]
fn confirmed_sync_probe_error_keeps_ingress_closed() {
    let ready = resolve_confirmed_sync_probe(Err(SyncError::MissingCheckpointResumeHead));
    assert!(!ready, "probe errors must keep ingress closed until a later successful probe",);
}

/// Latest canonical batch tip the queued `last_certain_block_id_by_batch_id` mapping response
/// resolves to on the success path — the exact value `reset_head_l1_origin_after_reorg` must
/// write to (and therefore return from) `set_head_l1_origin`.
const EXPECTED_TIP: u64 = 7_777;

/// Build a syncer wired to fresh L1 + L2-auth asserters preloaded with the RPC responses
/// `reset_head_l1_origin_after_reorg` consumes for one reorg, returning the asserters so the
/// caller can assert every queued response was drained.
///
/// Both variants queue `getCoreState` (nextProposalId = 100, so proposal_id = 99, past the
/// genesis boundary). With `queue_mapping = true` the batch mapping resolves to
/// `Some(EXPECTED_TIP)` and a `set_head_l1_origin` response is queued (its echoed value is
/// unused by the function; only success/failure matters). With `queue_mapping = false` the
/// mapping resolves to `None`, so the function must skip the write entirely.
async fn build_syncer_with_reorg_queues(
    queue_mapping: bool,
) -> (EventSyncer<RootProvider>, Asserter, Asserter) {
    let l1_asserter = Asserter::new();
    let l2_auth_asserter = Asserter::new();
    let syncer = EventSyncer {
        rpc: mock_client_with_asserters(l1_asserter.clone(), l2_auth_asserter.clone()),
        ..build_syncer().await
    };

    let core_state = sample_core_state(100);
    let encoded_core_state = Bytes::from(getCoreStateCall::abi_encode_returns(&core_state));
    l1_asserter.push_success(&encoded_core_state);
    if queue_mapping {
        l2_auth_asserter.push_success(&Some(U256::from(EXPECTED_TIP))); // last_certain_block_id_by_batch_id
        l2_auth_asserter.push_success(&Some(U256::from(EXPECTED_TIP))); // set_head_l1_origin
    } else {
        l2_auth_asserter.push_success(&Option::<U256>::None); // last_certain_block_id_by_batch_id
    }

    (syncer, l1_asserter, l2_auth_asserter)
}

/// After a reorg the head L1 origin must be lowered to the latest canonical batch tip —
/// asserting the VALUE written, not merely that the RPCs were called. A regression that wrote
/// the wrong block id (or nothing) would drain the same mock queue yet fail this assertion.
#[tokio::test]
async fn reset_head_l1_origin_after_reorg_writes_canonical_tip() {
    // (mapping present -> writes Some(tip)) and (mapping missing -> best-effort skip -> None).
    for (queue_mapping, expected) in [(true, Some(EXPECTED_TIP)), (false, None)] {
        let (syncer, l1_asserter, l2_auth_asserter) =
            build_syncer_with_reorg_queues(queue_mapping).await;

        let written = syncer.reset_head_l1_origin_after_reorg(1_234).await;

        assert_eq!(
            written, expected,
            "reset must return the exact head_l1_origin block id it wrote (queue_mapping = {queue_mapping})"
        );
        // A missing mapping must NOT issue a set_head_l1_origin call; both paths drain their
        // full queue.
        assert!(
            l1_asserter.read_q().is_empty(),
            "all queued L1 RPC responses consumed (queue_mapping = {queue_mapping})"
        );
        assert!(
            l2_auth_asserter.read_q().is_empty(),
            "all queued L2-auth RPC responses consumed (queue_mapping = {queue_mapping})"
        );
    }
}

#[test]
fn resume_head_resolution_requires_checkpoint_state_in_checkpoint_mode() {
    let err = resolve_resume_head_block_number(true, None, Some(100), Some(99))
        .expect_err("checkpoint mode should require checkpoint resume state");
    assert!(matches!(err, SyncError::MissingCheckpointResumeHead));

    let resolved = resolve_resume_head_block_number(true, Some(420), None, None)
        .expect("checkpoint resume head should be used when present");
    assert_eq!(resolved, 420);
}

#[test]
fn resume_head_resolution_requires_head_l1_origin_without_checkpoint() {
    let err = resolve_resume_head_block_number(false, Some(999), None, None)
        .expect_err("non-checkpoint mode should require head_l1_origin");
    assert!(matches!(err, SyncError::MissingHeadL1OriginResume));

    let resolved = resolve_resume_head_block_number(false, Some(999), Some(64), Some(80))
        .expect("head_l1_origin should drive resume when rpc head is not lower");
    assert_eq!(resolved, 64);

    let resolved = resolve_resume_head_block_number(false, None, None, Some(0))
        .expect("genesis fallback when rpc reports block 0 and origin is missing");
    assert_eq!(resolved, 0);
}

#[test]
fn resume_head_resolution_prefers_lower_non_zero_rpc_over_origin() {
    let resolved = resolve_resume_head_block_number(false, None, Some(64), Some(32))
        .expect("lower non-zero rpc block number should win");
    assert_eq!(resolved, 32);

    let resolved = resolve_resume_head_block_number(false, None, Some(64), Some(0))
        .expect("zero rpc block number must not override origin");
    assert_eq!(resolved, 64);
}

#[test]
fn resume_head_resolution_falls_back_to_origin_when_rpc_missing() {
    let resolved = resolve_resume_head_block_number(false, None, Some(64), None)
        .expect("missing rpc block number should fall back to local origin");
    assert_eq!(resolved, 64);
}

#[test]
fn zero_target_uses_finalized_block_when_finalized_safe_is_zero() {
    let start_block = resolve_zero_target_start_block(0, 4_096);
    assert_eq!(start_block, 4_096);
}

#[test]
fn zero_target_uses_genesis_when_finalized_safe_exists() {
    let start_block = resolve_zero_target_start_block(17, 4_096);
    assert_eq!(start_block, 0);
}

// -- resolve_target_with_optional_finalization tests --

#[test]
fn without_finalization_resets_to_zero_target() {
    let (target, safe) = resolve_target_with_optional_finalization(0, None);
    assert_eq!(target, 0);
    assert_eq!(safe, 0);

    // Even with a non-zero resume, no finalization resets both to 0.
    let (target, safe) = resolve_target_with_optional_finalization(5, None);
    assert_eq!(target, 0);
    assert_eq!(safe, 0);
}

#[test]
fn with_finalization_target_is_bounded_by_finalized_safe() {
    let (target, safe) = resolve_target_with_optional_finalization(120, Some(90));
    assert_eq!(target, 90);
    assert_eq!(safe, 90);
}

#[test]
fn with_finalization_target_keeps_resume_when_behind() {
    let (target, safe) = resolve_target_with_optional_finalization(50, Some(120));
    assert_eq!(target, 50);
    assert_eq!(safe, 120);
}

#[test]
fn reconnect_start_rewinds_to_finalized_when_finalized_is_behind_last_seen() {
    let reconnect_start = resolve_reconnect_start_block(120, Some(80), 10);
    assert_eq!(reconnect_start, 80);
}

#[test]
fn reconnect_start_keeps_one_block_overlap_when_finalized_is_ahead() {
    let reconnect_start = resolve_reconnect_start_block(120, Some(240), 10);
    assert_eq!(reconnect_start, 119);
}

#[test]
fn reconnect_start_falls_back_to_startup_anchor_without_finalization() {
    let reconnect_start = resolve_reconnect_start_block(120, None, 10);
    assert_eq!(reconnect_start, 10);
}

#[test]
fn scanner_setup_errors_fail_fast_before_first_successful_start() {
    let err = resolve_event_scanner_setup_error(false, "boom".into())
        .expect_err("startup scanner errors should fail fast");
    assert!(matches!(err, SyncError::EventScannerInit(reason) if reason == "boom"));

    let err = resolve_event_scanner_setup_error(true, "boom".into())
        .expect("post-start scanner errors should be retryable");
    assert_eq!(err, "boom");
}

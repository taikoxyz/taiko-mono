//! E2E tests for proposer -> driver Shasta proposal flows.
//!
//! Every test runs against the shared docker L1/L2 env brought up by
//! `tests/entrypoint.sh`; the nextest `l1-shared` group (and `#[serial]` under plain
//! `cargo test`) serializes them because they mutate shared chain state.

use std::{future::Future, sync::Arc, time::Duration};

use alloy_primitives::{B256, U256};
use alloy_provider::Provider;
use alloy_rpc_types::Log;
use alloy_sol_types::SolEvent;
use anyhow::{Context, Result, anyhow, ensure};
use bindings::inbox::Inbox::Proposed;
use driver::{
    DriverConfig,
    derivation::ShastaDerivationPipeline,
    sync::{SyncStage, engine::PayloadApplier, event::EventSyncer},
};
use proposer::{
    proposer::EngineBuildContext,
    transaction_builder::{BuiltProposalTx, ShastaProposalTransactionBuilder},
};
use rpc::{blob::BlobDataSource, client::Client};
use serial_test::serial;
use test_context::test_context;
use test_harness::{BeaconStubServer, ShastaEnv, verify_anchor_block};
use tokio::{
    spawn,
    task::{JoinError, JoinHandle},
};
use tracing::{info, warn};

/// Deadline for the event syncer to reach preconf-ingress readiness (scanner switched
/// to live mode and the confirmed-sync probe passed). Generous for loaded CI runners;
/// without a bound a syncer that dies before going live would hang the whole serialized
/// integration lane.
const SYNCER_READY_TIMEOUT: Duration = Duration::from_secs(120);

/// Deadline for a submitted proposal to be event-synced into the L2 chain.
const PROPOSAL_PROCESSED_TIMEOUT: Duration = Duration::from_secs(30);

async fn proposer_client(env: &ShastaEnv) -> Result<Client> {
    Client::new(env.client_config.clone()).await.map_err(Into::into)
}

fn decode_proposal_id(log: &Log) -> Result<u64> {
    Proposed::decode_raw_log(log.topics(), log.data().data.as_ref())
        .map(|event| event.id.to::<u64>())
        .map_err(|err| anyhow!("decode proposal log failed: {err}"))
}

/// Builds an anchor-only (empty txlist) proposal from the current chain heads.
async fn build_empty_proposal(env: &ShastaEnv, proposer: &Client) -> Result<BuiltProposalTx> {
    let builder =
        ShastaProposalTransactionBuilder::new(proposer.clone(), env.l2_suggested_fee_recipient);
    let (build_ctx, _) = EngineBuildContext::from_chain_heads(proposer).await?;
    Ok(builder.build(vec![Vec::new()], build_ctx).await?)
}

/// Submits a proposal transaction through a wallet-backed L1 provider and returns the
/// proposal ID and log.
///
/// The wallet lives only in this test helper: the production `Client` is walletless and
/// all production L1 sends flow through the proposer's tx-manager.
async fn submit_proposal(env: &ShastaEnv, request: BuiltProposalTx) -> Result<(u64, Log)> {
    let wallet_provider = env
        .client_config
        .l1_provider_source
        .to_provider_with_wallet(env.l1_proposer_private_key)
        .await?;
    let pending_tx = wallet_provider.send_transaction(request.to_transaction_request()).await?;
    let receipt = pending_tx.get_receipt().await?;
    ensure!(receipt.status(), "proposal transaction failed");
    let proposal_log: Log = receipt
        .logs()
        .iter()
        .find(|log| log.address() == env.inbox_address)
        .cloned()
        .context("missing Proposed log in receipt")?;
    let proposal_id = decode_proposal_id(&proposal_log)?;
    Ok((proposal_id, proposal_log))
}

/// Owns the event-sync task until its exit is observed or cancellation completes.
struct SyncerTask {
    handle: Option<JoinHandle<Result<()>>>,
}

impl SyncerTask {
    /// Wraps a newly spawned event-sync task.
    fn new(handle: JoinHandle<Result<()>>) -> Self {
        Self { handle: Some(handle) }
    }

    /// Waits for the task to exit and consumes its output exactly once.
    async fn wait_for_exit(&mut self, phase: &str) -> anyhow::Error {
        let Some(handle) = self.handle.as_mut() else {
            return anyhow!("event syncer exit was already observed {phase}");
        };
        let result = handle.await;
        self.handle.take();
        syncer_exit_error(result, phase)
    }

    /// Races an operation against unexpected event-sync task termination.
    async fn race<T>(&mut self, operation: impl Future<Output = T>, phase: &str) -> Result<T> {
        tokio::select! {
            result = operation => Ok(result),
            err = self.wait_for_exit(phase) => Err(err),
        }
    }

    /// Cancels the task and waits until its future has been dropped.
    async fn shutdown(mut self) -> Result<()> {
        self.abort_and_wait().await
    }

    /// Cancels and joins the task without moving the owner.
    async fn abort_and_wait(&mut self) -> Result<()> {
        let Some(handle) = self.handle.take() else {
            return Ok(());
        };
        handle.abort();
        match handle.await {
            Err(err) if err.is_cancelled() => Ok(()),
            result => Err(syncer_exit_error(result, "during shutdown")),
        }
    }
}

impl Drop for SyncerTask {
    /// Schedules cancellation as a fallback when explicit async shutdown is impossible.
    fn drop(&mut self) {
        if let Some(handle) = &self.handle {
            handle.abort();
        }
    }
}

/// Converts an unexpected event-sync task result into contextual test failure.
fn syncer_exit_error(
    result: std::result::Result<Result<()>, JoinError>,
    phase: &str,
) -> anyhow::Error {
    match result {
        Ok(Ok(())) => anyhow!("event syncer exited {phase}"),
        Ok(Err(err)) => err.context(format!("event syncer exited {phase}")),
        Err(err) => anyhow!("event syncer task failed {phase}: {err}"),
    }
}

/// An event syncer whose task must be explicitly joined before `ShastaEnv` teardown.
struct SyncerHandle {
    syncer: Arc<EventSyncer>,
    task: SyncerTask,
}

impl SyncerHandle {
    /// Joins task cancellation before returning the test result.
    async fn finish<T>(mut self, result: Result<T>) -> Result<T> {
        let shutdown = self.task.abort_and_wait().await;
        match (result, shutdown) {
            (Ok(value), Ok(())) => Ok(value),
            (Err(err), Ok(())) => Err(err),
            (Ok(_), Err(err)) => Err(err),
            (Err(err), Err(shutdown_err)) => {
                Err(err.context(format!("event syncer shutdown also failed: {shutdown_err:#}")))
            }
        }
    }
}

/// Spawns an `EventSyncer` against the beacon stub and waits (bounded) until preconf
/// ingress is ready, failing fast if the syncer task exits first.
async fn start_event_syncer(
    env: &ShastaEnv,
    beacon_stub: &BeaconStubServer,
) -> Result<(SyncerHandle, Client)> {
    let driver_config = DriverConfig::new(
        env.client_config.clone(),
        Duration::from_millis(50),
        beacon_stub.endpoint().clone(),
        None,
        None,
        true,
    );
    let driver_client = Client::new(driver_config.client.clone()).await?;
    let syncer = Arc::new(EventSyncer::new(&driver_config, driver_client.clone()).await?);
    let task: JoinHandle<Result<()>> = {
        let syncer = syncer.clone();
        spawn(async move { syncer.run().await.map_err(Into::into) })
    };
    // Guard the task from the moment of spawn: an early return below must abort the
    // syncer, not detach it into a race with ShastaEnv teardown's snapshot revert.
    let mut handle = SyncerHandle { syncer, task: SyncerTask::new(task) };

    let readiness_syncer = handle.syncer.clone();
    let readiness = handle
        .task
        .race(
            async move {
                tokio::time::timeout(
                    SYNCER_READY_TIMEOUT,
                    readiness_syncer.wait_preconf_ingress_ready(),
                )
                .await
                .context("timed out waiting for preconf ingress readiness")??;
                Ok(())
            },
            "before reaching readiness",
        )
        .await
        .and_then(|result| result);
    if let Err(err) = readiness {
        let shutdown = handle.task.abort_and_wait().await;
        return match shutdown {
            Ok(()) => Err(err),
            Err(shutdown_err) => {
                Err(err.context(format!("event syncer shutdown also failed: {shutdown_err:#}")))
            }
        };
    }

    Ok((handle, driver_client))
}

/// Pre-submission snapshot of the batch row the NEXT proposal will map to.
///
/// The shared L2 node's custom tables (`lastCertainBlockIDByBatchID`, `l1_origin`) are
/// NOT rolled back by the per-test L1 snapshot revert, so an earlier test can leave a
/// row for the same proposal id behind. The wait below uses this baseline to tell this
/// submission's row apart from such leftovers.
struct BatchRowBaseline {
    /// The proposal id the next submission will be assigned (`nextProposalId`).
    proposal_id: u64,
    /// Leftover batch-row target and the canonical block hash currently at that height.
    stale_target: Option<(u64, B256)>,
}

/// Captures [`BatchRowBaseline`] for the next proposal id. Must be called BEFORE
/// submitting the proposal.
async fn batch_row_baseline(driver_client: &Client) -> Result<BatchRowBaseline> {
    let core_state = driver_client.shasta.inbox.getCoreState().call().await?;
    let proposal_id = core_state.nextProposalId.to::<u64>();

    let stale_block = driver_client
        .last_certain_block_id_by_batch_id(U256::from(proposal_id))
        .await?
        .map(|block_number| block_number.to::<u64>());
    let stale_target = match stale_block {
        Some(block_number) => driver_client
            .l2_provider
            .get_block_by_number(block_number.into())
            .await?
            .map(|block| (block_number, block.hash())),
        None => None,
    };

    Ok(BatchRowBaseline { proposal_id, stale_target })
}

/// One readiness poll: `Ok(Some(head))` once the proposal is fully processed,
/// `Ok(None)` while still pending.
async fn poll_proposal_processed(
    event_syncer: &EventSyncer,
    driver_client: &Client,
    baseline: &BatchRowBaseline,
    l2_head_before: u64,
) -> Result<Option<u64>> {
    let Some(target_block) = driver_client
        .last_certain_block_id_by_batch_id(U256::from(baseline.proposal_id))
        .await?
        .map(|block_number| block_number.to::<u64>())
    else {
        return Ok(None);
    };

    // A leftover row from an earlier test is only superseded once the canonical block
    // at its height has been re-derived from this submission (fresh anchor/timestamp
    // guarantee a different hash).
    if let Some((stale_block, stale_hash)) = baseline.stale_target &&
        target_block == stale_block
    {
        let current_hash = driver_client
            .l2_provider
            .get_block_by_number(target_block.into())
            .await?
            .map(|block| block.hash());
        if current_hash == Some(stale_hash) {
            return Ok(None);
        }
    }

    let Some(head_block) = event_syncer.confirmed_sync_snapshot().await?.event_sync_tip() else {
        return Ok(None);
    };
    if head_block < target_block {
        return Ok(None);
    }

    let l2_head = driver_client.l2_provider.get_block_number().await?;
    if l2_head < l2_head_before {
        warn!(
            l2_head_before,
            l2_head, "L2 head moved backward while waiting for proposal processing"
        );
    }
    Ok((l2_head >= target_block).then_some(l2_head))
}

/// Waits for the event syncer to process a specific proposal using confirmed-sync state
/// polling. Transient RPC errors (e.g. a dropped WS frame mid-poll) count against the
/// deadline instead of failing the wait outright.
async fn wait_for_proposal_processed(
    syncer: &mut SyncerHandle,
    driver_client: &Client,
    baseline: &BatchRowBaseline,
    l2_head_before: u64,
    timeout: Duration,
) -> Result<u64> {
    let deadline = tokio::time::Instant::now() + timeout;
    let mut last_error = None;

    loop {
        let event_syncer = syncer.syncer.clone();
        let poll_result = syncer
            .task
            .race(
                poll_proposal_processed(&event_syncer, driver_client, baseline, l2_head_before),
                "while waiting for proposal processing",
            )
            .await?;
        match poll_result {
            Ok(Some(l2_head)) => return Ok(l2_head),
            Ok(None) => {}
            Err(err) => {
                warn!(?err, "transient error while polling for proposal processing");
                last_error = Some(err);
            }
        }

        if tokio::time::Instant::now() >= deadline {
            return Err(anyhow!(
                "timed out waiting for proposal {} (last error: {last_error:?})",
                baseline.proposal_id
            ));
        }
        syncer
            .task
            .race(
                tokio::time::sleep(Duration::from_millis(100)),
                "while waiting for proposal processing",
            )
            .await?;
    }
}

/// Tests the proposer -> driver event sync flow.
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn proposer_to_driver_event_sync(env: &mut ShastaEnv) -> Result<()> {
    let beacon_stub = BeaconStubServer::start().await?;
    let proposer = proposer_client(env).await?;

    // Build a proposal and inject its sidecar into the beacon stub.
    let request = build_empty_proposal(env, &proposer).await?;
    beacon_stub.set_default_blob_sidecar(request.blob_sidecar());

    // Start the event syncer before submitting the proposal.
    let (mut syncer, driver_client) = start_event_syncer(env, &beacon_stub).await?;

    let result: Result<()> = async {
        let l2_head_before = driver_client.l2_provider.get_block_number().await?;

        let baseline = batch_row_baseline(&driver_client).await?;
        let (proposal_id, _log) = submit_proposal(env, request).await?;
        ensure!(proposal_id == baseline.proposal_id, "proposal id diverged from core state");

        let l2_head_after = wait_for_proposal_processed(
            &mut syncer,
            &driver_client,
            &baseline,
            l2_head_before,
            PROPOSAL_PROCESSED_TIMEOUT,
        )
        .await?;

        verify_anchor_block(&driver_client, env.taiko_anchor_address)
            .await
            .context("verifying anchor block on L2")?;

        ensure!(
            l2_head_after >= l2_head_before,
            "L2 head should not move backwards after proposal processing"
        );

        Ok(())
    }
    .await;

    syncer.finish(result).await
}

/// Tests the known-canonical fast path in the derivation pipeline.
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn known_canonical_fast_path(env: &mut ShastaEnv) -> Result<()> {
    let beacon_stub = BeaconStubServer::start().await?;
    let beacon_endpoint = beacon_stub.endpoint().clone();
    let proposer = proposer_client(env).await?;

    let request = build_empty_proposal(env, &proposer).await?;
    beacon_stub.set_default_blob_sidecar(request.blob_sidecar());

    let (mut syncer, driver_client) = start_event_syncer(env, &beacon_stub).await?;

    let result: Result<()> = async {
        let l2_head_before = driver_client.l2_provider.get_block_number().await?;
        let baseline = batch_row_baseline(&driver_client).await?;
        let (proposal_id, proposal_log) = submit_proposal(env, request).await?;
        ensure!(proposal_id == baseline.proposal_id, "proposal id diverged from core state");

        wait_for_proposal_processed(
            &mut syncer,
            &driver_client,
            &baseline,
            l2_head_before,
            PROPOSAL_PROCESSED_TIMEOUT,
        )
        .await?;
        // Capture the canonical block hash produced by the first processing.
        let canonical_block = driver_client
            .l2_provider
            .get_block_by_number(alloy_eips::BlockNumberOrTag::Latest)
            .await?
            .ok_or_else(|| anyhow!("missing canonical block after proposal processing"))?;
        let canonical_number = canonical_block.number();
        info!(canonical_number, "captured canonical block after first processing");
        let canonical_hash = canonical_block.hash();

        // Re-process the same proposal via the derivation pipeline.
        let blob_source =
            Arc::new(BlobDataSource::new(Some(beacon_endpoint.clone()), None, false).await?);
        let pipeline =
            ShastaDerivationPipeline::new(driver_client.clone(), blob_source, U256::ZERO).await?;
        let applier: &(dyn PayloadApplier + Send + Sync) = &driver_client;
        let _outcomes = pipeline
            .process_proposal(&proposal_log, applier)
            .await
            .context("re-processing proposal for known-canonical path")?;
        let canonical_block_after = driver_client
            .l2_provider
            .get_block_by_number(alloy_eips::BlockNumberOrTag::Latest)
            .await?
            .ok_or_else(|| anyhow!("missing canonical block after reprocess"))?;

        ensure!(
            canonical_block_after.number() == canonical_number,
            "reprocessing should not change canonical head"
        );
        ensure!(
            canonical_block_after.hash() == canonical_hash,
            "canonical block hash should remain unchanged"
        );

        Ok(())
    }
    .await;

    syncer.finish(result).await
}

/// Tests processing multiple sequential proposals.
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn multiple_proposals_event_sync(env: &mut ShastaEnv) -> Result<()> {
    let beacon_stub = BeaconStubServer::start().await?;
    let proposer = proposer_client(env).await?;

    let first_request = build_empty_proposal(env, &proposer).await?;
    beacon_stub.set_default_blob_sidecar(first_request.blob_sidecar());

    let (mut syncer, driver_client) = start_event_syncer(env, &beacon_stub).await?;

    let result: Result<()> = async {
        let l2_head_before = driver_client.l2_provider.get_block_number().await?;

        // Submit first proposal.
        let first_baseline = batch_row_baseline(&driver_client).await?;
        let (proposal_id_1, _) = submit_proposal(env, first_request).await?;
        ensure!(
            proposal_id_1 == first_baseline.proposal_id,
            "proposal id diverged from core state"
        );
        let l2_head_after_first = wait_for_proposal_processed(
            &mut syncer,
            &driver_client,
            &first_baseline,
            l2_head_before,
            PROPOSAL_PROCESSED_TIMEOUT,
        )
        .await?;

        // Rebuild the second proposal from the advanced chain heads: reusing the first
        // request verbatim would fail manifest timestamp validation (parent timestamp
        // already equals the manifest's) and silently exercise the default-manifest
        // fallback path instead of a second real derivation.
        //
        // Append (rather than replace) the second sidecar: a scanner reconnect replays the
        // reorg-unsafe window, and re-fetching proposal 1's blob must keep succeeding —
        // consumers hash-match against every returned sidecar.
        let second_request = build_empty_proposal(env, &proposer).await?;
        beacon_stub.add_default_blob_sidecar(second_request.blob_sidecar());

        let second_baseline = batch_row_baseline(&driver_client).await?;
        let (proposal_id_2, _) = submit_proposal(env, second_request).await?;
        ensure!(
            proposal_id_2 == second_baseline.proposal_id,
            "proposal id diverged from core state"
        );
        let l2_head_after_second = wait_for_proposal_processed(
            &mut syncer,
            &driver_client,
            &second_baseline,
            l2_head_after_first,
            PROPOSAL_PROCESSED_TIMEOUT,
        )
        .await?;

        ensure!(proposal_id_2 > proposal_id_1, "expected sequential proposal ids");
        ensure!(
            l2_head_after_second > l2_head_after_first,
            "L2 head should advance after second proposal"
        );

        Ok(())
    }
    .await;

    syncer.finish(result).await
}

/// Tests direct derivation-pipeline processing of a proposal whose blob is served for
/// its exact beacon slot (unlike the syncer tests above, which use the stub's default
/// sidecar for all slots).
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn derivation_pipeline_processes_proposal_with_slot_targeted_blob(
    env: &mut ShastaEnv,
) -> Result<()> {
    let beacon_stub = BeaconStubServer::start().await?;
    let proposer = proposer_client(env).await?;

    let request = build_empty_proposal(env, &proposer).await?;
    let sidecar = request.blob_sidecar();

    let (proposal_id, proposal_log) = submit_proposal(env, request).await?;
    info!(proposal_id, "submitted proposal for slot-targeted derivation");

    // Inject the sidecar only for the L1 slot that actually carries the proposal.
    let block_number = proposal_log.block_number.context("proposal log missing block number")?;
    let block = proposer
        .l1_provider
        .get_block_by_number(block_number.into())
        .await?
        .context("missing block for proposal receipt")?;
    let slot = BeaconStubServer::timestamp_to_slot(block.header.timestamp);
    beacon_stub.add_blob_sidecar(slot, sidecar);

    let driver_client = Client::new(env.client_config.clone()).await?;
    let blob_source =
        Arc::new(BlobDataSource::new(Some(beacon_stub.endpoint().clone()), None, false).await?);
    let pipeline =
        ShastaDerivationPipeline::new(driver_client.clone(), blob_source, U256::ZERO).await?;

    let l2_head_before = driver_client.l2_provider.get_block_number().await?;

    let applier: &(dyn PayloadApplier + Send + Sync) = &driver_client;
    let outcomes = pipeline
        .process_proposal(&proposal_log, applier)
        .await
        .context("processing proposal through derivation pipeline")?;
    ensure!(!outcomes.is_empty(), "derivation pipeline returned no block outcomes");

    let l2_head_after = driver_client.l2_provider.get_block_number().await?;
    let max_outcome_block =
        outcomes.iter().map(|outcome| outcome.block_number()).max().unwrap_or(l2_head_before);
    ensure!(
        l2_head_after >= max_outcome_block,
        "expected L2 head to include derived proposal blocks"
    );

    verify_anchor_block(&driver_client, env.taiko_anchor_address)
        .await
        .context("verifying anchor block on L2")?;

    Ok(())
}

#[cfg(test)]
mod lifecycle_tests {
    use std::future::pending;

    use tokio::sync::oneshot;

    use super::*;

    struct DropSignal(Option<oneshot::Sender<()>>);

    impl Drop for DropSignal {
        fn drop(&mut self) {
            if let Some(sender) = self.0.take() {
                let _ = sender.send(());
            }
        }
    }

    #[test_log::test(tokio::test)]
    async fn observed_syncer_exit_can_be_shutdown_without_repolling() -> Result<()> {
        let mut task = SyncerTask::new(spawn(async { Err(anyhow!("syncer failed")) }));

        let err = task.wait_for_exit("before readiness").await;
        ensure!(err.to_string().contains("before readiness"));
        task.shutdown().await?;

        Ok(())
    }

    #[test_log::test(tokio::test)]
    async fn syncer_shutdown_waits_for_cancellation() -> Result<()> {
        let (started_tx, started_rx) = oneshot::channel();
        let (dropped_tx, dropped_rx) = oneshot::channel();
        let task = spawn(async move {
            let _drop_signal = DropSignal(Some(dropped_tx));
            let _ = started_tx.send(());
            pending::<()>().await;
            Ok(())
        });
        let task = SyncerTask::new(task);

        started_rx.await?;
        task.shutdown().await?;
        dropped_rx.await?;

        Ok(())
    }

    #[test_log::test(tokio::test)]
    async fn syncer_exit_wins_over_pending_operation() -> Result<()> {
        let mut task = SyncerTask::new(spawn(async { Err(anyhow!("syncer failed")) }));

        let err =
            task.race(pending::<()>(), "while waiting for proposal processing").await.unwrap_err();
        ensure!(err.to_string().contains("while waiting for proposal processing"));

        Ok(())
    }
}

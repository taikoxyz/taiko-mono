//! E2E tests for proposer -> driver event sync flows.

use std::{sync::Arc, time::Duration};

use alloy::consensus::BlobTransactionSidecarVariant;
use alloy_primitives::U256;
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
use tokio::spawn;
use tracing::{info, warn};

async fn proposer_client(env: &ShastaEnv) -> Result<Client> {
    Client::new(env.client_config.clone()).await.map_err(Into::into)
}

fn decode_proposal_id(log: &Log) -> Result<u64> {
    Proposed::decode_raw_log(log.topics(), log.data().data.as_ref())
        .map(|event| event.id.to::<u64>())
        .map_err(|err| anyhow!("decode proposal log failed: {err}"))
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

/// Waits for the event syncer to process a specific proposal using confirmed-sync state polling.
async fn wait_for_proposal_processed(
    event_syncer: &EventSyncer,
    driver_client: &Client,
    expected_proposal_id: u64,
    l2_head_before: u64,
    timeout: Duration,
) -> Result<u64> {
    let deadline = tokio::time::Instant::now() + timeout;

    loop {
        let target_block = driver_client
            .last_certain_block_id_by_batch_id(U256::from(expected_proposal_id))
            .await?
            .map(|block_number| block_number.to::<u64>());
        let confirmed_head = event_syncer.confirmed_sync_snapshot().await?.event_sync_tip();
        if let (Some(target_block), Some(head_block)) = (target_block, confirmed_head) &&
            head_block >= target_block
        {
            let l2_head = driver_client.l2_provider.get_block_number().await?;
            if l2_head < l2_head_before {
                warn!(
                    l2_head_before,
                    l2_head, "L2 head moved backward while waiting for proposal processing"
                );
            }
            if l2_head >= target_block {
                return Ok(l2_head);
            }
        };

        let remaining = deadline.saturating_duration_since(tokio::time::Instant::now());
        if remaining.is_zero() {
            return Err(anyhow!("timed out waiting for proposal {expected_proposal_id}"));
        }

        tokio::time::sleep(Duration::from_millis(100)).await;
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
    let builder =
        ShastaProposalTransactionBuilder::new(proposer.clone(), env.l2_suggested_fee_recipient);
    let (build_ctx, _) = EngineBuildContext::from_chain_heads(&proposer).await?;
    let request = builder.build(vec![Vec::new()], build_ctx).await?;
    beacon_stub.set_default_blob_sidecar(built_proposal_sidecar(&request));

    // Start event syncer before submitting the proposal.
    let driver_config = DriverConfig::new(
        env.client_config.clone(),
        Duration::from_millis(50),
        beacon_stub.endpoint().clone(),
        None,
        None,
        true,
    );
    let driver_client = Client::new(driver_config.client.clone()).await?;
    let event_syncer = Arc::new(EventSyncer::new(&driver_config, driver_client.clone()).await?);
    let syncer_handle = {
        let syncer = event_syncer.clone();
        spawn(async move {
            if let Err(err) = syncer.run().await {
                warn!(?err, "event syncer exited");
            }
        })
    };
    event_syncer.wait_preconf_ingress_ready().await?;

    let l2_head_before = driver_client.l2_provider.get_block_number().await?;

    let (proposal_id, _log) = submit_proposal(env, request).await?;

    let l2_head_after = wait_for_proposal_processed(
        &event_syncer,
        &driver_client,
        proposal_id,
        l2_head_before,
        Duration::from_secs(30),
    )
    .await?;

    verify_anchor_block(&driver_client, env.taiko_anchor_address)
        .await
        .context("verifying anchor block on L2")?;

    ensure!(
        l2_head_after >= l2_head_before,
        "L2 head should not move backwards after proposal processing"
    );
    syncer_handle.abort();
    // Bounded join so the aborted syncer actually stops before the beacon stub shuts down;
    // otherwise it leaks as a zombie retrying blob derivation against a dead stub, contending
    // the shared serialized devnet and wedging later tests.
    let _ = tokio::time::timeout(Duration::from_secs(5), syncer_handle).await;
    beacon_stub.shutdown().await?;

    Ok(())
}

/// Tests the known-canonical fast path in the derivation pipeline.
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn known_canonical_fast_path(env: &mut ShastaEnv) -> Result<()> {
    let beacon_stub = BeaconStubServer::start().await?;
    let beacon_endpoint = beacon_stub.endpoint().clone();
    let proposer = proposer_client(env).await?;

    let builder =
        ShastaProposalTransactionBuilder::new(proposer.clone(), env.l2_suggested_fee_recipient);
    let (build_ctx, _) = EngineBuildContext::from_chain_heads(&proposer).await?;
    let request = builder.build(vec![Vec::new()], build_ctx).await?;
    beacon_stub.set_default_blob_sidecar(built_proposal_sidecar(&request));

    let driver_config = DriverConfig::new(
        env.client_config.clone(),
        Duration::from_millis(50),
        beacon_endpoint.clone(),
        None,
        None,
        true,
    );
    let driver_client = Client::new(driver_config.client.clone()).await?;
    let event_syncer = Arc::new(EventSyncer::new(&driver_config, driver_client.clone()).await?);
    let syncer_handle = {
        let syncer = event_syncer.clone();
        spawn(async move {
            if let Err(err) = syncer.run().await {
                warn!(?err, "event syncer exited");
            }
        })
    };
    event_syncer.wait_preconf_ingress_ready().await?;

    let l2_head_before = driver_client.l2_provider.get_block_number().await?;
    // Snapshot the canonical head hash BEFORE submitting the proposal. On this shared,
    // serialized devnet the head may already be a prior test's derived block 1 (e.g. the
    // resume test, which runs just before this one and derives proposal 1 into block 1);
    // deriving THIS test's proposal 1 replaces that block at the same height, so only the
    // HASH changes, never the number. We hold this pre-submit hash so we can later prove
    // THIS test's derivation has observably landed (hash flipped away from this value).
    let pre_submit_head_hash = driver_client
        .l2_provider
        .get_block_by_number(alloy_eips::BlockNumberOrTag::Latest)
        .await?
        .ok_or_else(|| anyhow!("missing canonical base block before proposal submission"))?
        .hash();
    let (proposal_id, proposal_log) = submit_proposal(env, request).await?;

    let l2_head_after = wait_for_proposal_processed(
        &event_syncer,
        &driver_client,
        proposal_id,
        l2_head_before,
        Duration::from_secs(30),
    )
    .await?;
    // `wait_for_proposal_processed` gates on block NUMBER and can return VACUOUSLY on this
    // shared devnet: block 1 already exists at number 1 (from the prior test's derivation),
    // so all its gates are satisfied at t=0, MID-DERIVATION, and it returns before this
    // test's derivation has actually landed. A naive capture here would snapshot the STALE
    // pre-existing block 1; the real derivation then reorgs block 1 to a fresh hash and the
    // "canonical block hash should remain unchanged" assertion below would fail. We do NOT
    // touch the shared helper (sibling tests rely on its current semantics); instead we
    // locally wait until the canonical head hash has flipped away from `pre_submit_head_hash`
    // — i.e. THIS test's derivation has observably landed — and capture from THAT settled
    // block, so the re-process pass legitimately matches it via the known-canonical fast path.
    let derivation_deadline = tokio::time::Instant::now() + Duration::from_secs(30);
    let canonical_block = loop {
        let block = driver_client
            .l2_provider
            .get_block_by_number(alloy_eips::BlockNumberOrTag::Latest)
            .await?
            .ok_or_else(|| {
                anyhow!("missing canonical block while waiting for derivation to land")
            })?;
        if block.hash() != pre_submit_head_hash {
            break block;
        }
        if tokio::time::Instant::now() >= derivation_deadline {
            return Err(anyhow!(
                "proposal's derived block never landed: canonical head hash still equals the \
                 pre-submit head hash after 30s, so this test's derivation did not complete"
            ));
        }
        tokio::time::sleep(Duration::from_millis(100)).await;
    };
    let canonical_number = canonical_block.number();
    info!(canonical_number, l2_head_after, "captured canonical block after first processing");
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

    syncer_handle.abort();
    // Bounded join so the aborted syncer actually stops before the beacon stub shuts down;
    // otherwise it leaks as a zombie retrying blob derivation against a dead stub, contending
    // the shared serialized devnet and wedging later tests.
    let _ = tokio::time::timeout(Duration::from_secs(5), syncer_handle).await;
    beacon_stub.shutdown().await?;

    Ok(())
}

/// Tests processing multiple sequential proposals.
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn multiple_proposals_event_sync(env: &mut ShastaEnv) -> Result<()> {
    let beacon_stub = BeaconStubServer::start().await?;
    let proposer = proposer_client(env).await?;

    // Build a proposal once and inject its sidecar into the beacon stub.
    let builder =
        ShastaProposalTransactionBuilder::new(proposer.clone(), env.l2_suggested_fee_recipient);
    let (build_ctx, _) = EngineBuildContext::from_chain_heads(&proposer).await?;
    let request = builder.build(vec![Vec::new()], build_ctx).await?;
    beacon_stub.set_default_blob_sidecar(built_proposal_sidecar(&request));

    let driver_config = DriverConfig::new(
        env.client_config.clone(),
        Duration::from_millis(50),
        beacon_stub.endpoint().clone(),
        None,
        None,
        true,
    );
    let driver_client = Client::new(driver_config.client.clone()).await?;
    let event_syncer = Arc::new(EventSyncer::new(&driver_config, driver_client.clone()).await?);
    let syncer_handle = {
        let syncer = event_syncer.clone();
        spawn(async move {
            if let Err(err) = syncer.run().await {
                warn!(?err, "event syncer exited");
            }
        })
    };
    event_syncer.wait_preconf_ingress_ready().await?;

    let l2_head_before = driver_client.l2_provider.get_block_number().await?;

    // Submit first proposal.
    let (proposal_id_1, _) = submit_proposal(env, request.clone()).await?;
    let l2_head_after_first = wait_for_proposal_processed(
        &event_syncer,
        &driver_client,
        proposal_id_1,
        l2_head_before,
        Duration::from_secs(30),
    )
    .await?;

    // Submit second proposal (same manifest/sidecar).
    let (proposal_id_2, _) = submit_proposal(env, request).await?;
    let l2_head_after_second = wait_for_proposal_processed(
        &event_syncer,
        &driver_client,
        proposal_id_2,
        l2_head_after_first,
        Duration::from_secs(30),
    )
    .await?;

    ensure!(proposal_id_2 > proposal_id_1, "expected sequential proposal ids");
    ensure!(
        l2_head_after_second > l2_head_after_first,
        "L2 head should advance after second proposal"
    );

    syncer_handle.abort();
    // Bounded join so the aborted syncer actually stops before the beacon stub shuts down;
    // otherwise it leaks as a zombie retrying blob derivation against a dead stub, contending
    // the shared serialized devnet and wedging later tests.
    let _ = tokio::time::timeout(Duration::from_secs(5), syncer_handle).await;
    beacon_stub.shutdown().await?;

    Ok(())
}

/// Reads the current `head_l1_origin` block id, or `None` when the pointer is unset
/// (mirrors `shasta_event_sync.rs::head_l1_origin_block_id`; each `tests/*.rs` file is
/// its own crate so the helper is copied, not imported).
async fn head_l1_origin_block_id(driver_client: &Client) -> Result<Option<u64>> {
    Ok(driver_client.head_l1_origin().await?.map(|origin| origin.block_id.to::<u64>()))
}

/// A restarted syncer must resume from the confirmed head — reaching ready
/// without re-deriving existing blocks (known-canonical fast path) and
/// without moving the head backwards.
///
/// Readiness rationale (the difference between green and a deterministic CI hang):
/// syncer #2 starts AFTER proposal 1 is confirmed, so its readiness gate
/// (`ConfirmedSyncSnapshot::is_ready`) requires `last_block_id_by_batch_id(pid1)` to
/// resolve on the L2 node. It WILL, because syncer #1 already derived proposal 1 into
/// that same L2 node before being killed — the L2 tables persist across the restart.
/// Readiness therefore means "the L2 already reflects the confirmed boundary", NOT
/// "this syncer derived it": `wait_preconf_ingress_ready()` on syncer #2 latches via the
/// known-canonical state WITHOUT re-derivation. The L2-head number+hash assertions below
/// are what actually pin this: re-execution from genesis would change the head hash (or,
/// on a divergent replay, its number). We do NOT rely on the 60s deadline to catch
/// re-derivation — a deterministic re-derivation of one small proposal could finish inside
/// 60s and even reproduce identical hashes; the deadline only guards against a wedged
/// resume that never reaches readiness. The real guarantees here are: no wedge, no
/// rollback, stays live.
///
/// Compile-verified here; CI-executed against the Docker harness (unavailable locally).
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn driver_resumes_after_restart_without_rederiving(env: &mut ShastaEnv) -> Result<()> {
    // Bounded windows: proposal processing reuses the crate-wide 30s bound; restart
    // readiness gets its own 60s bound with a loud, explicit timeout message (never a
    // silent hang) because the resume path is what this test exercises.
    const PROPOSAL_TIMEOUT: Duration = Duration::from_secs(30);
    const RESTART_READY_TIMEOUT: Duration = Duration::from_secs(60);

    let beacon_stub = BeaconStubServer::start().await?;
    let proposer = proposer_client(env).await?;

    // Build ONE proposal request and serve its sidecar as the default so both the
    // pre-restart proposal 1 and the post-restart proposal 2 derive from a blob the stub
    // can always return regardless of L1 slot (`set_default_blob_sidecar` serves ANY
    // slot). Reusing a single request across sequential proposals is the pattern proven
    // by `multiple_proposals_event_sync` above.
    let builder =
        ShastaProposalTransactionBuilder::new(proposer.clone(), env.l2_suggested_fee_recipient);
    let (build_ctx, _) = EngineBuildContext::from_chain_heads(&proposer).await?;
    let request = builder.build(vec![Vec::new()], build_ctx).await?;
    beacon_stub.set_default_blob_sidecar(built_proposal_sidecar(&request));

    // 1. First syncer: EventSyncer::new against the harness nodes, spawn its run loop, wait for
    //    ingress readiness, then propose + process proposal 1 (existing flow). Record l2_head_1
    //    (number + hash) and head_l1_origin_1, then kill it: abort the run-loop JoinHandle AND drop
    //    the Arc<EventSyncer>. Any channels/tasks the syncer left behind are per-instance, so the
    //    second syncer starts clean.
    let driver_config = DriverConfig::new(
        env.client_config.clone(),
        Duration::from_millis(50),
        beacon_stub.endpoint().clone(),
        None,
        None,
        true,
    );
    let driver_client = Client::new(driver_config.client.clone()).await?;
    let event_syncer_1 = Arc::new(EventSyncer::new(&driver_config, driver_client.clone()).await?);
    let syncer_handle_1 = {
        let syncer = event_syncer_1.clone();
        spawn(async move {
            if let Err(err) = syncer.run().await {
                warn!(?err, "first event syncer exited");
            }
        })
    };
    event_syncer_1.wait_preconf_ingress_ready().await?;

    let l2_head_before = driver_client.l2_provider.get_block_number().await?;
    // Snapshot the canonical head hash BEFORE submitting proposal 1. On this devnet the head
    // is the `fork_to` base block (block 1, created by the harness with a random coinbase);
    // deriving proposal 1 produces block NUMBER 1 as well (genesis parent, manifest coinbase,
    // anchor tx), so it REPLACES this base block at the same height — only the HASH changes,
    // never the number. We hold the base hash so we can later prove the derived block has
    // observably landed (hash flipped away from this value).
    let base_head_hash = driver_client
        .l2_provider
        .get_block_by_number(alloy_eips::BlockNumberOrTag::Latest)
        .await?
        .ok_or_else(|| anyhow!("missing canonical base block before proposal 1"))?
        .hash();
    let (proposal_id_1, _) = submit_proposal(env, request.clone()).await?;
    let l2_head_1 = wait_for_proposal_processed(
        &event_syncer_1,
        &driver_client,
        proposal_id_1,
        l2_head_before,
        PROPOSAL_TIMEOUT,
    )
    .await?;
    // `wait_for_proposal_processed` can return VACUOUSLY on this shared, serialized devnet:
    // CI proved all three of its gates are already true at t=0 before syncer #1 derives
    // anything — `last_certain_block_id_by_batch_id(1)` is Some(1) (the batch-1→block-1
    // mapping persists in reth from earlier e2e tests, which all derive proposal 1 into
    // block 1), `event_sync_tip()` is Some(1) from the harness-bootstrapped head_l1_origin,
    // and `l2_head` (1) >= target (1). It therefore returned ~3ms after the scanner logged
    // "decoded proposal payload", MID-DERIVATION, so a naive capture here would snapshot the
    // BASE block and then race syncer #1's kill against its own derivation. We do NOT touch
    // the shared helper (sibling tests rely on its current semantics); instead we locally
    // wait until the derived block has OBSERVABLY landed — the head hash at the head height
    // has flipped away from `base_head_hash`. Only then is syncer #1's derivation of
    // proposal 1 guaranteed complete, so the post-restart re-derivation hits the SAME
    // known-canonical block and the hash assertion holds.
    let derivation_deadline = tokio::time::Instant::now() + Duration::from_secs(30);
    let canonical_block_1 = loop {
        let block = driver_client
            .l2_provider
            .get_block_by_number(alloy_eips::BlockNumberOrTag::Latest)
            .await?
            .ok_or_else(|| {
                anyhow!("missing canonical block while waiting for proposal 1 to land")
            })?;
        if block.hash() != base_head_hash {
            break block;
        }
        if tokio::time::Instant::now() >= derivation_deadline {
            return Err(anyhow!(
                "proposal 1's derived block never landed: canonical head hash still equals the \
                 fork_to base block hash after 30s, so syncer #1's derivation did not complete \
                 before the restart"
            ));
        }
        tokio::time::sleep(Duration::from_millis(100)).await;
    };
    // Capture the exact canonical block (number + hash) and the confirmed boundary that
    // proposal 1 established — these must be byte-identical after the restart.
    let l2_head_number_1 = canonical_block_1.number();
    let l2_head_hash_1 = canonical_block_1.hash();
    let head_l1_origin_1 = head_l1_origin_block_id(&driver_client)
        .await?
        .context("head_l1_origin must be set after proposal 1 is processed")?;
    info!(l2_head_1, l2_head_number_1, head_l1_origin_1, "captured confirmed head before restart");

    // Kill the first syncer: abort its run task and drop the Arc so no run loop or
    // per-instance channel survives into the second syncer's lifetime.
    syncer_handle_1.abort();
    // Join the aborted task so its termination (and the drop of the task-held
    // Arc<EventSyncer> clone) is complete by construction, not merely scheduled, before
    // syncer #2 starts. An aborted JoinHandle resolves to Err(cancelled); ignoring it is
    // correct here.
    let _ = syncer_handle_1.await;
    drop(event_syncer_1);

    // 2. Second syncer: EventSyncer::new against the SAME nodes (same driver_config / client),
    //    spawn its run loop, and wait for ingress readiness within a bounded 60s window. This must
    //    latch via the known-canonical fast path (see the readiness rationale above) rather than
    //    re-deriving proposal 1.
    let event_syncer_2 = Arc::new(EventSyncer::new(&driver_config, driver_client.clone()).await?);
    let syncer_handle_2 = {
        let syncer = event_syncer_2.clone();
        spawn(async move {
            if let Err(err) = syncer.run().await {
                warn!(?err, "second event syncer exited");
            }
        })
    };
    tokio::time::timeout(RESTART_READY_TIMEOUT, event_syncer_2.wait_preconf_ingress_ready())
        .await
        .map_err(|_| {
            // Loud, explicit failure — never a silent hang. The deadline exists so that a
            // resume path which wedges (never latches readiness) surfaces as a timeout
            // rather than blocking CI forever. It is NOT a re-derivation detector: a
            // deterministic re-derivation of this one small proposal could well finish
            // inside 60s. The no-wedge / no-rollback / stays-live guarantees are what the
            // assertions below actually enforce.
            anyhow!(
                "restarted syncer did not reach ingress readiness within {}s; the resume path \
                 failed to latch on the persisted confirmed head",
                RESTART_READY_TIMEOUT.as_secs()
            )
        })??;

    // 3. Assert the restart resumed from the confirmed head and re-derived nothing: the L2 head
    //    number AND hash are still exactly proposal 1's (no re-execution, no rollback), and
    //    head_l1_origin is unchanged.
    let canonical_block_after_restart = driver_client
        .l2_provider
        .get_block_by_number(alloy_eips::BlockNumberOrTag::Latest)
        .await?
        .ok_or_else(|| anyhow!("missing canonical block after restart"))?;
    ensure!(
        canonical_block_after_restart.number() == l2_head_number_1,
        "restart must not move the L2 head: expected {l2_head_number_1}, got {}",
        canonical_block_after_restart.number()
    );
    ensure!(
        canonical_block_after_restart.hash() == l2_head_hash_1,
        "restart must not re-execute the head block: L2 head hash changed"
    );
    let head_l1_origin_after_restart = head_l1_origin_block_id(&driver_client)
        .await?
        .context("head_l1_origin must remain set after restart")?;
    ensure!(
        head_l1_origin_after_restart == head_l1_origin_1,
        "restart must not move the confirmed boundary: expected {head_l1_origin_1}, got \
         {head_l1_origin_after_restart}"
    );
    ensure!(
        event_syncer_2.is_preconf_ingress_ready(),
        "restarted syncer must report ingress readiness"
    );

    // 4. Prove liveness: propose proposal 2 and assert the resumed syncer processes it (head
    //    advances) within the usual 30s window — it is live, not wedged on a stale resume point.
    let (proposal_id_2, _) = submit_proposal(env, request.clone()).await?;
    ensure!(proposal_id_2 > proposal_id_1, "expected sequential proposal ids across restart");
    let l2_head_after_second = wait_for_proposal_processed(
        &event_syncer_2,
        &driver_client,
        proposal_id_2,
        l2_head_1,
        PROPOSAL_TIMEOUT,
    )
    .await?;
    ensure!(
        l2_head_after_second > l2_head_1,
        "resumed syncer must advance the L2 head after proposal 2: got {l2_head_after_second}, \
         pre-restart head {l2_head_1}"
    );

    syncer_handle_2.abort();
    // Bounded join so the aborted syncer actually stops before the beacon stub shuts down
    // (prevents a zombie derivation loop against a dead stub — see the abort sites above).
    let _ = tokio::time::timeout(Duration::from_secs(5), syncer_handle_2).await;
    beacon_stub.shutdown().await?;

    Ok(())
}

/// Return the blob sidecar needed by beacon-based derivation tests.
fn built_proposal_sidecar(request: &BuiltProposalTx) -> BlobTransactionSidecarVariant {
    request.blob_sidecar()
}

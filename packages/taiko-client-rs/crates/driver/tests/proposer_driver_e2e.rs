//! E2E tests for proposer -> driver event sync flows.

use std::{sync::Arc, time::Duration};

use alloy_primitives::U256;
use alloy_provider::Provider;
use alloy_rpc_types::{Log, TransactionRequest};
use alloy_sol_types::SolEvent;
use anyhow::{Context, Result, anyhow, ensure};
use bindings::inbox::Inbox::Proposed;
use driver::{
    DriverConfig,
    derivation::{DerivationPipeline, ShastaDerivationPipeline},
    sync::{SyncStage, engine::PayloadApplier, event::EventSyncer},
};
use proposer::transaction_builder::ShastaProposalTransactionBuilder;
use rpc::{
    blob::BlobDataSource,
    client::{Client, ClientConfig, ClientWithWallet},
};
use serial_test::serial;
use test_context::test_context;
use test_harness::{BeaconStubServer, ShastaEnv, verify_anchor_block};
use tokio::spawn;
use tracing::warn;

fn client_config(env: &ShastaEnv) -> ClientConfig {
    ClientConfig {
        l1_provider_source: env.l1_source.clone(),
        l2_provider_url: env.l2_ws_0.clone(),
        l2_auth_provider_url: env.l2_auth_0.clone(),
        jwt_secret: env.jwt_secret.clone(),
        inbox_address: env.inbox_address,
    }
}

async fn proposer_client(env: &ShastaEnv) -> Result<ClientWithWallet> {
    Client::new_with_wallet(client_config(env), env.l1_proposer_private_key)
        .await
        .map_err(Into::into)
}

fn decode_proposal_id(log: &Log) -> Result<u64> {
    Proposed::decode_raw_log(log.topics(), log.data().data.as_ref())
        .map(|event| event.id.to::<u64>())
        .map_err(|err| anyhow!("decode proposal log failed: {err}"))
}

/// Submits a proposal transaction and returns the proposal ID and log.
async fn submit_proposal(
    proposer: &ClientWithWallet,
    request: TransactionRequest,
    inbox: alloy_primitives::Address,
) -> Result<(u64, Log)> {
    let pending_tx = proposer.l1_provider.send_transaction(request).await?;
    let receipt = pending_tx.get_receipt().await?;
    ensure!(receipt.status(), "proposal transaction failed");
    let proposal_log: Log = receipt
        .logs()
        .iter()
        .find(|log| log.address() == inbox)
        .cloned()
        .context("missing Proposed log in receipt")?;
    let proposal_id = decode_proposal_id(&proposal_log)?;
    Ok((proposal_id, proposal_log))
}

/// Waits for the event syncer to process a specific proposal using confirmed-sync state polling.
async fn wait_for_proposal_processed<P>(
    event_syncer: &EventSyncer<P>,
    driver_client: &Client<P>,
    expected_proposal_id: u64,
    l2_head_before: u64,
    timeout: Duration,
) -> Result<u64>
where
    P: Provider + Clone + 'static,
{
    let deadline = tokio::time::Instant::now() + timeout;

    loop {
        let target_block = driver_client
            .last_block_id_by_batch_id(U256::from(expected_proposal_id))
            .await?
            .map(|block_number| block_number.to::<u64>());
        let confirmed_head = event_syncer.confirmed_sync_snapshot().await?.event_sync_tip();
        if matches!(
            (target_block, confirmed_head),
            (Some(target_block), Some(head_block)) if head_block >= target_block
        ) {
            let l2_head = driver_client.l2_provider.get_block_number().await?;
            if l2_head < l2_head_before {
                warn!(
                    l2_head_before,
                    l2_head, "L2 head moved backward while waiting for proposal processing"
                );
            }
            return Ok(l2_head);
        }

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
    let request = builder.build(vec![Vec::new()], None).await?;
    let sidecar =
        request.sidecar.clone().context("expected blob sidecar for proposal transaction")?;
    beacon_stub.set_default_blob_sidecar(sidecar);

    // Start event syncer before submitting the proposal.
    let driver_config = DriverConfig::new(
        client_config(env),
        Duration::from_millis(50),
        beacon_stub.endpoint().clone(),
        None,
        None,
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

    let l2_head_before = driver_client.l2_provider.get_block_number().await?;

    let (proposal_id, _log) = submit_proposal(&proposer, request, env.inbox_address).await?;

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
    let request = builder.build(vec![Vec::new()], None).await?;
    let sidecar =
        request.sidecar.clone().context("expected blob sidecar for proposal transaction")?;
    beacon_stub.set_default_blob_sidecar(sidecar);

    let driver_config = DriverConfig::new(
        client_config(env),
        Duration::from_millis(50),
        beacon_endpoint.clone(),
        None,
        None,
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

    let l2_head_before = driver_client.l2_provider.get_block_number().await?;
    let (proposal_id, proposal_log) =
        submit_proposal(&proposer, request, env.inbox_address).await?;

    let _l2_head_after = wait_for_proposal_processed(
        &event_syncer,
        &driver_client,
        proposal_id,
        l2_head_before,
        Duration::from_secs(30),
    )
    .await?;
    // Capture the canonical block hash produced by the first processing.
    let canonical_block = driver_client
        .l2_provider
        .get_block_by_number(alloy_eips::BlockNumberOrTag::Latest)
        .await?
        .ok_or_else(|| anyhow!("missing canonical block after proposal processing"))?;
    let canonical_number = canonical_block.number();
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
    let request = builder.build(vec![Vec::new()], None).await?;
    let sidecar =
        request.sidecar.clone().context("expected blob sidecar for proposal transaction")?;
    beacon_stub.set_default_blob_sidecar(sidecar);

    let driver_config = DriverConfig::new(
        client_config(env),
        Duration::from_millis(50),
        beacon_stub.endpoint().clone(),
        None,
        None,
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

    let l2_head_before = driver_client.l2_provider.get_block_number().await?;

    // Submit first proposal.
    let (proposal_id_1, _) = submit_proposal(&proposer, request.clone(), env.inbox_address).await?;
    let l2_head_after_first = wait_for_proposal_processed(
        &event_syncer,
        &driver_client,
        proposal_id_1,
        l2_head_before,
        Duration::from_secs(30),
    )
    .await?;

    // Submit second proposal (same manifest/sidecar).
    let (proposal_id_2, _) = submit_proposal(&proposer, request, env.inbox_address).await?;
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
    beacon_stub.shutdown().await?;

    Ok(())
}

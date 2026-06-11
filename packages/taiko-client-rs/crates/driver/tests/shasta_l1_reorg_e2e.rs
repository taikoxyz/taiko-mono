//! E2E test for L1 reorg detection and recovery in the event syncer.
//!
//! A proposal is orphaned by reverting anvil to a snapshot and mining a
//! replacement chain. The driver must observe the reorg, lower the confirmed
//! `head_l1_origin` boundary back to the last proposal that survived, and then
//! re-derive the replacement proposal onto the canonical L2 chain.

use std::{borrow::Cow, sync::Arc, time::Duration};

use alloy::rpc::client::NoParams;
use alloy_primitives::U256;
use alloy_provider::Provider;
use alloy_rpc_types::Log;
use alloy_sol_types::SolEvent;
use anyhow::{Context, Result, anyhow, ensure};
use bindings::inbox::Inbox::Proposed;
use driver::{
    DriverConfig,
    sync::{SyncStage, event::EventSyncer},
};
use proposer::transaction_builder::{BuiltProposalTx, ShastaProposalTransactionBuilder};
use rpc::client::{Client, ClientConfig, ClientWithWallet};
use serial_test::serial;
use test_context::test_context;
use test_harness::{BeaconStubServer, ShastaEnv};
use tokio::spawn;
use tracing::{info, warn};

/// Number of replacement L1 blocks mined after the revert so the new chain
/// clearly overtakes the orphaned one.
const REPLACEMENT_BLOCKS: usize = 8;

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

/// Submits a proposal transaction and returns the proposal ID.
///
/// Bounded by a hard deadline: a stale cached nonce (e.g. after an L1 revert)
/// parks the transaction in the pool forever, and `get_receipt` would otherwise
/// hang the test instead of failing it.
async fn submit_proposal(
    proposer: &ClientWithWallet,
    request: BuiltProposalTx,
    inbox: alloy_primitives::Address,
) -> Result<u64> {
    let receipt = tokio::time::timeout(Duration::from_secs(60), async {
        let pending_tx =
            proposer.l1_provider.send_transaction(request.to_transaction_request()).await?;
        anyhow::Ok(pending_tx.get_receipt().await?)
    })
    .await
    .context("proposal submission deadline exceeded")??;
    ensure!(receipt.status(), "proposal transaction failed");
    let proposal_log: Log = receipt
        .logs()
        .iter()
        .find(|log| log.address() == inbox)
        .cloned()
        .context("missing Proposed log in receipt")?;
    decode_proposal_id(&proposal_log)
}

/// Waits for the event syncer to process a specific proposal using confirmed-sync
/// state polling.
async fn wait_for_proposal_processed<P>(
    event_syncer: &EventSyncer<P>,
    driver_client: &Client<P>,
    expected_proposal_id: u64,
    timeout: Duration,
) -> Result<u64>
where
    P: Provider + Clone + 'static,
{
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
            if l2_head >= target_block {
                return Ok(l2_head);
            }
        }

        let remaining = deadline.saturating_duration_since(tokio::time::Instant::now());
        if remaining.is_zero() {
            return Err(anyhow!("timed out waiting for proposal {expected_proposal_id}"));
        }

        tokio::time::sleep(Duration::from_millis(100)).await;
    }
}

/// Reads the confirmed head L1 origin block id, if written.
async fn head_l1_origin_block_id<P>(client: &Client<P>) -> Result<Option<u64>>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    Ok(client.head_l1_origin().await?.map(|head| head.block_id.to::<u64>()))
}

/// Polls until `head_l1_origin` equals the expected block id.
async fn wait_for_head_l1_origin<P>(
    client: &Client<P>,
    expected: u64,
    timeout: Duration,
) -> Result<()>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    let deadline = tokio::time::Instant::now() + timeout;
    loop {
        let current = head_l1_origin_block_id(client).await?;
        if current == Some(expected) {
            return Ok(());
        }
        ensure!(
            tokio::time::Instant::now() < deadline,
            "timed out waiting for head_l1_origin {expected} (current {current:?})"
        );
        tokio::time::sleep(Duration::from_millis(200)).await;
    }
}

#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn l1_reorg_resets_head_l1_origin_and_rederives(env: &mut ShastaEnv) -> Result<()> {
    let beacon_stub = BeaconStubServer::start().await?;
    let proposer = proposer_client(env).await?;

    // One proposal payload reused for every submission so the default blob
    // sidecar serves all derivation fetches, before and after the reorg.
    let builder =
        ShastaProposalTransactionBuilder::new(proposer.clone(), env.l2_suggested_fee_recipient);
    let request = builder.build(vec![Vec::new()], None).await?;
    beacon_stub.set_default_blob_sidecar(request.blob_sidecar());

    let mut driver_config = DriverConfig::new(
        client_config(env),
        Duration::from_millis(50),
        beacon_stub.endpoint().clone(),
        None,
        None,
    );
    driver_config.preconfirmation_enabled = true;
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

    // Proposal 1 survives the reorg.
    let proposal_1 = submit_proposal(&proposer, request.clone(), env.inbox_address).await?;
    wait_for_proposal_processed(&event_syncer, &driver_client, proposal_1, Duration::from_secs(30))
        .await?;
    let origin_after_p1 = head_l1_origin_block_id(&driver_client)
        .await?
        .context("head_l1_origin missing after proposal 1")?;
    info!(proposal_1, origin_after_p1, "proposal 1 derived");

    // Snapshot L1, then land proposal 2 on the branch that will be orphaned.
    let snapshot_id: String = driver_client
        .l1_provider
        .raw_request(Cow::Borrowed("evm_snapshot"), NoParams::default())
        .await
        .context("creating L1 snapshot")?;

    let proposal_2 = submit_proposal(&proposer, request.clone(), env.inbox_address).await?;
    wait_for_proposal_processed(&event_syncer, &driver_client, proposal_2, Duration::from_secs(30))
        .await?;
    let origin_after_p2 = head_l1_origin_block_id(&driver_client)
        .await?
        .context("head_l1_origin missing after proposal 2")?;
    ensure!(origin_after_p2 > origin_after_p1, "proposal 2 should advance the confirmed origin");
    info!(proposal_2, origin_after_p2, "proposal 2 derived on the soon-orphaned branch");

    // Orphan proposal 2: revert L1 and mine a longer replacement chain.
    let reverted: bool = driver_client
        .l1_provider
        .raw_request(Cow::Borrowed("evm_revert"), (&snapshot_id,))
        .await
        .context("reverting L1 snapshot")?;
    ensure!(reverted, "evm_revert returned false");
    let _: i64 = driver_client
        .l1_provider
        .raw_request(Cow::Borrowed("evm_increaseTime"), (1u64,))
        .await
        .context("advancing L1 time")?;
    let _: () = driver_client
        .l1_provider
        .raw_request(Cow::Borrowed("anvil_mine"), (REPLACEMENT_BLOCKS,))
        .await
        .context("mining replacement L1 blocks")?;
    info!("L1 reverted and replacement chain mined; waiting for reorg recovery");

    // The driver must observe the reorg and lower the confirmed boundary back to
    // the last block of proposal 1.
    wait_for_head_l1_origin(&driver_client, origin_after_p1, Duration::from_secs(60)).await?;
    info!(origin_after_p1, "head_l1_origin reset to the surviving proposal");

    // Re-propose proposal 2 on the canonical chain. A fresh wallet client is
    // required because the revert rolled the proposer's on-chain nonce back while
    // the previous client's nonce filler still caches the pre-revert value.
    let proposer = proposer_client(env).await?;
    let proposal_2_again = submit_proposal(&proposer, request, env.inbox_address).await?;
    ensure!(
        proposal_2_again == proposal_2,
        "replacement proposal should reuse id {proposal_2} (got {proposal_2_again})"
    );
    wait_for_proposal_processed(
        &event_syncer,
        &driver_client,
        proposal_2_again,
        Duration::from_secs(30),
    )
    .await?;

    // Re-deriving the replacement must heal the confirmed boundary back to the
    // proposal-2 tip. Identical proposal content legitimately resolves through the
    // known-canonical fast path (the L2 block is content-addressed and the anchor
    // context survived below the snapshot), so block hashes are not compared here;
    // the boundary round-trip 2 -> 1 -> 2 is the behavior under test.
    wait_for_head_l1_origin(&driver_client, origin_after_p2, Duration::from_secs(30)).await?;
    let l2_head = driver_client.l2_provider.get_block_number().await?;
    ensure!(
        l2_head == origin_after_p2,
        "L2 head should match the re-derived proposal tip (head {l2_head}, expected {origin_after_p2})"
    );
    info!(
        replacement_tip = origin_after_p2,
        "confirmed boundary healed after re-deriving the replacement proposal"
    );

    syncer_handle.abort();
    beacon_stub.shutdown().await?;
    Ok(())
}

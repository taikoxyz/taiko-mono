//! E2E tests for the prover against the Shasta Docker harness.
//!
//! These run a driver (to derive L2 blocks), a proposer (to submit proposals),
//! and the prover in dummy mode (filler proofs accepted by the `DUMMY_VERIFIERS`
//! compose verifier). They assert that proposals get proven and finalized on L1.
//!
//! Requires the harness from `tests/entrypoint.sh`; run via `TEST_CRATE=prover
//! just test`.

use std::{sync::Arc, time::Duration};

use alloy_provider::Provider;
use anyhow::{Result, anyhow, ensure};
use driver::{
    DriverConfig,
    sync::{SyncStage, event::EventSyncer},
};
use proposer::transaction_builder::{BuiltProposalTx, ShastaProposalTransactionBuilder};
use prover::{config::ProverConfigs, prover::Prover};
use rpc::client::{Client, ClientWithWallet};
use serial_test::serial;
use test_context::test_context;
use test_harness::{BeaconStubServer, ShastaEnv};
use tokio::{spawn, task::JoinHandle};
use tracing::warn;

/// Build a wallet-bound proposer client.
async fn proposer_client(env: &ShastaEnv) -> Result<ClientWithWallet> {
    Client::new_with_wallet(env.client_config.clone(), env.l1_proposer_private_key)
        .await
        .map_err(Into::into)
}

/// Build a prover config in dummy mode (no raiko); proves every proposal.
fn prover_config(env: &ShastaEnv, sgx_batch_size: u64) -> ProverConfigs {
    ProverConfigs {
        l1_provider_source: env.client_config.l1_provider_source.clone(),
        l2_provider_url: env.client_config.l2_provider_url.clone(),
        l2_auth_provider_url: env.client_config.l2_auth_provider_url.clone(),
        jwt_secret: env.client_config.jwt_secret.clone(),
        inbox_address: env.inbox_address,
        l1_prover_private_key: env.l1_prover_private_key,
        // Unused in dummy mode, but the config requires a URL.
        raiko_host: "http://localhost:1".parse().expect("static url"),
        raiko_zkvm_host: None,
        raiko_api_key: None,
        raiko_request_timeout: Duration::from_secs(30),
        starting_proposal_id: None,
        prove_unassigned_proposals: true,
        proposal_window_size: 0,
        max_zk_proof_proposal_distance: 30,
        dummy: true,
        proof_polling_interval: Duration::from_millis(200),
        local_proposer_addresses: vec![],
        block_confirmations: 0,
        force_batch_proving_interval: Duration::from_secs(2),
        sgx_batch_size,
        zkvm_batch_size: 1,
        shadow_mode: false,
        retry_interval: Duration::from_secs(2),
        confirmation_timeout: Duration::from_secs(60),
        receipt_query_interval: Some(Duration::from_millis(200)),
        min_tip_cap_gwei: 1,
        min_base_fee_gwei: 1,
    }
}

/// Start the driver event syncer so proposals derive into L2 blocks.
async fn start_driver(env: &ShastaEnv, beacon: &BeaconStubServer) -> Result<JoinHandle<()>> {
    let mut driver_config = DriverConfig::new(
        env.client_config.clone(),
        Duration::from_millis(50),
        beacon.endpoint().clone(),
        None,
        None,
    );
    driver_config.preconfirmation_enabled = true;
    let driver_client = Client::new(driver_config.client.clone()).await?;
    let event_syncer = Arc::new(EventSyncer::new(&driver_config, driver_client.clone()).await?);
    let handle = {
        let syncer = event_syncer.clone();
        spawn(async move {
            if let Err(err) = syncer.run().await {
                warn!(?err, "event syncer exited");
            }
        })
    };
    event_syncer.wait_preconf_ingress_ready().await?;
    Ok(handle)
}

/// Submit a proposal and return its id.
async fn submit_proposal(proposer: &ClientWithWallet, request: BuiltProposalTx) -> Result<u64> {
    let pending = proposer.l1_provider.send_transaction(request.to_transaction_request()).await?;
    let receipt = pending.get_receipt().await?;
    ensure!(receipt.status(), "proposal transaction failed");
    let core_state = proposer.shasta.inbox.getCoreState().call().await?;
    // nextProposalId advanced to one past the just-submitted proposal.
    Ok(core_state.nextProposalId.to::<u64>().saturating_sub(1))
}

/// Poll until `lastFinalizedProposalId >= target` or the deadline elapses.
async fn wait_for_finalized(
    client: &ClientWithWallet,
    target: u64,
    timeout: Duration,
) -> Result<()> {
    let deadline = tokio::time::Instant::now() + timeout;
    loop {
        let core_state = client.shasta.inbox.getCoreState().call().await?;
        if core_state.lastFinalizedProposalId.to::<u64>() >= target {
            return Ok(());
        }
        if tokio::time::Instant::now() >= deadline {
            return Err(anyhow!(
                "timed out waiting for proposal {target} to finalize (last finalized {})",
                core_state.lastFinalizedProposalId
            ));
        }
        tokio::time::sleep(Duration::from_millis(250)).await;
    }
}

/// A single proposal is proven and finalized end-to-end.
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn single_proposal_is_proven(env: &mut ShastaEnv) -> Result<()> {
    let beacon = BeaconStubServer::start().await?;
    let proposer = proposer_client(env).await?;

    let builder =
        ShastaProposalTransactionBuilder::new(proposer.clone(), env.l2_suggested_fee_recipient);
    let request = builder.build(vec![Vec::new()], None).await?;
    beacon.set_default_blob_sidecar(request.blob_sidecar());

    let driver_handle = start_driver(env, &beacon).await?;

    let prover = Prover::new(prover_config(env, 1)).await?;
    let prover_handle = spawn(async move {
        if let Err(err) = prover.start().await {
            warn!(?err, "prover exited");
        }
    });

    let proposal_id = submit_proposal(&proposer, request).await?;
    wait_for_finalized(&proposer, proposal_id, Duration::from_secs(90)).await?;

    prover_handle.abort();
    driver_handle.abort();
    beacon.shutdown().await?;
    Ok(())
}

/// Two proposals aggregate into a single prove submission (`sgx_batch_size = 2`).
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn two_proposals_aggregate_and_finalize(env: &mut ShastaEnv) -> Result<()> {
    let beacon = BeaconStubServer::start().await?;
    let proposer = proposer_client(env).await?;

    let builder =
        ShastaProposalTransactionBuilder::new(proposer.clone(), env.l2_suggested_fee_recipient);
    let request = builder.build(vec![Vec::new()], None).await?;
    beacon.set_default_blob_sidecar(request.blob_sidecar());

    let driver_handle = start_driver(env, &beacon).await?;

    let prover = Prover::new(prover_config(env, 2)).await?;
    let prover_handle = spawn(async move {
        if let Err(err) = prover.start().await {
            warn!(?err, "prover exited");
        }
    });

    submit_proposal(&proposer, request.clone()).await?;
    let second_id = submit_proposal(&proposer, request).await?;
    wait_for_finalized(&proposer, second_id, Duration::from_secs(120)).await?;

    prover_handle.abort();
    driver_handle.abort();
    beacon.shutdown().await?;
    Ok(())
}

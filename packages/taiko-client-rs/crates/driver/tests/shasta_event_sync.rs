use std::{sync::Arc, time::Duration};

use alloy_primitives::U256;
use alloy_provider::Provider;
use alloy_rpc_types::Log;
use anyhow::{Context, Result, ensure};
use driver::{
    Driver, DriverConfig,
    derivation::{DerivationPipeline, ShastaDerivationPipeline},
    sync::engine::PayloadApplier,
};
use proposer::transaction_builder::ShastaProposalTransactionBuilder;
use rpc::{
    blob::BlobDataSource,
    client::{Client, ClientConfig},
};
use serial_test::serial;
use test_context::test_context;
use test_harness::{BeaconStubServer, ShastaEnv, verify_anchor_block};

#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test)]
async fn syncs_shasta_proposal_into_l2(env: &mut ShastaEnv) -> Result<()> {
    let proposer_client = Client::new_with_wallet(
        ClientConfig {
            l1_provider_source: env.l1_source.clone(),
            l2_provider_url: env.l2_http_0.clone(),
            l2_auth_provider_url: env.l2_auth_0.clone(),
            jwt_secret: env.jwt_secret.clone(),
            inbox_address: env.inbox_address,
        },
        env.l1_proposer_private_key,
    )
    .await?;

    let builder = ShastaProposalTransactionBuilder::new(
        proposer_client.clone(),
        env.l2_suggested_fee_recipient,
    );

    // Build a proposal with an empty transaction list to force an anchor-only block.
    let request = builder.build(vec![Vec::new()], None).await?;
    let sidecar =
        request.sidecar.clone().context("expected blob sidecar for proposal transaction")?;

    // Start beacon stub and inject the blob sidecar.
    let beacon_stub = BeaconStubServer::start().await?;
    let beacon_endpoint = beacon_stub.endpoint().clone();

    let pending_tx = proposer_client.l1_provider.send_transaction(request).await?;
    let receipt =
        pending_tx.get_receipt().await.context("fetching proposal transaction receipt")?;
    ensure!(receipt.status(), "proposal transaction failed");

    // Get the block timestamp to compute the slot for blob injection.
    let block = proposer_client
        .l1_provider
        .get_block_by_number(receipt.block_number.unwrap().into())
        .await?
        .context("missing block for proposal receipt")?;
    let slot = BeaconStubServer::timestamp_to_slot(block.header.timestamp);
    beacon_stub.add_blob_sidecar(slot, sidecar);

    let proposal_log: Log = receipt
        .logs()
        .iter()
        .find(|log| log.address() == env.inbox_address)
        .cloned()
        .context("missing Proposed log in receipt")?;

    let driver_config = DriverConfig::new(
        ClientConfig {
            l1_provider_source: env.l1_source.clone(),
            l2_provider_url: env.l2_http_0.clone(),
            l2_auth_provider_url: env.l2_auth_0.clone(),
            jwt_secret: env.jwt_secret.clone(),
            inbox_address: env.inbox_address,
        },
        Duration::from_millis(50),
        beacon_endpoint.clone(),
        None,
        None,
    );
    let driver = Driver::new(driver_config).await?;
    let driver_client = driver.rpc_client().clone();

    let blob_source =
        Arc::new(BlobDataSource::new(Some(beacon_endpoint.clone()), None, false).await?);
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

    beacon_stub.shutdown().await?;

    Ok(())
}

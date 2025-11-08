use std::{sync::Arc, time::Duration};

use alloy::transports::http::reqwest::Url as RpcUrl;
use alloy_provider::Provider;
use anyhow::{Context, Result};
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
use test_harness::{
    BlobServer, ShastaEnv, init_tracing, verify_anchor_block, wait_for_new_proposal,
};

#[serial]
#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn syncs_shasta_proposal_into_l2() -> Result<()> {
    init_tracing("info");

    let env = ShastaEnv::load_from_env().await?;
    let indexer = env.event_indexer.clone();

    let previous_proposal_id =
        indexer.get_last_proposal().map(|payload| payload.proposal.id.to()).unwrap_or_default();

    let proposer_client = Client::new_with_wallet(
        ClientConfig {
            l1_provider_source: env.l1_source.clone(),
            l2_provider_url: env.l2_http.clone(),
            l2_auth_provider_url: env.l2_auth.clone(),
            jwt_secret: env.jwt_secret.clone(),
            inbox_address: env.inbox_address,
        },
        env.l1_proposer_private_key,
    )
    .await?;

    let builder = ShastaProposalTransactionBuilder::new(
        proposer_client.clone(),
        indexer.clone(),
        env.l2_suggested_fee_recipient,
    );

    // Build a proposal with an empty transaction list to force an anchor-only block.
    let request = builder.build(vec![Vec::new()]).await?;
    let sidecar =
        request.sidecar.clone().context("expected blob sidecar for proposal transaction")?;

    let blob_server = BlobServer::start(sidecar).await?;

    let pending_tx = proposer_client.l1_provider.send_transaction(request).await?;
    let receipt =
        pending_tx.get_receipt().await.context("fetching proposal transaction receipt")?;
    anyhow::ensure!(receipt.status(), "proposal transaction failed");

    let proposal_payload = wait_for_new_proposal(indexer.clone(), previous_proposal_id)
        .await
        .context("waiting for indexer to observe proposed event")?;

    let driver_config = DriverConfig::new(
        ClientConfig {
            l1_provider_source: env.l1_source.clone(),
            l2_provider_url: env.l2_http.clone(),
            l2_auth_provider_url: env.l2_auth.clone(),
            jwt_secret: env.jwt_secret.clone(),
            inbox_address: env.inbox_address,
        },
        Duration::from_millis(50),
        RpcUrl::parse(blob_server.base_url().as_str())?,
        None,
        Some(RpcUrl::parse(blob_server.base_url().as_str())?),
    );
    let driver = Driver::new(driver_config).await?;
    let driver_client = driver.rpc_client().clone();

    let blob_source = Arc::new(
        BlobDataSource::new(
            Some(blob_server.endpoint().clone()),
            Some(blob_server.endpoint().clone()),
            true,
        )
        .await?,
    );
    let pipeline = ShastaDerivationPipeline::new(driver_client.clone(), blob_source).await?;

    let l2_head_before = driver_client.l2_provider.get_block_number().await?;

    let applier: &(dyn PayloadApplier + Send + Sync) = &driver_client;
    let outcomes = pipeline
        .process_proposal(&proposal_payload.log, applier)
        .await
        .context("processing proposal through derivation pipeline")?;
    anyhow::ensure!(!outcomes.is_empty(), "derivation pipeline returned no block outcomes");

    let l2_head_after = driver_client.l2_provider.get_block_number().await?;
    anyhow::ensure!(
        l2_head_after > l2_head_before,
        "expected L2 head to advance after proposal processing"
    );

    verify_anchor_block(&driver_client, env.taiko_anchor_address)
        .await
        .context("verifying anchor block on L2")?;

    blob_server.shutdown().await?;
    Ok(())
}

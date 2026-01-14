//! End-to-end tests for proposer → driver event sync flows.
//!
//! These tests verify that L1 proposals emitted by the proposer are consumed by the
//! driver's EventSyncer to produce L2 blocks, and that the derivation pipeline
//! detects already-canonical blocks (known-canonical fast path).

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
use test_harness::{ShastaEnv, init_tracing, verify_anchor_block};
use tokio::{net::TcpListener, select, spawn, sync::Notify, task::JoinHandle, time::sleep};
use tracing::{info, warn};
use url::Url;

/// Minimal beacon API stub for driver startup (genesis/spec/block endpoints).
struct BeaconStubServer {
    endpoint: Url,
    shutdown: Arc<Notify>,
    handle: JoinHandle<()>,
}

impl BeaconStubServer {
    async fn start() -> Result<Self> {
        let listener = TcpListener::bind("127.0.0.1:0").await?;
        let addr = listener.local_addr()?;
        let endpoint = Url::parse(&format!("http://{addr}"))?;

        let shutdown = Arc::new(Notify::new());
        let cancel = shutdown.clone();

        let handle = spawn(async move {
            loop {
                select! {
                    _ = cancel.notified() => break,
                    accept_result = listener.accept() => {
                        let Ok((stream, _)) = accept_result else { continue };
                        spawn(async move {
                            let io = hyper_util::rt::TokioIo::new(stream);
                            let service = hyper::service::service_fn(|req| async move {
                                Ok::<_, hyper::Error>(handle_beacon_request(req))
                            });
                            let _ = hyper::server::conn::http1::Builder::new()
                                .serve_connection(io, service)
                                .await;
                        });
                    }
                }
            }
        });

        Ok(Self { endpoint, shutdown, handle })
    }

    fn endpoint(&self) -> &Url {
        &self.endpoint
    }

    async fn shutdown(self) -> Result<()> {
        self.shutdown.notify_waiters();
        self.handle.await?;
        Ok(())
    }
}

fn handle_beacon_request(
    req: hyper::Request<hyper::body::Incoming>,
) -> hyper::Response<http_body_util::Full<hyper::body::Bytes>> {
    use http_body_util::Full;
    use hyper::{Method, StatusCode, body::Bytes as HyperBytes, header::CONTENT_TYPE};

    let empty_response = |status| {
        hyper::Response::builder().status(status).body(Full::new(HyperBytes::new())).unwrap()
    };

    if req.method() != Method::GET {
        return empty_response(StatusCode::METHOD_NOT_ALLOWED);
    }

    let path = req.uri().path();
    let json = match path {
        "/eth/v1/beacon/genesis" => r#"{"data":{"genesis_time":"0"}}"#,
        "/eth/v1/config/spec" => r#"{"data":{"SECONDS_PER_SLOT":"12"}}"#,
        _ if path.starts_with("/eth/v2/beacon/blocks/") => {
            r#"{"data":{"message":{"body":{"execution_payload":{"block_number":"0"}}}}}"#
        }
        _ => return empty_response(StatusCode::NOT_FOUND),
    };

    hyper::Response::builder()
        .status(StatusCode::OK)
        .header(CONTENT_TYPE, "application/json")
        .body(Full::new(HyperBytes::from(json)))
        .unwrap()
}

fn client_config(env: &ShastaEnv) -> ClientConfig {
    ClientConfig {
        l1_provider_source: env.l1_source.clone(),
        l2_provider_url: env.l2_http.clone(),
        l2_auth_provider_url: env.l2_auth.clone(),
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
        if tokio::time::Instant::now() >= deadline {
            return Err(anyhow!("timed out waiting for proposal {expected_proposal_id}"));
        }

        let current_proposal_id = event_syncer.last_canonical_proposal_id();
        let l2_head = driver_client.l2_provider.get_block_number().await?;

        if current_proposal_id >= expected_proposal_id {
            if l2_head < l2_head_before {
                warn!(
                    l2_head_before,
                    l2_head, "L2 head moved backward while waiting for proposal processing"
                );
            }
            return Ok(l2_head);
        }

        sleep(Duration::from_millis(500)).await;
    }
}

#[test_context(ShastaEnv)]
#[serial]
#[tokio::test(flavor = "multi_thread")]
async fn proposer_to_driver_event_sync(env: &mut ShastaEnv) -> Result<()> {
    init_tracing("info");

    let beacon_stub = BeaconStubServer::start().await?;
    let proposer = proposer_client(env).await?;

    // Build a proposal and start the blob server with its sidecar.
    let builder =
        ShastaProposalTransactionBuilder::new(proposer.clone(), env.l2_suggested_fee_recipient);
    let request = builder.build(vec![Vec::new()]).await?;
    let sidecar =
        request.sidecar.clone().context("expected blob sidecar for proposal transaction")?;
    env.start_blob_server(sidecar).await?;
    let blob_endpoint = env.blob_server_endpoint()?;

    // Start event syncer before submitting the proposal.
    let driver_config = DriverConfig::new(
        client_config(env),
        Duration::from_millis(50),
        beacon_stub.endpoint().clone(),
        None,
        Some(blob_endpoint.clone()),
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
    info!(proposal_id, "proposal submitted");

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
    ensure!(
        event_syncer.last_canonical_proposal_id() >= proposal_id,
        "canonical proposal id should update"
    );

    syncer_handle.abort();
    beacon_stub.shutdown().await?;

    Ok(())
}

#[test_context(ShastaEnv)]
#[serial]
#[tokio::test(flavor = "multi_thread")]
async fn known_canonical_fast_path(env: &mut ShastaEnv) -> Result<()> {
    init_tracing("info");

    let beacon_stub = BeaconStubServer::start().await?;
    let proposer = proposer_client(env).await?;

    let builder =
        ShastaProposalTransactionBuilder::new(proposer.clone(), env.l2_suggested_fee_recipient);
    let request = builder.build(vec![Vec::new()]).await?;
    let sidecar =
        request.sidecar.clone().context("expected blob sidecar for proposal transaction")?;
    env.start_blob_server(sidecar).await?;
    let blob_endpoint = env.blob_server_endpoint()?;

    let driver_config = DriverConfig::new(
        client_config(env),
        Duration::from_millis(50),
        beacon_stub.endpoint().clone(),
        None,
        Some(blob_endpoint.clone()),
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
    let blob_source = Arc::new(
        BlobDataSource::new(Some(blob_endpoint.clone()), Some(blob_endpoint.clone()), true).await?,
    );
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

#[test_context(ShastaEnv)]
#[serial]
#[tokio::test(flavor = "multi_thread")]
async fn multiple_proposals_event_sync(env: &mut ShastaEnv) -> Result<()> {
    init_tracing("info");

    let beacon_stub = BeaconStubServer::start().await?;
    let proposer = proposer_client(env).await?;

    // Build a proposal once and reuse its sidecar (blob server only serves one sidecar).
    let builder =
        ShastaProposalTransactionBuilder::new(proposer.clone(), env.l2_suggested_fee_recipient);
    let request = builder.build(vec![Vec::new()]).await?;
    let sidecar =
        request.sidecar.clone().context("expected blob sidecar for proposal transaction")?;
    env.start_blob_server(sidecar).await?;
    let blob_endpoint = env.blob_server_endpoint()?;

    let driver_config = DriverConfig::new(
        client_config(env),
        Duration::from_millis(50),
        beacon_stub.endpoint().clone(),
        None,
        Some(blob_endpoint.clone()),
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

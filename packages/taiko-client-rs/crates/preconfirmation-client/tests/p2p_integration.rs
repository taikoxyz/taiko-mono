//! P2P integration test for the preconfirmation client.

#[path = "common/helpers.rs"]
mod helpers;

use std::sync::{
    Arc,
    atomic::{AtomicUsize, Ordering},
};

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_primitives::U256;
use async_trait::async_trait;
use driver::{
    error::DriverError,
    jsonrpc::{DriverRpcApi, DriverRpcServer},
};
use helpers::{
    ExternalP2pNode, PreparedBlock, build_publish_payloads, compute_starting_block, test_p2p_config,
    wait_for_commitment_and_txlist, wait_for_peer_connected,
};
use preconfirmation_client::{
    PreconfirmationClient, PreconfirmationClientConfig,
    driver_interface::{
        DriverClient, JsonRpcDriverClient, JsonRpcDriverClientConfig, PreconfirmationInput,
    },
};
use rpc::client::read_jwt_secret;
use secp256k1::SecretKey;
use serial_test::serial;
use test_context::test_context;
use test_harness::{ShastaEnv, init_tracing, preconfirmation::StaticLookaheadResolver};
use tokio::sync::Notify;

/// Driver client wrapper that falls back to the latest tip if safe tip is unavailable.
struct SafeTipDriver {
    inner: JsonRpcDriverClient,
}

impl SafeTipDriver {
    fn new(inner: JsonRpcDriverClient) -> Self {
        Self { inner }
    }
}

#[async_trait]
impl DriverClient for SafeTipDriver {
    async fn submit_preconfirmation(
        &self,
        input: PreconfirmationInput,
    ) -> preconfirmation_client::Result<()> {
        self.inner.submit_preconfirmation(input).await
    }

    async fn wait_event_sync(&self) -> preconfirmation_client::Result<()> {
        self.inner.wait_event_sync().await
    }

    async fn event_sync_tip(&self) -> preconfirmation_client::Result<U256> {
        match self.inner.event_sync_tip().await {
            Ok(tip) => Ok(tip),
            Err(_) => self.inner.preconf_tip().await,
        }
    }

    async fn preconf_tip(&self) -> preconfirmation_client::Result<U256> {
        self.inner.preconf_tip().await
    }
}

/// Driver RPC stub that records submission calls.
#[derive(Default)]
struct SubmissionSpy {
    submissions: AtomicUsize,
    notify: Notify,
}

impl SubmissionSpy {
    fn new() -> Arc<Self> {
        Arc::new(Self { submissions: AtomicUsize::new(0), notify: Notify::new() })
    }

    async fn wait_for_submissions(&self, count: usize) {
        loop {
            let notified = self.notify.notified();
            if self.submissions.load(Ordering::Acquire) >= count {
                return;
            }
            notified.await;
        }
    }
}

#[async_trait]
impl DriverRpcApi for SubmissionSpy {
    async fn submit_execution_payload_v2(
        &self,
        _payload: TaikoPayloadAttributes,
    ) -> Result<(), DriverError> {
        self.submissions.fetch_add(1, Ordering::AcqRel);
        self.notify.notify_waiters();
        Ok(())
    }

    fn last_canonical_proposal_id(&self) -> u64 {
        0
    }
}

#[test_context(ShastaEnv)]
#[serial]
#[tokio::test(flavor = "multi_thread")]
async fn p2p_gossip_submits_preconfirmation(env: &mut ShastaEnv) -> anyhow::Result<()> {
    init_tracing("info");

    let jwt_secret = read_jwt_secret(env.jwt_secret.clone())
        .ok_or_else(|| anyhow::anyhow!("missing jwt secret"))?;
    let spy = SubmissionSpy::new();
    let rpc_server =
        DriverRpcServer::start("127.0.0.1:0".parse()?, jwt_secret, spy.clone()).await?;

    let l1_http = std::env::var("L1_HTTP")?;
    let driver_rpc_url: url::Url = rpc_server.http_url().parse()?;
    let l1_rpc_url: url::Url = l1_http.parse()?;
    let l2_rpc_url: url::Url = env.l2_http.to_string().parse()?;

    let driver_client_cfg = JsonRpcDriverClientConfig::with_http_endpoint(
        driver_rpc_url,
        env.jwt_secret.clone(),
        l1_rpc_url,
        l2_rpc_url,
        env.inbox_address,
    );
    let driver_client = SafeTipDriver::new(JsonRpcDriverClient::new(driver_client_cfg).await?);

    let signer_sk = SecretKey::from_slice(&[1u8; 32]).expect("secret key");
    let signer = preconfirmation_types::public_key_to_address(
        &secp256k1::PublicKey::from_secret_key(&secp256k1::Secp256k1::new(), &signer_sk),
    );
    let submission_window_end = U256::from(1000u64);
    let commitment_block = compute_starting_block(&driver_client).await?;

    let resolver = StaticLookaheadResolver::new(signer, submission_window_end);

    // External P2P node used to publish gossip.
    let mut ext_node = ExternalP2pNode::spawn()?;
    let ext_dial_addr = ext_node.handle.dialable_addr().await?;

    // Internal preconfirmation client (real RPC driver, mock lookahead).
    let mut int_cfg =
        PreconfirmationClientConfig::new_with_resolver(test_p2p_config(), Arc::new(resolver));
    int_cfg.p2p.pre_dial_peers = vec![ext_dial_addr];

    let internal_client = PreconfirmationClient::new(int_cfg, driver_client)?;
    let mut events = internal_client.subscribe();

    let mut event_loop = internal_client.sync_and_catchup().await?;
    let event_loop_handle = tokio::spawn(async move { event_loop.run().await });

    // Wait for both peers to connect using event-driven waits.
    wait_for_peer_connected(&mut events).await;
    ext_node.handle.wait_for_peer_connected().await?;

    // Publish txlist + commitment from external client.
    let PreparedBlock { txlist, commitment } = build_publish_payloads(
        &signer_sk,
        signer,
        commitment_block,
        1,
        30_000_000,
        submission_window_end,
        false,
    )?;
    ext_node.handle.publish_raw_txlist(txlist).await?;
    ext_node.handle.publish_commitment(commitment).await?;

    // Internal client should observe txlist + commitment and submit to driver RPC.
    wait_for_commitment_and_txlist(&mut events).await;
    spy.wait_for_submissions(1).await;

    event_loop_handle.abort();
    ext_node.abort();
    rpc_server.stop().await;

    Ok(())
}

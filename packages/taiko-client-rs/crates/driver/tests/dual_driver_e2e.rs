//! E2E test verifying P2P gossip propagation between two drivers.

use std::{sync::Arc, time::Duration};

use alloy_primitives::{Address, U256};
use anyhow::{Context, Result, anyhow, ensure};
use driver::{DriverConfig, EventSyncer, sync::SyncStage};
use preconfirmation_net::{InMemoryStorage, LocalValidationAdapter, P2pNode};
use preconfirmation_node::{
    DriverClient, PreconfirmationClient, PreconfirmationClientConfig,
    driver_interface::EmbeddedDriverClient,
};
use rpc::{
    SubscriptionSource,
    client::{Client, ClientConfig, connect_http_with_timeout},
};
use serial_test::serial;
use test_context::test_context;
use test_harness::{
    BeaconStubServer, PreconfTxList, ShastaEnv, build_preconf_txlist, compute_next_block_base_fee,
    fetch_block_by_number,
    preconfirmation::{
        SafeTipDriverClient, StaticLookaheadResolver, build_publish_payloads_with_txs,
        derive_signer, test_p2p_config, wait_for_commitment_and_txlist, wait_for_peer_connected,
    },
    wait_for_block_or_loop_error,
};
use tokio::{spawn, sync::oneshot, task::JoinHandle};
use tracing::{info, warn};
use url::Url;

// ============================================================================
// Driver Instance Helper
// ============================================================================

/// Running driver instance with its embedded driver client and background tasks.
struct DriverInstance {
    /// Embedded driver client for this instance.
    driver_client: Arc<EmbeddedDriverClient>,
    /// Background event syncer task handle.
    event_handle: JoinHandle<()>,
}

impl DriverInstance {
    /// Starts a new driver instance connected to the specified L2 node.
    async fn start(
        l2_http: &Url,
        l2_auth: &Url,
        l1_source: &SubscriptionSource,
        jwt_secret_path: &std::path::Path,
        inbox_address: Address,
        beacon_endpoint: &Url,
    ) -> Result<Self> {
        let client_config = ClientConfig {
            l1_provider_source: l1_source.clone(),
            l2_provider_url: l2_http.clone(),
            l2_auth_provider_url: l2_auth.clone(),
            jwt_secret: jwt_secret_path.to_path_buf(),
            inbox_address,
        };

        let mut driver_config = DriverConfig::new(
            client_config.clone(),
            Duration::from_millis(50),
            beacon_endpoint.clone(),
            None,
            None,
        );
        driver_config.preconfirmation_enabled = true;

        let rpc_client = Client::new(client_config).await?;
        let event_syncer = Arc::new(EventSyncer::new(&driver_config, rpc_client.clone()).await?);
        let event_handle = spawn({
            let syncer = event_syncer.clone();
            async move {
                if let Err(err) = syncer.run().await {
                    warn!(?err, "event syncer exited");
                }
            }
        });

        event_syncer
            .wait_preconf_ingress_ready()
            .await
            .ok_or_else(|| anyhow!("preconfirmation ingress disabled"))?;

        let embedded_driver = Arc::new(EmbeddedDriverClient::new(event_syncer, rpc_client));

        Ok(Self { driver_client: embedded_driver, event_handle })
    }

    /// Stops background tasks for this driver instance.
    async fn stop(self) {
        self.event_handle.abort();
    }
}

// ============================================================================
// Test
// ============================================================================

/// Tests that P2P gossip propagates to multiple drivers producing identical blocks.
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn dual_driver_p2p_gossip_syncs_both_nodes(env: &mut ShastaEnv) -> Result<()> {
    let l2_http_1: Url = env.l2_http_1.clone();
    let l2_auth_1: Url = env.l2_auth_1.clone();

    let beacon_server = BeaconStubServer::start().await?;

    info!("starting driver 1 (L2 node 0)");
    let driver1 = DriverInstance::start(
        &env.l2_http_0.clone(),
        &env.l2_auth_0.clone(),
        &env.l1_source,
        &env.jwt_secret,
        env.inbox_address,
        beacon_server.endpoint(),
    )
    .await
    .context("starting driver 1")?;

    info!("starting driver 2 (L2 node 1)");
    let driver2 = DriverInstance::start(
        &l2_http_1,
        &l2_auth_1,
        &env.l1_source,
        &env.jwt_secret,
        env.inbox_address,
        beacon_server.endpoint(),
    )
    .await
    .context("starting driver 2")?;

    let l2_provider_1 = connect_http_with_timeout(l2_http_1.clone());

    let driver1_client = SafeTipDriverClient::new(driver1.driver_client.clone());
    let driver2_client = SafeTipDriverClient::new(driver2.driver_client.clone());

    let (signer_sk, signer) = derive_signer(1);

    let submission_window_end = U256::from(1000u64);
    let event_sync_tip = driver1_client.event_sync_tip().await?;
    let preconf_tip = driver1_client.preconf_tip().await?;
    let commitment_block = event_sync_tip.max(preconf_tip) + U256::ONE;
    let commitment_block_num = commitment_block.to::<u64>();

    let parent_block =
        fetch_block_by_number(&env.client.l2_provider, commitment_block_num.saturating_sub(1))
            .await?;
    let parent_header = &parent_block.header.inner;
    let preconf_timestamp = parent_header.timestamp.saturating_add(1);
    let preconf_gas_limit = parent_header.gas_limit;
    let preconf_base_fee = compute_next_block_base_fee(
        &env.client.l2_provider,
        commitment_block_num.saturating_sub(1),
    )
    .await?;

    let (mut ext_handle, ext_node) = P2pNode::new_with_validator_and_storage(
        test_p2p_config(),
        Box::new(LocalValidationAdapter::new(None)),
        Arc::new(InMemoryStorage::default()),
    )?;
    let ext_node_handle = spawn(async move { ext_node.run().await });
    let ext_dial_addr = ext_handle.dialable_addr().await?;

    let mut preconf1_cfg = PreconfirmationClientConfig::new_with_resolver(
        test_p2p_config(),
        Arc::new(StaticLookaheadResolver::new(signer, submission_window_end)),
    );
    preconf1_cfg.p2p.pre_dial_peers = vec![ext_dial_addr.clone()];

    let preconf_client1 = PreconfirmationClient::new(preconf1_cfg, driver1_client)?;
    let mut events1 = preconf_client1.subscribe();

    let mut event_loop1 = preconf_client1.sync_and_catchup().await?;
    let (event_loop1_tx, mut event_loop1_rx) = oneshot::channel::<anyhow::Result<()>>();
    let event_loop1_handle = spawn(async move {
        let _ = event_loop1_tx.send(event_loop1.run().await.map_err(Into::into));
    });

    info!("waiting for preconf client 1 to connect to external publisher");
    wait_for_peer_connected(&mut events1).await;
    ext_handle.wait_for_peer_connected().await?;

    let mut preconf2_cfg = PreconfirmationClientConfig::new_with_resolver(
        test_p2p_config(),
        Arc::new(StaticLookaheadResolver::new(signer, submission_window_end)),
    );
    preconf2_cfg.p2p.pre_dial_peers = vec![ext_dial_addr.clone()];

    let preconf_client2 = PreconfirmationClient::new(preconf2_cfg, driver2_client)?;
    let mut events2 = preconf_client2.subscribe();

    let mut event_loop2 = preconf_client2.sync_and_catchup().await?;
    let (event_loop2_tx, mut event_loop2_rx) = oneshot::channel::<anyhow::Result<()>>();
    let event_loop2_handle = spawn(async move {
        let _ = event_loop2_tx.send(event_loop2.run().await.map_err(Into::into));
    });

    info!("waiting for preconf client 2 to connect to external publisher");
    wait_for_peer_connected(&mut events2).await;
    ext_handle.wait_for_peer_connected().await?;

    let PreconfTxList { raw_tx_bytes, transfers: _ } = build_preconf_txlist(
        &env.client,
        parent_block.header.hash,
        commitment_block_num,
        preconf_base_fee,
    )
    .await?;

    let (txlist, signed_commitment) = build_publish_payloads_with_txs(
        &signer_sk,
        signer,
        submission_window_end,
        commitment_block,
        preconf_timestamp,
        preconf_gas_limit,
        raw_tx_bytes,
    )?;

    ext_handle.publish_raw_txlist(txlist).await?;
    ext_handle.publish_commitment(signed_commitment.clone()).await?;

    wait_for_commitment_and_txlist(&mut events1).await;
    wait_for_commitment_and_txlist(&mut events2).await;

    let produced_block_0 = wait_for_block_or_loop_error(
        &env.client.l2_provider,
        commitment_block_num,
        Duration::from_secs(30),
        &mut event_loop1_rx,
        "preconf event loop 1",
    )
    .await?;
    let produced_block_1 = wait_for_block_or_loop_error(
        &l2_provider_1,
        commitment_block_num,
        Duration::from_secs(30),
        &mut event_loop2_rx,
        "preconf event loop 2",
    )
    .await?;

    ensure!(
        produced_block_0.header.hash == produced_block_1.header.hash,
        "blocks should match across both drivers"
    );

    // Cleanup background tasks.
    event_loop1_handle.abort();
    event_loop2_handle.abort();
    ext_node_handle.abort();
    driver1.stop().await;
    driver2.stop().await;
    beacon_server.shutdown().await?;

    Ok(())
}

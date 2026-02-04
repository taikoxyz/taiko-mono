//! E2E test verifying P2P gossip propagation between two drivers.

use std::{io::Write as IoWrite, sync::Arc, time::Duration};

use alloy_consensus::transaction::SignerRecoverable;
use alloy_eips::{BlockNumberOrTag, Encodable2718};
use alloy_primitives::{Address, U256};
use alloy_provider::{
    Provider, RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers,
};
use alloy_rlp::encode as rlp_encode;
use anyhow::{Context, Result, anyhow, ensure};
use driver::{
    DriverConfig,
    sync::{SyncStage, event::EventSyncer},
};
use flate2::{Compression, write::ZlibEncoder};
use preconfirmation_driver::{DriverClient, PreconfirmationClient, PreconfirmationClientConfig};
use preconfirmation_net::{InMemoryStorage, LocalValidationAdapter, P2pNode};
use preconfirmation_types::{
    Bytes20, Bytes32, PreconfCommitment, Preconfirmation, RawTxListGossip, SignedCommitment,
    TxListBytes, address_to_bytes20, keccak256_bytes, sign_commitment, u256_to_uint256,
    uint256_to_u256,
};
use rpc::{
    SubscriptionSource,
    client::{Client, ClientConfig, connect_provider_with_timeout},
};
use serial_test::serial;
use test_context::test_context;
use test_harness::{
    BeaconStubServer, PreconfTxList, ShastaEnv, build_preconf_txlist, compute_next_block_base_fee,
    fetch_block_by_number,
    preconfirmation::{
        EventSyncerDriverClient, SafeTipDriverClient, StaticLookaheadResolver,
        build_publish_payloads_with_txs, derive_signer, test_p2p_config,
        wait_for_commitment_and_txlist, wait_for_peer_connected,
    },
    wait_for_block, wait_for_block_or_loop_error,
};
use tokio::{spawn, sync::oneshot, task::JoinHandle};
use tracing::{info, warn};
use url::Url;

// ============================================================================
// Driver Instance Helper
// ============================================================================

/// Running driver instance with its RPC server and background tasks.
struct DriverInstance {
    rpc_client: DriverRpcClient,
    event_syncer: Arc<EventSyncer<DriverRpcProvider>>,
    event_handle: JoinHandle<()>,
}

type DriverRpcProvider = FillProvider<JoinedRecommendedFillers, RootProvider>;
type DriverRpcClient = Client<DriverRpcProvider>;

impl DriverInstance {
    /// Starts a new driver instance connected to the specified L2 node.
    async fn start(
        l2_ws: &Url,
        l2_auth: &Url,
        l1_source: &SubscriptionSource,
        jwt_secret_path: &std::path::Path,
        inbox_address: Address,
        beacon_endpoint: &Url,
    ) -> Result<Self> {
        let client_config = ClientConfig {
            l1_provider_source: l1_source.clone(),
            l2_provider_url: l2_ws.clone(),
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

        Ok(Self { rpc_client, event_syncer, event_handle })
    }

    async fn stop(self) {
        self.event_handle.abort();
    }
}

fn build_txlist_bytes(raw_tx_bytes: &[Vec<u8>]) -> Result<TxListBytes> {
    let tx_list_items: Vec<Vec<u8>> = raw_tx_bytes.to_vec();
    let tx_list = rlp_encode(&tx_list_items);
    let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
    encoder.write_all(&tx_list)?;
    let compressed = encoder.finish()?;
    TxListBytes::try_from(compressed).map_err(|(_, err)| anyhow!("txlist bytes error: {err}"))
}

// ============================================================================
// Test
// ============================================================================

/// Tests that P2P gossip propagates to multiple drivers producing identical blocks.
#[test_context(ShastaEnv)]
#[serial]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn dual_driver_p2p_gossip_syncs_both_nodes(env: &mut ShastaEnv) -> Result<()> {
    let l2_ws_1: Url = env.l2_ws_1.clone();
    let l2_auth_1: Url = env.l2_auth_1.clone();

    let beacon_server = BeaconStubServer::start().await?;

    info!("starting driver 1 (L2 node 0)");
    let driver1 = DriverInstance::start(
        &env.l2_ws_0.clone(),
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
        &l2_ws_1,
        &l2_auth_1,
        &env.l1_source,
        &env.jwt_secret,
        env.inbox_address,
        beacon_server.endpoint(),
    )
    .await
    .context("starting driver 2")?;

    let l2_provider_1 = connect_provider_with_timeout(l2_ws_1.clone()).await?;

    let driver1_embedded =
        EventSyncerDriverClient::new(driver1.event_syncer.clone(), driver1.rpc_client.clone());
    let driver1_client = SafeTipDriverClient::new(Arc::new(driver1_embedded));

    let driver2_embedded =
        EventSyncerDriverClient::new(driver2.event_syncer.clone(), driver2.rpc_client.clone());
    let driver2_client = SafeTipDriverClient::new(Arc::new(driver2_embedded));

    let (signer_sk, signer) = derive_signer(1);

    let submission_window_end = U256::from(1000u64);
    let event_sync_tip = driver1_client.event_sync_tip().await?;
    let preconf_tip = driver1_client.preconf_tip().await?;
    let commitment_block = event_sync_tip.max(preconf_tip) + U256::ONE;
    let commitment_block_num = commitment_block.to::<u64>();
    let parent_block_num = commitment_block_num.saturating_sub(1);

    let block_timeout = Duration::from_secs(30);
    let parent_block_exists = l2_provider_1
        .get_block_by_number(BlockNumberOrTag::Number(parent_block_num))
        .full()
        .await?
        .is_some();
    let needs_warmup = !parent_block_exists;

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

    info!("waiting for preconf client 2 to join the mesh");
    wait_for_peer_connected(&mut events2).await;

    if needs_warmup {
        info!(
            parent_block_num,
            "parent block missing on L2 node 1; publishing warmup preconfirmation"
        );
        let warmup_block = fetch_block_by_number(&env.client.l2_provider, parent_block_num).await?;
        let warmup_header = &warmup_block.header.inner;
        let txs = warmup_block
            .transactions
            .as_transactions()
            .ok_or_else(|| anyhow!("expected full transactions for block {parent_block_num}"))?;
        let raw_tx_bytes: Vec<Vec<u8>> = txs.iter().map(|tx| tx.encoded_2718().to_vec()).collect();
        let txlist_bytes = build_txlist_bytes(&raw_tx_bytes)?;
        let raw_tx_list_hash =
            Bytes32::try_from(keccak256_bytes(txlist_bytes.as_ref()).as_slice().to_vec())
                .map_err(|(_, err)| anyhow!("txlist hash error: {err}"))?;

        let preconf = Preconfirmation {
            block_number: u256_to_uint256(U256::from(parent_block_num)),
            timestamp: u256_to_uint256(U256::from(warmup_header.timestamp)),
            gas_limit: u256_to_uint256(U256::from(warmup_header.gas_limit)),
            proposal_id: u256_to_uint256(U256::from(parent_block_num)),
            coinbase: address_to_bytes20(warmup_header.beneficiary),
            submission_window_end: u256_to_uint256(submission_window_end),
            raw_tx_list_hash: raw_tx_list_hash.clone(),
            ..Default::default()
        };
        let commitment = PreconfCommitment { preconf, slasher_address: Bytes20::default() };
        let signature = sign_commitment(&commitment, &signer_sk)?;
        let signed_commitment = SignedCommitment { commitment, signature };
        let txlist = RawTxListGossip { raw_tx_list_hash, txlist: txlist_bytes };

        info!(
            block_number = parent_block_num,
            "publishing warmup preconfirmation via external node"
        );
        ext_handle.publish_raw_txlist(txlist).await?;
        ext_handle.publish_commitment(signed_commitment).await?;
        let node1_block = wait_for_block(&l2_provider_1, parent_block_num, block_timeout).await?;
        ensure!(
            node1_block.header.hash == warmup_block.header.hash,
            "warmup block hash mismatch: node0={} node1={}",
            warmup_block.header.hash,
            node1_block.header.hash
        );
    }

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

    let PreconfTxList { raw_tx_bytes, transfers } = build_preconf_txlist(
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

    info!(block_number = commitment_block_num, "publishing preconfirmation via external node");
    ext_handle.publish_raw_txlist(txlist).await?;
    ext_handle.publish_commitment(signed_commitment.clone()).await?;

    info!("waiting for preconf client 1 to receive gossip");
    wait_for_commitment_and_txlist(&mut events1).await;

    info!("waiting for preconf client 2 to receive gossip");
    wait_for_commitment_and_txlist(&mut events2).await;

    info!("waiting for block {} on L2 node 0", commitment_block_num);
    let block_node0 = wait_for_block_or_loop_error(
        &env.client.l2_provider,
        commitment_block_num,
        block_timeout,
        &mut event_loop1_rx,
        "preconf event loop 1",
    )
    .await?;

    info!("waiting for block {} on L2 node 1", commitment_block_num);
    let block_node1 = wait_for_block_or_loop_error(
        &l2_provider_1,
        commitment_block_num,
        block_timeout,
        &mut event_loop2_rx,
        "preconf event loop 2",
    )
    .await?;

    info!("verifying both L2 nodes produced identical blocks");
    ensure!(
        block_node0.header.hash == block_node1.header.hash,
        "block hash mismatch: node0={} node1={}",
        block_node0.header.hash,
        block_node1.header.hash
    );

    let header = &block_node0.header.inner;
    let preconf = &signed_commitment.commitment.preconf;
    ensure!(
        header.beneficiary == Address::from_slice(preconf.coinbase.as_ref()),
        "beneficiary mismatch"
    );
    ensure!(
        header.number == uint256_to_u256(&preconf.block_number).to::<u64>(),
        "block number mismatch"
    );
    ensure!(
        header.gas_limit == uint256_to_u256(&preconf.gas_limit).to::<u64>(),
        "gas limit mismatch"
    );
    ensure!(
        header.timestamp == uint256_to_u256(&preconf.timestamp).to::<u64>(),
        "timestamp mismatch"
    );

    let txs = block_node0
        .transactions
        .as_transactions()
        .ok_or_else(|| anyhow!("expected full transactions"))?;
    ensure!(txs.len() == transfers.len() + 1, "expected anchor + {} transfer(s)", transfers.len());

    for (idx, expected) in transfers.iter().enumerate() {
        let tx = &txs[idx + 1];
        ensure!(*tx.hash() == expected.hash, "transfer tx hash mismatch at index {idx}");
        ensure!(tx.recover_signer()? == expected.from, "transfer signer mismatch at index {idx}");
    }

    info!(
        block_hash = %block_node0.header.hash,
        block_number = commitment_block_num,
        "dual-driver E2E test passed: both nodes synced to identical block"
    );

    event_loop1_handle.abort();
    event_loop2_handle.abort();
    ext_node_handle.abort();
    driver1.stop().await;
    driver2.stop().await;
    beacon_server.shutdown().await?;

    Ok(())
}

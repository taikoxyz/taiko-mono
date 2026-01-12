use std::{
    io::Write,
    net::{IpAddr, Ipv4Addr, SocketAddr, TcpListener},
    path::PathBuf,
    sync::{
        Arc,
        atomic::{AtomicU64, AtomicUsize, Ordering},
    },
    time::Duration,
};

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_provider::Provider;
use alloy_rpc_types::BlockNumberOrTag;
use async_trait::async_trait;
use driver::{
    error::DriverError,
    jsonrpc::{DriverIpcServer, DriverRpcApi},
};
use flate2::{Compression, write::ZlibEncoder};
use libp2p::Multiaddr;
use preconfirmation_client::{
    PreconfirmationClient, PreconfirmationClientConfig,
    driver_interface::jsonrpc::{JsonRpcDriverClient, JsonRpcDriverClientConfig},
    subscription::PreconfirmationEvent,
};
use preconfirmation_net::{NetworkCommand, P2pConfig};
use preconfirmation_types::{
    Bytes20, Bytes32, PreconfCommitment, Preconfirmation, RawTxListGossip, SignedCommitment,
    TxListBytes, Uint256, keccak256_bytes, public_key_to_address, sign_commitment,
};
use protocol::preconfirmation::{PreconfSignerResolver, PreconfSlotInfo};
use secp256k1::SecretKey;
use serial_test::serial;
use test_harness::ShastaEnv;
use tokio::sync::{Notify, broadcast};
use url::Url;

struct StaticResolver {
    signer: alloy_primitives::Address,
    submission_window_end: alloy_primitives::U256,
}

#[async_trait]
impl PreconfSignerResolver for StaticResolver {
    async fn signer_for_timestamp(
        &self,
        _l2_block_timestamp: alloy_primitives::U256,
    ) -> protocol::preconfirmation::Result<alloy_primitives::Address> {
        Ok(self.signer)
    }

    async fn slot_info_for_timestamp(
        &self,
        _l2_block_timestamp: alloy_primitives::U256,
    ) -> protocol::preconfirmation::Result<PreconfSlotInfo> {
        Ok(PreconfSlotInfo {
            signer: self.signer,
            submission_window_end: self.submission_window_end,
        })
    }
}

#[derive(Default)]
struct StubDriver {
    submissions: AtomicUsize,
    last: AtomicU64,
    notify: Arc<Notify>,
}

impl StubDriver {
    fn new(notify: Arc<Notify>) -> Self {
        Self { submissions: AtomicUsize::new(0), last: AtomicU64::new(u64::MAX), notify }
    }
}

#[async_trait]
impl DriverRpcApi for StubDriver {
    async fn submit_execution_payload_v2(
        &self,
        _payload: TaikoPayloadAttributes,
    ) -> Result<(), DriverError> {
        self.submissions.fetch_add(1, Ordering::SeqCst);
        self.notify.notify_one();
        Ok(())
    }

    fn last_canonical_proposal_id(&self) -> u64 {
        self.last.load(Ordering::Relaxed)
    }
}

fn reserve_port() -> u16 {
    TcpListener::bind(SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 0))
        .expect("bind")
        .local_addr()
        .expect("local addr")
        .port()
}

fn build_p2p_config(port: u16, chain_id: u64) -> P2pConfig {
    let mut cfg = P2pConfig::default();
    cfg.chain_id = chain_id;
    cfg.listen_addr = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), port);
    cfg.discovery_listen = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 0);
    cfg.enable_discovery = false;
    cfg.enable_quic = false;
    cfg.enable_tcp = true;
    cfg.bootnodes = Vec::new();
    cfg
}

fn dial_addr(port: u16) -> Multiaddr {
    format!("/ip4/127.0.0.1/tcp/{port}").parse().expect("multiaddr")
}

fn build_txlist() -> (RawTxListGossip, Bytes32) {
    let rlp_payload = vec![0xC0];
    let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
    encoder.write_all(&rlp_payload).expect("zlib encode failed");
    let compressed = encoder.finish().expect("zlib encode failed");
    let txlist_bytes = TxListBytes::try_from(compressed).expect("txlist bytes error");
    let txlist_hash = keccak256_bytes(txlist_bytes.as_ref());
    let raw_tx_list_hash =
        Bytes32::try_from(txlist_hash.as_slice().to_vec()).expect("txlist hash error");
    let txlist =
        RawTxListGossip { raw_tx_list_hash: raw_tx_list_hash.clone(), txlist: txlist_bytes };

    (txlist, raw_tx_list_hash)
}

fn build_commitment(
    sk: &SecretKey,
    raw_tx_list_hash: Bytes32,
    block_number: u64,
    timestamp: u64,
    submission_window_end: u64,
) -> SignedCommitment {
    let preconf = Preconfirmation {
        eop: false,
        block_number: Uint256::from(block_number),
        timestamp: Uint256::from(timestamp),
        submission_window_end: Uint256::from(submission_window_end),
        raw_tx_list_hash: raw_tx_list_hash.clone(),
        parent_preconfirmation_hash: Bytes32::try_from(vec![0u8; 32]).expect("parent hash"),
        ..Default::default()
    };
    let commitment = PreconfCommitment { preconf, slasher_address: Bytes20::default() };
    let signature = sign_commitment(&commitment, sk).expect("sign commitment failed");
    SignedCommitment { commitment, signature }
}

#[serial]
#[tokio::test]
async fn p2p_gossip_submits_to_driver() -> anyhow::Result<()> {
    let env = match ShastaEnv::load_from_env().await {
        Ok(env) => env,
        Err(err) => {
            eprintln!("skipping preconf P2P IPC integration test: {err:#}");
            return Ok(());
        }
    };

    let notify = Arc::new(Notify::new());
    let driver = Arc::new(StubDriver::new(notify.clone()));

    let ipc_path = PathBuf::from(format!("/tmp/preconf-driver-{}.ipc", std::process::id()));
    let _ = std::fs::remove_file(&ipc_path);
    let ipc_server = DriverIpcServer::start(ipc_path.clone(), driver.clone()).await;

    let result = async {
        let ipc_server = ipc_server?;

        let l1_http: Url = std::env::var("L1_HTTP")?.parse()?;
        let l2_http = env.l2_http.clone();
        let driver_cfg = JsonRpcDriverClientConfig::with_ipc_endpoint(
            ipc_path.clone(),
            l1_http,
            l2_http.clone(),
            env.inbox_address,
        );
        let driver_client = JsonRpcDriverClient::new(driver_cfg).await?;

        let chain_id = std::env::var("L2_CHAIN_ID")
            .ok()
            .and_then(|value| value.parse::<u64>().ok())
            .unwrap_or(167001);

        let latest_block = env
            .client
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await?
            .ok_or_else(|| anyhow::anyhow!("missing latest L2 block"))?;
        let block_number = latest_block.number().saturating_add(1);
        let timestamp = latest_block.header.timestamp.saturating_add(1);
        let submission_window_end = timestamp.saturating_add(30);

        let (txlist, raw_tx_list_hash) = build_txlist();
        let sk = SecretKey::from_slice(&[7u8; 32]).expect("secret key");
        let signer = public_key_to_address(&secp256k1::PublicKey::from_secret_key(
            &secp256k1::Secp256k1::new(),
            &sk,
        ));
        let commitment =
            build_commitment(&sk, raw_tx_list_hash, block_number, timestamp, submission_window_end);

        let resolver = Arc::new(StaticResolver {
            signer,
            submission_window_end: alloy_primitives::U256::from(submission_window_end),
        });

        let port1 = reserve_port();
        let port2 = reserve_port();
        let config1 = PreconfirmationClientConfig {
            p2p: build_p2p_config(port1, chain_id),
            expected_slasher: None,
            request_timeout: Duration::from_secs(10),
            catchup_batch_size: 64,
            txlist_fetch_concurrency: None,
            lookahead_resolver: resolver.clone(),
            retention_limit: preconfirmation_client::config::DEFAULT_RETENTION_LIMIT,
        };
        let config2 = PreconfirmationClientConfig {
            p2p: build_p2p_config(port2, chain_id),
            expected_slasher: None,
            request_timeout: Duration::from_secs(10),
            catchup_batch_size: 64,
            txlist_fetch_concurrency: None,
            lookahead_resolver: resolver.clone(),
            retention_limit: preconfirmation_client::config::DEFAULT_RETENTION_LIMIT,
        };

        let client1 = PreconfirmationClient::new(config1, driver_client.clone())?;
        let client2 = PreconfirmationClient::new(config2, driver_client.clone())?;

        let mut events1 = client1.subscribe();
        let mut events2 = client2.subscribe();

        let cmd1 = client1.command_sender();
        let cmd2 = client2.command_sender();

        let sync1 = tokio::spawn(async move { client1.sync_and_catchup().await });
        let sync2 = tokio::spawn(async move { client2.sync_and_catchup().await });

        cmd1.send(NetworkCommand::Dial { addr: dial_addr(port2) }).await?;
        cmd2.send(NetworkCommand::Dial { addr: dial_addr(port1) }).await?;

        let loop1 = sync1.await??;
        let loop2 = sync2.await??;

        let handle1 = tokio::spawn(async move { loop1.run_with_retry().await });
        let handle2 = tokio::spawn(async move { loop2.run_with_retry().await });

        wait_for_peer_connected(&mut events1).await?;
        wait_for_peer_connected(&mut events2).await?;

        cmd1.send(NetworkCommand::PublishCommitment(commitment)).await?;
        cmd1.send(NetworkCommand::PublishRawTxList(txlist)).await?;

        tokio::time::timeout(Duration::from_secs(20), notify.notified()).await?;

        handle1.abort();
        handle2.abort();
        ipc_server.stop().await;
        let _ = std::fs::remove_file(&ipc_path);
        Ok(())
    }
    .await;

    env.shutdown().await?;
    result
}

async fn wait_for_peer_connected(
    receiver: &mut broadcast::Receiver<PreconfirmationEvent>,
) -> anyhow::Result<()> {
    tokio::time::timeout(Duration::from_secs(10), async {
        loop {
            match receiver.recv().await {
                Ok(PreconfirmationEvent::PeerConnected(_)) => {
                    return Ok(());
                }
                Ok(_) => continue,
                Err(broadcast::error::RecvError::Lagged(_)) => continue,
                Err(err) => {
                    return Err(anyhow::anyhow!("event channel closed: {err}"));
                }
            }
        }
    })
    .await??;
    Ok(())
}

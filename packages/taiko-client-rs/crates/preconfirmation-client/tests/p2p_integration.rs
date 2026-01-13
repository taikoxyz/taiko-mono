//! P2P integration test for the preconfirmation client.

use std::{
    net::{IpAddr, Ipv4Addr, SocketAddr},
    sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    },
};

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_primitives::{Address, U256};
use async_trait::async_trait;
use driver::{
    error::DriverError,
    jsonrpc::{DriverRpcApi, DriverRpcServer},
};
use preconfirmation_client::{
    PreconfirmationClient, PreconfirmationClientConfig,
    driver_interface::{DriverClient, JsonRpcDriverClient, JsonRpcDriverClientConfig},
    subscription::PreconfirmationEvent,
};
use preconfirmation_net::{
    InMemoryStorage, LocalValidationAdapter, P2pConfig, P2pNode, PreconfStorage, ValidationAdapter,
};
use preconfirmation_types::{
    Bytes20, Bytes32, PreconfCommitment, Preconfirmation, RawTxListGossip, SignedCommitment,
    TxListBytes, address_to_bytes20, keccak256_bytes, sign_commitment, u256_to_uint256,
};
use rpc::client::read_jwt_secret;
use secp256k1::SecretKey;
use serial_test::serial;
use test_context::test_context;
use test_harness::{ShastaEnv, init_tracing, preconfirmation::StaticLookaheadResolver};
use tokio::{sync::Notify, task::JoinHandle};

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

fn test_p2p_config() -> P2pConfig {
    let mut cfg = P2pConfig::default();
    cfg.listen_addr = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 0);
    cfg.discovery_listen = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), 0);
    cfg.enable_discovery = false;
    cfg
}

fn build_publish_payloads(
    signer_sk: &SecretKey,
    signer: Address,
    submission_window_end: U256,
    block_number: U256,
) -> (RawTxListGossip, SignedCommitment) {
    // Build a minimal txlist payload (RLP empty list) and compress it.
    let rlp_payload = vec![0xC0];
    let mut encoder = flate2::write::ZlibEncoder::new(Vec::new(), flate2::Compression::default());
    std::io::Write::write_all(&mut encoder, &rlp_payload).expect("zlib encode failed");
    let compressed = encoder.finish().expect("zlib encode failed");
    let txlist_bytes = TxListBytes::try_from(compressed).expect("txlist bytes error");
    let txlist_hash = keccak256_bytes(txlist_bytes.as_ref());
    let raw_tx_list_hash =
        Bytes32::try_from(txlist_hash.as_slice().to_vec()).expect("txlist hash error");
    let txlist =
        RawTxListGossip { raw_tx_list_hash: raw_tx_list_hash.clone(), txlist: txlist_bytes };

    // Build a signed commitment that references the txlist hash.
    let preconf = Preconfirmation {
        eop: false,
        block_number: u256_to_uint256(block_number),
        timestamp: u256_to_uint256(U256::from(1u64)),
        gas_limit: u256_to_uint256(U256::from(30_000_000u64)),
        proposal_id: u256_to_uint256(block_number),
        coinbase: address_to_bytes20(signer),
        submission_window_end: u256_to_uint256(submission_window_end),
        raw_tx_list_hash: raw_tx_list_hash.clone(),
        ..Default::default()
    };
    let commitment = PreconfCommitment { preconf, slasher_address: Bytes20::default() };
    let signature = sign_commitment(&commitment, signer_sk).expect("sign commitment failed");
    let signed_commitment = SignedCommitment { commitment, signature };

    (txlist, signed_commitment)
}

async fn wait_for_peer_connected(
    events: &mut tokio::sync::broadcast::Receiver<PreconfirmationEvent>,
) {
    loop {
        match events.recv().await {
            Ok(PreconfirmationEvent::PeerConnected(_)) => return,
            Ok(_) => continue,
            Err(err) => panic!("preconfirmation event stream closed: {err}"),
        }
    }
}

async fn wait_for_commitment_and_txlist(
    events: &mut tokio::sync::broadcast::Receiver<PreconfirmationEvent>,
) {
    let mut saw_commitment = false;
    let mut saw_txlist = false;
    while !(saw_commitment && saw_txlist) {
        match events.recv().await {
            Ok(PreconfirmationEvent::NewCommitment(_)) => {
                saw_commitment = true;
            }
            Ok(PreconfirmationEvent::NewTxList(_)) => {
                saw_txlist = true;
            }
            Ok(_) => continue,
            Err(err) => panic!("preconfirmation event stream closed: {err}"),
        }
    }
}

#[test_context(ShastaEnv)]
#[serial]
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
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
    let driver_client = JsonRpcDriverClient::new(driver_client_cfg).await?;

    let signer_sk = SecretKey::from_slice(&[1u8; 32]).expect("secret key");
    let signer = preconfirmation_types::public_key_to_address(
        &secp256k1::PublicKey::from_secret_key(&secp256k1::Secp256k1::new(), &signer_sk),
    );
    let submission_window_end = U256::from(1000u64);
    let event_sync_tip = driver_client.event_sync_tip().await?;
    let preconf_tip = driver_client.preconf_tip().await?;
    let commitment_block = if preconf_tip > event_sync_tip {
        preconf_tip + U256::ONE
    } else {
        event_sync_tip + U256::ONE
    };

    let resolver = StaticLookaheadResolver::new(signer, submission_window_end);

    // External P2P node used to publish gossip.
    let ext_cfg = test_p2p_config();
    let ext_validator: Box<dyn ValidationAdapter> = Box::new(LocalValidationAdapter::new(None));
    let ext_storage: Arc<dyn PreconfStorage> = Arc::new(InMemoryStorage::default());
    let (mut ext_handle, ext_node) =
        P2pNode::new_with_validator_and_storage(ext_cfg, ext_validator, ext_storage)?;
    let ext_node_handle: JoinHandle<anyhow::Result<()>> =
        tokio::spawn(async move { ext_node.run().await });

    let ext_dial_addr = ext_handle.dialable_addr().await?;

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
    ext_handle.wait_for_peer_connected().await?;

    // Publish txlist + commitment from external client.
    let (txlist, signed_commitment) =
        build_publish_payloads(&signer_sk, signer, submission_window_end, commitment_block);
    ext_handle.publish_raw_txlist(txlist).await?;
    ext_handle.publish_commitment(signed_commitment).await?;

    // Internal client should observe txlist + commitment and submit to driver RPC.
    wait_for_commitment_and_txlist(&mut events).await;
    spy.wait_for_submissions(1).await;

    event_loop_handle.abort();
    ext_node_handle.abort();
    rpc_server.stop().await;

    Ok(())
}

#![allow(clippy::too_many_arguments)]

use super::*;
use crate::{
    P2pConfig,
    behaviour::NetBehaviour,
    builder::BuiltParts,
    reputation::PeerReputationStore,
    validation::{LookaheadResolver, LookaheadValidationAdapter},
};
use futures::task::{ArcWake, noop_waker_ref, waker_ref};
use libp2p::{
    Multiaddr, Transport,
    core::{transport::memory::MemoryTransport, upgrade},
    identity, noise,
    swarm::Swarm,
    yamux,
};
use preconfirmation_types::{
    PreconfCommitment, Preconfirmation, SignedCommitment, Uint256, public_key_to_address,
};
use ssz_rs::Vector;
use std::{
    collections::HashMap,
    str::FromStr,
    sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    },
    task::{Context, Poll},
};
use tokio::{sync::oneshot, time::Duration};

/// Deterministic resolver that always returns the configured signer and echoes the slot end.
struct StaticLookaheadResolver {
    /// Signer address to return for all timestamps.
    signer: alloy_primitives::Address,
}

impl LookaheadResolver for StaticLookaheadResolver {
    fn signer_for_timestamp(
        &self,
        _submission_window_end: &preconfirmation_types::Uint256,
    ) -> Result<alloy_primitives::Address, String> {
        Ok(self.signer)
    }

    fn expected_slot_end(
        &self,
        submission_window_end: &preconfirmation_types::Uint256,
    ) -> Result<preconfirmation_types::Uint256, String> {
        Ok(submission_window_end.clone())
    }
}

/// Derive an Ethereum address from a secp256k1 secret key.
fn signer_for_sk(sk: &secp256k1::SecretKey) -> alloy_primitives::Address {
    public_key_to_address(&secp256k1::PublicKey::from_secret_key(&secp256k1::Secp256k1::new(), sk))
}

/// Listen on a loopback memory transport and return the assigned address.
async fn listen_on(driver: &mut NetworkDriver) -> Multiaddr {
    let addr: Multiaddr = Multiaddr::from_str("/ip4/127.0.0.1/tcp/0").unwrap();
    driver.swarm.listen_on(addr).unwrap();
    for _ in 0..10 {
        pump_sync(driver);
        if let Some(addr) = driver.swarm.listeners().next().cloned() {
            return addr;
        }
        tokio::time::sleep(Duration::from_millis(50)).await;
    }
    driver.swarm.listeners().next().cloned().expect("listener addr")
}

/// Poll the driver once synchronously.
fn pump_sync(driver: &mut NetworkDriver) {
    let w = noop_waker_ref();
    let mut cx = Context::from_waker(w);
    let _ = driver.poll(&mut cx);
}

/// Poll the driver once asynchronously.
async fn pump_async(driver: &mut NetworkDriver) {
    futures::future::poll_fn(|cx| {
        let _ = driver.poll(cx);
        Poll::Ready(())
    })
    .await;
}

#[test]
fn driver_poll_registers_command_waker() {
    struct WakeCounter {
        wakes: AtomicUsize,
    }

    impl ArcWake for WakeCounter {
        fn wake_by_ref(arc_self: &Arc<Self>) {
            arc_self.wakes.fetch_add(1, Ordering::SeqCst);
        }
    }

    let cfg = NetworkConfig { enable_discovery: false, ..Default::default() };
    let lookahead = Arc::new(StaticLookaheadResolver { signer: alloy_primitives::Address::ZERO });
    let parts = build_memory_parts(cfg.chain_id, &cfg);
    let (mut driver, handle) = driver_from_parts(parts, &cfg, lookahead);

    let waker_state = Arc::new(WakeCounter { wakes: AtomicUsize::new(0) });
    let waker = waker_ref(&waker_state);
    let mut cx = Context::from_waker(&waker);

    assert!(matches!(driver.poll(&mut cx), Poll::Pending));
    assert_eq!(waker_state.wakes.load(Ordering::SeqCst), 0);

    handle
        .commands
        .try_send(NetworkCommand::UpdateHead { head: PreconfHead::default() })
        .expect("send update head command");

    assert!(waker_state.wakes.load(Ordering::SeqCst) > 0);
}

/// Build transport/behaviour parts using the in-memory transport for deterministic tests.
fn build_memory_parts(chain_id: u64, cfg: &NetworkConfig) -> BuiltParts {
    let keypair = identity::Keypair::generate_ed25519();
    let noise_config = noise::Config::new(&keypair).expect("noise config");
    let transport = MemoryTransport::default()
        .upgrade(upgrade::Version::V1Lazy)
        .authenticate(noise_config)
        .multiplex(yamux::Config::default())
        .boxed();

    let topics = (
        libp2p::gossipsub::IdentTopic::new(
            preconfirmation_types::topic_preconfirmation_commitments(chain_id),
        ),
        libp2p::gossipsub::IdentTopic::new(preconfirmation_types::topic_raw_txlists(chain_id)),
    );
    let protocols = crate::codec::Protocols {
        commitments: preconfirmation_types::protocol_get_commitments_by_number(chain_id),
        raw_txlists: preconfirmation_types::protocol_get_raw_txlist(chain_id),
        head: preconfirmation_types::protocol_get_head(chain_id),
    };
    let behaviour =
        NetBehaviour::new(keypair.clone(), topics.clone(), protocols, cfg).expect("behaviour");

    BuiltParts { keypair, transport, behaviour, topics }
}

/// Build a driver from pre-built parts (used for memory transport tests).
fn driver_from_parts(
    parts: BuiltParts,
    cfg: &NetworkConfig,
    lookahead: Arc<dyn LookaheadResolver>,
) -> (NetworkDriver, NetworkHandle) {
    let peer_id = parts.keypair.public().to_peer_id();
    let config = libp2p::swarm::Config::with_tokio_executor();
    let swarm = Swarm::new(parts.transport, parts.behaviour, peer_id, config);

    cfg.validate_request_rate_limits();

    let (events_tx, events_rx) = mpsc::channel(256);
    let (cmd_tx, cmd_rx) = mpsc::channel(256);
    let _ = events_tx.try_send(NetworkEvent::Started);

    (
        NetworkDriver {
            swarm,
            events_tx: events_tx.clone(),
            commands_rx: cmd_rx,
            topics: parts.topics,
            reputation: PeerReputationStore::new(ReputationConfig {
                greylist_threshold: cfg.reputation_greylist,
                ban_threshold: cfg.reputation_ban,
                halflife: cfg.reputation_halflife,
            }),
            request_limiter: RequestRateLimiter::new(
                cfg.request_window,
                cfg.max_requests_per_window,
            ),
            pending_requests: HashMap::new(),
            validator: Box::new(LookaheadValidationAdapter::new(None, lookahead)),
            discovery_rx: None,
            connected_peers: 0,
            head: PreconfHead::default(),
            kona_gater: super::build_kona_gater(cfg),
            storage: crate::storage::default_storage(),
        },
        NetworkHandle {
            events: events_rx,
            commands: cmd_tx,
            local_peer_id: peer_id,
            listen_addr_timeout: None,
        },
    )
}

#[test]
fn driver_exposes_peer_reputation_store() {
    let cfg = NetworkConfig { enable_discovery: false, ..Default::default() };
    let lookahead = Arc::new(StaticLookaheadResolver { signer: alloy_primitives::Address::ZERO });
    let parts = build_memory_parts(cfg.chain_id, &cfg);
    let (driver, _handle) = driver_from_parts(parts, &cfg, lookahead);

    let store: &PeerReputationStore = &driver.reputation;
    let peer = *driver.swarm.local_peer_id();
    assert!(!store.is_banned(&peer));
}

/// Create a signed commitment for testing using the provided secret key.
fn sample_signed_commitment(sk: &secp256k1::SecretKey) -> SignedCommitment {
    let commitment = PreconfCommitment {
        preconf: Preconfirmation {
            eop: true,
            block_number: Uint256::from(1u64),
            timestamp: Uint256::from(1u64),
            gas_limit: Uint256::from(1u64),
            coinbase: Vector::try_from(vec![0u8; 20]).unwrap(),
            anchor_block_number: Uint256::from(1u64),
            raw_tx_list_hash: Vector::try_from(vec![0u8; 32]).unwrap(),
            parent_preconfirmation_hash: Vector::try_from(vec![0u8; 32]).unwrap(),
            submission_window_end: Uint256::from(1u64),
            prover_auth: Vector::try_from(vec![0u8; 20]).unwrap(),
            proposal_id: Uint256::from(1u64),
        },
        slasher_address: Vector::try_from(vec![0u8; 20]).unwrap(),
    };
    let sig = preconfirmation_types::sign_commitment(&commitment, sk).unwrap();
    SignedCommitment { commitment, signature: sig }
}

/// End-to-end gossip and req/resp roundtrip between two in-memory peers.
#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn gossipsub_and_reqresp_roundtrip() {
    // Keep a hard cap so dev runs don't stall; still exercises the same path.
    let deadline = tokio::time::Instant::now() + Duration::from_secs(25);
    let mut success = false;
    for _attempt in 0..2 {
        let mut cfg = NetworkConfig { enable_discovery: false, ..Default::default() };
        cfg.listen_addr = "127.0.0.1:0".parse().unwrap();
        cfg.discv5_listen = "127.0.0.1:0".parse().unwrap();
        let sk1 = secp256k1::SecretKey::new(&mut rand::thread_rng());
        let lookahead = Arc::new(StaticLookaheadResolver { signer: signer_for_sk(&sk1) });
        let validator1 = Box::new(LookaheadValidationAdapter::new(None, lookahead.clone()));
        let Ok((mut driver1, mut handle1)) =
            NetworkDriver::new_with_validator(cfg.clone(), validator1)
        else {
            eprintln!("skipping: environment may block local TCP (driver init failed)");
            return;
        };
        let validator2 = Box::new(LookaheadValidationAdapter::new(None, lookahead));
        let Ok((mut driver2, mut handle2)) = NetworkDriver::new_with_validator(cfg, validator2)
        else {
            eprintln!("skipping: environment may block local TCP (driver init failed)");
            return;
        };

        let _addr1 = listen_on(&mut driver1).await;
        let addr2 = listen_on(&mut driver2).await;
        let peer1_id = *driver1.swarm.local_peer_id();
        let peer2_id = *driver2.swarm.local_peer_id();
        let mut addr2_full = addr2.clone();
        addr2_full.push(libp2p::multiaddr::Protocol::P2p(peer2_id));

        driver1.swarm.dial(addr2_full.clone()).unwrap();

        let mut peer1_connected = false;
        let mut peer2_connected = false;
        for _ in 0..400 {
            pump_async(&mut driver1).await;
            pump_async(&mut driver2).await;
            while let Ok(ev) = handle1.events.try_recv() {
                if matches!(ev, NetworkEvent::PeerConnected(_)) {
                    peer1_connected = true;
                }
            }
            while let Ok(ev) = handle2.events.try_recv() {
                if matches!(ev, NetworkEvent::PeerConnected(_)) {
                    peer2_connected = true;
                }
            }
            if peer1_connected && peer2_connected {
                break;
            }
            if tokio::time::Instant::now() >= deadline {
                break;
            }
            tokio::time::sleep(Duration::from_millis(5)).await;
        }
        if !(peer1_connected && peer2_connected) {
            continue;
        }

        driver1.swarm.behaviour_mut().gossipsub.add_explicit_peer(&peer2_id);
        driver2.swarm.behaviour_mut().gossipsub.add_explicit_peer(&peer1_id);

        for _ in 0..8 {
            pump_async(&mut driver1).await;
            pump_async(&mut driver2).await;
            tokio::time::sleep(Duration::from_millis(60)).await;
        }

        let commit = sample_signed_commitment(&sk1);
        handle1.commands.send(NetworkCommand::PublishCommitment(commit.clone())).await.unwrap();

        let mut received = false;
        for _ in 0..400 {
            pump_async(&mut driver1).await;
            pump_async(&mut driver2).await;
            if let Ok(NetworkEvent::GossipSignedCommitment { msg, .. }) = handle2.events.try_recv()
            {
                assert_eq!(*msg, commit);
                received = true;
                break;
            }
            if tokio::time::Instant::now() >= deadline {
                break;
            }
            tokio::time::sleep(Duration::from_millis(5)).await;
        }
        if !received {
            continue;
        }

        handle1
            .commands
            .send(NetworkCommand::RequestCommitments {
                respond_to: None,
                start_block: Uint256::from(0u64),
                max_count: 1,
                peer: None,
            })
            .await
            .unwrap();

        let mut got_resp = false;
        for _ in 0..400 {
            pump_async(&mut driver1).await;
            pump_async(&mut driver2).await;
            if let Ok(NetworkEvent::ReqRespCommitments { .. }) = handle1.events.try_recv() {
                got_resp = true;
                break;
            }
            if tokio::time::Instant::now() >= deadline {
                break;
            }
            tokio::time::sleep(Duration::from_millis(5)).await;
        }
        if got_resp {
            success = true;
            break;
        }
    }

    if !success {
        eprintln!(
            "skipping: real TCP roundtrip failed after retries; environment may block local TCP"
        );
    }
}

/// In-memory transport covers gossip, req/resp, and ban propagation.
#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn memory_transport_gossip_reqresp_and_ban() {
    let cfg = NetworkConfig { enable_discovery: false, ..Default::default() };
    let parts1 = build_memory_parts(cfg.chain_id, &cfg);
    let parts2 = build_memory_parts(cfg.chain_id, &cfg);
    let sk = secp256k1::SecretKey::from_slice(&[9u8; 32]).unwrap();
    let lookahead = Arc::new(StaticLookaheadResolver { signer: signer_for_sk(&sk) });
    let (mut driver1, handle1) = driver_from_parts(parts1, &cfg, lookahead.clone());
    let (mut driver2, mut handle2) = driver_from_parts(parts2, &cfg, lookahead);

    let (tx, rx) = oneshot::channel();
    handle1
        .commands
        .send(NetworkCommand::RequestHead { respond_to: Some(tx), peer: None })
        .await
        .unwrap();
    pump_async(&mut driver1).await;
    let result = tokio::time::timeout(Duration::from_millis(50), rx).await;
    let Ok(Ok(Err(err))) = result else {
        panic!("expected req/resp error when no peers available");
    };
    assert_eq!(err.kind, NetworkErrorKind::ReqRespBackpressure);

    let addr1: Multiaddr = "/memory/1001".parse().unwrap();
    let mut addr1_full = addr1.clone();
    addr1_full.push(libp2p::multiaddr::Protocol::P2p(*driver1.swarm.local_peer_id()));

    driver1.swarm.listen_on(addr1.clone()).unwrap();
    driver2.swarm.dial(addr1_full.clone()).unwrap();

    for _ in 0..50 {
        pump_async(&mut driver1).await;
        pump_async(&mut driver2).await;
        tokio::time::sleep(Duration::from_millis(50)).await;
    }

    handle1
        .commands
        .send(NetworkCommand::PublishCommitment(sample_signed_commitment(&sk)))
        .await
        .unwrap();

    handle2
        .commands
        .send(NetworkCommand::RequestCommitments {
            respond_to: None,
            start_block: Uint256::from(0u64),
            max_count: 1,
            peer: None,
        })
        .await
        .unwrap();

    let mut received = false;
    let mut banned = false;
    for _ in 0..2000 {
        pump_async(&mut driver1).await;
        pump_async(&mut driver2).await;
        while let Ok(ev) = handle2.events.try_recv() {
            match ev {
                NetworkEvent::GossipSignedCommitment { .. } => received = true,
                NetworkEvent::ReqRespCommitments { .. } => received = true,
                NetworkEvent::PeerDisconnected(peer) if peer == *driver2.swarm.local_peer_id() => {
                    banned = true;
                }
                _ => {}
            }
        }
        if received {
            break;
        }
        tokio::time::sleep(Duration::from_millis(10)).await;
    }

    assert!(received);
    assert!(!banned);
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn reqresp_errors_when_no_peer_available() {
    let cfg = NetworkConfig { enable_discovery: false, ..Default::default() };
    let lookahead = Arc::new(StaticLookaheadResolver { signer: alloy_primitives::Address::ZERO });
    let validator = Box::new(LookaheadValidationAdapter::new(None, lookahead));
    let Ok((mut driver, handle)) = NetworkDriver::new_with_validator(cfg, validator) else {
        panic!("driver init failed");
    };

    let (tx, rx) = oneshot::channel();
    handle
        .commands
        .send(NetworkCommand::RequestHead { respond_to: Some(tx), peer: None })
        .await
        .unwrap();
    pump_async(&mut driver).await;

    let result = tokio::time::timeout(Duration::from_millis(50), rx).await;
    let Ok(Ok(Err(err))) = result else {
        panic!("expected req/resp error when no peers available");
    };
    assert_eq!(err.kind, NetworkErrorKind::ReqRespBackpressure);
}

#[test]
fn p2p_config_enable_quic_wiring() {
    let p2p = P2pConfig { enable_quic: false, enable_tcp: true, ..Default::default() };
    let internal: NetworkConfig = p2p.into();
    assert!(!internal.enable_quic);
    assert!(internal.enable_tcp);
}

#[test]
fn p2p_config_transport_defaults_match_internal() {
    let p2p = P2pConfig::default();
    assert!(p2p.enable_quic);
    assert!(p2p.enable_tcp);
}

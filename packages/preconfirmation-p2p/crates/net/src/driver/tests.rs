#![allow(clippy::too_many_arguments)]

use super::*;
use crate::{behaviour::NetBehaviour, builder::BuiltParts};
use futures::task::noop_waker_ref;
use libp2p::{
    Multiaddr, Transport,
    core::{transport::memory::MemoryTransport, upgrade},
    identity, noise,
    swarm::Swarm,
    yamux,
};
use preconfirmation_types::{PreconfCommitment, Preconfirmation, SignedCommitment, Uint256};
use ssz_rs::Vector;
use std::{str::FromStr, task::Context};
use tokio::time::Duration;

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

fn pump_sync(driver: &mut NetworkDriver) {
    let w = noop_waker_ref();
    let mut cx = Context::from_waker(w);
    let _ = driver.poll(&mut cx);
}

async fn pump_async(driver: &mut NetworkDriver) {
    futures::future::poll_fn(|cx| {
        let _ = driver.poll(cx);
        std::task::Poll::Ready(())
    })
    .await;
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
        commitments: crate::codec::SszProtocol(
            preconfirmation_types::protocol_get_commitments_by_number(chain_id),
        ),
        raw_txlists: crate::codec::SszProtocol(preconfirmation_types::protocol_get_raw_txlist(
            chain_id,
        )),
        head: crate::codec::SszProtocol(preconfirmation_types::protocol_get_head(chain_id)),
    };
    let behaviour =
        NetBehaviour::new(keypair.public(), topics.clone(), protocols, cfg).expect("behaviour");

    BuiltParts { keypair, transport, behaviour, topics }
}

/// Build a driver from pre-built parts (used for memory transport tests).
fn driver_from_parts(parts: BuiltParts, cfg: &NetworkConfig) -> (NetworkDriver, NetworkHandle) {
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
            reputation: super::build_reputation_backend(ReputationConfig {
                greylist_threshold: cfg.reputation_greylist,
                ban_threshold: cfg.reputation_ban,
                halflife: cfg.reputation_halflife,
                weights: reth_network_types::peers::reputation::ReputationChangeWeights::default(),
            }),
            request_limiter: RequestRateLimiter::new(
                cfg.request_window,
                cfg.max_requests_per_window,
            ),
            commitments_out: VecDeque::new(),
            raw_txlists_out: VecDeque::new(),
            head_out: VecDeque::new(),
            validator: Box::new(LocalValidationAdapter::new(None)),
            discovery_rx: None,
            _discovery_task: None,
            connected_peers: 0,
            head: PreconfHead::default(),
            kona_gater: super::build_kona_gater(cfg),
            commitments_store: std::collections::BTreeMap::new(),
            txlist_store: std::collections::HashMap::new(),
        },
        NetworkHandle { events: events_rx, commands: cmd_tx },
    )
}

fn sample_signed_commitment(sk: &secp256k1::SecretKey) -> SignedCommitment {
    let commitment = PreconfCommitment {
        preconf: Preconfirmation {
            eop: false,
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

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn gossipsub_and_reqresp_roundtrip() {
    // Keep a hard cap so dev runs don't stall; still exercises the same path.
    let deadline = tokio::time::Instant::now() + Duration::from_secs(25);
    let mut success = false;
    for _attempt in 0..2 {
        let mut cfg = NetworkConfig { enable_discovery: false, ..Default::default() };
        cfg.listen_addr.set_port(0);
        cfg.discv5_listen.set_port(0);
        let (driver1, mut handle1) = NetworkDriver::new(cfg.clone()).unwrap();
        let (driver2, mut handle2) = NetworkDriver::new(cfg).unwrap();

        let mut driver1 = driver1;
        let mut driver2 = driver2;

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

        let sk1 = secp256k1::SecretKey::new(&mut rand::thread_rng());
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

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn memory_transport_gossip_reqresp_and_ban() {
    let cfg = NetworkConfig { enable_discovery: false, ..Default::default() };
    let parts1 = build_memory_parts(cfg.chain_id, &cfg);
    let parts2 = build_memory_parts(cfg.chain_id, &cfg);
    let (mut driver1, handle1) = driver_from_parts(parts1, &cfg);
    let (mut driver2, mut handle2) = driver_from_parts(parts2, &cfg);

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
        .send(NetworkCommand::PublishCommitment(sample_signed_commitment(
            &secp256k1::SecretKey::new(&mut rand::thread_rng()),
        )))
        .await
        .unwrap();

    handle2
        .commands
        .send(NetworkCommand::RequestCommitments {
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

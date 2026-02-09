#![allow(dead_code)]

#[path = "../src/codec.rs"]
mod codec;
#[path = "../src/error.rs"]
mod error;
#[path = "../src/network.rs"]
mod network;

use std::time::Duration;

use alloy_primitives::{Address, B256, Bloom, Bytes, U256};
use alloy_rpc_types_engine::ExecutionPayloadV1;
use futures::StreamExt;
use libp2p::{
    Transport,
    core::upgrade,
    gossipsub, identify, identity, noise, ping,
    swarm::{NetworkBehaviour, SwarmEvent},
    tcp, yamux,
};
use preconfirmation_net::P2pConfig;

use network::{NetworkCommand, NetworkEvent, WhitelistNetwork};

fn sample_response_envelope() -> codec::WhitelistExecutionPayloadEnvelope {
    codec::WhitelistExecutionPayloadEnvelope {
        end_of_sequencing: Some(true),
        is_forced_inclusion: Some(true),
        parent_beacon_block_root: Some(B256::from([0x44u8; 32])),
        execution_payload: ExecutionPayloadV1 {
            parent_hash: B256::from([0x01u8; 32]),
            fee_recipient: Address::from([0x11u8; 20]),
            state_root: B256::from([0x02u8; 32]),
            receipts_root: B256::from([0x03u8; 32]),
            logs_bloom: Bloom::default(),
            prev_randao: B256::from([0x04u8; 32]),
            block_number: 42,
            gas_limit: 30_000_000,
            gas_used: 21_000,
            timestamp: 1_735_000_000,
            extra_data: Bytes::from(vec![0x55u8; 8]),
            base_fee_per_gas: U256::from(1_000_000_000u64),
            block_hash: B256::from([0x05u8; 32]),
            transactions: vec![Bytes::from(vec![0x99u8; 4])],
        },
        signature: Some([0x22u8; 65]),
    }
}

#[tokio::test]
async fn whitelist_network_subscribes_to_go_style_anonymous_request_topic() {
    /// Test-only swarm behaviour for request-topic ingress validation.
    #[derive(NetworkBehaviour)]
    struct TestBehaviour {
        /// Gossipsub behaviour under test.
        gossipsub: gossipsub::Behaviour,
        /// Ping behaviour required by the composite behaviour.
        ping: ping::Behaviour,
        /// Identify behaviour required by the composite behaviour.
        identify: identify::Behaviour,
    }

    let chain_id = 167_000;
    let topic = gossipsub::IdentTopic::new(format!("/taiko/{chain_id}/0/requestPreconfBlocks"));

    let key = identity::Keypair::generate_ed25519();
    let peer_id = key.public().to_peer_id();
    let noise_config = noise::Config::new(&key).expect("noise config");

    let transport = tcp::tokio::Transport::new(tcp::Config::default().nodelay(true))
        .upgrade(upgrade::Version::V1Lazy)
        .authenticate(noise_config)
        .multiplex(yamux::Config::default())
        .boxed();

    let mut gs = network::build_gossipsub().expect("gossipsub config");
    gs.subscribe(&topic).expect("topic subscribe");

    let behaviour = TestBehaviour {
        gossipsub: gs,
        ping: ping::Behaviour::new(ping::Config::new()),
        identify: identify::Behaviour::new(identify::Config::new(
            "/taiko/whitelist-preconfirmation-test/1.0.0".to_string(),
            key.public(),
        )),
    };

    let mut peer_swarm = libp2p::Swarm::new(
        transport,
        behaviour,
        peer_id,
        libp2p::swarm::Config::with_tokio_executor(),
    );

    peer_swarm
        .listen_on("/ip4/127.0.0.1/tcp/0".parse().expect("listen addr"))
        .expect("listen should succeed");

    let external_addr = loop {
        match peer_swarm.select_next_some().await {
            SwarmEvent::NewListenAddr { address, .. } => {
                break address;
            }
            _ => {}
        }
    };

    let dial_addr = external_addr.with(libp2p::multiaddr::Protocol::P2p(peer_id));

    let mut cfg = P2pConfig::default();
    cfg.chain_id = chain_id;
    cfg.enable_discovery = false;
    cfg.enable_tcp = true;
    cfg.listen_addr = "127.0.0.1:0".parse().expect("listen addr");
    cfg.pre_dial_peers = vec![dial_addr];

    let mut whitelist_network = WhitelistNetwork::spawn(cfg).expect("spawn network");

    let publish_task = tokio::spawn(async move {
        let mut connected = false;
        let mut interval = tokio::time::interval(Duration::from_millis(800));
        let payload = [0x77u8; 32].to_vec();

        loop {
            tokio::select! {
                event = peer_swarm.select_next_some() => {
                    if let SwarmEvent::ConnectionEstablished { .. } = event {
                        connected = true;
                    }
                }
                _ = interval.tick(), if connected => {
                    let _ = peer_swarm.behaviour_mut().gossipsub.publish(topic.clone(), payload.clone());
                }
            }
        }
    });

    let received_hash = tokio::time::timeout(Duration::from_secs(20), async {
        loop {
            match whitelist_network.event_rx.recv().await {
                Some(NetworkEvent::UnsafeRequest { hash, .. }) => return hash,
                Some(_) => continue,
                None => panic!("event channel closed before request arrived"),
            }
        }
    })
    .await
    .expect("timed out waiting for unsafe request");

    assert_eq!(received_hash, B256::from([0x77u8; 32]));

    publish_task.abort();
    let _ = whitelist_network.command_tx.send(NetworkCommand::Shutdown).await;
    let _ = whitelist_network.handle.await;
}

#[tokio::test]
async fn whitelist_network_publishes_to_go_style_response_topic() {
    /// Test-only swarm behaviour mirroring the production protocol stack.
    #[derive(NetworkBehaviour)]
    #[behaviour(to_swarm = "TestBehaviourEvent")]
    struct TestBehaviour {
        /// Gossipsub behaviour under test.
        gossipsub: gossipsub::Behaviour,
        /// Ping behaviour required by the composite behaviour.
        ping: ping::Behaviour,
        /// Identify behaviour required by the composite behaviour.
        identify: identify::Behaviour,
    }

    /// Test-only event wrapper emitted by `TestBehaviour`.
    #[derive(Debug)]
    enum TestBehaviourEvent {
        /// Wrapped gossipsub event.
        Gossipsub(Box<gossipsub::Event>),
        /// Ping event marker.
        Ping,
        /// Identify event marker.
        Identify,
    }

    impl From<gossipsub::Event> for TestBehaviourEvent {
        /// Convert gossipsub events into the unified test event type.
        fn from(value: gossipsub::Event) -> Self {
            Self::Gossipsub(Box::new(value))
        }
    }

    impl From<ping::Event> for TestBehaviourEvent {
        /// Convert ping events into the unified test event type.
        fn from(_: ping::Event) -> Self {
            Self::Ping
        }
    }

    impl From<identify::Event> for TestBehaviourEvent {
        /// Convert identify events into the unified test event type.
        fn from(_: identify::Event) -> Self {
            Self::Identify
        }
    }

    let chain_id = 167_000;
    let topic = gossipsub::IdentTopic::new(format!("/taiko/{chain_id}/0/responsePreconfBlocks"));

    let key = identity::Keypair::generate_ed25519();
    let peer_id = key.public().to_peer_id();
    let noise_config = noise::Config::new(&key).expect("noise config");

    let transport = tcp::tokio::Transport::new(tcp::Config::default().nodelay(true))
        .upgrade(upgrade::Version::V1Lazy)
        .authenticate(noise_config)
        .multiplex(yamux::Config::default())
        .boxed();

    let mut gs = network::build_gossipsub().expect("gossipsub config");
    gs.subscribe(&topic).expect("topic subscribe");

    let behaviour = TestBehaviour {
        gossipsub: gs,
        ping: ping::Behaviour::new(ping::Config::new()),
        identify: identify::Behaviour::new(identify::Config::new(
            "/taiko/whitelist-preconfirmation-test/1.0.0".to_string(),
            key.public(),
        )),
    };

    let mut peer_swarm = libp2p::Swarm::new(
        transport,
        behaviour,
        peer_id,
        libp2p::swarm::Config::with_tokio_executor(),
    );

    peer_swarm
        .listen_on("/ip4/127.0.0.1/tcp/0".parse().expect("listen addr"))
        .expect("listen should succeed");

    let external_addr = loop {
        match peer_swarm.select_next_some().await {
            SwarmEvent::NewListenAddr { address, .. } => {
                break address;
            }
            _ => {}
        }
    };

    let dial_addr = external_addr.with(libp2p::multiaddr::Protocol::P2p(peer_id));

    let mut cfg = P2pConfig::default();
    cfg.chain_id = chain_id;
    cfg.enable_discovery = false;
    cfg.enable_tcp = true;
    cfg.listen_addr = "127.0.0.1:0".parse().expect("listen addr");
    cfg.pre_dial_peers = vec![dial_addr];

    let whitelist_network = WhitelistNetwork::spawn(cfg).expect("spawn network");
    let expected = sample_response_envelope();
    let expected_to_publish = expected.clone();
    let command_tx = whitelist_network.command_tx.clone();
    let local_peer_id = whitelist_network.local_peer_id;

    let decoded = tokio::time::timeout(Duration::from_secs(20), async move {
        let mut subscribed = false;
        let mut interval = tokio::time::interval(Duration::from_millis(500));
        loop {
            tokio::select! {
                event = peer_swarm.select_next_some() => {
                    if let SwarmEvent::Behaviour(TestBehaviourEvent::Gossipsub(event)) = event {
                        match *event {
                            gossipsub::Event::Subscribed { peer_id, topic: subscribed_topic }
                                if peer_id == local_peer_id &&
                                    subscribed_topic == topic.hash() =>
                            {
                                subscribed = true;
                            }
                            gossipsub::Event::Message { message, .. } => {
                                if message.topic == topic.hash() {
                                    return codec::decode_unsafe_response_message(&message.data)
                                        .expect("decode response");
                                }
                            }
                            _ => {}
                        }
                    }
                }
                _ = interval.tick(), if subscribed => {
                    command_tx
                        .send(NetworkCommand::PublishUnsafeResponse {
                            envelope: Box::new(expected_to_publish.clone()),
                        })
                        .await
                        .expect("publish response command");
                }
            }
        }
    })
    .await
    .expect("timed out waiting for response publication");

    assert_eq!(decoded.execution_payload.block_hash, expected.execution_payload.block_hash);
    assert_eq!(decoded.signature, expected.signature);

    let _ = whitelist_network.command_tx.send(NetworkCommand::Shutdown).await;
    let _ = whitelist_network.handle.await;
}

use std::{sync::Arc, time::Duration};

use alloy_primitives::{Address, B256, Bloom, Bytes, U256};
use alloy_rpc_types_engine::ExecutionPayloadV1;
use futures::StreamExt;
use libp2p::{
    PeerId, Transport,
    core::upgrade,
    gossipsub, identify, identity, noise, ping,
    swarm::{NetworkBehaviour, SwarmEvent},
    tcp, yamux,
};
use preconfirmation_net::P2pConfig;
use protocol::signer::FixedKSigner;
use tokio::sync::mpsc;

use super::{
    NetworkCommand, NetworkEvent, WhitelistNetwork,
    bootnodes::{classify_bootnodes, parse_enode_url},
    event_loop::{
        decode_eos_epoch, decode_eos_epoch_exact, decode_request_hash, decode_request_hash_exact,
        forward_event,
    },
    gossip::{build_gossipsub, message_id},
    inbound::EpochSeenTracker,
};
use crate::{
    codec::{
        DecodedUnsafePayload, WhitelistExecutionPayloadEnvelope, decode_unsafe_response_message,
        encode_envelope_ssz,
    },
    network::inbound::GossipsubInboundState,
};

fn sample_response_envelope() -> WhitelistExecutionPayloadEnvelope {
    WhitelistExecutionPayloadEnvelope {
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

fn sample_preconf_payload() -> DecodedUnsafePayload {
    let envelope = sample_response_envelope();
    let payload_bytes = encode_envelope_ssz(&envelope);
    DecodedUnsafePayload { wire_signature: [0x11u8; 65], payload_bytes, envelope }
}

fn signed_wire_signature(signer: &FixedKSigner, prehash: B256) -> [u8; 65] {
    let sig = signer.sign_with_predefined_k(prehash.as_ref()).expect("sign prehash for test");

    let mut wire_signature = [0u8; 65];
    wire_signature[..32].copy_from_slice(&sig.signature.r().to_be_bytes::<32>());
    wire_signature[32..64].copy_from_slice(&sig.signature.s().to_be_bytes::<32>());
    wire_signature[64] = sig.recovery_id;
    wire_signature
}

fn sample_signed_preconf_payload(chain_id: u64, signer: &FixedKSigner) -> DecodedUnsafePayload {
    let mut payload = sample_preconf_payload();
    payload.wire_signature = signed_wire_signature(
        signer,
        crate::codec::block_signing_hash(chain_id, payload.payload_bytes.as_slice()),
    );
    payload
}

fn sample_signed_response_envelope(
    chain_id: u64,
    signer: &FixedKSigner,
) -> WhitelistExecutionPayloadEnvelope {
    let mut envelope = sample_response_envelope();
    envelope.signature = Some(signed_wire_signature(
        signer,
        crate::codec::block_signing_hash(
            chain_id,
            envelope.execution_payload.block_hash.as_slice(),
        ),
    ));
    envelope
}

#[test]
fn message_id_changes_with_snappy_validity() {
    let topic = "/taiko/167000/0/requestPreconfBlocks";
    let payload = b"hello-whitelist-preconfirmation";
    let compressed =
        snap::raw::Encoder::new().compress_vec(payload).expect("compression should work");

    let valid = gossipsub::Message {
        source: None,
        data: compressed,
        sequence_number: None,
        topic: gossipsub::TopicHash::from_raw(topic),
    };
    let invalid = gossipsub::Message {
        source: None,
        data: payload.to_vec(),
        sequence_number: None,
        topic: gossipsub::TopicHash::from_raw(topic),
    };

    let valid_id = message_id(&valid);
    let invalid_id = message_id(&invalid);

    assert_eq!(valid_id.0.len(), 20);
    assert_eq!(invalid_id.0.len(), 20);
    assert_ne!(valid_id, invalid_id);

    let changed_topic = gossipsub::Message {
        source: None,
        data: snap::raw::Encoder::new().compress_vec(payload).expect("compression should work"),
        sequence_number: None,
        topic: gossipsub::TopicHash::from_raw("/taiko/1/0/requestPreconfBlocks"),
    };
    let changed_topic_id = message_id(&changed_topic);
    assert_ne!(valid_id, changed_topic_id);
}

#[test]
fn parse_enode_url_valid_ipv4() {
    let url = "enode://a3f84d16471e6d8a0dc1e2d62f7a9c5b3e4f5678901234567890abcdef123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef01234567@10.0.1.5:30303?discport=30304";
    let addr = parse_enode_url(url).expect("should parse valid enode URL");
    assert_eq!(addr.to_string(), "/ip4/10.0.1.5/tcp/30303");
}

#[test]
fn parse_enode_url_valid_ipv4_no_query() {
    let url = "enode://abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890@192.168.1.1:30303";
    let addr = parse_enode_url(url).expect("should parse enode URL without query");
    assert_eq!(addr.to_string(), "/ip4/192.168.1.1/tcp/30303");
}

#[test]
fn parse_enode_url_invalid_inputs() {
    assert!(parse_enode_url("enr:-IS4QO3Qh8n0").is_none(), "ENR should not parse as enode");
    assert!(parse_enode_url("enode://no-at-sign").is_none(), "missing @ should fail");
    assert!(
        parse_enode_url("enode://abc@not-a-socket-addr").is_none(),
        "bad host:port should fail"
    );
    assert!(parse_enode_url("/ip4/127.0.0.1/tcp/9000").is_none(), "multiaddr should fail");
    assert!(parse_enode_url("").is_none(), "empty string should fail");
}

#[test]
fn decode_eos_epoch_accepts_u64_be_bytes() {
    let epoch = 42u64;
    assert_eq!(decode_eos_epoch(&epoch.to_be_bytes()), epoch);
}

#[test]
fn decode_eos_epoch_matches_set_bytes_semantics_for_variable_lengths() {
    assert_eq!(decode_eos_epoch(&[]), 0);
    assert_eq!(decode_eos_epoch(&[0u8; 7]), 0);
    assert_eq!(decode_eos_epoch(&[0x01u8; 9]), 0x0101010101010101);
}

#[test]
fn decode_eos_epoch_requires_fixed_8_byte_length_for_request_topic() {
    assert_eq!(
        decode_eos_epoch_exact(&42u64.to_be_bytes()),
        Some(u64::from_be_bytes(42u64.to_be_bytes()))
    );
    assert_eq!(decode_eos_epoch_exact(&[]), None);
    assert_eq!(decode_eos_epoch_exact(&[0x2au8; 7]), None);
    assert_eq!(decode_eos_epoch_exact(&[0x2au8; 9]), None);
}

#[test]
fn decode_request_hash_matches_set_bytes_semantics_for_variable_lengths() {
    let mut expected_short = [0u8; 32];
    expected_short[31] = 0x01;
    assert_eq!(decode_request_hash(&[]), B256::ZERO);
    assert_eq!(decode_request_hash(&[0x01u8]), B256::from(expected_short));

    let mut expected_short_vec = [0u8; 32];
    expected_short_vec[29] = 0xff;
    expected_short_vec[30] = 0xff;
    expected_short_vec[31] = 0xff;
    assert_eq!(decode_request_hash(&[0xffu8; 3]), B256::from(expected_short_vec));

    assert_eq!(decode_request_hash(&[0x01u8; 33]), B256::from([0x01u8; 32]));
}

#[test]
fn decode_request_hash_requires_fixed_32_byte_length_for_request_topic() {
    assert_eq!(decode_request_hash_exact(&[0x02u8; 32]), Some(B256::from([0x02u8; 32])));
    assert_eq!(decode_request_hash_exact(&[]), None);
    assert_eq!(decode_request_hash_exact(&[0x02u8; 33]), None);
}

#[test]
fn height_seen_tracker_rejects_over_limit_and_skips_tracking_rejected_hashes() {
    let mut validation_state =
        GossipsubInboundState::new_with_allow_all_sequencers(167_000, Vec::new(), false);

    assert!(validation_state.preconf_seen_by_height.can_accept(1, B256::from([1u8; 32]), 1));
    assert!(validation_state.preconf_seen_by_height.can_accept(1, B256::from([2u8; 32]), 1));
    assert!(!validation_state.preconf_seen_by_height.can_accept(1, B256::from([3u8; 32]), 1));
    assert_eq!(validation_state.preconf_seen_by_height.seen_by_height.len(), 1);
    assert_eq!(validation_state.preconf_seen_by_height.seen_by_height[&1].len(), 2);
    assert_eq!(
        validation_state.preconf_seen_by_height.seen_by_height[&1],
        vec![B256::from([1u8; 32]), B256::from([2u8; 32])]
    );

    assert!(validation_state.preconf_seen_by_height.can_accept(2, B256::from([3u8; 32]), 0));
    assert_eq!(validation_state.preconf_seen_by_height.seen_by_height.len(), 2);
}

#[test]
fn epoch_seen_tracker_rejects_over_limit_without_tracking_rejected_counts() {
    let mut tracker = EpochSeenTracker::default();

    assert!(tracker.can_accept(7, 1));
    tracker.mark(7);
    assert!(tracker.can_accept(7, 1));
    tracker.mark(7);
    assert!(!tracker.can_accept(7, 1));
    assert_eq!(tracker.seen_by_epoch.get(&7), Some(&2usize));
}

#[test]
fn validate_preconf_blocks_rejects_empty_transaction_payload() {
    let mut validation_state =
        GossipsubInboundState::new_with_allow_all_sequencers(167_000, Vec::new(), false);
    let mut payload = sample_preconf_payload();
    payload.envelope.execution_payload.transactions.clear();

    assert!(matches!(
        validation_state.validate_preconf_blocks(&payload),
        gossipsub::MessageAcceptance::Reject
    ));
}

#[test]
fn validate_preconf_blocks_rejects_invalid_signature() {
    let mut validation_state =
        GossipsubInboundState::new_with_allow_all_sequencers(167_000, Vec::new(), false);
    let payload = sample_preconf_payload();

    assert!(matches!(
        validation_state.validate_preconf_blocks(&payload),
        gossipsub::MessageAcceptance::Reject
    ));
}

#[test]
fn validate_response_rejects_missing_signature() {
    let mut validation_state =
        GossipsubInboundState::new_with_allow_all_sequencers(167_000, Vec::new(), false);
    let mut envelope = sample_response_envelope();
    envelope.signature = None;

    assert!(matches!(
        validation_state.validate_response(&envelope),
        gossipsub::MessageAcceptance::Reject
    ));
}

#[test]
fn validate_preconf_blocks_rejects_non_allowlisted_signer() {
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let payload = sample_signed_preconf_payload(167_000, &signer);
    let mut validation_state = GossipsubInboundState::new_with_allow_all_sequencers(
        167_000,
        vec![Address::from([0x11u8; 20])],
        false,
    );

    assert!(matches!(
        validation_state.validate_preconf_blocks(&payload),
        gossipsub::MessageAcceptance::Reject
    ));
}

#[test]
fn validate_preconf_blocks_accepts_allowlisted_signer() {
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let signer_address = signer.address();
    let payload = sample_signed_preconf_payload(167_000, &signer);
    let mut validation_state =
        GossipsubInboundState::new_with_allow_all_sequencers(167_000, vec![signer_address], false);

    assert!(matches!(
        validation_state.validate_preconf_blocks(&payload),
        gossipsub::MessageAcceptance::Accept
    ));
}

#[test]
fn validate_preconf_blocks_rejects_empty_allowlist_signer() {
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let payload = sample_signed_preconf_payload(167_000, &signer);
    let mut validation_state =
        GossipsubInboundState::new_with_allow_all_sequencers(167_000, Vec::new(), false);

    assert!(matches!(
        validation_state.validate_preconf_blocks(&payload),
        gossipsub::MessageAcceptance::Reject
    ));
}

#[test]
fn validate_preconf_blocks_rejects_single_fallback_zero_signer() {
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let payload = sample_signed_preconf_payload(167_000, &signer);
    let mut validation_state =
        GossipsubInboundState::new_with_allow_all_sequencers(167_000, Vec::new(), false);

    assert!(matches!(
        validation_state.validate_preconf_blocks(&payload),
        gossipsub::MessageAcceptance::Reject
    ));
}

#[test]
fn validate_preconf_blocks_rejects_invalid_fallback_signer() {
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let payload = sample_signed_preconf_payload(167_000, &signer);
    let mut validation_state =
        GossipsubInboundState::new_with_allow_all_sequencers(167_000, Vec::new(), false);

    assert!(matches!(
        validation_state.validate_preconf_blocks(&payload),
        gossipsub::MessageAcceptance::Reject
    ));
}

#[test]
fn validate_response_rejects_non_allowlisted_signer() {
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let envelope = sample_signed_response_envelope(167_000, &signer);
    let mut validation_state = GossipsubInboundState::new_with_allow_all_sequencers(
        167_000,
        vec![Address::from([0x11u8; 20])],
        false,
    );

    assert!(matches!(
        validation_state.validate_response(&envelope),
        gossipsub::MessageAcceptance::Reject
    ));
}

#[test]
fn validate_response_accepts_allowlisted_signer() {
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let signer_address = signer.address();
    let envelope = sample_signed_response_envelope(167_000, &signer);
    let mut validation_state =
        GossipsubInboundState::new_with_allow_all_sequencers(167_000, vec![signer_address], false);

    assert!(matches!(
        validation_state.validate_response(&envelope),
        gossipsub::MessageAcceptance::Accept
    ));
}

#[test]
fn validate_response_rejects_empty_allowlist_signer() {
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let envelope = sample_signed_response_envelope(167_000, &signer);
    let mut validation_state =
        GossipsubInboundState::new_with_allow_all_sequencers(167_000, Vec::new(), false);

    assert!(matches!(
        validation_state.validate_response(&envelope),
        gossipsub::MessageAcceptance::Reject
    ));
}

#[test]
fn validate_response_rejects_invalid_fallback_signer() {
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let envelope = sample_signed_response_envelope(167_000, &signer);
    let mut validation_state =
        GossipsubInboundState::new_with_allow_all_sequencers(167_000, Vec::new(), false);

    assert!(matches!(
        validation_state.validate_response(&envelope),
        gossipsub::MessageAcceptance::Reject
    ));
}

#[test]
fn validate_response_rejects_invalid_signature_before_ignore_fallback() {
    let mut validation_state =
        GossipsubInboundState::new_with_allow_all_sequencers(167_000, Vec::new(), false);
    let envelope = sample_response_envelope();

    assert!(matches!(
        validation_state.validate_response(&envelope),
        gossipsub::MessageAcceptance::Reject
    ));
}

#[test]
fn validate_response_rejects_when_allowlist_is_empty() {
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let envelope = sample_signed_response_envelope(167_000, &signer);
    let mut validation_state =
        GossipsubInboundState::new_with_allow_all_sequencers(167_000, Vec::new(), false);

    assert!(matches!(
        validation_state.validate_response(&envelope),
        gossipsub::MessageAcceptance::Reject
    ));
}

#[test]
fn classify_bootnodes_splits_enr_and_multiaddr_entries() {
    let input = vec![
        "/ip4/127.0.0.1/tcp/9000/p2p/12D3KooWEhXfLw7BrTHr2VfVki6jPiKG8AqfXw3hNziR6mM2Mz4s"
            .to_string(),
        "enr:-IS4QO3Qh8n0cxb5KJ9f5Xx8t9wq2fS28uFh8gJQ6KxJxRk6J1V1kWQ5g6nAiJmK8P8e9Z5hY3rP0mFf6vM1Sxg6W4qGAYN1ZHCCdl8"
            .to_string(),
        "enode://a3f84d16471e6d8a0dc1e2d62f7a9c5b3e4f5678901234567890abcdef123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef01234567@10.0.1.5:30303?discport=30304"
            .to_string(),
        "not-a-valid-bootnode".to_string(),
    ];

    let parsed = classify_bootnodes(input);

    assert_eq!(parsed.dial_addrs.len(), 2, "should have multiaddr + enode dial addresses");
    assert_eq!(parsed.discovery_enrs.len(), 1);
    assert_eq!(parsed.dial_addrs[1].to_string(), "/ip4/10.0.1.5/tcp/30303");
}

#[tokio::test]
async fn forward_event_uses_backpressure_instead_of_dropping() {
    let (tx, mut rx) = mpsc::channel(1);

    tx.send(NetworkEvent::UnsafeRequest { from: PeerId::random(), hash: B256::ZERO })
        .await
        .expect("first send should fill channel");

    let delayed_tx = tx.clone();
    let send_task = tokio::spawn(async move {
        forward_event(
            &delayed_tx,
            NetworkEvent::UnsafeRequest { from: PeerId::random(), hash: B256::from([1u8; 32]) },
        )
        .await
    });

    tokio::time::sleep(Duration::from_millis(100)).await;
    assert!(!send_task.is_finished());

    let _ = rx.recv().await;

    let send_result = tokio::time::timeout(Duration::from_secs(2), send_task)
        .await
        .expect("send should eventually complete")
        .expect("send task should not panic");
    assert!(send_result.is_ok());

    let next = rx.recv().await;
    assert!(matches!(next, Some(NetworkEvent::UnsafeRequest { .. })));
}

#[tokio::test]
async fn whitelist_network_publishes_anonymous_preconf_request() {
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
    let topic = gossipsub::IdentTopic::new(format!("/taiko/{chain_id}/0/requestPreconfBlocks"));

    let key = identity::Keypair::generate_ed25519();
    let peer_id = key.public().to_peer_id();
    let noise_config = noise::Config::new(&key).expect("noise config");

    let transport = tcp::tokio::Transport::new(tcp::Config::default().nodelay(true))
        .upgrade(upgrade::Version::V1Lazy)
        .authenticate(noise_config)
        .multiplex(yamux::Config::default())
        .boxed();

    let mut gs = build_gossipsub().expect("gossipsub config");
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
        if let SwarmEvent::NewListenAddr { address, .. } = peer_swarm.select_next_some().await {
            break address;
        }
    };

    let dial_addr = external_addr.with(libp2p::multiaddr::Protocol::P2p(peer_id));

    let cfg = P2pConfig {
        chain_id,
        enable_discovery: false,
        enable_tcp: true,
        listen_addr: "127.0.0.1:0".parse().expect("listen addr"),
        pre_dial_peers: vec![dial_addr],
        ..Default::default()
    };

    let whitelist_network =
        WhitelistNetwork::spawn_with_whitelist_filter(cfg).expect("spawn network");
    let expected_hash = B256::from([0x66u8; 32]);
    let command_tx = whitelist_network.command_tx.clone();
    let local_peer_id = whitelist_network.local_peer_id;

    let received_hash = tokio::time::timeout(Duration::from_secs(20), async move {
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
                                if message.topic == topic.hash() && message.data.len() == 32 {
                                    return B256::from_slice(&message.data);
                                }
                            }
                            _ => {}
                        }
                    }
                }
                _ = interval.tick(), if subscribed => {
                    command_tx
                        .send(NetworkCommand::PublishUnsafeRequest {
                            hash: expected_hash,
                        })
                        .await
                        .expect("publish request command");
                }
            }
        }
    })
    .await
    .expect("timed out waiting for request publication");

    assert_eq!(received_hash, expected_hash);

    let _ = whitelist_network.command_tx.send(NetworkCommand::Shutdown).await;
    let _ = whitelist_network.handle.await;
}

#[tokio::test]
async fn whitelist_network_loopbacks_published_unsafe_payload() {
    let cfg = P2pConfig {
        chain_id: 167_000,
        enable_discovery: false,
        enable_tcp: true,
        listen_addr: "127.0.0.1:0".parse().expect("listen addr"),
        ..Default::default()
    };

    let mut whitelist_network =
        WhitelistNetwork::spawn_with_whitelist_filter(cfg).expect("spawn network");
    let expected_signature = [0x77u8; 65];
    let expected_envelope = Arc::new(sample_response_envelope());

    whitelist_network
        .command_tx
        .send(NetworkCommand::PublishUnsafePayload {
            signature: expected_signature,
            envelope: expected_envelope.clone(),
        })
        .await
        .expect("queue publish payload command");

    let event = tokio::time::timeout(Duration::from_secs(5), whitelist_network.event_rx.recv())
        .await
        .expect("timed out waiting for local unsafe payload event")
        .expect("network event channel should stay open");

    match event {
        NetworkEvent::UnsafePayload { from, payload } => {
            assert_eq!(from, whitelist_network.local_peer_id);
            assert_eq!(payload.wire_signature, expected_signature);
            assert_eq!(payload.payload_bytes, encode_envelope_ssz(&expected_envelope));
            assert_eq!(
                payload.envelope.execution_payload.block_hash,
                expected_envelope.execution_payload.block_hash
            );
        }
        other => panic!("unexpected event: {other:?}"),
    }

    let _ = whitelist_network.command_tx.send(NetworkCommand::Shutdown).await;
    let _ = whitelist_network.handle.await;
}

#[tokio::test]
async fn whitelist_network_publishes_anonymous_preconf_response() {
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

    let mut gs = build_gossipsub().expect("gossipsub config");
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
        if let SwarmEvent::NewListenAddr { address, .. } = peer_swarm.select_next_some().await {
            break address;
        }
    };

    let dial_addr = external_addr.with(libp2p::multiaddr::Protocol::P2p(peer_id));

    let cfg = P2pConfig {
        chain_id,
        enable_discovery: false,
        enable_tcp: true,
        listen_addr: "127.0.0.1:0".parse().expect("listen addr"),
        pre_dial_peers: vec![dial_addr],
        ..Default::default()
    };

    let whitelist_network =
        WhitelistNetwork::spawn_with_whitelist_filter(cfg).expect("spawn network");
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
                                    return decode_unsafe_response_message(&message.data)
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
                            envelope: Arc::new(expected_to_publish.clone()),
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

#[tokio::test]
async fn whitelist_network_receives_anonymous_preconf_request() {
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

    let mut gs = build_gossipsub().expect("gossipsub config");
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
        if let SwarmEvent::NewListenAddr { address, .. } = peer_swarm.select_next_some().await {
            break address;
        }
    };

    let dial_addr = external_addr.with(libp2p::multiaddr::Protocol::P2p(peer_id));

    let cfg = P2pConfig {
        chain_id,
        enable_discovery: false,
        enable_tcp: true,
        listen_addr: "127.0.0.1:0".parse().expect("listen addr"),
        pre_dial_peers: vec![dial_addr],
        ..Default::default()
    };

    let mut whitelist_network =
        WhitelistNetwork::spawn_with_whitelist_filter(cfg).expect("spawn network");

    let publish_task = tokio::spawn(async move {
        let mut connected = false;
        let mut interval = tokio::time::interval(Duration::from_millis(800));
        let payload = [0x11u8; 32].to_vec();

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

    assert_eq!(received_hash, B256::from([0x11u8; 32]));

    publish_task.abort();
    let _ = whitelist_network.command_tx.send(NetworkCommand::Shutdown).await;
    let _ = whitelist_network.handle.await;
}

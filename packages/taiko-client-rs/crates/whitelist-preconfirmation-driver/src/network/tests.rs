use std::{
    sync::Arc,
    time::{Duration, Instant},
};

use alloy_primitives::{Address, B256, Bloom, Bytes, U256, hex, keccak256};
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
    wire::topics::Topics,
};

/// Compatibility note:
/// - topic names must stay aligned with github.com/taikoxyz/optimism/op-node/p2p/gossip.go and the
///   Taiko preconf topic helpers it defines
/// - request payloads are raw hash / big-endian epoch
/// - payload gossip is snappy(signature || SSZ(envelope))
/// - response gossip is snappy(SSZ(envelope))
#[test]
fn topics_match_go_contract() {
    let topics = Topics::new(167_000);
    assert_eq!(topics.preconf_blocks.hash().to_string(), "/taiko/167000/0/preconfBlocks");
    assert_eq!(topics.preconf_request.hash().to_string(), "/taiko/167000/0/requestPreconfBlocks");
    assert_eq!(topics.preconf_response.hash().to_string(), "/taiko/167000/0/responsePreconfBlocks");
    assert_eq!(
        topics.eos_request.hash().to_string(),
        "/taiko/167000/0/requestEndOfSequencingPreconfBlocks"
    );
}

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
fn go_compat_preconf_blocks_wire_layout_matches_expected() {
    let envelope = sample_response_envelope();
    let signature = [0x11u8; 65];
    let expected = go_fixture_bytes(concat!(
        "b0050011fe0100080103447a010000017a01004e820000027a010000037a01000000fe0100fe0100fe0100",
        "fa010000047a0100002a2d200c80c3c901010b0408520106140000c0ff6967010a00fc011608ca9a3b010c",
        "5e010000057a01001004020000550d0120040000009999999922fe0100",
    ));

    let encoded = crate::codec::encode_unsafe_payload_message(&signature, &envelope)
        .expect("encode preconf payload");

    assert_eq!(encoded, expected);
}

#[test]
fn go_compat_response_wire_layout_matches_expected() {
    let envelope = sample_response_envelope();
    let expected = go_fixture_bytes(concat!(
        "ef04080103447a010000017a010000114a010000027a010000037a01000000fe0100fe0100fe0100fa0100",
        "00047a0100002a2d200c80c3c901010b0408520106140000c0ff6967010a00fc011608ca9a3b010c5e0100",
        "00057a01001004020000550d0120040000009999999922fe0100",
    ));

    let encoded =
        crate::codec::encode_unsafe_response_message(&envelope).expect("encode response payload");

    assert_eq!(encoded, expected);
}

#[test]
fn go_compat_request_wire_layout_matches_expected() {
    let hash = B256::from([0x33u8; 32]);
    let expected =
        go_fixture_bytes("3333333333333333333333333333333333333333333333333333333333333333");

    let encoded = crate::codec::encode_unsafe_request_message(hash);

    assert_eq!(encoded, expected);
}

#[test]
fn go_compat_eos_request_wire_layout_matches_expected() {
    let epoch = 0x0102_0304_0506_0708u64;
    let expected = go_fixture_bytes("0102030405060708");

    let encoded = crate::codec::encode_eos_request_message(epoch);

    assert_eq!(encoded, expected);
}

#[test]
fn go_compat_block_signing_hash_matches_op_signer_formula() {
    let chain_id = 167_000u64;
    let payload_bytes = encode_envelope_ssz(&sample_response_envelope());
    let expected_payload_hash = B256::from_slice(
        &hex::decode("c7e1b7515a63e76d8a6603bc60f83da53e2c2221819350a51aef6ac443f9b142").unwrap(),
    );
    let expected = B256::from_slice(
        &hex::decode("c02e3b49eac6dd7dc65198c8398ed552ebcce1d130ca962e044e3953c5b4631f").unwrap(),
    );

    assert_eq!(keccak256(&payload_bytes), expected_payload_hash);

    assert_eq!(crate::codec::block_signing_hash(chain_id, &payload_bytes), expected);
}

fn go_fixture_bytes(hex_bytes: &str) -> Vec<u8> {
    hex::decode(hex_bytes).expect("valid Go fixture hex")
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
fn response_seen_tracker_records_recent_hashes_for_suppression() {
    let mut validation_state = GossipsubInboundState::new(167_000);
    let hash = B256::from([0x6au8; 32]);
    let now = Instant::now();

    assert!(!validation_state.response_seen_recently(hash, now));

    validation_state.mark_response_seen(hash, now);
    assert!(validation_state.response_seen_recently(hash, now));
    assert!(validation_state.response_seen_recently(hash, now + Duration::from_secs(5)));
    assert!(!validation_state.response_seen_recently(hash, now + Duration::from_secs(11)));
}

#[test]
fn invalid_decodable_response_does_not_mark_seen_hash() {
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let mut validation_state = GossipsubInboundState::new(167_000);
    let envelope = sample_signed_response_envelope(167_000, &signer);
    let hash = envelope.execution_payload.block_hash;
    let mut invalid_but_decodable = envelope.clone();
    invalid_but_decodable.execution_payload.transactions.clear();

    assert!(matches!(
        validation_state.validate_response(&invalid_but_decodable),
        gossipsub::MessageAcceptance::Reject
    ));
    assert!(!validation_state.response_seen_recently(hash, Instant::now()));
}

#[tokio::test]
async fn invalid_inbound_response_does_not_suppress_later_valid_local_publish() {
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
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let mut valid_envelope = sample_signed_response_envelope(chain_id, &signer);
    let mut invalid_envelope = valid_envelope.clone();
    invalid_envelope.execution_payload.transactions.clear();
    let valid_parent_beacon_block_root = Some(B256::from([0x7au8; 32]));
    valid_envelope.parent_beacon_block_root = valid_parent_beacon_block_root;

    let encoded_invalid_response = crate::codec::encode_unsafe_response_message(&invalid_envelope)
        .expect("encode invalid response");

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
        sequencer_addresses: vec![signer.address()],
        ..Default::default()
    };

    let mut whitelist_network =
        WhitelistNetwork::spawn_with_whitelist_filter(cfg).expect("spawn network");
    let command_tx = whitelist_network.command_tx.clone();
    let local_peer_id = whitelist_network.local_peer_id;

    let received_valid_response = tokio::time::timeout(Duration::from_secs(20), async {
        let mut connected = false;
        let mut subscribed = false;
        let mut invalid_published = false;

        while !invalid_published {
            let event = peer_swarm.select_next_some().await;
            match event {
                SwarmEvent::ConnectionEstablished { .. } => {
                    connected = true;
                }
                SwarmEvent::Behaviour(TestBehaviourEvent::Gossipsub(event)) => match *event {
                    gossipsub::Event::Subscribed { peer_id, topic: subscribed_topic }
                        if peer_id == local_peer_id && subscribed_topic == topic.hash() =>
                    {
                        subscribed = true;
                    }
                    _ => {}
                },
                _ => {}
            }

            if connected && subscribed && !invalid_published {
                invalid_published = true;
                peer_swarm
                    .behaviour_mut()
                    .gossipsub
                    .publish(topic.clone(), encoded_invalid_response.clone())
                    .expect("publish invalid response");
            }
        }

        let invalid_event =
            tokio::time::timeout(Duration::from_millis(500), whitelist_network.event_rx.recv())
                .await;
        assert!(
            invalid_event.is_err(),
            "invalid inbound response should not be accepted by the event loop"
        );

        command_tx
            .send(NetworkCommand::PublishUnsafeResponse {
                envelope: Arc::new(valid_envelope.clone()),
            })
            .await
            .expect("publish valid response command");

        loop {
            match peer_swarm.select_next_some().await {
                SwarmEvent::Behaviour(TestBehaviourEvent::Gossipsub(event)) => {
                    if let gossipsub::Event::Message { message, .. } = *event &&
                        message.topic == topic.hash()
                    {
                        let decoded = decode_unsafe_response_message(&message.data)
                            .expect("decode valid response");
                        if decoded.execution_payload.block_hash ==
                            valid_envelope.execution_payload.block_hash &&
                            decoded.parent_beacon_block_root == valid_parent_beacon_block_root
                        {
                            return decoded;
                        }
                    }
                }
                _ => {}
            }
        }
    })
    .await
    .expect("timed out waiting for later valid response");

    assert_eq!(
        received_valid_response.execution_payload.block_hash,
        valid_envelope.execution_payload.block_hash
    );
    assert_eq!(received_valid_response.signature, valid_envelope.signature);

    let _ = whitelist_network.command_tx.send(NetworkCommand::Shutdown).await;
    let _ = whitelist_network.handle.await;
}

#[test]
fn validate_preconf_blocks_rejects_empty_transaction_payload() {
    let mut validation_state = GossipsubInboundState::new(167_000);
    let mut payload = sample_preconf_payload();
    payload.envelope.execution_payload.transactions.clear();

    assert!(matches!(
        validation_state.validate_preconf_blocks(&payload),
        gossipsub::MessageAcceptance::Reject
    ));
}

#[test]
fn validate_preconf_blocks_rejects_invalid_signature() {
    let mut validation_state = GossipsubInboundState::new(167_000);
    let payload = sample_preconf_payload();

    assert!(matches!(
        validation_state.validate_preconf_blocks(&payload),
        gossipsub::MessageAcceptance::Reject
    ));
}

#[test]
fn validate_response_rejects_missing_signature() {
    let mut validation_state = GossipsubInboundState::new(167_000);
    let mut envelope = sample_response_envelope();
    envelope.signature = None;

    assert!(matches!(
        validation_state.validate_response(&envelope),
        gossipsub::MessageAcceptance::Reject
    ));
}

#[test]
fn validate_preconf_blocks_accepts_valid_signed_payload_without_static_allowlist() {
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let payload = sample_signed_preconf_payload(167_000, &signer);
    let mut validation_state = GossipsubInboundState::new(167_000);

    assert!(matches!(
        validation_state.validate_preconf_blocks(&payload),
        gossipsub::MessageAcceptance::Accept
    ));
}

#[test]
fn validate_preconf_blocks_rejects_invalid_signature_before_payload_checks() {
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let payload = sample_signed_preconf_payload(167_000, &signer);
    let mut validation_state = GossipsubInboundState::new(167_000);

    assert!(matches!(
        validation_state.validate_preconf_blocks(&DecodedUnsafePayload {
            wire_signature: [0u8; 65],
            ..payload
        }),
        gossipsub::MessageAcceptance::Reject
    ));
}

#[test]
fn validate_response_accepts_valid_signed_envelope_without_static_allowlist() {
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let envelope = sample_signed_response_envelope(167_000, &signer);
    let mut validation_state = GossipsubInboundState::new(167_000);

    assert!(matches!(
        validation_state.validate_response(&envelope),
        gossipsub::MessageAcceptance::Accept
    ));
}

#[test]
fn validate_response_rejects_invalid_fallback_signer() {
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let envelope = sample_signed_response_envelope(167_000, &signer);
    let mut validation_state = GossipsubInboundState::new(167_000);

    assert!(matches!(
        validation_state.validate_response(&WhitelistExecutionPayloadEnvelope {
            signature: Some([0u8; 65]),
            ..envelope
        }),
        gossipsub::MessageAcceptance::Reject
    ));
}

#[test]
fn validate_response_rejects_invalid_signature_before_ignore_fallback() {
    let mut validation_state = GossipsubInboundState::new(167_000);
    let envelope = sample_response_envelope();

    assert!(matches!(
        validation_state.validate_response(&envelope),
        gossipsub::MessageAcceptance::Reject
    ));
}

#[test]
fn validate_preconf_blocks_does_not_spend_height_quota_before_downstream_authority() {
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let payload = sample_signed_preconf_payload(167_000, &signer);
    let mut validation_state = GossipsubInboundState::new(167_000);

    for _ in 0..12 {
        assert!(matches!(
            validation_state.validate_preconf_blocks(&payload),
            gossipsub::MessageAcceptance::Accept
        ));
    }
}

#[test]
fn validate_response_does_not_spend_height_quota_before_downstream_authority() {
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let envelope = sample_signed_response_envelope(167_000, &signer);
    let mut validation_state = GossipsubInboundState::new(167_000);

    for _ in 0..5 {
        assert!(matches!(
            validation_state.validate_response(&envelope),
            gossipsub::MessageAcceptance::Accept
        ));
    }
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
async fn response_publish_is_suppressed_when_recent_response_seen() {
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
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let seen_envelope = sample_signed_response_envelope(chain_id, &signer);
    let mut suppressed_envelope = seen_envelope.clone();
    suppressed_envelope.signature = Some([0x33u8; 65]);
    let encoded_seen_response =
        crate::codec::encode_unsafe_response_message(&seen_envelope).expect("encode seen response");

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
        sequencer_addresses: vec![signer.address()],
        ..Default::default()
    };

    let mut whitelist_network =
        WhitelistNetwork::spawn_with_whitelist_filter(cfg).expect("spawn network");
    let command_tx = whitelist_network.command_tx.clone();
    let local_peer_id = whitelist_network.local_peer_id;

    let observed_seen_response = tokio::time::timeout(Duration::from_secs(20), async {
        let mut connected = false;
        let mut subscribed = false;
        let mut published_seen_response = false;
        loop {
            tokio::select! {
                event = peer_swarm.select_next_some() => {
                    match event {
                        SwarmEvent::ConnectionEstablished { .. } => {
                            connected = true;
                        }
                        SwarmEvent::Behaviour(TestBehaviourEvent::Gossipsub(event)) => {
                            if let gossipsub::Event::Subscribed { peer_id, topic: subscribed_topic }
                                = *event
                                && peer_id == local_peer_id &&
                                    subscribed_topic == topic.hash()
                            {
                                subscribed = true;
                            }
                        }
                        _ => {}
                    }

                    if connected && subscribed && !published_seen_response {
                        published_seen_response = true;
                        peer_swarm
                            .behaviour_mut()
                            .gossipsub
                            .publish(topic.clone(), encoded_seen_response.clone())
                            .expect("publish seen response");
                    }
                }
                maybe_event = whitelist_network.event_rx.recv() => {
                    match maybe_event {
                        Some(NetworkEvent::UnsafeResponse { envelope, .. })
                            if envelope.execution_payload.block_hash
                                == seen_envelope.execution_payload.block_hash =>
                        {
                            return envelope;
                        }
                        Some(_) => continue,
                        None => panic!("event channel closed before seen response arrived"),
                    }
                }
            }
        }
    })
    .await
    .expect("timed out waiting for recent response observation");

    assert_eq!(
        observed_seen_response.execution_payload.block_hash,
        seen_envelope.execution_payload.block_hash
    );

    command_tx
        .send(NetworkCommand::PublishUnsafeResponse {
            envelope: Arc::new(suppressed_envelope.clone()),
        })
        .await
        .expect("queue suppressed response command");

    let suppressed_signature = suppressed_envelope.signature;
    let publish_result = tokio::time::timeout(Duration::from_secs(2), async move {
        loop {
            if let SwarmEvent::Behaviour(TestBehaviourEvent::Gossipsub(event)) =
                peer_swarm.select_next_some().await &&
                let gossipsub::Event::Message { message, .. } = *event &&
                message.topic == topic.hash() &&
                let Ok(decoded) = decode_unsafe_response_message(&message.data) &&
                decoded.signature == suppressed_signature
            {
                return decoded;
            }
        }
    })
    .await;

    assert!(publish_result.is_err(), "suppressed response should not be republished");

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

#[tokio::test]
async fn whitelist_network_gossip_request_round_trip_without_reqresp() {
    let chain_id = 167_000;
    let signer = FixedKSigner::golden_touch().expect("golden touch signer");
    let signer_address = signer.address();
    let envelope = sample_signed_response_envelope(chain_id, &signer);
    let expected_hash = envelope.execution_payload.block_hash;
    let response_topic =
        gossipsub::IdentTopic::new(format!("/taiko/{chain_id}/0/responsePreconfBlocks"));
    let request_topic =
        gossipsub::IdentTopic::new(format!("/taiko/{chain_id}/0/requestPreconfBlocks"));
    let encoded_response =
        crate::codec::encode_unsafe_response_message(&envelope).expect("encode response for test");

    /// Test-only swarm behaviour mirroring the production gossip stack.
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
        fn from(value: gossipsub::Event) -> Self {
            Self::Gossipsub(Box::new(value))
        }
    }

    impl From<ping::Event> for TestBehaviourEvent {
        fn from(_: ping::Event) -> Self {
            Self::Ping
        }
    }

    impl From<identify::Event> for TestBehaviourEvent {
        fn from(_: identify::Event) -> Self {
            Self::Identify
        }
    }

    let key = identity::Keypair::generate_ed25519();
    let peer_id = key.public().to_peer_id();
    let noise_config = noise::Config::new(&key).expect("noise config");

    let transport = tcp::tokio::Transport::new(tcp::Config::default().nodelay(true))
        .upgrade(upgrade::Version::V1Lazy)
        .authenticate(noise_config)
        .multiplex(yamux::Config::default())
        .boxed();

    let mut gs = build_gossipsub().expect("gossipsub config");
    gs.subscribe(&request_topic).expect("request topic subscribe");
    gs.subscribe(&response_topic).expect("response topic subscribe");

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
        sequencer_addresses: vec![signer_address],
        ..Default::default()
    };

    let mut whitelist_network =
        WhitelistNetwork::spawn_with_whitelist_filter(cfg).expect("spawn network");
    let command_tx = whitelist_network.command_tx.clone();

    let (response_hash, response_env) = tokio::time::timeout(Duration::from_secs(20), async move {
        let mut connected = false;
        let mut requested = false;
        loop {
            tokio::select! {
                event = peer_swarm.select_next_some() => {
                    match event {
                        SwarmEvent::ConnectionEstablished { .. } => {
                            connected = true;
                        }
                        SwarmEvent::Behaviour(TestBehaviourEvent::Gossipsub(event)) => {
                            if let gossipsub::Event::Message { message, .. } = *event
                                && message.topic == request_topic.hash()
                            {
                                assert_eq!(message.data.as_slice(), expected_hash.as_slice());
                                peer_swarm
                                    .behaviour_mut()
                                    .gossipsub
                                    .publish(response_topic.clone(), encoded_response.clone())
                                    .expect("publish response");
                            }
                        }
                        _ => {}
                    }
                }
                event = whitelist_network.event_rx.recv() => {
                    if let Some(NetworkEvent::UnsafeResponse {
                        envelope: env,
                        ..
                    }) = event
                    {
                        return (env.execution_payload.block_hash, env);
                    }
                }
                _ = tokio::time::sleep(Duration::from_millis(100)), if connected && !requested => {
                    requested = true;
                    command_tx
                        .send(NetworkCommand::PublishUnsafeRequest {
                            hash: expected_hash,
                        })
                        .await
                        .expect("queue request publish");
                }
            }
        }
    })
    .await
    .expect("timed out waiting for gossip request/response round-trip");

    assert_eq!(response_hash, expected_hash);
    assert_eq!(response_env.execution_payload.block_hash, envelope.execution_payload.block_hash);
    assert_eq!(
        response_env.execution_payload.block_number,
        envelope.execution_payload.block_number
    );
    assert_eq!(response_env.signature, envelope.signature);

    let _ = whitelist_network.command_tx.send(NetworkCommand::Shutdown).await;
    let _ = whitelist_network.handle.await;
}

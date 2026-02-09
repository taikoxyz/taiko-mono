//! Minimal libp2p network runtime for whitelist preconfirmation topics.

use std::collections::HashSet;

use alloy_primitives::B256;
use futures::StreamExt;
use libp2p::{
    Multiaddr, PeerId, Swarm, Transport, core::upgrade, gossipsub, identify, identity, noise, ping,
    swarm::NetworkBehaviour, tcp, yamux,
};
use preconfirmation_net::{P2pConfig, spawn_discovery};
use sha2::{Digest, Sha256};
use tokio::{sync::mpsc, task::JoinHandle};
use tracing::{debug, warn};

use crate::{
    codec::{
        DecodedUnsafePayload, WhitelistExecutionPayloadEnvelope, decode_unsafe_payload_message,
        decode_unsafe_response_message, encode_unsafe_request_message,
        encode_unsafe_response_message,
    },
    error::{Result, WhitelistPreconfirmationDriverError},
};

/// Maximum allowed gossip payload size after decompression.
const MAX_GOSSIP_SIZE_BYTES: usize = kona_gossip::MAX_GOSSIP_SIZE;
/// Prefix used in Go-compatible message-id hashing for valid snappy payloads.
const MESSAGE_ID_PREFIX_VALID_SNAPPY: [u8; 4] = [1, 0, 0, 0];
/// Prefix used in Go-compatible message-id hashing for invalid snappy payloads.
const MESSAGE_ID_PREFIX_INVALID_SNAPPY: [u8; 4] = [0, 0, 0, 0];

/// Inbound network event for whitelist preconfirmation processing.
#[derive(Debug)]
pub(crate) enum NetworkEvent {
    /// Incoming `preconfBlocks` payload.
    UnsafePayload {
        /// Peer that propagated the message.
        from: PeerId,
        /// Decoded payload.
        payload: DecodedUnsafePayload,
    },
    /// Incoming `responsePreconfBlocks` payload.
    UnsafeResponse {
        /// Peer that propagated the message.
        from: PeerId,
        /// Decoded envelope.
        envelope: crate::codec::WhitelistExecutionPayloadEnvelope,
    },
    /// Incoming `requestPreconfBlocks` message.
    UnsafeRequest {
        /// Peer that propagated the message.
        from: PeerId,
        /// Requested block hash.
        hash: B256,
    },
    /// Incoming `requestEndOfSequencingPreconfBlocks` message.
    EndOfSequencingRequest {
        /// Peer that propagated the message.
        from: PeerId,
        /// Requested epoch.
        epoch: u64,
    },
}

/// Outbound commands for the whitelist preconfirmation network.
#[derive(Debug)]
pub(crate) enum NetworkCommand {
    /// Publish an unsafe-block request to the `requestPreconfBlocks` topic.
    PublishUnsafeRequest {
        /// Requested block hash.
        hash: B256,
    },
    /// Publish an unsafe-block response to the `responsePreconfBlocks` topic.
    PublishUnsafeResponse {
        /// Envelope to publish.
        envelope: Box<WhitelistExecutionPayloadEnvelope>,
    },
    /// Shutdown the network loop.
    Shutdown,
}

/// Handle to the running whitelist network.
pub(crate) struct WhitelistNetwork {
    /// Local peer id.
    pub local_peer_id: PeerId,
    /// Inbound event stream.
    pub event_rx: mpsc::Receiver<NetworkEvent>,
    /// Outbound command sender.
    pub command_tx: mpsc::Sender<NetworkCommand>,
    /// Background task running the swarm.
    pub handle: JoinHandle<Result<()>>,
}

#[derive(Clone)]
struct Topics {
    /// Topic carrying signed unsafe payload gossip.
    preconf_blocks: gossipsub::IdentTopic,
    /// Topic used to request a payload by block hash.
    preconf_request: gossipsub::IdentTopic,
    /// Topic used to answer payload-by-hash requests.
    preconf_response: gossipsub::IdentTopic,
    /// Topic used by peers requesting end-of-sequencing payloads.
    eos_request: gossipsub::IdentTopic,
}

impl Topics {
    /// Build all whitelist preconfirmation topic names for the given chain id.
    fn new(chain_id: u64) -> Self {
        Self {
            preconf_blocks: gossipsub::IdentTopic::new(format!(
                "/taiko/{chain_id}/0/preconfBlocks"
            )),
            preconf_request: gossipsub::IdentTopic::new(format!(
                "/taiko/{chain_id}/0/requestPreconfBlocks"
            )),
            preconf_response: gossipsub::IdentTopic::new(format!(
                "/taiko/{chain_id}/0/responsePreconfBlocks"
            )),
            eos_request: gossipsub::IdentTopic::new(format!(
                "/taiko/{chain_id}/0/requestEndOfSequencingPreconfBlocks"
            )),
        }
    }
}

#[derive(NetworkBehaviour)]
#[behaviour(to_swarm = "BehaviourEvent")]
struct Behaviour {
    /// Gossip transport for whitelist preconfirmation topics.
    gossipsub: gossipsub::Behaviour,
    /// Ping protocol for liveness.
    ping: ping::Behaviour,
    /// Identify protocol for peer metadata exchange.
    identify: identify::Behaviour,
}

#[derive(Debug)]
enum BehaviourEvent {
    /// Wrapped gossipsub event.
    Gossipsub(Box<gossipsub::Event>),
    /// Ping event marker.
    Ping,
    /// Identify event marker.
    Identify,
}

impl From<gossipsub::Event> for BehaviourEvent {
    /// Convert a gossipsub event into a behaviour event.
    fn from(value: gossipsub::Event) -> Self {
        Self::Gossipsub(Box::new(value))
    }
}

impl From<ping::Event> for BehaviourEvent {
    /// Convert a ping event into a behaviour event.
    fn from(_: ping::Event) -> Self {
        Self::Ping
    }
}

impl From<identify::Event> for BehaviourEvent {
    /// Convert an identify event into a behaviour event.
    fn from(_: identify::Event) -> Self {
        Self::Identify
    }
}

#[derive(Debug, Default, PartialEq, Eq)]
struct ClassifiedBootnodes {
    /// Parsed multiaddrs to dial directly.
    dial_addrs: Vec<Multiaddr>,
    /// ENR entries to feed into discovery.
    discovery_enrs: Vec<String>,
}

impl WhitelistNetwork {
    /// Spawn the whitelist preconfirmation network task.
    pub fn spawn(cfg: P2pConfig) -> Result<Self> {
        let local_key = identity::Keypair::generate_ed25519();
        let local_peer_id = local_key.public().to_peer_id();

        let topics = Topics::new(cfg.chain_id);
        let mut gossipsub = build_gossipsub()?;
        gossipsub.subscribe(&topics.preconf_blocks).map_err(to_p2p_err)?;
        gossipsub.subscribe(&topics.preconf_request).map_err(to_p2p_err)?;
        gossipsub.subscribe(&topics.preconf_response).map_err(to_p2p_err)?;
        gossipsub.subscribe(&topics.eos_request).map_err(to_p2p_err)?;

        let behaviour = Behaviour {
            gossipsub,
            ping: ping::Behaviour::new(ping::Config::new()),
            identify: identify::Behaviour::new(identify::Config::new(
                "/taiko/whitelist-preconfirmation/1.0.0".to_string(),
                local_key.public(),
            )),
        };

        let noise_config = noise::Config::new(&local_key).map_err(to_p2p_err)?;
        let transport = tcp::tokio::Transport::new(tcp::Config::default().nodelay(true))
            .upgrade(upgrade::Version::V1Lazy)
            .authenticate(noise_config)
            .multiplex(yamux::Config::default())
            .boxed();

        let mut swarm = Swarm::new(
            transport,
            behaviour,
            local_peer_id,
            libp2p::swarm::Config::with_tokio_executor(),
        );

        if cfg.enable_tcp {
            let listen_addr = if cfg.listen_addr.is_ipv4() {
                format!("/ip4/{}/tcp/{}", cfg.listen_addr.ip(), cfg.listen_addr.port())
            } else {
                format!("/ip6/{}/tcp/{}", cfg.listen_addr.ip(), cfg.listen_addr.port())
            }
            .parse::<Multiaddr>()
            .map_err(to_p2p_err)?;
            swarm.listen_on(listen_addr).map_err(to_p2p_err)?;
        }

        let bootnodes = classify_bootnodes(cfg.bootnodes);
        let mut dialed_addrs = HashSet::new();

        for peer in cfg.pre_dial_peers {
            dial_once(&mut swarm, &mut dialed_addrs, peer, "static peer");
        }

        for addr in bootnodes.dial_addrs {
            dial_once(&mut swarm, &mut dialed_addrs, addr, "bootnode");
        }

        let mut discovery_rx = if cfg.enable_discovery {
            spawn_discovery(cfg.discovery_listen, bootnodes.discovery_enrs)
                .map_err(|err| {
                    warn!(error = %err, "failed to start whitelist preconfirmation discovery");
                })
                .ok()
        } else {
            if !bootnodes.discovery_enrs.is_empty() {
                warn!(
                    count = bootnodes.discovery_enrs.len(),
                    "discovery is disabled; skipping ENR bootnodes"
                );
            }
            None
        };

        let (event_tx, event_rx) = mpsc::channel(1024);
        let (command_tx, mut command_rx) = mpsc::channel(512);

        let handle = tokio::spawn(async move {
            loop {
                let has_discovery = discovery_rx.is_some();

                tokio::select! {
                    maybe_command = command_rx.recv() => {
                        let Some(command) = maybe_command else {
                            return Ok(());
                        };
                        match command {
                            NetworkCommand::PublishUnsafeRequest { hash } => {
                                let payload = encode_unsafe_request_message(hash);
                                if let Err(err) = swarm
                                    .behaviour_mut()
                                    .gossipsub
                                    .publish(topics.preconf_request.clone(), payload)
                                {
                                    warn!(
                                        hash = %hash,
                                        error = %err,
                                        "failed to publish whitelist preconfirmation request"
                                    );
                                }
                            }
                            NetworkCommand::PublishUnsafeResponse { envelope } => {
                                let hash = envelope.execution_payload.block_hash;
                                match encode_unsafe_response_message(&envelope) {
                                    Ok(payload) => {
                                        if let Err(err) = swarm
                                            .behaviour_mut()
                                            .gossipsub
                                            .publish(topics.preconf_response.clone(), payload)
                                        {
                                            warn!(
                                                hash = %hash,
                                                error = %err,
                                                "failed to publish whitelist preconfirmation response"
                                            );
                                        }
                                    }
                                    Err(err) => {
                                        warn!(
                                            hash = %hash,
                                            error = %err,
                                            "failed to encode whitelist preconfirmation response"
                                        );
                                    }
                                }
                            }
                            NetworkCommand::Shutdown => {
                                return Ok(());
                            }
                        }
                    }
                    maybe_addr = recv_discovered_multiaddr(&mut discovery_rx), if has_discovery => {
                        match maybe_addr {
                            Some(addr) => {
                                dial_once(&mut swarm, &mut dialed_addrs, addr, "discovery");
                            }
                            None => {
                                discovery_rx = None;
                                debug!("whitelist preconfirmation discovery stream closed");
                            }
                        }
                    }
                    event = swarm.select_next_some() => {
                        handle_swarm_event(event, &topics, &event_tx).await?;
                    }
                }
            }
        });

        Ok(Self { local_peer_id, event_rx, command_tx, handle })
    }
}

/// Build the gossipsub behaviour.
pub(crate) fn build_gossipsub() -> Result<gossipsub::Behaviour> {
    let config = gossipsub::ConfigBuilder::default()
        .validation_mode(gossipsub::ValidationMode::Anonymous)
        .heartbeat_interval(*kona_gossip::GOSSIP_HEARTBEAT)
        .duplicate_cache_time(*kona_gossip::SEEN_MESSAGES_TTL)
        .message_id_fn(message_id)
        .max_transmit_size(MAX_GOSSIP_SIZE_BYTES)
        .build()
        .map_err(to_p2p_err)?;

    gossipsub::Behaviour::new(gossipsub::MessageAuthenticity::Anonymous, config).map_err(to_p2p_err)
}

/// Classify bootnodes into direct-dial multiaddrs and discovery ENRs.
fn classify_bootnodes(bootnodes: Vec<String>) -> ClassifiedBootnodes {
    let mut classified = ClassifiedBootnodes::default();

    for entry in bootnodes {
        let value = entry.trim();
        if value.is_empty() {
            continue;
        }

        if value.starts_with("enr:") {
            classified.discovery_enrs.push(value.to_string());
            continue;
        }

        match value.parse::<Multiaddr>() {
            Ok(addr) => classified.dial_addrs.push(addr),
            Err(err) => {
                warn!(
                    bootnode = %value,
                    error = %err,
                    "invalid bootnode entry; expected ENR or multiaddr"
                );
            }
        }
    }

    classified
}

/// Compute Go-compatible gossipsub message IDs.
pub(crate) fn message_id(message: &gossipsub::Message) -> gossipsub::MessageId {
    let (valid_snappy, data) = try_decompress_snappy(&message.data);

    let topic = message.topic.as_str().as_bytes();
    let topic_len = (topic.len() as u64).to_le_bytes();

    let prefix = if valid_snappy {
        MESSAGE_ID_PREFIX_VALID_SNAPPY
    } else {
        MESSAGE_ID_PREFIX_INVALID_SNAPPY
    };

    let mut hasher = Sha256::new();
    hasher.update(prefix);
    hasher.update(topic_len);
    hasher.update(topic);
    hasher.update(&data);

    let hash = hasher.finalize();
    gossipsub::MessageId::from(hash[..20].to_vec())
}

/// Try to decompress snappy data. Returns (is_valid_snappy, data).
fn try_decompress_snappy(compressed: &[u8]) -> (bool, Vec<u8>) {
    let Ok(decoded_len) = snap::raw::decompress_len(compressed) else {
        return (false, compressed.to_vec());
    };

    if decoded_len > MAX_GOSSIP_SIZE_BYTES {
        return (false, compressed.to_vec());
    }

    snap::raw::Decoder::new()
        .decompress_vec(compressed)
        .map(|data| (true, data))
        .unwrap_or_else(|_| (false, compressed.to_vec()))
}

/// Dial a peer address once.
fn dial_once(
    swarm: &mut Swarm<Behaviour>,
    dialed_addrs: &mut HashSet<Multiaddr>,
    addr: Multiaddr,
    source: &str,
) {
    if !dialed_addrs.insert(addr.clone()) {
        debug!(%addr, source, "already dialed address; skipping");
        return;
    }

    if let Err(err) = swarm.dial(addr.clone()) {
        warn!(%addr, source, error = %err, "failed to dial address");
    }
}

/// Receive one discovery event, if discovery is enabled.
async fn recv_discovered_multiaddr(
    discovery_rx: &mut Option<mpsc::Receiver<Multiaddr>>,
) -> Option<Multiaddr> {
    discovery_rx.as_mut()?.recv().await
}

/// Handle a swarm event.
async fn handle_swarm_event(
    event: libp2p::swarm::SwarmEvent<BehaviourEvent>,
    topics: &Topics,
    event_tx: &mpsc::Sender<NetworkEvent>,
) -> Result<()> {
    match event {
        libp2p::swarm::SwarmEvent::Behaviour(BehaviourEvent::Gossipsub(event)) => {
            handle_gossipsub_event(*event, topics, event_tx).await?;
        }
        libp2p::swarm::SwarmEvent::NewListenAddr { address, .. } => {
            debug!(%address, "whitelist preconfirmation network listening");
        }
        libp2p::swarm::SwarmEvent::ConnectionEstablished { peer_id, .. } => {
            debug!(%peer_id, "peer connected");
        }
        libp2p::swarm::SwarmEvent::ConnectionClosed { peer_id, .. } => {
            debug!(%peer_id, "peer disconnected");
        }
        libp2p::swarm::SwarmEvent::Behaviour(BehaviourEvent::Ping | BehaviourEvent::Identify) => {}
        other => {
            debug!(event = ?other, "ignored swarm event");
        }
    }
    Ok(())
}

/// Handle a gossipsub event.
async fn handle_gossipsub_event(
    event: gossipsub::Event,
    topics: &Topics,
    event_tx: &mpsc::Sender<NetworkEvent>,
) -> Result<()> {
    let gossipsub::Event::Message { propagation_source, message, .. } = event else {
        return Ok(());
    };

    let topic = &message.topic;
    let from = propagation_source;

    if *topic == topics.preconf_blocks.hash() {
        match decode_unsafe_payload_message(&message.data) {
            Ok(payload) => {
                forward_event(event_tx, NetworkEvent::UnsafePayload { from, payload }).await?
            }
            Err(err) => debug!(error = %err, "failed to decode unsafe payload"),
        }
        return Ok(());
    }

    if *topic == topics.preconf_response.hash() {
        match decode_unsafe_response_message(&message.data) {
            Ok(envelope) => {
                forward_event(event_tx, NetworkEvent::UnsafeResponse { from, envelope }).await?
            }
            Err(err) => debug!(error = %err, "failed to decode unsafe response"),
        }
        return Ok(());
    }

    if *topic == topics.preconf_request.hash() {
        if message.data.len() == 32 {
            let hash = B256::from_slice(&message.data);
            forward_event(event_tx, NetworkEvent::UnsafeRequest { from, hash }).await?;
        } else {
            debug!(len = message.data.len(), "invalid preconf request payload length");
        }
        return Ok(());
    }

    if *topic == topics.eos_request.hash() {
        if message.data.len() <= 8 {
            let epoch = message.data.iter().fold(0u64, |acc, byte| (acc << 8) | u64::from(*byte));
            forward_event(event_tx, NetworkEvent::EndOfSequencingRequest { from, epoch }).await?;
        } else {
            debug!(len = message.data.len(), "invalid end-of-sequencing payload length");
        }
    }

    Ok(())
}

/// Forward one decoded event to the importer with backpressure.
async fn forward_event(event_tx: &mpsc::Sender<NetworkEvent>, event: NetworkEvent) -> Result<()> {
    event_tx.send(event).await.map_err(|err| {
        warn!(error = %err, "whitelist preconfirmation event channel closed");
        WhitelistPreconfirmationDriverError::P2p(format!(
            "whitelist preconfirmation event channel closed: {err}"
        ))
    })
}

/// Convert a p2p error into a driver error.
fn to_p2p_err(err: impl std::fmt::Display) -> WhitelistPreconfirmationDriverError {
    WhitelistPreconfirmationDriverError::P2p(err.to_string())
}

#[cfg(test)]
mod tests {
    use std::time::Duration;

    use alloy_primitives::{Address, Bloom, Bytes, U256};
    use alloy_rpc_types_engine::ExecutionPayloadV1;
    use libp2p::{
        Transport,
        core::upgrade,
        gossipsub, identify, identity, noise, ping,
        swarm::{NetworkBehaviour, SwarmEvent},
        tcp, yamux,
    };

    use super::*;

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
    fn classify_bootnodes_splits_enr_and_multiaddr_entries() {
        let input = vec![
            "/ip4/127.0.0.1/tcp/9000/p2p/12D3KooWEhXfLw7BrTHr2VfVki6jPiKG8AqfXw3hNziR6mM2Mz4s"
                .to_string(),
            "enr:-IS4QO3Qh8n0cxb5KJ9f5Xx8t9wq2fS28uFh8gJQ6KxJxRk6J1V1kWQ5g6nAiJmK8P8e9Z5hY3rP0mFf6vM1Sxg6W4qGAYN1ZHCCdl8"
                .to_string(),
            "not-a-valid-bootnode".to_string(),
        ];

        let parsed = classify_bootnodes(input);

        assert_eq!(parsed.dial_addrs.len(), 1);
        assert_eq!(parsed.discovery_enrs.len(), 1);
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
        let topic =
            gossipsub::IdentTopic::new(format!("/taiko/{chain_id}/0/responsePreconfBlocks"));

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
}

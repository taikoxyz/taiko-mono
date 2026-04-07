//! Network driver for the whitelist preconfirmation gossipsub stack.
//!
//! Contains type definitions, swarm bootstrap, transport helpers, the network
//! runtime event loop, gossipsub event handling, and decode/metrics helpers.

use std::{collections::HashSet, net::SocketAddr, sync::Arc, time::Instant};

use alloy_primitives::B256;
use futures::StreamExt;
use libp2p::{
    Multiaddr, PeerId, Swarm, Transport, core::upgrade, dns, gossipsub, identity, noise, tcp, yamux,
};
use tokio::{sync::mpsc, task::JoinHandle};
use tracing::{debug, warn};

use super::{
    behaviour::{BehaviourEvent, TaikoBehaviour, build_behaviour},
    discovery::{classify_bootnodes, init_discovery, recv_discovered_multiaddr},
    handler::GossipsubInboundState,
    topics::Topics,
};
use crate::{
    codec::{
        DecodedUnsafePayload, WhitelistExecutionPayloadEnvelope, decode_envelope_ssz,
        decode_unsafe_payload_signature, decode_unsafe_response_message, encode_envelope_ssz,
        encode_eos_request_message, encode_unsafe_payload_message, encode_unsafe_request_message,
        encode_unsafe_response_message,
    },
    error::{Result, WhitelistPreconfirmationDriverError},
    metrics::WhitelistPreconfirmationDriverMetrics,
    operator_set::SharedOperatorSet,
};

/// Network event emitted by the whitelist preconfirmation gossipsub stack.
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
        envelope: WhitelistExecutionPayloadEnvelope,
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
        envelope: Arc<WhitelistExecutionPayloadEnvelope>,
    },
    /// Publish a signed unsafe payload to the `preconfBlocks` topic.
    PublishUnsafePayload {
        /// 65-byte secp256k1 signature.
        signature: [u8; 65],
        /// Envelope to publish.
        envelope: Arc<WhitelistExecutionPayloadEnvelope>,
    },
    /// Publish an end-of-sequencing request to the `requestEndOfSequencingPreconfBlocks` topic.
    PublishEndOfSequencingRequest {
        /// Epoch number.
        epoch: u64,
    },
    /// Shutdown the network loop.
    Shutdown,
}

/// Handle to the running whitelist network.
pub(crate) struct WhitelistNetwork {
    /// Local peer id.
    pub(crate) local_peer_id: PeerId,
    /// Inbound event stream.
    pub(crate) event_rx: mpsc::Receiver<NetworkEvent>,
    /// Outbound command sender.
    pub(crate) command_tx: mpsc::Sender<NetworkCommand>,
    /// Background task running the swarm.
    pub(crate) handle: JoinHandle<Result<()>>,
}

/// Configuration for the whitelist preconfirmation P2P network.
#[derive(Debug, Clone)]
pub struct NetworkConfig {
    /// Enable TCP transport.
    pub enable_tcp: bool,
    /// TCP listen address.
    pub listen_addr: SocketAddr,
    /// Bootnodes as ENR or multiaddr strings.
    pub bootnodes: Vec<String>,
    /// Static peers to dial on startup.
    pub pre_dial_peers: Vec<Multiaddr>,
    /// Enable discv5 peer discovery.
    pub enable_discovery: bool,
    /// UDP listen address for discv5 discovery.
    pub discovery_listen: SocketAddr,
}

impl Default for NetworkConfig {
    fn default() -> Self {
        Self {
            enable_tcp: true,
            listen_addr: SocketAddr::from(([0, 0, 0, 0], 9222)),
            bootnodes: Vec::new(),
            pre_dial_peers: Vec::new(),
            enable_discovery: false,
            discovery_listen: SocketAddr::from(([0, 0, 0, 0], 9223)),
        }
    }
}

impl WhitelistNetwork {
    /// Spawn the whitelist preconfirmation network task.
    pub(crate) fn spawn(
        chain_id: u64,
        cfg: NetworkConfig,
        operator_set: SharedOperatorSet,
    ) -> Result<Self> {
        let NetworkConfig {
            enable_tcp,
            listen_addr,
            bootnodes,
            pre_dial_peers,
            enable_discovery,
            discovery_listen,
        } = cfg;

        let local_key = identity::Keypair::generate_ed25519();
        let local_peer_id = local_key.public().to_peer_id();

        let topics = Topics::new(chain_id);
        let behaviour = build_behaviour(&local_key, &topics)?;
        let mut swarm = build_swarm(&local_key, local_peer_id, behaviour)?;
        configure_listen_addr(&mut swarm, enable_tcp, listen_addr)?;

        let bootnodes = classify_bootnodes(bootnodes);
        let dialed_addrs = dial_initial_peers(&mut swarm, pre_dial_peers, bootnodes.dial_addrs);
        let discovery_rx =
            init_discovery(enable_discovery, discovery_listen, bootnodes.discovery_enrs);

        let (event_tx, event_rx) = mpsc::channel(1024);
        let (command_tx, command_rx) = mpsc::channel(512);

        let inbound_validation_state = GossipsubInboundState::new(chain_id, operator_set);

        let runtime = NetworkRuntime {
            swarm,
            topics,
            event_tx,
            command_rx,
            discovery_rx,
            dialed_addrs,
            inbound_validation_state,
            local_peer_id_for_events: local_peer_id,
        };

        let handle = tokio::spawn(async move { runtime.run().await });

        Ok(Self { local_peer_id, event_rx, command_tx, handle })
    }
}

/// Build a libp2p swarm with DNS-over-TCP transport, noise auth, and yamux multiplexing.
fn build_swarm(
    local_key: &identity::Keypair,
    local_peer_id: PeerId,
    behaviour: TaikoBehaviour,
) -> Result<Swarm<TaikoBehaviour>> {
    let noise_config =
        noise::Config::new(local_key).map_err(WhitelistPreconfirmationDriverError::p2p)?;
    let base_tcp = tcp::tokio::Transport::new(tcp::Config::default().nodelay(true));
    let tcp_with_dns = dns::tokio::Transport::system(base_tcp)
        .map_err(WhitelistPreconfirmationDriverError::p2p)?;
    let transport = tcp_with_dns
        .upgrade(upgrade::Version::V1Lazy)
        .authenticate(noise_config)
        .multiplex(yamux::Config::default())
        .boxed();

    Ok(Swarm::new(
        transport,
        behaviour,
        local_peer_id,
        libp2p::swarm::Config::with_tokio_executor(),
    ))
}

/// Configure the TCP listen address when TCP serving is enabled.
fn configure_listen_addr(
    swarm: &mut Swarm<TaikoBehaviour>,
    enable_tcp: bool,
    listen_addr: SocketAddr,
) -> Result<()> {
    if !enable_tcp {
        return Ok(());
    }

    let listen_addr = if listen_addr.is_ipv4() {
        format!("/ip4/{}/tcp/{}", listen_addr.ip(), listen_addr.port())
    } else {
        format!("/ip6/{}/tcp/{}", listen_addr.ip(), listen_addr.port())
    }
    .parse::<Multiaddr>()
    .map_err(WhitelistPreconfirmationDriverError::p2p)?;

    swarm.listen_on(listen_addr).map_err(WhitelistPreconfirmationDriverError::p2p)?;

    Ok(())
}

/// Dial a peer address once.
fn dial_once(
    swarm: &mut Swarm<TaikoBehaviour>,
    dialed_addrs: &mut HashSet<Multiaddr>,
    addr: Multiaddr,
    source: &str,
) {
    if !dialed_addrs.insert(addr.clone()) {
        debug!(%addr, source, "already dialed address; skipping");
        return;
    }

    if let Err(err) = swarm.dial(addr.clone()) {
        metrics::counter!(
            WhitelistPreconfirmationDriverMetrics::NETWORK_DIAL_ATTEMPTS_TOTAL,
            "source" => source.to_string(),
            "result" => "failed",
        )
        .increment(1);
        warn!(%addr, source, error = %err, "failed to dial address");
    } else {
        metrics::counter!(
            WhitelistPreconfirmationDriverMetrics::NETWORK_DIAL_ATTEMPTS_TOTAL,
            "source" => source.to_string(),
            "result" => "ok",
        )
        .increment(1);
    }
}

/// Dial configured static peers and bootnode multiaddrs once each.
fn dial_initial_peers(
    swarm: &mut Swarm<TaikoBehaviour>,
    pre_dial_peers: Vec<Multiaddr>,
    bootnode_dial_addrs: Vec<Multiaddr>,
) -> HashSet<Multiaddr> {
    let mut dialed_addrs = HashSet::new();

    for peer in pre_dial_peers {
        dial_once(swarm, &mut dialed_addrs, peer, "static peer");
    }

    for addr in bootnode_dial_addrs {
        dial_once(swarm, &mut dialed_addrs, addr, "bootnode");
    }

    dialed_addrs
}

/// Runtime state machine that owns networking resources and processes loop inputs.
struct NetworkRuntime {
    /// Live libp2p swarm.
    swarm: Swarm<TaikoBehaviour>,
    /// Topic bundle used for outbound publishing and inbound routing.
    topics: Topics,
    /// Channel used to forward validated network events to the importer.
    event_tx: mpsc::Sender<NetworkEvent>,
    /// Channel receiving outbound publish commands from higher-level components.
    command_rx: mpsc::Receiver<NetworkCommand>,
    /// Optional discovery stream for ENR-derived dial candidates.
    discovery_rx: Option<mpsc::Receiver<Multiaddr>>,
    /// Set of addresses already dialed to avoid redundant dial attempts.
    dialed_addrs: HashSet<Multiaddr>,
    /// Inbound validation and dedupe state for gossipsub messages.
    inbound_validation_state: GossipsubInboundState,
    /// Local peer id used by loopback payload events.
    local_peer_id_for_events: PeerId,
}

impl NetworkRuntime {
    /// Run the network runtime loop until an explicit shutdown signal or channel closure.
    async fn run(mut self) -> Result<()> {
        while self.run_once().await? {}

        Ok(())
    }

    /// Process one input event from command, discovery, or swarm.
    async fn run_once(&mut self) -> Result<bool> {
        let has_discovery = self.discovery_rx.is_some();

        tokio::select! {
            maybe_command = self.command_rx.recv() => {
                match maybe_command {
                    None => Ok(false),
                    Some(NetworkCommand::Shutdown) => Ok(false),
                    Some(command) => {
                        self.handle_command(command).await?;
                        Ok(true)
                    },
                }
            }
            maybe_addr = recv_discovered_multiaddr(&mut self.discovery_rx), if has_discovery => {
                self.handle_discovery_multiaddr(maybe_addr);
                Ok(true)
            }
            event = self.swarm.select_next_some() => {
                self.handle_swarm_event(event).await?;
                Ok(true)
            }
        }
    }

    /// Execute one outbound network command.
    async fn handle_command(&mut self, command: NetworkCommand) -> Result<()> {
        match command {
            NetworkCommand::PublishUnsafeRequest { hash } => {
                self.publish_unsafe_request(hash);
            }
            NetworkCommand::PublishUnsafeResponse { envelope } => {
                self.publish_unsafe_response(envelope);
            }
            NetworkCommand::PublishUnsafePayload { signature, envelope } => {
                self.publish_unsafe_payload(signature, envelope).await?;
            }
            NetworkCommand::PublishEndOfSequencingRequest { epoch } => {
                self.publish_end_of_sequencing_request(epoch);
            }
            NetworkCommand::Shutdown => unreachable!("handled in run_once"),
        }

        Ok(())
    }

    /// Publish a `requestPreconfBlocks` message.
    fn publish_unsafe_request(&mut self, hash: B256) {
        let payload = encode_unsafe_request_message(hash);
        self.publish_to_gossipsub(
            self.topics.preconf_request.clone(),
            payload,
            "request_preconf_blocks",
            &format!("{hash}"),
        );
    }

    /// Publish a `responsePreconfBlocks` message.
    fn publish_unsafe_response(&mut self, envelope: Arc<WhitelistExecutionPayloadEnvelope>) {
        let hash = envelope.execution_payload.block_hash;
        self.encode_and_publish(
            encode_unsafe_response_message(&envelope),
            self.topics.preconf_response.clone(),
            "response_preconf_blocks",
            &format!("{hash}"),
        );
    }

    /// Publish a `preconfBlocks` message and emit loopback event for local cache/import.
    async fn publish_unsafe_payload(
        &mut self,
        signature: [u8; 65],
        envelope: Arc<WhitelistExecutionPayloadEnvelope>,
    ) -> Result<()> {
        let hash = envelope.execution_payload.block_hash;

        // Loop back locally-built payloads so importer caches can serve
        // follow-up EOS catch-up requests even without peer echo.
        let payload_bytes = encode_envelope_ssz(&envelope);
        let local_event = NetworkEvent::UnsafePayload {
            from: self.local_peer_id_for_events,
            payload: DecodedUnsafePayload {
                wire_signature: signature,
                payload_bytes,
                envelope: (*envelope).clone(),
            },
        };

        // Loopback first so downstream cache/import logic observes the
        // payload even when there are no peers to echo it back.
        forward_event(&self.event_tx, local_event).await?;

        self.encode_and_publish(
            encode_unsafe_payload_message(&signature, &envelope),
            self.topics.preconf_blocks.clone(),
            "preconf_blocks",
            &format!("{hash}"),
        );

        Ok(())
    }

    /// Publish a `requestEndOfSequencingPreconfBlocks` message.
    fn publish_end_of_sequencing_request(&mut self, epoch: u64) {
        let payload = encode_eos_request_message(epoch);
        self.publish_to_gossipsub(
            self.topics.eos_request.clone(),
            payload,
            "request_eos_preconf_blocks",
            &format!("epoch {epoch}"),
        );
    }

    /// Encode-then-publish helper: handles the common `Result<Vec<u8>>` encode
    /// followed by gossipsub publish, recording metrics for each outcome.
    fn encode_and_publish(
        &mut self,
        encoded: std::result::Result<Vec<u8>, impl std::fmt::Display>,
        topic: gossipsub::IdentTopic,
        topic_label: &'static str,
        context: &str,
    ) {
        match encoded {
            Ok(payload) => {
                self.publish_to_gossipsub(topic, payload, topic_label, context);
            }
            Err(err) => {
                record_publish(topic_label, "encode_failed");
                warn!(
                    context,
                    error = %err,
                    "failed to encode whitelist preconfirmation message"
                );
            }
        }
    }

    /// Publish raw bytes to a gossipsub topic, recording publish success or failure.
    fn publish_to_gossipsub(
        &mut self,
        topic: gossipsub::IdentTopic,
        payload: Vec<u8>,
        topic_label: &'static str,
        context: &str,
    ) {
        if let Err(err) = self.swarm.behaviour_mut().gossipsub.publish(topic, payload) {
            record_publish(topic_label, "publish_failed");
            warn!(
                context,
                error = %err,
                "failed to publish whitelist preconfirmation message"
            );
        } else {
            record_publish(topic_label, "published");
        }
    }

    /// Handle one discovery result by dialing or disabling discovery when closed.
    fn handle_discovery_multiaddr(&mut self, maybe_addr: Option<Multiaddr>) {
        match maybe_addr {
            Some(addr) => {
                dial_once(&mut self.swarm, &mut self.dialed_addrs, addr, "discovery");
            }
            None => {
                self.discovery_rx = None;
                debug!("whitelist preconfirmation discovery stream closed");
            }
        }
    }

    /// Delegate one swarm event to the appropriate handler.
    async fn handle_swarm_event(
        &mut self,
        event: libp2p::swarm::SwarmEvent<BehaviourEvent>,
    ) -> Result<()> {
        match event {
            libp2p::swarm::SwarmEvent::Behaviour(BehaviourEvent::Gossipsub(event)) => {
                self.handle_gossipsub_event(*event).await?;
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
            libp2p::swarm::SwarmEvent::Behaviour(
                BehaviourEvent::Ping | BehaviourEvent::Identify,
            ) => {}
            other => {
                debug!(event = ?other, "ignored swarm event");
            }
        }
        Ok(())
    }

    /// Handle one gossipsub event.
    async fn handle_gossipsub_event(&mut self, event: gossipsub::Event) -> Result<()> {
        let gossipsub::Event::Message { propagation_source, message_id, message, .. } = event
        else {
            return Ok(());
        };

        let topic = &message.topic;
        let from = propagation_source;
        let now = Instant::now();

        let mut report = |acceptance: gossipsub::MessageAcceptance| {
            // Explicitly report every decision so mesh scoring remains aligned with local
            // validation.
            let _ = self.swarm.behaviour_mut().gossipsub.report_message_validation_result(
                &message_id,
                &from,
                acceptance,
            );
        };

        if *topic == self.topics.preconf_blocks.hash() {
            let (acceptance, inbound_label) = match decode_unsafe_payload_signature(&message.data)
                .and_then(|(sig, bytes)| decode_envelope_ssz(&bytes).map(|env| (sig, bytes, env)))
            {
                Ok((wire_signature, payload_bytes, envelope)) => {
                    let payload = DecodedUnsafePayload { wire_signature, payload_bytes, envelope };
                    let acceptance =
                        self.inbound_validation_state.validate_preconf_blocks(&payload);

                    if matches!(acceptance, gossipsub::MessageAcceptance::Accept) &&
                        let Err(err) = forward_event(
                            &self.event_tx,
                            NetworkEvent::UnsafePayload { from, payload },
                        )
                        .await
                    {
                        // If forwarding to importer fails, reject to avoid silently
                        // accepting data that local consumers could not process.
                        report(gossipsub::MessageAcceptance::Reject);
                        return Err(err);
                    }

                    let label = acceptance_label(&acceptance);
                    (acceptance, label)
                }
                Err(_) => (gossipsub::MessageAcceptance::Reject, "decode_failed"),
            };

            record_inbound("preconf_blocks", inbound_label);
            report(acceptance);
            return Ok(());
        }

        if *topic == self.topics.preconf_response.hash() {
            let (acceptance, inbound_label) = match decode_unsafe_response_message(&message.data) {
                Ok(envelope) => {
                    let acceptance = self.inbound_validation_state.validate_response(&envelope);
                    if matches!(acceptance, gossipsub::MessageAcceptance::Accept) &&
                        let Err(err) = forward_event(
                            &self.event_tx,
                            NetworkEvent::UnsafeResponse { from, envelope },
                        )
                        .await
                    {
                        report(gossipsub::MessageAcceptance::Reject);
                        return Err(err);
                    }

                    let inbound_label = acceptance_label(&acceptance);
                    (acceptance, inbound_label)
                }
                Err(_) => (gossipsub::MessageAcceptance::Reject, "decode_failed"),
            };

            record_inbound("response_preconf_blocks", inbound_label);
            report(acceptance);
            return Ok(());
        }

        if *topic == self.topics.preconf_request.hash() {
            let Some(hash) = decode_request_hash_exact(&message.data) else {
                let (acceptance, inbound_label) =
                    (gossipsub::MessageAcceptance::Reject, "decode_failed");
                record_inbound("request_preconf_blocks", inbound_label);
                report(acceptance);
                return Ok(());
            };

            let acceptance = self.inbound_validation_state.validate_request(from, hash, now);
            if matches!(acceptance, gossipsub::MessageAcceptance::Accept) {
                // Requests are relayed only after inbound dedupe/rate checks pass.
                forward_event(&self.event_tx, NetworkEvent::UnsafeRequest { from, hash }).await?;
            }

            record_inbound("request_preconf_blocks", acceptance_label(&acceptance));
            report(acceptance);
            return Ok(());
        }

        if *topic == self.topics.eos_request.hash() {
            let Some(epoch) = decode_eos_epoch_exact(&message.data) else {
                let (acceptance, inbound_label) =
                    (gossipsub::MessageAcceptance::Reject, "decode_failed");
                record_inbound("request_eos_preconf_blocks", inbound_label);
                report(acceptance);
                return Ok(());
            };

            let acceptance = self.inbound_validation_state.validate_eos_request(from, epoch, now);
            if matches!(acceptance, gossipsub::MessageAcceptance::Accept) {
                // EOS requests follow the same acceptance gate as preconf requests.
                forward_event(&self.event_tx, NetworkEvent::EndOfSequencingRequest { from, epoch })
                    .await?;
            }

            record_inbound("request_eos_preconf_blocks", acceptance_label(&acceptance));
            report(acceptance);
        }

        Ok(())
    }
}

/// Convert a gossipsub message acceptance decision into a metrics label.
fn acceptance_label(acceptance: &gossipsub::MessageAcceptance) -> &'static str {
    match acceptance {
        gossipsub::MessageAcceptance::Accept => "accepted",
        gossipsub::MessageAcceptance::Ignore => "ignored",
        gossipsub::MessageAcceptance::Reject => "rejected",
    }
}

/// Record one outbound publish lifecycle outcome for the given network topic label.
fn record_publish(topic: &'static str, result: &'static str) {
    metrics::counter!(
        WhitelistPreconfirmationDriverMetrics::NETWORK_OUTBOUND_PUBLISH_TOTAL,
        "topic" => topic,
        "result" => result,
    )
    .increment(1);
}

/// Record one inbound message result for the given network topic label.
fn record_inbound(topic: &'static str, result: &'static str) {
    metrics::counter!(
        WhitelistPreconfirmationDriverMetrics::NETWORK_INBOUND_MESSAGES_TOTAL,
        "topic" => topic,
        "result" => result,
    )
    .increment(1);
}

/// Forward one decoded event to the importer with backpressure.
pub(super) async fn forward_event(
    event_tx: &mpsc::Sender<NetworkEvent>,
    event: NetworkEvent,
) -> Result<()> {
    event_tx.send(event).await.map_err(|err| {
        metrics::counter!(WhitelistPreconfirmationDriverMetrics::NETWORK_FORWARD_FAILURES_TOTAL)
            .increment(1);
        warn!(error = %err, "whitelist preconfirmation event channel closed");
        WhitelistPreconfirmationDriverError::p2p(format!(
            "whitelist preconfirmation event channel closed: {err}"
        ))
    })
}

/// Decode an end-of-sequencing epoch when the payload is exactly 8 bytes.
pub(super) fn decode_eos_epoch_exact(payload: &[u8]) -> Option<u64> {
    let bytes: [u8; 8] = payload.try_into().ok()?;
    Some(u64::from_be_bytes(bytes))
}

/// Decode a 32-byte request hash payload exactly (non-padded path).
pub(super) fn decode_request_hash_exact(payload: &[u8]) -> Option<B256> {
    let bytes: [u8; 32] = payload.try_into().ok()?;
    Some(B256::from(bytes))
}

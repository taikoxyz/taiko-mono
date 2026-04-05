//! Swarm bootstrap and main network loop orchestration.

use std::{
    collections::{HashSet, VecDeque},
    net::SocketAddr,
    sync::Arc,
    time::{Duration, Instant},
};

use alloy_primitives::B256;
use futures::StreamExt;
use libp2p::{
    Multiaddr, PeerId, Swarm, Transport, core::upgrade, dns, identify, identity, noise, ping, tcp,
    yamux,
};
use preconfirmation_net::{P2pConfig, spawn_discovery};
use tokio::sync::mpsc;
use tracing::{debug, warn};

use super::{
    bootnodes::{classify_bootnodes, dial_once, recv_discovered_multiaddr},
    event_loop::{forward_event, handle_swarm_event},
    gossip::{build_gossipsub, deterministic_jitter},
    inbound::GossipsubInboundState,
    types::{Behaviour, BehaviourEvent, NetworkCommand, NetworkEvent, WhitelistNetwork},
};
use crate::{
    codec::{
        DecodedUnsafePayload, WhitelistExecutionPayloadEnvelope, encode_envelope_ssz,
        encode_eos_request_message, encode_unsafe_payload_message, encode_unsafe_request_message,
        encode_unsafe_response_message,
    },
    error::{Result, WhitelistPreconfirmationDriverError},
    metrics::WhitelistPreconfirmationDriverMetrics,
    wire::topics::Topics,
};

/// Maximum deterministic delay before gossiping a `responsePreconfBlocks` response.
const RESPONSE_JITTER_MAX: Duration = Duration::from_secs(1);

#[derive(Debug)]
/// Pending `responsePreconfBlocks` publish waiting for its deterministic deadline.
struct PendingResponsePublish {
    /// Hash used for response suppression and dedupe.
    hash: B256,
    /// Envelope to publish when the deadline elapses.
    envelope: Arc<WhitelistExecutionPayloadEnvelope>,
    /// Tokio deadline for the delayed publish.
    deadline: tokio::time::Instant,
}

/// Build whitelist topics and subscribe gossipsub to all required channels.
fn build_topics_and_gossipsub(chain_id: u64) -> Result<(Topics, libp2p::gossipsub::Behaviour)> {
    let topics = Topics::new(chain_id);
    let mut gossipsub = build_gossipsub()?;
    gossipsub
        .subscribe(&topics.preconf_blocks)
        .map_err(WhitelistPreconfirmationDriverError::p2p)?;
    gossipsub
        .subscribe(&topics.preconf_request)
        .map_err(WhitelistPreconfirmationDriverError::p2p)?;
    gossipsub
        .subscribe(&topics.preconf_response)
        .map_err(WhitelistPreconfirmationDriverError::p2p)?;
    gossipsub.subscribe(&topics.eos_request).map_err(WhitelistPreconfirmationDriverError::p2p)?;

    Ok((topics, gossipsub))
}

/// Assemble the libp2p behaviour stack from key material and gossipsub.
fn build_behaviour(
    local_key: &identity::Keypair,
    gossipsub: libp2p::gossipsub::Behaviour,
) -> Behaviour {
    Behaviour {
        gossipsub,
        ping: ping::Behaviour::new(ping::Config::new()),
        identify: identify::Behaviour::new(identify::Config::new(
            "/taiko/whitelist-preconfirmation/1.0.0".to_string(),
            local_key.public(),
        )),
    }
}

/// Build a libp2p swarm with DNS-over-TCP transport, noise auth, and yamux multiplexing.
fn build_swarm(
    local_key: &identity::Keypair,
    local_peer_id: PeerId,
    behaviour: Behaviour,
) -> Result<Swarm<Behaviour>> {
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
    swarm: &mut Swarm<Behaviour>,
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

/// Dial configured static peers and bootnode multiaddrs once each.
fn dial_initial_peers(
    swarm: &mut Swarm<Behaviour>,
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

/// Initialize optional discovery receiver based on config and available ENR bootnodes.
fn init_discovery_receiver(
    enable_discovery: bool,
    discovery_listen: SocketAddr,
    discovery_enrs: Vec<String>,
) -> Option<mpsc::Receiver<Multiaddr>> {
    match (enable_discovery, discovery_enrs.is_empty()) {
        (true, false) => spawn_discovery(discovery_listen, discovery_enrs)
            .map_err(|err| {
                warn!(error = %err, "failed to start whitelist preconfirmation discovery");
            })
            .ok(),
        (true, true) => {
            tracing::info!(
                "discovery enabled but no ENR bootnodes provided; skipping discv5 bootstrap"
            );
            None
        }
        (false, false) => {
            warn!(count = discovery_enrs.len(), "discovery is disabled; skipping ENR bootnodes");
            None
        }
        (false, true) => None,
    }
}

/// Runtime state machine that owns networking resources and processes loop inputs.
struct NetworkRuntime {
    /// Live libp2p swarm.
    swarm: Swarm<Behaviour>,
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
    /// Pending response publishes waiting for deterministic jitter deadlines.
    pending_response_publishes: VecDeque<PendingResponsePublish>,
    /// Hashes already scheduled for a delayed response publish.
    pending_response_hashes: HashSet<B256>,
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
        self.publish_due_responses().await?;

        let has_discovery = self.discovery_rx.is_some();
        let pending_response_deadline = self.next_pending_response_deadline();

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
            _ = async {
                if let Some(deadline) = pending_response_deadline {
                    tokio::time::sleep_until(deadline).await;
                }
            }, if pending_response_deadline.is_some() => {
                self.publish_due_responses().await?;
                Ok(true)
            }
        }
    }

    /// Execute one outbound network command.
    async fn handle_command(&mut self, command: NetworkCommand) -> Result<()> {
        match command {
            NetworkCommand::PublishUnsafeResponse { envelope } => {
                self.schedule_unsafe_response_publish(envelope);
            }
            NetworkCommand::PublishUnsafePayload { signature, envelope } => {
                self.publish_unsafe_payload(signature, envelope).await?;
            }
            NetworkCommand::PublishEndOfSequencingRequest { epoch } => {
                self.publish_end_of_sequencing_request(epoch);
            }
            NetworkCommand::PublishUnsafeRequest { hash } => {
                self.publish_unsafe_request(hash);
            }
            NetworkCommand::Shutdown => {
                // Shutdown is handled in `run_once`.
            }
        }

        Ok(())
    }

    /// Queue a `responsePreconfBlocks` message behind deterministic jitter.
    fn schedule_unsafe_response_publish(
        &mut self,
        envelope: Arc<WhitelistExecutionPayloadEnvelope>,
    ) {
        let hash = envelope.execution_payload.block_hash;
        let now = Instant::now();

        if self.pending_response_hashes.contains(&hash) {
            record_outbound_publish("response_preconf_blocks", "suppressed_pending_response");
            return;
        }

        if self.inbound_validation_state.response_seen_recently(hash, now) {
            record_outbound_publish("response_preconf_blocks", "suppressed_recent_response");
            return;
        }

        let delay = deterministic_jitter(self.local_peer_id_for_events, hash, RESPONSE_JITTER_MAX);
        let pending = PendingResponsePublish {
            hash,
            envelope,
            deadline: tokio::time::Instant::now() + delay,
        };

        self.pending_response_hashes.insert(hash);
        self.insert_pending_response_publish(pending);
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

        match encode_unsafe_payload_message(&signature, &envelope) {
            Ok(payload) => {
                if let Err(err) = self
                    .swarm
                    .behaviour_mut()
                    .gossipsub
                    .publish(self.topics.preconf_blocks.clone(), payload)
                {
                    record_outbound_publish("preconf_blocks", "publish_failed");
                    warn!(
                        hash = %hash,
                        error = %err,
                        "failed to publish whitelist preconfirmation payload"
                    );
                } else {
                    record_outbound_publish("preconf_blocks", "published");
                }
            }
            Err(err) => {
                record_outbound_publish("preconf_blocks", "encode_failed");
                warn!(
                    hash = %hash,
                    error = %err,
                    "failed to encode whitelist preconfirmation payload"
                );
            }
        }

        Ok(())
    }

    /// Publish a `requestEndOfSequencingPreconfBlocks` message.
    fn publish_end_of_sequencing_request(&mut self, epoch: u64) {
        let payload = encode_eos_request_message(epoch);
        if let Err(err) =
            self.swarm.behaviour_mut().gossipsub.publish(self.topics.eos_request.clone(), payload)
        {
            record_outbound_publish("request_eos_preconf_blocks", "publish_failed");
            warn!(
                epoch,
                error = %err,
                "failed to publish end-of-sequencing request"
            );
        } else {
            record_outbound_publish("request_eos_preconf_blocks", "published");
        }
    }

    /// Publish a `requestPreconfBlocks` message.
    fn publish_unsafe_request(&mut self, hash: B256) {
        let payload = encode_unsafe_request_message(hash);
        if let Err(err) = self
            .swarm
            .behaviour_mut()
            .gossipsub
            .publish(self.topics.preconf_request.clone(), payload)
        {
            record_outbound_publish("request_preconf_blocks", "publish_failed");
            warn!(
                hash = %hash,
                error = %err,
                "failed to publish gossip fallback for direct block request"
            );
        } else {
            record_outbound_publish("request_preconf_blocks", "published");
        }
    }

    /// Return the earliest pending response deadline, if one exists.
    fn next_pending_response_deadline(&self) -> Option<tokio::time::Instant> {
        self.pending_response_publishes.front().map(|pending| pending.deadline)
    }

    /// Insert a pending response publish in deadline order.
    fn insert_pending_response_publish(&mut self, pending: PendingResponsePublish) {
        let index = self
            .pending_response_publishes
            .iter()
            .position(|existing| existing.deadline > pending.deadline)
            .unwrap_or(self.pending_response_publishes.len());
        self.pending_response_publishes.insert(index, pending);
    }

    /// Publish any queued response whose deterministic deadline has elapsed.
    async fn publish_due_responses(&mut self) -> Result<()> {
        while self.publish_one_due_response().await? {}

        Ok(())
    }

    /// Publish one queued response if the front item is ready.
    async fn publish_one_due_response(&mut self) -> Result<bool> {
        let Some(pending) = self.pending_response_publishes.front() else {
            return Ok(false);
        };

        if pending.deadline > tokio::time::Instant::now() {
            return Ok(false);
        }

        let Some(pending) = self.pending_response_publishes.pop_front() else {
            return Ok(false);
        };
        self.pending_response_hashes.remove(&pending.hash);

        let now = Instant::now();
        if self.inbound_validation_state.response_seen_recently(pending.hash, now) {
            record_outbound_publish("response_preconf_blocks", "suppressed_recent_response");
            return Ok(true);
        }

        match encode_unsafe_response_message(&pending.envelope) {
            Ok(payload) => {
                if let Err(err) = self
                    .swarm
                    .behaviour_mut()
                    .gossipsub
                    .publish(self.topics.preconf_response.clone(), payload)
                {
                    record_outbound_publish("response_preconf_blocks", "publish_failed");
                    warn!(
                        hash = %pending.hash,
                        error = %err,
                        "failed to publish whitelist preconfirmation response"
                    );
                } else {
                    record_outbound_publish("response_preconf_blocks", "published");
                    self.inbound_validation_state.mark_response_seen(pending.hash, now);
                }
            }
            Err(err) => {
                record_outbound_publish("response_preconf_blocks", "encode_failed");
                warn!(
                    hash = %pending.hash,
                    error = %err,
                    "failed to encode whitelist preconfirmation response"
                );
            }
        }

        Ok(true)
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

    /// Delegate one swarm event to the shared event-processing module.
    async fn handle_swarm_event(
        &mut self,
        event: libp2p::swarm::SwarmEvent<BehaviourEvent>,
    ) -> Result<()> {
        handle_swarm_event(
            event,
            &self.topics,
            &self.event_tx,
            &mut self.inbound_validation_state,
            &mut self.swarm,
        )
        .await
    }
}

/// Record one outbound publish lifecycle outcome for the given network topic label.
fn record_outbound_publish(topic: &'static str, result: &'static str) {
    metrics::counter!(
        WhitelistPreconfirmationDriverMetrics::NETWORK_OUTBOUND_PUBLISH_TOTAL,
        "topic" => topic,
        "result" => result,
    )
    .increment(1);
}

impl WhitelistNetwork {
    /// Spawn the whitelist preconfirmation network task.
    pub(crate) fn spawn_with_whitelist_filter(cfg: P2pConfig) -> Result<Self> {
        Self::spawn_with_filter(cfg)
    }

    /// Internal spawn path that wires transport, behaviour, and the event loop.
    fn spawn_with_filter(cfg: P2pConfig) -> Result<Self> {
        let P2pConfig {
            chain_id,
            enable_tcp,
            listen_addr,
            bootnodes,
            pre_dial_peers,
            enable_discovery,
            discovery_listen,
            sequencer_addresses,
            allow_all_sequencers,
            ..
        } = cfg;

        let local_key = identity::Keypair::generate_ed25519();
        let local_peer_id = local_key.public().to_peer_id();

        let (topics, gossipsub) = build_topics_and_gossipsub(chain_id)?;
        let behaviour = build_behaviour(&local_key, gossipsub);
        let mut swarm = build_swarm(&local_key, local_peer_id, behaviour)?;
        configure_listen_addr(&mut swarm, enable_tcp, listen_addr)?;

        let bootnodes = classify_bootnodes(bootnodes);
        let dialed_addrs = dial_initial_peers(&mut swarm, pre_dial_peers, bootnodes.dial_addrs);
        let discovery_rx =
            init_discovery_receiver(enable_discovery, discovery_listen, bootnodes.discovery_enrs);

        let (event_tx, event_rx) = mpsc::channel(1024);
        let (command_tx, command_rx) = mpsc::channel(512);

        let inbound_validation_state = GossipsubInboundState::new_with_allow_all_sequencers(
            chain_id,
            sequencer_addresses,
            allow_all_sequencers,
        );

        let runtime = NetworkRuntime {
            swarm,
            topics,
            event_tx,
            command_rx,
            discovery_rx,
            dialed_addrs,
            inbound_validation_state,
            pending_response_publishes: VecDeque::new(),
            pending_response_hashes: HashSet::new(),
            local_peer_id_for_events: local_peer_id,
        };

        let handle = tokio::spawn(async move { runtime.run().await });

        Ok(Self { local_peer_id, event_rx, command_tx, handle })
    }
}

//! Network driver for the whitelist preconfirmation gossipsub stack.
//!
//! Contains type definitions, swarm bootstrap, transport helpers, the network
//! runtime event loop, gossipsub event handling, and decode/metrics helpers.

use std::{
    collections::HashSet,
    net::SocketAddr,
    sync::Arc,
    time::{Duration, Instant},
};

use alloy_primitives::B256;
use futures::StreamExt;
use libp2p::{
    Multiaddr, PeerId, Swarm, Transport, core::upgrade, dns, gossipsub, identity,
    multiaddr::Protocol, noise, swarm::DialError, tcp, yamux,
};
use tokio::{
    sync::mpsc,
    task::JoinHandle,
    time::{Instant as TokioInstant, Interval, MissedTickBehavior},
};
use tracing::{debug, info, warn};

use super::{
    behaviour::{BehaviourEvent, TaikoBehaviour, build_behaviour},
    discovery::{classify_bootnodes, init_discovery, recv_discovered_multiaddr},
    handler::GossipsubInboundState,
    topics::Topics,
};
use crate::{
    codec::{
        DecodedUnsafePayload, WhitelistExecutionPayloadEnvelope, decode_envelope_ssz,
        decode_unsafe_payload_signature, decode_unsafe_response_message,
        encode_eos_request_message, encode_unsafe_payload_message, encode_unsafe_request_message,
        encode_unsafe_response_message,
    },
    error::{Result, WhitelistPreconfirmationDriverError},
    metrics::WhitelistPreconfirmationDriverMetrics,
    operator_set::SharedOperatorSet,
};

/// Interval for retrying configured bootnode/static peer dials.
const CONFIGURED_PEER_RETRY_INTERVAL: Duration = Duration::from_secs(30);
/// Expected length of a secp256k1 private key.
const SECP256K1_PRIVATE_KEY_LEN: usize = 32;

/// Interval for logging current preconfirmation peer connectivity.
const PEER_STATUS_LOG_INTERVAL: Duration = Duration::from_secs(60);

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
    /// Peer id for this network instance.
    pub(crate) peer_id: PeerId,
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
    /// Optional externally dialable TCP address advertised in the local enode URL.
    pub advertise_addr: Option<SocketAddr>,
    /// Bootnodes as ENR or multiaddr strings.
    pub bootnodes: Vec<String>,
    /// Static peers to dial on startup.
    pub pre_dial_peers: Vec<Multiaddr>,
    /// Enable discv5 peer discovery.
    pub enable_discovery: bool,
    /// UDP listen address for discv5 discovery.
    pub discovery_listen: SocketAddr,
    /// Optional parsed secp256k1 keypair for the local P2P network identity.
    pub preconfirmation_p2p_key: Option<identity::Keypair>,
}

impl Default for NetworkConfig {
    fn default() -> Self {
        Self {
            enable_tcp: true,
            listen_addr: SocketAddr::from(([0, 0, 0, 0], 9222)),
            advertise_addr: None,
            bootnodes: Vec::new(),
            pre_dial_peers: Vec::new(),
            enable_discovery: false,
            discovery_listen: SocketAddr::from(([0, 0, 0, 0], 9223)),
            preconfirmation_p2p_key: None,
        }
    }
}

impl NetworkConfig {
    /// Parse an optional raw secp256k1 private key for the local P2P network identity.
    pub fn parse_preconfirmation_p2p_priv_raw(
        raw_key: Option<&str>,
    ) -> Result<Option<identity::Keypair>> {
        raw_key.map(parse_preconfirmation_p2p_priv_raw).transpose()
    }

    /// Build the local libp2p identity key, falling back to an ephemeral key.
    fn local_key(&self) -> identity::Keypair {
        self.preconfirmation_p2p_key.clone().unwrap_or_else(identity::Keypair::generate_ed25519)
    }
}

/// Parse a raw secp256k1 private key into a libp2p identity keypair.
fn parse_preconfirmation_p2p_priv_raw(raw_key: &str) -> Result<identity::Keypair> {
    let raw_key = raw_key.strip_prefix("0x").unwrap_or(raw_key);
    let key_bytes = alloy_primitives::hex::decode(raw_key).map_err(|err| {
        WhitelistPreconfirmationDriverError::p2p(format!(
            "invalid preconfirmation.p2p-priv-raw hex: {err}"
        ))
    })?;
    if key_bytes.len() != SECP256K1_PRIVATE_KEY_LEN {
        return Err(WhitelistPreconfirmationDriverError::p2p(format!(
            "invalid preconfirmation.p2p-priv-raw key length: expected 32 bytes, got {}",
            key_bytes.len()
        )));
    }

    let secret_key = identity::secp256k1::SecretKey::try_from_bytes(key_bytes).map_err(|err| {
        WhitelistPreconfirmationDriverError::p2p(format!(
            "invalid preconfirmation.p2p-priv-raw key: {err}"
        ))
    })?;

    Ok(identity::Keypair::from(identity::secp256k1::Keypair::from(secret_key)))
}

/// Build the Ethereum-style enode URL advertised for the secp256k1 P2P identity.
fn advertised_enode_url(
    local_key: &identity::Keypair,
    enable_tcp: bool,
    listen_addr: SocketAddr,
    advertise_addr: Option<SocketAddr>,
    discovery_listen: Option<SocketAddr>,
) -> Option<String> {
    if !enable_tcp {
        return None;
    }

    let secp256k1_key = local_key.clone().try_into_secp256k1().ok()?;
    let uncompressed_public_key = secp256k1_key.public().to_bytes_uncompressed();
    let advertised_addr = advertise_addr.unwrap_or(listen_addr);
    let mut enode = format!(
        "enode://{}@{}",
        alloy_primitives::hex::encode(&uncompressed_public_key[1..]),
        enode_endpoint(advertised_addr)
    );
    if let Some(discovery_listen) =
        discovery_listen.filter(|addr| addr.port() != advertised_addr.port())
    {
        enode.push_str(&format!("?discport={}", discovery_listen.port()));
    }
    Some(enode)
}

/// Format the endpoint component of an enode URL.
fn enode_endpoint(addr: SocketAddr) -> String {
    match addr {
        SocketAddr::V4(addr) => addr.to_string(),
        SocketAddr::V6(addr) => format!("[{}]:{}", addr.ip(), addr.port()),
    }
}

/// Address configured for persistent preconfirmation peer dialing.
#[derive(Clone, Debug, Eq, PartialEq)]
struct ConfiguredPeerAddr {
    /// Dialable libp2p multiaddr.
    addr: Multiaddr,
    /// Human-readable source label used in logs and metrics.
    source: &'static str,
}

impl WhitelistNetwork {
    /// Spawn the whitelist preconfirmation network task.
    pub(crate) async fn spawn(
        chain_id: u64,
        cfg: NetworkConfig,
        operator_set: SharedOperatorSet,
    ) -> Result<Self> {
        let local_key = cfg.local_key();
        let NetworkConfig {
            enable_tcp,
            listen_addr,
            advertise_addr,
            bootnodes,
            pre_dial_peers,
            enable_discovery,
            discovery_listen,
            preconfirmation_p2p_key: _,
        } = cfg;

        let peer_id = local_key.public().to_peer_id();
        let advertised_enode = advertised_enode_url(
            &local_key,
            enable_tcp,
            listen_addr,
            advertise_addr,
            enable_discovery.then_some(discovery_listen),
        );
        info!(
            %peer_id,
            advertised_enode = advertised_enode.as_deref().unwrap_or("unavailable"),
            tcp_enabled = enable_tcp,
            listen_addr = %listen_addr,
            advertise_addr = advertise_addr.map(|addr| addr.to_string()).as_deref().unwrap_or("unset"),
            "whitelist preconfirmation local P2P identity"
        );

        let topics = Topics::new(chain_id);
        let behaviour = build_behaviour(&local_key, &topics)?;
        let mut swarm = build_swarm(&local_key, peer_id, behaviour)?;
        configure_listen_addr(&mut swarm, enable_tcp, listen_addr)?;

        let bootnodes = classify_bootnodes(bootnodes);
        let configured_peer_addrs =
            dial_initial_peers(&mut swarm, pre_dial_peers, bootnodes.dial_addrs);
        let discovery_rx =
            init_discovery(enable_discovery, discovery_listen, bootnodes.discovery_enrs).await;

        let (event_tx, event_rx) = mpsc::channel(1024);
        let (command_tx, command_rx) = mpsc::channel(512);

        let inbound_validation_state = GossipsubInboundState::new(chain_id, operator_set);

        let runtime = NetworkRuntime {
            swarm,
            topics,
            event_tx,
            command_rx,
            discovery_rx,
            discovered_dial_addrs: HashSet::new(),
            connected_configured_addrs: HashSet::new(),
            configured_peer_addrs,
            peer_retry_interval: delayed_interval(CONFIGURED_PEER_RETRY_INTERVAL),
            peer_status_log_interval: delayed_interval(PEER_STATUS_LOG_INTERVAL),
            inbound_validation_state,
            peer_id_for_events: peer_id,
        };

        let handle = tokio::spawn(async move { runtime.run().await });

        Ok(Self { peer_id, event_rx, command_tx, handle })
    }
}

/// Build a libp2p swarm with DNS-over-TCP transport, noise auth, and yamux multiplexing.
fn build_swarm(
    local_key: &identity::Keypair,
    peer_id: PeerId,
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

    Ok(Swarm::new(transport, behaviour, peer_id, libp2p::swarm::Config::with_tokio_executor()))
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

/// Create an interval whose first tick fires after one full period.
fn delayed_interval(period: Duration) -> Interval {
    let mut interval = tokio::time::interval_at(TokioInstant::now() + period, period);
    interval.set_missed_tick_behavior(MissedTickBehavior::Delay);
    interval
}

/// Extract the terminal peer id from a libp2p multiaddr when present.
fn peer_id_from_addr(addr: &Multiaddr) -> Option<PeerId> {
    addr.iter()
        .filter_map(|protocol| match protocol {
            Protocol::P2p(peer_id) => Some(peer_id),
            _ => None,
        })
        .last()
}

/// Dial a configured peer address unless it is already connected by peer id.
fn dial_configured_peer(
    swarm: &mut Swarm<TaikoBehaviour>,
    connected_configured_addrs: &HashSet<Multiaddr>,
    peer: &ConfiguredPeerAddr,
    reason: &'static str,
) {
    if connected_configured_addrs.contains(&peer.addr) {
        WhitelistPreconfirmationDriverMetrics::inc_network_dial_attempt(
            peer.source,
            "skipped_connected_addr",
        );
        debug!(addr = %peer.addr, source = peer.source, reason, "configured peer address already connected");
        return;
    }

    if let Some(peer_id) = peer_id_from_addr(&peer.addr) &&
        swarm.is_connected(&peer_id)
    {
        WhitelistPreconfirmationDriverMetrics::inc_network_dial_attempt(
            peer.source,
            "skipped_connected",
        );
        debug!(addr = %peer.addr, source = peer.source, %peer_id, reason, "configured peer already connected");
        return;
    }

    dial_addr(swarm, peer.addr.clone(), peer.source, reason);
}

/// Dial one discovered peer address at most once.
fn dial_discovered_peer(
    swarm: &mut Swarm<TaikoBehaviour>,
    discovered_dial_addrs: &mut HashSet<Multiaddr>,
    addr: Multiaddr,
) {
    if !discovered_dial_addrs.insert(addr.clone()) {
        debug!(%addr, source = "discovery", "already dialed discovered address; skipping");
        return;
    }

    dial_addr(swarm, addr, "discovery", "discovered");
}

/// Dial a peer address and record the immediate swarm result.
fn dial_addr(
    swarm: &mut Swarm<TaikoBehaviour>,
    addr: Multiaddr,
    source: &str,
    reason: &'static str,
) {
    if let Err(err) = swarm.dial(addr.clone()) {
        WhitelistPreconfirmationDriverMetrics::inc_network_dial_attempt(source, "failed");
        if matches!(err, DialError::DialPeerConditionFalse(_)) {
            debug!(%addr, source, reason, error = %err, "configured peer dial skipped by swarm");
        } else {
            warn!(%addr, source, reason, error = %err, "failed to dial address");
        }
    } else {
        WhitelistPreconfirmationDriverMetrics::inc_network_dial_attempt(source, "ok");
    }
}

/// Dial configured static peers and bootnode multiaddrs, returning them for retries.
fn dial_initial_peers(
    swarm: &mut Swarm<TaikoBehaviour>,
    pre_dial_peers: Vec<Multiaddr>,
    bootnode_dial_addrs: Vec<Multiaddr>,
) -> Vec<ConfiguredPeerAddr> {
    let mut seen = HashSet::new();
    let mut configured_peers = Vec::new();

    for peer in pre_dial_peers {
        push_configured_peer(&mut configured_peers, &mut seen, peer, "static peer");
    }

    for addr in bootnode_dial_addrs {
        push_configured_peer(&mut configured_peers, &mut seen, addr, "bootnode");
    }

    for peer in &configured_peers {
        dial_configured_peer(swarm, &HashSet::new(), peer, "startup");
    }

    configured_peers
}

/// Add a configured peer once, preserving the first source label seen.
fn push_configured_peer(
    configured_peers: &mut Vec<ConfiguredPeerAddr>,
    seen: &mut HashSet<Multiaddr>,
    addr: Multiaddr,
    source: &'static str,
) {
    if !seen.insert(addr.clone()) {
        debug!(%addr, source, "duplicate configured peer address; skipping");
        return;
    }

    configured_peers.push(ConfiguredPeerAddr { addr, source });
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
    /// Set of discovered addresses already dialed to avoid discovery churn.
    discovered_dial_addrs: HashSet<Multiaddr>,
    /// Connected configured addresses used to prevent duplicate direct dials.
    connected_configured_addrs: HashSet<Multiaddr>,
    /// Configured static peer and bootnode addresses retried for connectivity.
    configured_peer_addrs: Vec<ConfiguredPeerAddr>,
    /// Periodic timer for retrying configured peer dials.
    peer_retry_interval: Interval,
    /// Periodic timer for logging peer connectivity status.
    peer_status_log_interval: Interval,
    /// Inbound validation and dedupe state for gossipsub messages.
    inbound_validation_state: GossipsubInboundState,
    /// Local peer id used to ignore self-propagated gossip.
    peer_id_for_events: PeerId,
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
                        self.handle_command(command);
                        Ok(true)
                    },
                }
            }
            maybe_addr = recv_discovered_multiaddr(&mut self.discovery_rx), if has_discovery => {
                self.handle_discovery_multiaddr(maybe_addr);
                Ok(true)
            }
            _ = self.peer_retry_interval.tick() => {
                self.retry_configured_peers();
                Ok(true)
            }
            _ = self.peer_status_log_interval.tick() => {
                self.log_peer_status();
                Ok(true)
            }
            event = self.swarm.select_next_some() => {
                self.handle_swarm_event(event).await?;
                Ok(true)
            }
        }
    }

    /// Execute one outbound network command.
    fn handle_command(&mut self, command: NetworkCommand) {
        match command {
            NetworkCommand::PublishUnsafeRequest { hash } => {
                self.publish_unsafe_request(hash);
            }
            NetworkCommand::PublishUnsafeResponse { envelope } => {
                self.publish_unsafe_response(envelope);
            }
            NetworkCommand::PublishUnsafePayload { signature, envelope } => {
                self.publish_unsafe_payload(signature, envelope);
            }
            NetworkCommand::PublishEndOfSequencingRequest { epoch } => {
                self.publish_end_of_sequencing_request(epoch);
            }
            NetworkCommand::Shutdown => unreachable!("handled in run_once"),
        }
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

    /// Publish a `preconfBlocks` message.
    fn publish_unsafe_payload(
        &mut self,
        signature: [u8; 65],
        envelope: Arc<WhitelistExecutionPayloadEnvelope>,
    ) {
        let hash = envelope.execution_payload.block_hash;
        self.encode_and_publish(
            encode_unsafe_payload_message(&signature, &envelope),
            self.topics.preconf_blocks.clone(),
            "preconf_blocks",
            &format!("{hash}"),
        );
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
                WhitelistPreconfirmationDriverMetrics::inc_network_outbound_publish(
                    topic_label,
                    "encode_failed",
                );
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
            WhitelistPreconfirmationDriverMetrics::inc_network_outbound_publish(
                topic_label,
                "publish_failed",
            );
            warn!(
                context,
                error = %err,
                "failed to publish whitelist preconfirmation message"
            );
        } else {
            WhitelistPreconfirmationDriverMetrics::inc_network_outbound_publish(
                topic_label,
                "published",
            );
        }
    }

    /// Handle one discovery result by dialing or disabling discovery when closed.
    fn handle_discovery_multiaddr(&mut self, maybe_addr: Option<Multiaddr>) {
        match maybe_addr {
            Some(addr) => {
                dial_discovered_peer(&mut self.swarm, &mut self.discovered_dial_addrs, addr);
            }
            None => {
                self.discovery_rx = None;
                debug!("whitelist preconfirmation discovery stream closed");
            }
        }
    }

    /// Retry all configured bootnode/static peer addresses.
    fn retry_configured_peers(&mut self) {
        if self.configured_peer_addrs.is_empty() {
            return;
        }

        for peer in &self.configured_peer_addrs {
            dial_configured_peer(&mut self.swarm, &self.connected_configured_addrs, peer, "retry");
        }
    }

    /// Log connected and gossipsub mesh peers for preconfirmation topics.
    fn log_peer_status(&mut self) {
        let connected_peers = self.swarm.connected_peers().copied().collect::<Vec<_>>();
        let listeners = self.swarm.listeners().map(ToString::to_string).collect::<Vec<_>>();
        let behaviour = self.swarm.behaviour();
        let preconf_blocks_mesh_peers =
            behaviour.gossipsub.mesh_peers(&self.topics.preconf_blocks.hash()).count();
        let request_mesh_peers =
            behaviour.gossipsub.mesh_peers(&self.topics.preconf_request.hash()).count();
        let response_mesh_peers =
            behaviour.gossipsub.mesh_peers(&self.topics.preconf_response.hash()).count();
        let eos_request_mesh_peers =
            behaviour.gossipsub.mesh_peers(&self.topics.eos_request.hash()).count();
        let gossip_topic_peers = behaviour.gossipsub.all_peers().count();

        info!(
            connected_peer_count = connected_peers.len(),
            connected_peers = %format_peer_ids(&connected_peers),
            configured_peer_count = self.configured_peer_addrs.len(),
            connected_configured_addr_count = self.connected_configured_addrs.len(),
            discovered_peer_count = self.discovered_dial_addrs.len(),
            gossip_topic_peer_count = gossip_topic_peers,
            preconf_blocks_mesh_peers,
            request_mesh_peers,
            response_mesh_peers,
            eos_request_mesh_peers,
            listeners = %listeners.join(","),
            "whitelist preconfirmation peer status"
        );
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
            libp2p::swarm::SwarmEvent::ConnectionEstablished { peer_id, endpoint, .. } => {
                self.track_configured_connection(endpoint.get_remote_address());
                debug!(%peer_id, remote_addr = %endpoint.get_remote_address(), "peer connected");
            }
            libp2p::swarm::SwarmEvent::ConnectionClosed {
                peer_id,
                endpoint,
                num_established,
                ..
            } => {
                if num_established == 0 {
                    self.connected_configured_addrs.remove(endpoint.get_remote_address());
                }
                debug!(%peer_id, remote_addr = %endpoint.get_remote_address(), "peer disconnected");
            }
            libp2p::swarm::SwarmEvent::Behaviour(BehaviourEvent::Ignored) => {}
            other => {
                debug!(event = ?other, "ignored swarm event");
            }
        }
        Ok(())
    }

    /// Track a newly connected configured address for duplicate-dial suppression.
    fn track_configured_connection(&mut self, remote_addr: &Multiaddr) {
        if self.configured_peer_addrs.iter().any(|peer| &peer.addr == remote_addr) {
            self.connected_configured_addrs.insert(remote_addr.clone());
        }
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

        if from == self.peer_id_for_events {
            debug!(peer = %from, topic = %topic, "ignoring self-propagated whitelist preconfirmation gossip");
            let _ = self.swarm.behaviour_mut().gossipsub.report_message_validation_result(
                &message_id,
                &from,
                gossipsub::MessageAcceptance::Ignore,
            );
            return Ok(());
        }

        if *topic == self.topics.preconf_blocks.hash() {
            let acceptance = match decode_unsafe_payload_signature(&message.data)
                .and_then(|(sig, bytes)| decode_envelope_ssz(&bytes).map(|env| (sig, bytes, env)))
            {
                Ok((wire_signature, payload_bytes, envelope)) => {
                    let payload = DecodedUnsafePayload { wire_signature, payload_bytes, envelope };
                    let acceptance =
                        self.inbound_validation_state.validate_preconf_blocks(&payload);

                    if matches!(acceptance, gossipsub::MessageAcceptance::Accept) {
                        log_inbound_envelope(
                            from,
                            &payload.envelope,
                            "📥 New preconfirmation block gossip",
                        );
                        if let Err(err) = forward_event(
                            &self.event_tx,
                            NetworkEvent::UnsafePayload { from, payload },
                        )
                        .await
                        {
                            // If forwarding to importer fails, reject to avoid silently
                            // accepting data that local consumers could not process.
                            self.report_validation(
                                &message_id,
                                from,
                                gossipsub::MessageAcceptance::Reject,
                            );
                            return Err(err);
                        }
                    }

                    acceptance
                }
                Err(_) => {
                    self.record_decode_failed("preconf_blocks", &message_id, from);
                    return Ok(());
                }
            };

            self.record_inbound_and_report("preconf_blocks", acceptance, &message_id, from);
            return Ok(());
        }

        if *topic == self.topics.preconf_response.hash() {
            let acceptance = match decode_unsafe_response_message(&message.data) {
                Ok(envelope) => {
                    let acceptance = self.inbound_validation_state.validate_response(&envelope);
                    if matches!(acceptance, gossipsub::MessageAcceptance::Accept) {
                        log_inbound_envelope(
                            from,
                            &envelope,
                            "📥 New preconfirmation block response gossip",
                        );
                        if let Err(err) = forward_event(
                            &self.event_tx,
                            NetworkEvent::UnsafeResponse { from, envelope },
                        )
                        .await
                        {
                            self.report_validation(
                                &message_id,
                                from,
                                gossipsub::MessageAcceptance::Reject,
                            );
                            return Err(err);
                        }
                    }

                    acceptance
                }
                Err(_) => {
                    self.record_decode_failed("response_preconf_blocks", &message_id, from);
                    return Ok(());
                }
            };

            self.record_inbound_and_report(
                "response_preconf_blocks",
                acceptance,
                &message_id,
                from,
            );
            return Ok(());
        }

        if *topic == self.topics.preconf_request.hash() {
            let Some(hash) = decode_request_hash_exact(&message.data) else {
                self.record_decode_failed("request_preconf_blocks", &message_id, from);
                return Ok(());
            };

            let acceptance = self.inbound_validation_state.validate_request(from, now);
            if matches!(acceptance, gossipsub::MessageAcceptance::Accept) {
                info!(
                    peer = %from,
                    requested_block_hash = %hash,
                    "📥 New preconfirmation block request gossip"
                );
                // Requests are relayed only after inbound dedupe/rate checks pass.
                forward_event(&self.event_tx, NetworkEvent::UnsafeRequest { from, hash }).await?;
            }

            self.record_inbound_and_report("request_preconf_blocks", acceptance, &message_id, from);
            return Ok(());
        }

        if *topic == self.topics.eos_request.hash() {
            let Some(epoch) = decode_eos_epoch_exact(&message.data) else {
                self.record_decode_failed("request_eos_preconf_blocks", &message_id, from);
                return Ok(());
            };

            let acceptance = self.inbound_validation_state.validate_eos_request(from, epoch, now);
            if matches!(acceptance, gossipsub::MessageAcceptance::Accept) {
                info!(
                    peer = %from,
                    epoch,
                    "📥 New end-of-sequencing preconfirmation request gossip"
                );
                // EOS requests follow the same acceptance gate as preconf requests.
                forward_event(&self.event_tx, NetworkEvent::EndOfSequencingRequest { from, epoch })
                    .await?;
            }

            self.record_inbound_and_report(
                "request_eos_preconf_blocks",
                acceptance,
                &message_id,
                from,
            );
        }

        Ok(())
    }

    /// Report a gossipsub validation decision so mesh scoring stays aligned with
    /// local validation.
    fn report_validation(
        &mut self,
        message_id: &gossipsub::MessageId,
        from: PeerId,
        acceptance: gossipsub::MessageAcceptance,
    ) {
        let _ = self
            .swarm
            .behaviour_mut()
            .gossipsub
            .report_message_validation_result(message_id, &from, acceptance);
    }

    /// Record an inbound-message metric for `topic_label` (using the acceptance's
    /// label) and report the validation decision in one step.
    fn record_inbound_and_report(
        &mut self,
        topic_label: &'static str,
        acceptance: gossipsub::MessageAcceptance,
        message_id: &gossipsub::MessageId,
        from: PeerId,
    ) {
        self.record_inbound_and_report_labeled(
            topic_label,
            acceptance_label(&acceptance),
            acceptance,
            message_id,
            from,
        );
    }

    /// Record an inbound-message metric for `topic_label` using an explicit
    /// `inbound_label`, then report `acceptance` to gossipsub.
    ///
    /// Used for decode failures, where the metric label (`"decode_failed"`) differs
    /// from the reported acceptance (`Reject`).
    fn record_inbound_and_report_labeled(
        &mut self,
        topic_label: &'static str,
        inbound_label: &str,
        acceptance: gossipsub::MessageAcceptance,
        message_id: &gossipsub::MessageId,
        from: PeerId,
    ) {
        WhitelistPreconfirmationDriverMetrics::inc_network_inbound_message(
            topic_label,
            inbound_label,
        );
        self.report_validation(message_id, from, acceptance);
    }

    /// Record a `decode_failed` inbound metric for `topic_label` and report `Reject`.
    fn record_decode_failed(
        &mut self,
        topic_label: &'static str,
        message_id: &gossipsub::MessageId,
        from: PeerId,
    ) {
        self.record_inbound_and_report_labeled(
            topic_label,
            "decode_failed",
            gossipsub::MessageAcceptance::Reject,
            message_id,
            from,
        );
    }
}

/// Format peer ids into a compact comma-separated log value.
fn format_peer_ids(peers: &[PeerId]) -> String {
    peers.iter().map(ToString::to_string).collect::<Vec<_>>().join(",")
}

#[cfg(test)]
mod tests {
    use std::net::{Ipv4Addr, Ipv6Addr};

    use alloy_primitives::hex;

    use super::*;

    #[test]
    fn peer_id_from_addr_returns_terminal_peer_id() {
        let relay_peer = PeerId::random();
        let target_peer = PeerId::random();
        let addr = Multiaddr::empty()
            .with(Protocol::Ip4(Ipv4Addr::LOCALHOST))
            .with(Protocol::Tcp(30303))
            .with(Protocol::P2p(relay_peer))
            .with(Protocol::P2pCircuit)
            .with(Protocol::P2p(target_peer));

        assert_eq!(peer_id_from_addr(&addr), Some(target_peer));
    }

    #[test]
    fn peer_id_from_addr_returns_none_without_peer_id() {
        let addr =
            Multiaddr::empty().with(Protocol::Ip4(Ipv4Addr::LOCALHOST)).with(Protocol::Tcp(30303));

        assert_eq!(peer_id_from_addr(&addr), None);
    }

    #[test]
    fn network_config_local_key_uses_raw_secp256k1_private_key() {
        let raw_key = "1875af8dad47674dd6897fb7bcdc1ba872144914082e02dace98dcf2ba16aa8d";
        let cfg = NetworkConfig {
            preconfirmation_p2p_key: NetworkConfig::parse_preconfirmation_p2p_priv_raw(Some(
                raw_key,
            ))
            .expect("raw key should parse"),
            ..Default::default()
        };

        let local_key = cfg.local_key();
        let expected_key = identity::Keypair::from(identity::secp256k1::Keypair::from(
            identity::secp256k1::SecretKey::try_from_bytes(
                hex::decode(raw_key).expect("valid hex"),
            )
            .expect("valid secp256k1 key"),
        ));

        assert_eq!(local_key.public().to_peer_id(), expected_key.public().to_peer_id());
    }

    #[test]
    fn network_config_local_key_accepts_hex_prefix() {
        let raw_key = "0x1875af8dad47674dd6897fb7bcdc1ba872144914082e02dace98dcf2ba16aa8d";
        NetworkConfig::parse_preconfirmation_p2p_priv_raw(Some(raw_key))
            .expect("raw key with prefix should parse");
    }

    #[test]
    fn network_config_local_key_rejects_invalid_raw_key() {
        let err = NetworkConfig::parse_preconfirmation_p2p_priv_raw(Some("not-hex"))
            .expect_err("invalid raw key should fail");

        assert!(
            matches!(err, WhitelistPreconfirmationDriverError::P2p(message) if message.contains("preconfirmation.p2p-priv-raw"))
        );
    }

    #[test]
    fn network_config_local_key_rejects_wrong_raw_key_length() {
        let raw_key = "01".repeat(31);

        let err = NetworkConfig::parse_preconfirmation_p2p_priv_raw(Some(&raw_key))
            .expect_err("short raw key should fail");

        assert!(
            matches!(err, WhitelistPreconfirmationDriverError::P2p(message) if message.contains("expected 32 bytes"))
        );
    }

    #[test]
    fn network_config_debug_does_not_include_raw_key() {
        let raw_key = "1875af8dad47674dd6897fb7bcdc1ba872144914082e02dace98dcf2ba16aa8d";
        let cfg = NetworkConfig {
            preconfirmation_p2p_key: NetworkConfig::parse_preconfirmation_p2p_priv_raw(Some(
                raw_key,
            ))
            .expect("raw key should parse"),
            ..Default::default()
        };

        let debug = format!("{cfg:?}");

        assert!(!debug.contains(raw_key));
    }

    #[test]
    fn advertised_enode_url_uses_secp256k1_public_key() {
        let raw_key = "1875af8dad47674dd6897fb7bcdc1ba872144914082e02dace98dcf2ba16aa8d";
        let local_key = NetworkConfig::parse_preconfirmation_p2p_priv_raw(Some(raw_key))
            .expect("raw key should parse")
            .expect("key should be configured");
        let listen_addr = SocketAddr::from((Ipv4Addr::LOCALHOST, 30303));

        let enode = advertised_enode_url(&local_key, true, listen_addr, None, None)
            .expect("secp key has enode");
        let public_key = enode
            .strip_prefix("enode://")
            .and_then(|rest| rest.split_once('@'))
            .map(|(public_key, _)| public_key)
            .expect("enode should include public key");

        assert!(enode.ends_with("@127.0.0.1:30303"));
        assert_eq!(public_key.len(), 128);
        assert!(!public_key.starts_with("04"));
    }

    #[test]
    fn advertised_enode_url_uses_advertise_addr_when_configured() {
        let raw_key = "1875af8dad47674dd6897fb7bcdc1ba872144914082e02dace98dcf2ba16aa8d";
        let local_key = NetworkConfig::parse_preconfirmation_p2p_priv_raw(Some(raw_key))
            .expect("raw key should parse")
            .expect("key should be configured");
        let listen_addr = SocketAddr::from((Ipv4Addr::UNSPECIFIED, 30303));
        let advertise_addr = SocketAddr::from(([203, 0, 113, 10], 30303));

        let enode = advertised_enode_url(&local_key, true, listen_addr, Some(advertise_addr), None)
            .expect("secp key has enode");

        assert!(enode.ends_with("@203.0.113.10:30303"));
    }

    #[test]
    fn advertised_enode_url_brackets_ipv6_advertise_addr() {
        let raw_key = "1875af8dad47674dd6897fb7bcdc1ba872144914082e02dace98dcf2ba16aa8d";
        let local_key = NetworkConfig::parse_preconfirmation_p2p_priv_raw(Some(raw_key))
            .expect("raw key should parse")
            .expect("key should be configured");
        let listen_addr = SocketAddr::from((Ipv6Addr::UNSPECIFIED, 30303));
        let advertise_addr = SocketAddr::from((Ipv6Addr::LOCALHOST, 30303));

        let enode = advertised_enode_url(&local_key, true, listen_addr, Some(advertise_addr), None)
            .expect("secp key has enode");

        assert!(enode.ends_with("@[::1]:30303"));
    }

    #[test]
    fn advertised_enode_url_appends_discovery_port_when_different_from_tcp_port() {
        let raw_key = "1875af8dad47674dd6897fb7bcdc1ba872144914082e02dace98dcf2ba16aa8d";
        let local_key = NetworkConfig::parse_preconfirmation_p2p_priv_raw(Some(raw_key))
            .expect("raw key should parse")
            .expect("key should be configured");
        let listen_addr = SocketAddr::from((Ipv4Addr::UNSPECIFIED, 4001));
        let advertise_addr = SocketAddr::from(([34, 41, 203, 88], 4001));
        let discovery_listen = SocketAddr::from((Ipv4Addr::UNSPECIFIED, 30304));

        let enode = advertised_enode_url(
            &local_key,
            true,
            listen_addr,
            Some(advertise_addr),
            Some(discovery_listen),
        )
        .expect("secp key has enode");

        assert!(enode.ends_with("@34.41.203.88:4001?discport=30304"));
    }

    #[test]
    fn advertised_enode_url_is_unavailable_for_non_secp256k1_key() {
        let local_key = identity::Keypair::generate_ed25519();
        let listen_addr = SocketAddr::from((Ipv4Addr::LOCALHOST, 30303));

        assert_eq!(advertised_enode_url(&local_key, true, listen_addr, None, None), None);
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

/// Emit an entry log for an inbound gossip envelope.
fn log_inbound_envelope(
    from: PeerId,
    envelope: &WhitelistExecutionPayloadEnvelope,
    message: &'static str,
) {
    let execution_payload = &envelope.execution_payload;
    info!(
        peer = %from,
        block_id = execution_payload.block_number,
        block_hash = %execution_payload.block_hash,
        coinbase = %execution_payload.fee_recipient,
        timestamp = execution_payload.timestamp,
        gas_limit = execution_payload.gas_limit,
        gas_used = execution_payload.gas_used,
        base_fee_per_gas = %execution_payload.base_fee_per_gas,
        extra_data = %alloy_primitives::hex::encode(&execution_payload.extra_data),
        parent_hash = %execution_payload.parent_hash,
        end_of_sequencing = envelope.end_of_sequencing.unwrap_or(false),
        is_forced_inclusion = envelope.is_forced_inclusion.unwrap_or(false),
        "{message}"
    );
}

/// Forward one decoded event to the importer with backpressure.
pub(super) async fn forward_event(
    event_tx: &mpsc::Sender<NetworkEvent>,
    event: NetworkEvent,
) -> Result<()> {
    event_tx.send(event).await.map_err(|err| {
        WhitelistPreconfirmationDriverMetrics::inc_network_forward_failure();
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

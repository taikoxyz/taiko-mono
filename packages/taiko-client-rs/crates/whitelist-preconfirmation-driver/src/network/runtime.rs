//! Network driver for the whitelist preconfirmation gossipsub stack.
//!
//! Contains type definitions, swarm bootstrap, transport helpers, the network
//! runtime event loop, gossipsub event handling, and decode/metrics helpers.

use std::{
    collections::{HashMap, HashSet},
    net::SocketAddr,
    sync::Arc,
    time::{Duration, Instant},
};

use alloy_primitives::B256;
use futures::StreamExt;
use libp2p::{
    Multiaddr, PeerId, Swarm, Transport,
    core::upgrade,
    dns, gossipsub, identity,
    multiaddr::Protocol,
    noise,
    swarm::{ConnectionId, DialError, dial_opts::DialOpts},
    tcp, yamux,
};
use tokio::{
    sync::mpsc,
    task::JoinHandle,
    time::{Instant as TokioInstant, Interval, MissedTickBehavior},
};
use tracing::{debug, info, warn};

use kona_disc::Discv5Handler;
use kona_gossip::{ConnectionGate, ConnectionGater, GaterConfig};

use super::{
    behaviour::{BehaviourEvent, TaikoBehaviour, build_behaviour},
    discovery::{
        classify_bootnodes, discovered_candidate, parse_discovery_bootnodes, spawn_discovery,
    },
    handler::GossipsubInboundState,
    peer_manager::PeerWatermarks,
    topics::Topics,
};
use crate::{
    codec::{
        DecodedUnsafePayload, WhitelistExecutionPayloadEnvelope, decode_envelope_ssz,
        decode_unsafe_payload_signature, decode_unsafe_response_message,
        encode_unsafe_payload_message, encode_unsafe_request_message,
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

/// Default low-tide peer count, matching op-node's `p2p.peers.lo`: discovered peers are
/// dialed while the connection count is below this target.
pub const DEFAULT_PEERS_LO: usize = 20;

/// Default high-tide peer count, matching op-node's `p2p.peers.hi`: unprotected
/// distinct peers are softly pruned above this threshold.
pub const DEFAULT_PEERS_HI: usize = 30;

/// Maximum dials per discovered address within one dial period, matching kona-node's
/// `p2p.redial` default.
const DISCOVERED_PEER_REDIAL_THRESHOLD: u64 = 500;

/// Window after which a discovered address's dial count resets, matching kona-node's
/// `p2p.redial.period` default.
const DISCOVERED_PEER_DIAL_PERIOD: Duration = Duration::from_secs(60 * 60);

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
    /// TCP listen address.
    pub listen_addr: SocketAddr,
    /// Optional externally dialable TCP address advertised in the local enode URL.
    pub advertise_addr: Option<SocketAddr>,
    /// Bootnodes as ENR, enode URL, or multiaddr strings; dialable TCP entries are dialed
    /// directly, and ENR/enode entries additionally seed discv5 discovery.
    pub bootnodes: Vec<String>,
    /// Static peers to dial on startup.
    pub pre_dial_peers: Vec<Multiaddr>,
    /// Optional parsed secp256k1 keypair for the local P2P network identity.
    pub preconfirmation_p2p_key: Option<identity::Keypair>,
    /// UDP listen address for discv5 peer discovery; `None` disables discovery.
    pub discovery_listen: Option<SocketAddr>,
    /// Low-tide peer count: discovered candidates are dialed while below this target.
    pub peers_lo: usize,
    /// Soft pruning threshold for unprotected distinct peers; configured peers may exceed it.
    pub peers_hi: usize,
}

impl Default for NetworkConfig {
    fn default() -> Self {
        Self {
            listen_addr: SocketAddr::from(([0, 0, 0, 0], 9222)),
            advertise_addr: None,
            bootnodes: Vec::new(),
            pre_dial_peers: Vec::new(),
            preconfirmation_p2p_key: None,
            discovery_listen: None,
            peers_lo: DEFAULT_PEERS_LO,
            peers_hi: DEFAULT_PEERS_HI,
        }
    }
}

impl NetworkConfig {
    /// Validate peer watermarks and enabled discovery's advertised endpoints.
    ///
    /// Zero low tide disables discovery-driven dialing, but high tide must remain positive
    /// and no lower than low tide. Enabled discovery rejects zero ports, unspecified or
    /// multicast advertised IPs, and a listen/advertise IP-family mismatch: ENR
    /// auto-update is disabled, so the local record would otherwise permanently advertise
    /// an endpoint peers cannot reach.
    pub fn validate(&self) -> Result<()> {
        if self.peers_hi == 0 {
            return Err(WhitelistPreconfirmationDriverError::p2p(
                "--p2p.peers.hi must be greater than zero",
            ));
        }
        if self.peers_lo > self.peers_hi {
            return Err(WhitelistPreconfirmationDriverError::p2p(format!(
                "--p2p.peers.lo ({}) must not exceed --p2p.peers.hi ({})",
                self.peers_lo, self.peers_hi
            )));
        }
        if self.discovery_listen.is_some_and(|addr| addr.port() == 0) {
            return Err(WhitelistPreconfirmationDriverError::p2p(
                "--p2p.discovery.addr UDP port must be greater than zero when discovery is enabled",
            ));
        }
        if let Some(listen) = self.discovery_listen &&
            let Some(advertise) = self.advertise_addr
        {
            if advertise.port() == 0 {
                return Err(WhitelistPreconfirmationDriverError::p2p(
                    "--p2p.advertise.addr TCP port must be greater than zero when discovery is \
                     enabled: it is published in the local node record",
                ));
            }
            if advertise.ip().is_unspecified() || advertise.ip().is_multicast() {
                return Err(WhitelistPreconfirmationDriverError::p2p(
                    "--p2p.advertise.addr must be a routable unicast IP when discovery is \
                     enabled: it is published in the local node record",
                ));
            }
            if advertise.is_ipv4() != listen.is_ipv4() {
                return Err(WhitelistPreconfirmationDriverError::p2p(
                    "--p2p.advertise.addr and --p2p.discovery.addr must use the same IP family: \
                     dual-stack discovery is not supported",
                ));
            }
        }

        Ok(())
    }

    /// Parse an optional raw secp256k1 private key for the local P2P network identity.
    pub fn parse_preconfirmation_p2p_priv_raw(
        raw_key: Option<&str>,
    ) -> Result<Option<identity::Keypair>> {
        raw_key.map(parse_preconfirmation_p2p_priv_raw).transpose()
    }

    /// Build the local libp2p identity key, falling back to an ephemeral key.
    ///
    /// The fallback is secp256k1 so the identity can double as the discv5 ENR signing
    /// key: Go peers derive the libp2p peer id from the ENR key when dialing, so
    /// discovery only works when both are the same key.
    fn local_key(&self) -> identity::Keypair {
        self.preconfirmation_p2p_key.clone().unwrap_or_else(identity::Keypair::generate_secp256k1)
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
    listen_addr: SocketAddr,
    advertise_addr: Option<SocketAddr>,
) -> Option<String> {
    let secp256k1_key = local_key.clone().try_into_secp256k1().ok()?;
    let uncompressed_public_key = secp256k1_key.public().to_bytes_uncompressed();
    let advertised_addr = advertise_addr.unwrap_or(listen_addr);
    Some(format!(
        "enode://{}@{}",
        alloy_primitives::hex::encode(&uncompressed_public_key[1..]),
        enode_endpoint(advertised_addr)
    ))
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
    pub(crate) fn spawn(
        chain_id: u64,
        cfg: NetworkConfig,
        operator_set: SharedOperatorSet,
    ) -> Result<Self> {
        cfg.validate()?;
        let local_key = cfg.local_key();
        let NetworkConfig {
            listen_addr,
            advertise_addr,
            bootnodes,
            pre_dial_peers,
            preconfirmation_p2p_key: _,
            discovery_listen,
            peers_lo,
            peers_hi,
        } = cfg;

        let peer_id = local_key.public().to_peer_id();
        let advertised_enode = advertised_enode_url(&local_key, listen_addr, advertise_addr);
        info!(
            %peer_id,
            advertised_enode = advertised_enode.as_deref().unwrap_or("unavailable"),
            listen_addr = %listen_addr,
            advertise_addr = advertise_addr.map(|addr| addr.to_string()).as_deref().unwrap_or("unset"),
            "whitelist preconfirmation local P2P identity"
        );

        let topics = Topics::new(chain_id);
        let behaviour = build_behaviour(&local_key, &topics)?;
        let mut swarm = build_swarm(&local_key, peer_id, behaviour)?;
        configure_listen_addr(&mut swarm, listen_addr)?;

        let bootnode_dial_addrs = classify_bootnodes(&bootnodes);
        let configured_peer_addrs =
            dial_initial_peers(&mut swarm, pre_dial_peers, bootnode_dial_addrs);
        let configured_peer_ids = configured_peer_ids(&configured_peer_addrs);
        let peer_watermarks =
            PeerWatermarks::with_protected(peers_hi, configured_peer_ids.iter().copied());

        let (discovery_handle, discovery_rx) =
            start_discovery(&local_key, chain_id, discovery_listen, advertise_addr, &bootnodes);

        let (event_tx, event_rx) = mpsc::channel(1024);
        let (command_tx, command_rx) = mpsc::channel(512);

        let inbound_validation_state = GossipsubInboundState::new(chain_id, operator_set);

        let runtime = NetworkRuntime {
            swarm,
            topics,
            event_tx,
            command_rx,
            connected_configured_addrs: HashSet::new(),
            failing_configured_addrs: HashSet::new(),
            configured_peer_addrs,
            configured_peer_ids,
            peer_retry_interval: delayed_interval(CONFIGURED_PEER_RETRY_INTERVAL),
            peer_status_log_interval: delayed_interval(PEER_STATUS_LOG_INTERVAL),
            inbound_validation_state,
            peer_id_for_events: peer_id,
            _discovery_handle: discovery_handle,
            discovery_rx,
            gater: ConnectionGater::new(GaterConfig {
                peer_redialing: Some(DISCOVERED_PEER_REDIAL_THRESHOLD),
                dial_period: DISCOVERED_PEER_DIAL_PERIOD,
            }),
            discovered_dials: HashMap::new(),
            peer_watermarks,
            peers_lo,
            peers_hi,
        };

        let handle = tokio::spawn(async move { runtime.run().await });

        Ok(Self { peer_id, event_rx, command_tx, handle })
    }
}

/// Start discv5 discovery when it is enabled and advertisable.
///
/// Discovery needs a dialable advertised endpoint for the local ENR; without
/// `--p2p.advertise.addr` the node would publish an undialable record, so discovery is
/// skipped with a warning. Failures to start are downgraded to warnings as well: the
/// configured-peer backbone keeps the node connected without discovery.
fn start_discovery(
    local_key: &identity::Keypair,
    chain_id: u64,
    discovery_listen: Option<SocketAddr>,
    advertise_addr: Option<SocketAddr>,
    bootnodes: &[String],
) -> (Option<Discv5Handler>, Option<mpsc::Receiver<discv5::Enr>>) {
    let Some(listen) = discovery_listen else {
        return (None, None);
    };
    let Some(advertise) = advertise_addr else {
        warn!(
            "discv5 discovery requires --p2p.advertise.addr for a dialable node record; \
             discovery disabled"
        );
        return (None, None);
    };

    match spawn_discovery(
        local_key,
        chain_id,
        listen,
        advertise,
        parse_discovery_bootnodes(bootnodes),
    ) {
        Ok((handle, rx)) => {
            info!(
                %listen,
                %advertise,
                chain_id,
                "discv5 peer discovery started"
            );
            (Some(handle), Some(rx))
        }
        Err(err) => {
            warn!(error = %err, "failed to start discv5 discovery; continuing without it");
            (None, None)
        }
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

/// Configure the TCP listen address.
fn configure_listen_addr(swarm: &mut Swarm<TaikoBehaviour>, listen_addr: SocketAddr) -> Result<()> {
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
    match addr.iter().last() {
        Some(Protocol::P2p(peer_id)) => Some(peer_id),
        _ => None,
    }
}

/// Collect configured peer identities pinned by terminal `/p2p/<PeerId>` components.
fn configured_peer_ids(configured_peer_addrs: &[ConfiguredPeerAddr]) -> HashSet<PeerId> {
    configured_peer_addrs.iter().filter_map(|peer| peer_id_from_addr(&peer.addr)).collect()
}

/// Resolve the configured source label for a pinned peer identity, if any.
fn configured_source_for_peer_id(
    configured_peer_addrs: &[ConfiguredPeerAddr],
    peer_id: &PeerId,
) -> Option<&'static str> {
    configured_peer_addrs
        .iter()
        .find(|peer| peer_id_from_addr(&peer.addr).as_ref() == Some(peer_id))
        .map(|peer| peer.source)
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
    /// Connected configured addresses used to prevent duplicate direct dials.
    connected_configured_addrs: HashSet<Multiaddr>,
    /// Configured addresses whose latest dial attempt failed, for edge-triggered logging.
    failing_configured_addrs: HashSet<Multiaddr>,
    /// Configured static peer and bootnode addresses retried for connectivity.
    configured_peer_addrs: Vec<ConfiguredPeerAddr>,
    /// Configured identities known before connection events from terminal `/p2p` components.
    configured_peer_ids: HashSet<PeerId>,
    /// Periodic timer for retrying configured peer dials.
    peer_retry_interval: Interval,
    /// Periodic timer for logging peer connectivity status.
    peer_status_log_interval: Interval,
    /// Inbound validation and dedupe state for gossipsub messages.
    inbound_validation_state: GossipsubInboundState,
    /// Local peer id used to ignore self-propagated gossip.
    peer_id_for_events: PeerId,
    /// Keeps the discv5 service task alive; dropping the handle would close its request
    /// channel and make the driver loop spin on a closed receiver.
    _discovery_handle: Option<Discv5Handler>,
    /// Stream of chain-validated discovered ENRs; `None` when discovery is disabled.
    discovery_rx: Option<mpsc::Receiver<discv5::Enr>>,
    /// Dial gate for discovered peers: redial thresholds and duplicate-dial suppression.
    gater: ConnectionGater,
    /// In-flight discovered dials by connection id, so gate cleanup is scoped to the
    /// dial that actually established or failed rather than keyed by peer id (configured
    /// dials may target the same pinned peer concurrently).
    discovered_dials: HashMap<ConnectionId, PeerId>,
    /// Distinct-peer high-tide state, including configured-peer protection.
    peer_watermarks: PeerWatermarks,
    /// Low-tide peer target: discovered peers are dialed while below this count.
    peers_lo: usize,
    /// High-tide peer threshold used for pruning and status logs.
    peers_hi: usize,
}

impl NetworkRuntime {
    /// Run the network runtime loop until an explicit shutdown signal or channel closure.
    async fn run(mut self) -> Result<()> {
        while self.run_once().await? {}

        Ok(())
    }

    /// Process one input event from command, timer, or swarm.
    async fn run_once(&mut self) -> Result<bool> {
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
            _ = self.peer_retry_interval.tick() => {
                self.retry_configured_peers();
                Ok(true)
            }
            _ = self.peer_status_log_interval.tick() => {
                self.log_peer_status();
                Ok(true)
            }
            maybe_enr = recv_discovered(&mut self.discovery_rx) => {
                match maybe_enr {
                    Some(enr) => self.handle_discovered_enr(&enr),
                    None => {
                        warn!("discv5 discovery stream closed; continuing with configured peers only");
                        self.discovery_rx = None;
                    }
                }
                Ok(true)
            }
            event = self.swarm.select_next_some() => {
                self.handle_swarm_event(event).await?;
                Ok(true)
            }
        }
    }

    /// Handle one discovered ENR: dial it while below the low-tide peer target.
    ///
    /// Mirrors kona-node's discovery-to-gossip wiring: the connection gate suppresses
    /// duplicate dials and enforces redial thresholds. The runtime prunes excess distinct
    /// peers above high tide. The low-tide guard matches op-node's `connectGoal`: once
    /// enough peers are connected, discovered ENRs are dropped (discovery keeps emitting
    /// fresh ones, so nothing is lost).
    fn handle_discovered_enr(&mut self, enr: &discv5::Enr) {
        // Count in-flight discovered dials alongside established connections so an ENR
        // burst cannot schedule far past the low tide before handshakes settle. Only
        // discovered dials pass through the gate, so `current_dials` is exactly that
        // in-flight set (established and failed dials are removed as their events
        // arrive).
        let connected_or_dialing =
            self.swarm.connected_peers().count() + self.gater.current_dials.len();
        if connected_or_dialing >= self.peers_lo {
            WhitelistPreconfirmationDriverMetrics::inc_network_discovered_candidate("at_target");
            return;
        }

        let Some(addr) = discovered_candidate(enr, &self.peer_id_for_events) else {
            WhitelistPreconfirmationDriverMetrics::inc_network_discovered_candidate("undialable");
            return;
        };

        let Some(peer_id) = ConnectionGater::peer_id_from_addr(&addr) else {
            WhitelistPreconfirmationDriverMetrics::inc_network_discovered_candidate("undialable");
            return;
        };
        if self.swarm.is_connected(&peer_id) {
            WhitelistPreconfirmationDriverMetrics::inc_network_discovered_candidate(
                "already_connected",
            );
            return;
        }

        if let Err(dial_error) = self.gater.can_dial(&addr) {
            debug!(%addr, ?dial_error, "connection gate rejected discovered peer");
            WhitelistPreconfirmationDriverMetrics::inc_network_discovered_candidate("gated");
            return;
        }

        self.gater.dialing(&addr);
        // Capture the connection id up front so this dial's establishment or failure can
        // be matched back to the gate entry it opened.
        let dial_opts = DialOpts::from(addr.clone());
        let connection_id = dial_opts.connection_id();
        match self.swarm.dial(dial_opts) {
            Ok(()) => {
                debug!(%addr, %peer_id, "dialing discovered peer");
                self.gater.dialed(&addr);
                self.discovered_dials.insert(connection_id, peer_id);
                WhitelistPreconfirmationDriverMetrics::inc_network_discovered_candidate("dialed");
                WhitelistPreconfirmationDriverMetrics::inc_network_dial_attempt("discovered", "ok");
            }
            Err(err) => {
                debug!(%addr, error = %err, "failed to dial discovered peer");
                self.gater.remove_dial(&peer_id);
                WhitelistPreconfirmationDriverMetrics::inc_network_dial_attempt(
                    "discovered",
                    "failed",
                );
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

        WhitelistPreconfirmationDriverMetrics::set_network_peer_count(connected_peers.len());

        info!(
            connected_peer_count = connected_peers.len(),
            connected_peers = %format_peer_ids(&connected_peers),
            configured_peer_count = self.configured_peer_addrs.len(),
            connected_configured_addr_count = self.connected_configured_addrs.len(),
            discovery_enabled = self.discovery_rx.is_some(),
            peers_lo = self.peers_lo,
            peers_hi = self.peers_hi,
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
            libp2p::swarm::SwarmEvent::ConnectionEstablished {
                peer_id,
                connection_id,
                endpoint,
                ..
            } => {
                self.handle_connection_established(
                    peer_id,
                    connection_id,
                    endpoint.get_remote_address(),
                );
            }
            libp2p::swarm::SwarmEvent::ConnectionClosed {
                peer_id,
                endpoint,
                num_established,
                ..
            } => {
                if num_established == 0 {
                    self.connected_configured_addrs.remove(endpoint.get_remote_address());
                    self.peer_watermarks.disconnected(&peer_id);
                }
                WhitelistPreconfirmationDriverMetrics::set_network_peer_count(
                    self.swarm.connected_peers().count(),
                );
                debug!(%peer_id, remote_addr = %endpoint.get_remote_address(), "peer disconnected");
            }
            libp2p::swarm::SwarmEvent::OutgoingConnectionError {
                connection_id,
                peer_id,
                error,
                ..
            } => {
                self.handle_outgoing_connection_error(connection_id, peer_id, error);
            }
            libp2p::swarm::SwarmEvent::Behaviour(BehaviourEvent::Ignored) => {}
            other => {
                debug!(event = ?other, "ignored swarm event");
            }
        }
        Ok(())
    }

    /// Handle a newly established connection: clear in-flight dial state, protect and
    /// track configured peers, prune unprotected peers above high tide, and refresh the
    /// connected-peer gauge.
    fn handle_connection_established(
        &mut self,
        peer_id: PeerId,
        connection_id: ConnectionId,
        remote_addr: &Multiaddr,
    ) {
        // Scope gate cleanup to the discovered dial that produced this connection: an
        // unrelated configured or inbound connection for the same peer must not clear a
        // still-pending discovered dial's in-flight marker. This keeps `current_dials`
        // an accurate in-flight set for low-tide accounting; redial suppression of
        // connected peers is handled by the `is_connected` check before discovered
        // dials.
        if self.discovered_dials.remove(&connection_id).is_some() {
            self.gater.remove_dial(&peer_id);
        }
        let exact_configured_addr = self.track_configured_connection(remote_addr);
        if exact_configured_addr && self.failing_configured_addrs.remove(remote_addr) {
            info!(%peer_id, %remote_addr, "configured peer address recovered");
        }
        if exact_configured_addr || self.configured_peer_ids.contains(&peer_id) {
            self.peer_watermarks.protect(peer_id);
        }
        if let Some(peer_to_prune) =
            self.peer_watermarks.peer_to_prune(self.swarm.connected_peers().copied(), peer_id)
        {
            self.peer_watermarks.mark_disconnecting(peer_to_prune);
            if self.swarm.disconnect_peer_id(peer_to_prune).is_err() {
                self.peer_watermarks.disconnected(&peer_to_prune);
            } else {
                info!(
                    %peer_to_prune,
                    peers_hi = self.peers_hi,
                    "pruning unprotected peer above high tide"
                );
            }
        }
        WhitelistPreconfirmationDriverMetrics::set_network_peer_count(
            self.swarm.connected_peers().count(),
        );
        debug!(%peer_id, %remote_addr, "peer connected");
    }

    /// Track a newly connected configured address and report whether it is configured.
    fn track_configured_connection(&mut self, remote_addr: &Multiaddr) -> bool {
        let configured = self.configured_peer_addrs.iter().any(|peer| &peer.addr == remote_addr);
        if configured {
            self.connected_configured_addrs.insert(remote_addr.clone());
        }
        configured
    }

    /// Clear dial-gate state and surface asynchronous outgoing dial failures.
    ///
    /// `dial_addr` only observes errors `Swarm::dial` returns synchronously; connect
    /// timeouts and refusals arrive later as `OutgoingConnectionError` events. Configured
    /// addresses warn only when transitioning into the failing state, which is cleared
    /// when that configured address establishes a connection again. A peer answering a
    /// pinned address with the wrong identity — or an address that resolves back to this
    /// node — gets the same edge-triggered warning: for configured peers those are
    /// operator-visible misconfigurations, not routine churn.
    fn handle_outgoing_connection_error(
        &mut self,
        connection_id: ConnectionId,
        peer_id: Option<PeerId>,
        error: DialError,
    ) {
        // Scope gate cleanup to the discovered dial that actually failed: an unrelated
        // configured dial failing for the same pinned peer must not clear a pending
        // discovered dial's in-flight marker.
        if let Some(discovered_peer) = self.discovered_dials.remove(&connection_id) {
            self.gater.remove_dial(&discovered_peer);
        }

        if let DialError::LocalPeerId { address } = &error {
            let (source, first_failure) = note_dial_failure(
                &self.configured_peer_addrs,
                &self.connected_configured_addrs,
                &mut self.failing_configured_addrs,
                address,
            );
            WhitelistPreconfirmationDriverMetrics::inc_network_dial_attempt(source, "self_dial");
            if first_failure {
                warn!(%address, source, "configured address dials back to this node");
            } else {
                debug!(%address, source, "dial address resolves to this node");
            }
            return;
        }

        if let DialError::WrongPeerId { obtained, address } = &error {
            let (source, first_failure) = note_dial_failure(
                &self.configured_peer_addrs,
                &self.connected_configured_addrs,
                &mut self.failing_configured_addrs,
                address,
            );
            WhitelistPreconfirmationDriverMetrics::inc_network_dial_attempt(
                source,
                "wrong_peer_id",
            );
            if first_failure {
                warn!(%address, source, %obtained, "dialed peer presented an unexpected identity");
            } else {
                debug!(%address, source, %obtained, "dialed peer presented an unexpected identity");
            }
            return;
        }

        let DialError::Transport(failed) = &error else {
            let source = peer_id
                .as_ref()
                .and_then(|peer_id| {
                    configured_source_for_peer_id(&self.configured_peer_addrs, peer_id)
                })
                .unwrap_or("unknown");
            WhitelistPreconfirmationDriverMetrics::inc_network_dial_attempt(
                source,
                "connect_failed",
            );
            debug!(?peer_id, source, %error, "outgoing connection attempt failed");
            return;
        };

        for (addr, transport_error) in failed {
            let (source, first_failure) = note_dial_failure(
                &self.configured_peer_addrs,
                &self.connected_configured_addrs,
                &mut self.failing_configured_addrs,
                addr,
            );
            WhitelistPreconfirmationDriverMetrics::inc_network_dial_attempt(
                source,
                "connect_failed",
            );

            if first_failure {
                warn!(
                    %addr,
                    source,
                    error = %transport_error,
                    retry_interval = ?CONFIGURED_PEER_RETRY_INTERVAL,
                    "configured peer dial failed; further failures logged at debug until it recovers"
                );
            } else {
                debug!(%addr, source, error = %transport_error, "outgoing connection attempt failed");
            }
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
        WhitelistPreconfirmationDriverMetrics::inc_network_inbound_message(
            topic_label,
            acceptance_label(&acceptance),
        );
        self.report_validation(message_id, from, acceptance);
    }

    /// Record a `decode_failed` inbound metric for `topic_label` and report `Reject`.
    ///
    /// The metric label (`"decode_failed"`) intentionally differs from the reported
    /// acceptance (`Reject`) so undecodable traffic is distinguishable in metrics.
    fn record_decode_failed(
        &mut self,
        topic_label: &'static str,
        message_id: &gossipsub::MessageId,
        from: PeerId,
    ) {
        WhitelistPreconfirmationDriverMetrics::inc_network_inbound_message(
            topic_label,
            "decode_failed",
        );
        self.report_validation(message_id, from, gossipsub::MessageAcceptance::Reject);
    }
}

/// Format peer ids into a compact comma-separated log value.
fn format_peer_ids(peers: &[PeerId]) -> String {
    peers.iter().map(ToString::to_string).collect::<Vec<_>>().join(",")
}

/// Record one failed dial address against the failing-address set.
///
/// Returns the configured source label (`"unknown"` for unconfigured addresses) and
/// whether this is the address's first failure since it last connected. Unconfigured
/// and currently connected addresses are not tracked and never report a first failure.
fn note_dial_failure(
    configured_peer_addrs: &[ConfiguredPeerAddr],
    connected_configured_addrs: &HashSet<Multiaddr>,
    failing_configured_addrs: &mut HashSet<Multiaddr>,
    addr: &Multiaddr,
) -> (&'static str, bool) {
    let source =
        configured_peer_addrs.iter().find(|peer| &peer.addr == addr).map(|peer| peer.source);

    match source {
        Some(source) if connected_configured_addrs.contains(addr) => {
            failing_configured_addrs.remove(addr);
            (source, false)
        }
        Some(source) => (source, failing_configured_addrs.insert(addr.clone())),
        None => ("unknown", false),
    }
}

/// Receive one discovered ENR, pending forever when discovery is disabled.
///
/// Keeping the disabled branch pending lets the runtime `select!` poll this arm
/// unconditionally without waking on a closed or absent channel.
async fn recv_discovered(rx: &mut Option<mpsc::Receiver<discv5::Enr>>) -> Option<discv5::Enr> {
    match rx {
        Some(rx) => rx.recv().await,
        None => std::future::pending().await,
    }
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
    fn peer_id_from_addr_ignores_non_terminal_peer_id() {
        let relay_peer = PeerId::random();
        let addr = Multiaddr::empty()
            .with(Protocol::Ip4(Ipv4Addr::LOCALHOST))
            .with(Protocol::Tcp(30303))
            .with(Protocol::P2p(relay_peer))
            .with(Protocol::P2pCircuit);

        assert_eq!(peer_id_from_addr(&addr), None);
    }

    #[test]
    fn configured_peer_identity_is_protected_before_exact_address_connects() {
        let configured_peer = PeerId::random();
        let unprotected_peer = PeerId::random();
        let configured = vec![ConfiguredPeerAddr {
            addr: Multiaddr::empty()
                .with(Protocol::Ip4(Ipv4Addr::LOCALHOST))
                .with(Protocol::Tcp(30303))
                .with(Protocol::P2p(configured_peer)),
            source: "static peer",
        }];
        let configured_ids = configured_peer_ids(&configured);
        let manager = PeerWatermarks::with_protected(1, configured_ids.iter().copied());

        assert_eq!(
            manager.peer_to_prune([unprotected_peer, configured_peer], configured_peer),
            Some(unprotected_peer),
            "configured identity must displace an unprotected peer before its exact address connects"
        );
    }

    #[test]
    fn network_config_validate_rejects_zero_peer_high_tide() {
        let cfg = NetworkConfig { peers_lo: 0, peers_hi: 0, ..Default::default() };

        let err = cfg.validate().expect_err("zero high tide must fail");

        assert!(err.to_string().contains("--p2p.peers.hi must be greater than zero"));
    }

    #[test]
    fn network_config_validate_rejects_low_tide_above_high_tide() {
        let cfg = NetworkConfig { peers_lo: 2, peers_hi: 1, ..Default::default() };

        let err = cfg.validate().expect_err("low tide above high tide must fail");

        assert!(err.to_string().contains("--p2p.peers.lo (2)"));
    }

    #[test]
    fn network_config_validate_allows_zero_peer_low_tide() {
        let cfg = NetworkConfig { peers_lo: 0, peers_hi: 1, ..Default::default() };

        cfg.validate().expect("zero low tide must remain valid");
    }

    #[test]
    fn network_config_validate_rejects_zero_discovery_udp_port() {
        let cfg = NetworkConfig {
            discovery_listen: Some(SocketAddr::from((Ipv4Addr::LOCALHOST, 0))),
            ..Default::default()
        };

        let err = cfg.validate().expect_err("enabled discovery with UDP/0 must fail");

        assert!(err.to_string().contains("--p2p.discovery.addr"));
    }

    #[test]
    fn network_config_validate_rejects_zero_advertise_tcp_port_with_discovery() {
        let cfg = NetworkConfig {
            discovery_listen: Some(SocketAddr::from((Ipv4Addr::LOCALHOST, 30304))),
            advertise_addr: Some(SocketAddr::from((Ipv4Addr::LOCALHOST, 0))),
            ..Default::default()
        };

        let err = cfg.validate().expect_err("enabled discovery with advertised TCP/0 must fail");

        assert!(err.to_string().contains("--p2p.advertise.addr"));
    }

    #[test]
    fn network_config_validate_rejects_unspecified_advertise_ip_with_discovery() {
        let cfg = NetworkConfig {
            discovery_listen: Some(SocketAddr::from((Ipv4Addr::LOCALHOST, 30304))),
            advertise_addr: Some(SocketAddr::from((Ipv4Addr::UNSPECIFIED, 4001))),
            ..Default::default()
        };

        let err = cfg.validate().expect_err("unspecified advertised IP must fail");

        assert!(err.to_string().contains("routable unicast"));
    }

    #[test]
    fn network_config_validate_rejects_mismatched_discovery_ip_families() {
        let cfg = NetworkConfig {
            discovery_listen: Some(SocketAddr::from((Ipv4Addr::UNSPECIFIED, 30304))),
            advertise_addr: Some(SocketAddr::from((Ipv6Addr::LOCALHOST, 4001))),
            ..Default::default()
        };

        let err = cfg.validate().expect_err("mixed listen/advertise IP families must fail");

        assert!(err.to_string().contains("same IP family"));
    }

    #[test]
    fn network_config_validate_allows_matching_advertise_endpoint() {
        let cfg = NetworkConfig {
            discovery_listen: Some(SocketAddr::from((Ipv4Addr::UNSPECIFIED, 30304))),
            advertise_addr: Some(SocketAddr::from(([203, 0, 113, 10], 4001))),
            ..Default::default()
        };

        cfg.validate().expect("routable matching-family advertise endpoint must pass");
    }

    #[test]
    fn network_config_validate_allows_zero_advertise_tcp_port_without_discovery() {
        let cfg = NetworkConfig {
            discovery_listen: None,
            advertise_addr: Some(SocketAddr::from((Ipv4Addr::LOCALHOST, 0))),
            ..Default::default()
        };

        cfg.validate().expect("advertised TCP/0 without discovery only affects log output");
    }

    #[test]
    fn configured_source_for_peer_id_resolves_only_pinned_identities() {
        let pinned_peer = PeerId::random();
        let configured = vec![
            ConfiguredPeerAddr {
                addr: Multiaddr::empty()
                    .with(Protocol::Ip4(Ipv4Addr::LOCALHOST))
                    .with(Protocol::Tcp(4001))
                    .with(Protocol::P2p(pinned_peer)),
                source: "bootnode",
            },
            ConfiguredPeerAddr {
                addr: Multiaddr::empty()
                    .with(Protocol::Ip4(Ipv4Addr::LOCALHOST))
                    .with(Protocol::Tcp(4002)),
                source: "static peer",
            },
        ];

        assert_eq!(configured_source_for_peer_id(&configured, &pinned_peer), Some("bootnode"));
        assert_eq!(configured_source_for_peer_id(&configured, &PeerId::random()), None);
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
    fn spawn_rejects_invalid_config_before_runtime_setup() {
        let cfg = NetworkConfig {
            listen_addr: SocketAddr::from((Ipv4Addr::LOCALHOST, 0)),
            peers_lo: 0,
            peers_hi: 0,
            ..Default::default()
        };
        let operator_set = Arc::new(arc_swap::ArcSwap::from_pointee(HashSet::new()));

        match WhitelistNetwork::spawn(1, cfg, operator_set) {
            Err(err) => assert!(err.to_string().contains("--p2p.peers.hi")),
            Ok(_) => panic!("invalid public config must fail before spawning the runtime"),
        }
    }

    #[test]
    fn advertised_enode_url_uses_secp256k1_public_key() {
        let raw_key = "1875af8dad47674dd6897fb7bcdc1ba872144914082e02dace98dcf2ba16aa8d";
        let local_key = NetworkConfig::parse_preconfirmation_p2p_priv_raw(Some(raw_key))
            .expect("raw key should parse")
            .expect("key should be configured");
        let listen_addr = SocketAddr::from((Ipv4Addr::LOCALHOST, 30303));

        let enode =
            advertised_enode_url(&local_key, listen_addr, None).expect("secp key has enode");
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

        let enode = advertised_enode_url(&local_key, listen_addr, Some(advertise_addr))
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

        let enode = advertised_enode_url(&local_key, listen_addr, Some(advertise_addr))
            .expect("secp key has enode");

        assert!(enode.ends_with("@[::1]:30303"));
    }

    #[test]
    fn advertised_enode_url_is_unavailable_for_non_secp256k1_key() {
        let local_key = identity::Keypair::generate_ed25519();
        let listen_addr = SocketAddr::from((Ipv4Addr::LOCALHOST, 30303));

        assert_eq!(advertised_enode_url(&local_key, listen_addr, None), None);
    }

    #[test]
    fn note_dial_failure_reports_first_failure_only_until_recovery() {
        let addr: Multiaddr = "/ip4/10.0.0.1/tcp/4001".parse().expect("valid multiaddr");
        let configured = vec![ConfiguredPeerAddr { addr: addr.clone(), source: "bootnode" }];
        let connected = HashSet::new();
        let mut failing = HashSet::new();
        assert_eq!(
            note_dial_failure(&configured, &connected, &mut failing, &addr),
            ("bootnode", true)
        );
        assert_eq!(
            note_dial_failure(&configured, &connected, &mut failing, &addr),
            ("bootnode", false)
        );
        failing.remove(&addr);
        assert_eq!(
            note_dial_failure(&configured, &connected, &mut failing, &addr),
            ("bootnode", true)
        );
    }

    #[test]
    fn note_dial_failure_ignores_stale_failure_after_success() {
        let addr: Multiaddr = "/ip4/10.0.0.1/tcp/4001".parse().expect("valid multiaddr");
        let configured = vec![ConfiguredPeerAddr { addr: addr.clone(), source: "bootnode" }];
        let mut connected = HashSet::new();
        let mut failing = HashSet::new();

        assert_eq!(
            note_dial_failure(&configured, &connected, &mut failing, &addr),
            ("bootnode", true)
        );
        failing.remove(&addr);
        connected.insert(addr.clone());

        assert_eq!(
            note_dial_failure(&configured, &connected, &mut failing, &addr),
            ("bootnode", false)
        );
        assert!(failing.is_empty(), "stale failure must not reopen the address outage");
    }

    #[test]
    fn note_dial_failure_ignores_unconfigured_addresses() {
        let configured = vec![ConfiguredPeerAddr {
            addr: "/ip4/10.0.0.1/tcp/4001".parse().expect("valid multiaddr"),
            source: "static peer",
        }];
        let connected = HashSet::new();
        let mut failing = HashSet::new();
        let unknown: Multiaddr = "/ip4/10.0.0.2/tcp/4001".parse().expect("valid multiaddr");
        assert_eq!(
            note_dial_failure(&configured, &connected, &mut failing, &unknown),
            ("unknown", false)
        );
        assert!(failing.is_empty());
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

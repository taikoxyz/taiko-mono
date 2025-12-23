//! Main network driver for the preconfirmation P2P layer.
//!
//! This module owns the libp2p swarm, handles commands/events, and wires
//! discovery, reputation, gossip, and request/response handling.

mod behaviour;
mod discovery;
mod gossip;
mod reqresp;

#[cfg(test)]
mod tests;

use std::{
    collections::{HashMap, VecDeque},
    num::NonZeroU8,
    str::FromStr,
    sync::Arc,
};

use libp2p::{Multiaddr, PeerId, futures::StreamExt, gossipsub, swarm::Swarm};
use tokio::{
    sync::mpsc::{self, Receiver, Sender, error::TrySendError},
    task::JoinHandle,
};

use crate::{
    behaviour::NetBehaviourEvent,
    builder::build_transport_and_behaviour,
    command::NetworkCommand,
    config::NetworkConfig,
    discovery::{DiscoveryConfig, DiscoveryEvent, spawn_discovery},
    event::{NetworkError, NetworkErrorKind, NetworkEvent},
    reputation::{
        PeerAction, ReputationBackend, ReputationConfig, ReqRespKind, RequestRateLimiter,
        reth_adapter::RethReputationAdapter,
    },
    storage::{PreconfStorage, default_storage},
    validation::{LookaheadResolver, LookaheadValidationAdapter, ValidationAdapter},
};
use kona_gossip::{ConnectionGate, ConnectionGater, GaterConfig as KonaGaterConfig};
use preconfirmation_types::{PreconfHead, address_to_bytes20};
use ssz_rs::Deserialize;

/// Handle returned to the service layer; exposes the event receiver and command sender endpoints.
#[derive(Debug)]
pub struct NetworkHandle {
    /// Receiver for network events emitted by the driver.
    pub events: Receiver<NetworkEvent>,
    /// Sender for commands targeting the driver.
    pub commands: Sender<NetworkCommand>,
}

/// Poll-driven swarm driver that owns the libp2p `Swarm` and associated behaviours.
pub struct NetworkDriver {
    /// The underlying libp2p swarm that manages connections, protocols, and events.
    swarm: Swarm<crate::behaviour::NetBehaviour>,
    /// Sender for network events to be consumed by the service layer.
    events_tx: Sender<NetworkEvent>,
    /// Receiver for commands from the service layer to control the network.
    commands_rx: Receiver<NetworkCommand>,
    /// Gossip topics for commitments and raw transaction lists.
    topics: (gossipsub::IdentTopic, gossipsub::IdentTopic),
    /// Backend for managing peer reputation.
    reputation: Box<dyn ReputationBackend>,
    /// Rate limiter for incoming requests.
    request_limiter: RequestRateLimiter,
    /// Pending outbound req/resp timestamps for latency metrics.
    commitments_out: VecDeque<tokio::time::Instant>,
    /// Pending outbound raw-txlist req/resp timestamps for latency metrics.
    raw_txlists_out: VecDeque<tokio::time::Instant>,
    /// Pending outbound head req/resp timestamps for latency metrics.
    head_out: VecDeque<tokio::time::Instant>,
    /// Validator adapter (swap in upstream implementation here).
    validator: Box<dyn ValidationAdapter>,
    /// Optional receiver for discovery events.
    discovery_rx: Option<Receiver<DiscoveryEvent>>,
    /// Handle to the spawned discovery task.
    _discovery_task: Option<JoinHandle<()>>,
    /// Counter for currently connected peers.
    connected_peers: i64,
    /// The current local preconfirmation head, served to peers on request.
    head: PreconfHead,
    /// Kona connection gater for managing inbound and outbound connections.
    kona_gater: kona_gossip::ConnectionGater,
    /// Storage backend for commitments/txlists (in-memory by default).
    storage: Arc<dyn PreconfStorage>,
    /// Correlation IDs for outbound commitments requests.
    commitments_req_ids: HashMap<libp2p::request_response::OutboundRequestId, u64>,
    /// Correlation IDs for outbound raw-txlist requests.
    raw_txlists_req_ids: HashMap<libp2p::request_response::OutboundRequestId, u64>,
    /// Correlation IDs for outbound head requests.
    head_req_ids: HashMap<libp2p::request_response::OutboundRequestId, u64>,
}

/// Constructs the reputation backend adapter. At runtime this delegates to the reth-backed
/// implementation so we reuse upstream scoring/ban logic instead of duplicating it here.
fn build_reputation_backend(cfg: ReputationConfig) -> Box<dyn ReputationBackend> {
    Box::new(RethReputationAdapter::new(cfg))
}

/// Builds a `ConnectionGater` instance based on the provided `NetworkConfig`.
fn build_kona_gater(cfg: &NetworkConfig) -> ConnectionGater {
    let mut gater = ConnectionGater::new(KonaGaterConfig {
        peer_redialing: cfg.gater_peer_redialing,
        dial_period: cfg.gater_dial_period,
    });

    for cidr in &cfg.gater_blocked_subnets {
        match ipnet::IpNet::from_str(cidr) {
            Ok(net) => {
                gater.blocked_subnets.insert(net);
            }
            Err(_) => {
                tracing::warn!(target: "p2p", cidr, "invalid blocked subnet, ignoring");
            }
        }
    }

    gater
}

impl NetworkDriver {
    /// Constructs a new `NetworkDriver` and its associated `NetworkHandle`.
    pub fn new(
        cfg: NetworkConfig,
        lookahead: Arc<dyn LookaheadResolver>,
    ) -> anyhow::Result<(Self, NetworkHandle)> {
        Self::new_with_lookahead_and_storage(cfg, lookahead, None)
    }

    /// Constructs a new `NetworkDriver` with optional lookahead resolver and storage backend.
    pub fn new_with_lookahead_and_storage(
        cfg: NetworkConfig,
        lookahead: Arc<dyn LookaheadResolver>,
        storage: Option<Arc<dyn PreconfStorage>>,
    ) -> anyhow::Result<(Self, NetworkHandle)> {
        let dial_factor = {
            let (_, _, _, _, _, _, dial) = cfg.resolve_connection_caps();
            NonZeroU8::new(dial).unwrap_or_else(|| NonZeroU8::new(1).unwrap())
        };

        let parts = build_transport_and_behaviour(&cfg)?;
        let peer_id = parts.keypair.public().to_peer_id();
        let config =
            libp2p::swarm::Config::with_tokio_executor().with_dial_concurrency_factor(dial_factor);
        let mut swarm = Swarm::new(parts.transport, parts.behaviour, peer_id, config);

        // Listen on TCP and/or QUIC based on config.
        if cfg.enable_tcp {
            let listen_addr_str = if cfg.listen_addr.is_ipv4() {
                format!("/ip4/{}/tcp/{}", cfg.listen_addr.ip(), cfg.listen_addr.port())
            } else {
                format!("/ip6/{}/tcp/{}", cfg.listen_addr.ip(), cfg.listen_addr.port())
            };
            let listen_addr: Multiaddr = listen_addr_str.parse()?;
            swarm.listen_on(listen_addr)?;
        }
        #[cfg(feature = "quic-transport")]
        if cfg.enable_quic {
            let quic_addr_str = if cfg.listen_addr.is_ipv4() {
                format!("/ip4/{}/udp/{}/quic-v1", cfg.listen_addr.ip(), cfg.listen_addr.port())
            } else {
                format!("/ip6/{}/udp/{}/quic-v1", cfg.listen_addr.ip(), cfg.listen_addr.port())
            };
            let quic_addr: Multiaddr = quic_addr_str.parse()?;
            swarm.listen_on(quic_addr)?;
        }

        let (events_tx, events_rx) = mpsc::channel(256);
        let (cmd_tx, cmd_rx) = mpsc::channel(256);

        let _ = events_tx.try_send(NetworkEvent::Started);

        cfg.validate_request_rate_limits();

        let mut discovery_rx = None;
        let mut discovery_task = None;
        if cfg.enable_discovery {
            let disc_cfg = DiscoveryConfig {
                listen: cfg.discv5_listen,
                bootnodes: cfg.bootnodes.clone(),
                enr_udp_port: None,
                enr_tcp_port: None,
            };
            if let Ok((rx, task)) = spawn_discovery(disc_cfg, cfg.discovery_preset) {
                discovery_rx = Some(rx);
                discovery_task = Some(task);
            }
        }

        Ok((
            Self {
                swarm,
                events_tx: events_tx.clone(),
                commands_rx: cmd_rx,
                topics: parts.topics,
                reputation: build_reputation_backend(ReputationConfig {
                    greylist_threshold: cfg.reputation_greylist,
                    ban_threshold: cfg.reputation_ban,
                    halflife: cfg.reputation_halflife,
                    weights:
                        reth_network_types::peers::reputation::ReputationChangeWeights::default(),
                }),
                request_limiter: RequestRateLimiter::new(
                    cfg.request_window,
                    cfg.max_requests_per_window,
                ),
                commitments_out: VecDeque::new(),
                raw_txlists_out: VecDeque::new(),
                head_out: VecDeque::new(),
                validator: Box::new(LookaheadValidationAdapter::new(
                    cfg.slasher_address.map(address_to_bytes20),
                    lookahead,
                )) as Box<dyn ValidationAdapter>,
                discovery_rx,
                _discovery_task: discovery_task,
                connected_peers: 0,
                head: PreconfHead::default(),
                kona_gater: build_kona_gater(&cfg),
                storage: storage.unwrap_or_else(default_storage),
                commitments_req_ids: HashMap::new(),
                raw_txlists_req_ids: HashMap::new(),
                head_req_ids: HashMap::new(),
            },
            NetworkHandle { events: events_rx, commands: cmd_tx },
        ))
    }

    /// Best-effort error emission; drops silently if the event channel is full/closed while still
    /// recording drop metrics.
    fn emit_error(&mut self, kind: NetworkErrorKind, detail: impl Into<String>) {
        self.emit_error_with_request(kind, detail, None);
    }

    /// Emits an error optionally correlated to a request id.
    fn emit_error_with_request(
        &mut self,
        kind: NetworkErrorKind,
        detail: impl Into<String>,
        request_id: Option<u64>,
    ) {
        let err = NetworkError::new(kind, detail).with_request_id(request_id);
        match self.events_tx.try_send(NetworkEvent::Error(err.clone())) {
            Ok(()) => {}
            Err(TrySendError::Full(_)) => {
                metrics::counter!("p2p_event_dropped", "surface" => "event_tx", "reason" => "full", "kind" => err.kind.as_str()).increment(1);
            }
            Err(TrySendError::Closed(_)) => {
                metrics::counter!("p2p_event_dropped", "surface" => "event_tx", "reason" => "closed", "kind" => err.kind.as_str()).increment(1);
            }
        }
    }

    /// Publishes an SSZ-serializable message over a given gossipsub topic.
    fn publish_gossip<T: ssz_rs::prelude::SimpleSerialize>(
        &mut self,
        topic: &gossipsub::IdentTopic,
        msg: T,
    ) -> anyhow::Result<()> {
        let bytes = ssz_rs::serialize(&msg)?;
        self.swarm
            .behaviour_mut()
            .gossipsub
            .publish(topic.clone(), bytes)
            .map_err(|e| anyhow::anyhow!(e.to_string()))?;
        Ok(())
    }

    /// Applies a reputation action to a given peer and enforces bans/greylists.
    fn apply_reputation(&mut self, peer: PeerId, action: PeerAction) {
        let ev = self.reputation.apply(peer, action);
        if ev.is_banned && !ev.was_banned {
            metrics::counter!("p2p_reputation_ban").increment(1);
            self.swarm.behaviour_mut().block_list.block_peer(ev.peer);
            self.kona_gater.block_peer(&ev.peer);
            let _ = self.swarm.disconnect_peer_id(ev.peer);
        }
        if ev.is_greylisted && !ev.was_greylisted {
            metrics::counter!("p2p_reputation_greylist").increment(1);
        }
    }
}

impl Drop for NetworkDriver {
    /// Sends a `NetworkEvent::Stopped` event when the `NetworkDriver` is dropped.
    fn drop(&mut self) {
        let _ = self.events_tx.try_send(NetworkEvent::Stopped);
    }
}

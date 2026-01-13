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

use std::{collections::HashMap, num::NonZeroU8, str::FromStr, sync::Arc};

use libp2p::{Multiaddr, PeerId, futures::StreamExt, gossipsub, swarm::Swarm};
use tokio::sync::mpsc::{self, Receiver, Sender, error::TrySendError};

use crate::{
    behaviour::NetBehaviourEvent,
    builder::build_transport_and_behaviour,
    command::NetworkCommand,
    config::NetworkConfig,
    discovery::spawn_discovery,
    event::{NetworkError, NetworkErrorKind, NetworkEvent},
    reputation::{
        PeerAction, PeerReputationStore, ReputationConfig, ReqRespKind, RequestRateLimiter,
    },
    storage::{PreconfStorage, default_storage},
    validation::ValidationAdapter,
};
use kona_gossip::{ConnectionGate, ConnectionGater, GaterConfig as KonaGaterConfig};
use preconfirmation_types::PreconfHead;
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
    reputation: PeerReputationStore,
    /// Rate limiter for incoming requests.
    request_limiter: RequestRateLimiter,
    /// Pending outbound req/resp requests keyed by (protocol kind, request id).
    pending_requests: HashMap<
        (ReqRespKind, libp2p::request_response::OutboundRequestId),
        reqresp::PendingRequest,
    >,
    /// Validator adapter (swap in upstream implementation here).
    validator: Box<dyn ValidationAdapter>,
    /// Optional receiver for discovery-surfaced multiaddrs.
    discovery_rx: Option<Receiver<Multiaddr>>,
    /// Counter for currently connected peers.
    connected_peers: i64,
    /// The current local preconfirmation head, served to peers on request.
    head: PreconfHead,
    /// Kona connection gater for managing inbound and outbound connections.
    kona_gater: kona_gossip::ConnectionGater,
    /// Storage backend for commitments/txlists (in-memory by default).
    storage: Arc<dyn PreconfStorage>,
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
    /// Constructs a new `NetworkDriver` with a provided validation adapter.
    pub(crate) fn new_with_validator(
        cfg: NetworkConfig,
        validator: Box<dyn ValidationAdapter>,
    ) -> anyhow::Result<(Self, NetworkHandle)> {
        Self::new_with_validator_and_storage(cfg, validator, None)
    }

    /// Constructs a new `NetworkDriver` with custom validation and optional storage backend.
    pub fn new_with_validator_and_storage(
        cfg: NetworkConfig,
        validator: Box<dyn ValidationAdapter>,
        storage: Option<Arc<dyn PreconfStorage>>,
    ) -> anyhow::Result<(Self, NetworkHandle)> {
        let dial_factor =
            NonZeroU8::new(cfg.dial_concurrency_factor).unwrap_or(NonZeroU8::new(1).unwrap());

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
        if cfg.enable_discovery {
            discovery_rx = spawn_discovery(cfg.discv5_listen, cfg.bootnodes.clone()).ok();
        }

        Ok((
            Self {
                swarm,
                events_tx: events_tx.clone(),
                commands_rx: cmd_rx,
                topics: parts.topics,
                reputation: PeerReputationStore::new(ReputationConfig {
                    greylist_threshold: cfg.reputation_greylist,
                    ban_threshold: cfg.reputation_ban,
                    halflife: cfg.reputation_halflife,
                }),
                request_limiter: RequestRateLimiter::new(
                    cfg.request_window,
                    cfg.max_requests_per_window,
                ),
                pending_requests: HashMap::new(),
                validator,
                discovery_rx,
                connected_peers: 0,
                head: PreconfHead::default(),
                kona_gater: build_kona_gater(&cfg),
                storage: storage.unwrap_or_else(default_storage),
            },
            NetworkHandle { events: events_rx, commands: cmd_tx },
        ))
    }

    /// Best-effort error emission; drops silently if the event channel is full/closed while still
    /// recording drop metrics.
    fn emit_error(&mut self, kind: NetworkErrorKind, detail: impl Into<String>) {
        let err = NetworkError::new(kind, detail);
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

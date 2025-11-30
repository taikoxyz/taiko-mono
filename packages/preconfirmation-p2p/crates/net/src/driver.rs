use std::task::{Context, Poll};

#[cfg(feature = "kona-gater")]
use libp2p::Multiaddr;
use libp2p::{
    PeerId,
    futures::StreamExt,
    gossipsub, request_response as rr,
    swarm::{Swarm, SwarmEvent},
};
use tokio::{
    sync::mpsc::{self, Receiver, Sender},
    task::JoinHandle,
};

use crate::{
    behaviour::NetBehaviourEvent,
    builder::build_transport_and_behaviour,
    command::NetworkCommand,
    config::NetworkConfig,
    discovery::{DiscoveryConfig, DiscoveryEvent, spawn_discovery},
    event::NetworkEvent,
};

#[cfg(not(feature = "reth-peers"))]
use crate::reputation::PeerReputationStore;
#[cfg(feature = "reth-peers")]
use crate::reputation::PeerReputationStore;
#[cfg(feature = "reth-peers")]
use crate::reputation::reth_adapter::RethReputationAdapter;
use crate::reputation::{PeerAction, ReputationBackend, ReputationConfig, RequestRateLimiter};
#[cfg(feature = "kona-gater")]
use kona_gossip::{ConnectionGate as KonaConnectionGate, GaterConfig as KonaGaterConfig};
use preconfirmation_types::{
    GetCommitmentsByNumberRequest, GetCommitmentsByNumberResponse, GetHeadRequest,
    GetRawTxListRequest, GetRawTxListResponse, PreconfHead, RawTxListGossip, SignedCommitment,
    validate_commitments_response, validate_raw_txlist_gossip, verify_signed_commitment,
};
use ssz_rs::Deserialize;

#[cfg(feature = "reth-peers")]
fn build_reputation_backend(cfg: ReputationConfig) -> Box<dyn ReputationBackend> {
    Box::new(RethReputationAdapter::new(cfg))
}

#[cfg(not(feature = "reth-peers"))]
fn build_reputation_backend(cfg: ReputationConfig) -> Box<dyn ReputationBackend> {
    Box::new(PeerReputationStore::new(cfg))
}

/// Handle returned to service layer; exposes the event receiver and command sender endpoints.
#[derive(Debug)]
pub struct NetworkHandle {
    /// Receiver for network events emitted by the driver.
    pub events: Receiver<NetworkEvent>,
    /// Sender for commands targeting the driver.
    pub commands: Sender<NetworkCommand>,
}

/// Poll-driven swarm driver that owns the libp2p `Swarm` and associated behaviours.
pub struct NetworkDriver {
    swarm: Swarm<crate::behaviour::NetBehaviour>,
    events_tx: Sender<NetworkEvent>,
    commands_rx: Receiver<NetworkCommand>,
    topics: (gossipsub::IdentTopic, gossipsub::IdentTopic),
    reputation: Box<dyn ReputationBackend>,
    request_limiter: RequestRateLimiter,
    discovery_rx: Option<Receiver<DiscoveryEvent>>,
    _discovery_task: Option<JoinHandle<()>>,
    connected_peers: i64,
    head: PreconfHead,
    #[cfg(feature = "kona-gater")]
    kona_gater: kona_gossip::ConnectionGater,
}

// Active reputation backend selected via feature flag.
// Legacy alias kept for clarity when reading older code; no longer used directly.
#[allow(dead_code)]
type ReputationStore = PeerReputationStore;

impl NetworkDriver {
    /// Construct a driver and its handle using the provided network config.
    pub fn new(cfg: NetworkConfig) -> anyhow::Result<(Self, NetworkHandle)> {
        let parts = build_transport_and_behaviour(&cfg)?;
        let peer_id = parts.keypair.public().to_peer_id();
        let config = libp2p::swarm::Config::with_tokio_executor();
        let swarm = Swarm::new(parts.transport, parts.behaviour, peer_id, config);

        let (events_tx, events_rx) = mpsc::channel(256);
        let (cmd_tx, cmd_rx) = mpsc::channel(256);

        // Best-effort lifecycle notification.
        let _ = events_tx.try_send(NetworkEvent::Started);

        let mut discovery_rx = None;
        let mut discovery_task = None;
        if cfg.enable_discovery {
            let disc_cfg = DiscoveryConfig {
                listen: cfg.discv5_listen,
                bootnodes: cfg.bootnodes.clone(),
                enr_udp_port: None,
                enr_tcp_port: None,
            };
            if let Ok((rx, task)) = spawn_discovery(disc_cfg) {
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
                }),
                request_limiter: RequestRateLimiter::new(
                    cfg.request_window,
                    cfg.max_requests_per_window,
                ),
                discovery_rx,
                _discovery_task: discovery_task,
                connected_peers: 0,
                head: PreconfHead::default(),
                #[cfg(feature = "kona-gater")]
                kona_gater: kona_gossip::ConnectionGater::new(KonaGaterConfig::default()),
            },
            NetworkHandle { events: events_rx, commands: cmd_tx },
        ))
    }

    /// Run one poll of the swarm; intended to be driven by an async loop in service.
    pub fn poll(&mut self, cx: &mut Context<'_>) -> Poll<()> {
        // Process outbound commands first so we don't starve the swarm.
        while let Ok(cmd) = self.commands_rx.try_recv() {
            self.handle_command(cmd);
        }

        if let Some(rx) = self.discovery_rx.as_mut() {
            let mut drained = Vec::new();
            while let Ok(event) = rx.try_recv() {
                drained.push(event);
            }
            for event in drained {
                self.handle_discovery_event(event);
            }
        }

        match self.swarm.poll_next_unpin(cx) {
            Poll::Ready(Some(event)) => {
                self.handle_swarm_event(event);
                Poll::Ready(())
            }
            Poll::Ready(None) => Poll::Ready(()),
            Poll::Pending => Poll::Pending,
        }
    }

    fn handle_swarm_event(&mut self, event: SwarmEvent<NetBehaviourEvent>) {
        match event {
            SwarmEvent::Behaviour(ev) => self.handle_behaviour_event(ev),
            SwarmEvent::ConnectionEstablished { peer_id, .. } => {
                self.connected_peers += 1;
                metrics::gauge!("p2p_connected_peers").set(self.connected_peers as f64);
                if self.reputation.is_banned(&peer_id) {
                    let _ = self.swarm.disconnect_peer_id(peer_id);
                }
                let _ = self.events_tx.try_send(NetworkEvent::PeerConnected(peer_id));
            }
            SwarmEvent::ConnectionClosed { peer_id, .. } => {
                self.connected_peers -= 1;
                metrics::gauge!("p2p_connected_peers").set(self.connected_peers.max(0) as f64);
                let _ = self.events_tx.try_send(NetworkEvent::PeerDisconnected(peer_id));
            }
            _ => {}
        }
    }

    fn handle_behaviour_event(&mut self, ev: NetBehaviourEvent) {
        match ev {
            NetBehaviourEvent::Gossipsub(ev) => self.handle_gossipsub_event(ev),
            NetBehaviourEvent::CommitmentsRr(ev) => self.handle_commitments_rr_event(ev),
            NetBehaviourEvent::RawTxlistsRr(ev) => self.handle_raw_txlists_rr_event(ev),
            NetBehaviourEvent::HeadRr(ev) => self.handle_head_rr_event(ev),
            _ => {}
        }
    }

    fn handle_gossipsub_event(&mut self, ev: gossipsub::Event) {
        if let gossipsub::Event::Message { propagation_source, message, .. } = ev {
            if self.reputation.is_banned(&propagation_source) {
                metrics::counter!("p2p_gossip_dropped_banned").increment(1);
                return;
            }

            let topic = message.topic.clone();
            if topic == self.topics.0.hash() {
                match SignedCommitment::deserialize(&message.data) {
                    Ok(msg) => {
                        if verify_signed_commitment(&msg).is_ok() {
                            metrics::counter!("p2p_gossip_valid", "kind" => "commitment")
                                .increment(1);
                            self.apply_reputation(propagation_source, PeerAction::GossipValid);
                            let _ =
                                self.events_tx.try_send(NetworkEvent::GossipSignedCommitment {
                                    from: propagation_source,
                                    msg,
                                });
                        } else {
                            metrics::counter!("p2p_gossip_invalid", "kind" => "commitment", "reason" => "sig").increment(1);
                            self.apply_reputation(
                                propagation_source,
                                PeerAction::GossipInvalid,
                            );
                            let _ = self.events_tx.try_send(NetworkEvent::Error(
                                "invalid signed commitment gossip".into(),
                            ));
                        }
                    }
                    Err(_) => {
                        metrics::counter!("p2p_gossip_invalid", "kind" => "commitment", "reason" => "decode").increment(1);
                        self.apply_reputation(propagation_source, PeerAction::GossipInvalid);
                        let _ = self.events_tx.try_send(NetworkEvent::Error(
                            "invalid signed commitment gossip".into(),
                        ));
                    }
                }
            } else if topic == self.topics.1.hash() {
                match RawTxListGossip::deserialize(&message.data) {
                    Ok(msg) => {
                        if validate_raw_txlist_gossip(&msg).is_ok() {
                            metrics::counter!("p2p_gossip_valid", "kind" => "raw_txlists")
                                .increment(1);
                            self.apply_reputation(propagation_source, PeerAction::GossipValid);
                            let _ = self.events_tx.try_send(NetworkEvent::GossipRawTxList {
                                from: propagation_source,
                                msg,
                            });
                        } else {
                            metrics::counter!("p2p_gossip_invalid", "kind" => "raw_txlists", "reason" => "validation").increment(1);
                            self.apply_reputation(
                                propagation_source,
                                PeerAction::GossipInvalid,
                            );
                            let _ = self.events_tx.try_send(NetworkEvent::Error(
                                "invalid raw txlist gossip".into(),
                            ));
                        }
                    }
                    Err(_) => {
                        metrics::counter!("p2p_gossip_invalid", "kind" => "raw_txlists", "reason" => "decode").increment(1);
                        self.apply_reputation(propagation_source, PeerAction::GossipInvalid);
                        let _ = self
                            .events_tx
                            .try_send(NetworkEvent::Error("invalid raw txlist gossip".into()));
                    }
                }
            }
        }
    }

    fn handle_commitments_rr_event(
        &mut self,
        ev: rr::Event<GetCommitmentsByNumberRequest, GetCommitmentsByNumberResponse>,
    ) {
        match ev {
            rr::Event::Message { peer, message, .. } => match message {
                rr::Message::Request { channel, .. } => {
                    if self.reputation.is_banned(&peer) {
                        metrics::counter!("p2p_reqresp_dropped", "kind" => "commitments", "reason" => "banned").increment(1);
                        return;
                    }
                    if !self.request_limiter.allow(peer, std::time::Instant::now()) {
                        metrics::counter!("p2p_reqresp_rate_limited", "kind" => "commitments")
                            .increment(1);
                        let _ = self.events_tx.try_send(NetworkEvent::Error(
                            "commitments request rate-limited".into(),
                        ));
                        self.apply_reputation(peer, PeerAction::Timeout);
                        return;
                    }

                    let _ = self
                        .events_tx
                        .try_send(NetworkEvent::InboundCommitmentsRequest { from: peer });
                    let _ = self
                        .swarm
                        .behaviour_mut()
                        .commitments_rr
                        .send_response(channel, GetCommitmentsByNumberResponse::default());
                    metrics::counter!("p2p_reqresp_success", "kind" => "commitments", "direction" => "inbound").increment(1);
                    self.apply_reputation(peer, PeerAction::ReqRespSuccess);
                }
                rr::Message::Response { response, .. } => {
                    if validate_commitments_response(&response).is_ok() {
                        metrics::counter!("p2p_reqresp_success", "kind" => "commitments", "direction" => "outbound").increment(1);
                        self.apply_reputation(peer, PeerAction::ReqRespSuccess);
                        let _ = self.events_tx.try_send(NetworkEvent::ReqRespCommitments {
                            from: peer,
                            msg: response,
                        });
                    } else {
                        metrics::counter!("p2p_reqresp_error", "kind" => "commitments", "reason" => "validation").increment(1);
                        self.apply_reputation(peer, PeerAction::ReqRespError);
                        let _ = self
                            .events_tx
                            .try_send(NetworkEvent::Error("invalid commitments response".into()));
                    }
                }
            },
            rr::Event::OutboundFailure { peer, error, .. } => {
                metrics::counter!("p2p_reqresp_error", "kind" => "commitments", "reason" => "outbound_failure").increment(1);
                self.apply_reputation(peer, PeerAction::ReqRespError);
                let _ = self.events_tx.try_send(NetworkEvent::Error(format!(
                    "req-resp commitments with {peer}: {error}"
                )));
            }
            rr::Event::InboundFailure { peer, error, .. } => {
                metrics::counter!("p2p_reqresp_error", "kind" => "commitments", "reason" => "inbound_failure").increment(1);
                self.apply_reputation(peer, PeerAction::ReqRespError);
                let _ = self.events_tx.try_send(NetworkEvent::Error(format!(
                    "req-resp commitments with {peer}: {error}"
                )));
            }
            rr::Event::ResponseSent { .. } => {}
        }
    }

    fn handle_raw_txlists_rr_event(
        &mut self,
        ev: rr::Event<GetRawTxListRequest, GetRawTxListResponse>,
    ) {
        match ev {
            rr::Event::Message { peer, message, .. } => match message {
                rr::Message::Request { channel, .. } => {
                    if self.reputation.is_banned(&peer) {
                        metrics::counter!("p2p_reqresp_dropped", "kind" => "raw_txlists", "reason" => "banned").increment(1);
                        return;
                    }
                    if !self.request_limiter.allow(peer, std::time::Instant::now()) {
                        metrics::counter!("p2p_reqresp_rate_limited", "kind" => "raw_txlists")
                            .increment(1);
                        let _ = self.events_tx.try_send(NetworkEvent::Error(
                            "raw txlist request rate-limited".into(),
                        ));
                        self.apply_reputation(peer, PeerAction::Timeout);
                        return;
                    }

                    let _ = self
                        .events_tx
                        .try_send(NetworkEvent::InboundRawTxListRequest { from: peer });
                    let _ = self
                        .swarm
                        .behaviour_mut()
                        .raw_txlists_rr
                        .send_response(channel, GetRawTxListResponse::default());
                    metrics::counter!("p2p_reqresp_success", "kind" => "raw_txlists", "direction" => "inbound").increment(1);
                    self.apply_reputation(peer, PeerAction::ReqRespSuccess);
                }
                rr::Message::Response { response, .. } => {
                    let candidate = RawTxListGossip {
                        raw_tx_list_hash: response.raw_tx_list_hash.clone(),
                        anchor_block_number: response.anchor_block_number.clone(),
                        txlist: response.txlist.clone(),
                    };

                    if validate_raw_txlist_gossip(&candidate).is_ok() {
                        metrics::counter!("p2p_reqresp_success", "kind" => "raw_txlists", "direction" => "outbound").increment(1);
                        self.apply_reputation(peer, PeerAction::ReqRespSuccess);
                        let _ = self
                            .events_tx
                            .try_send(NetworkEvent::ReqRespRawTxList { from: peer, msg: response });
                    } else {
                        metrics::counter!("p2p_reqresp_error", "kind" => "raw_txlists", "reason" => "validation").increment(1);
                        self.apply_reputation(peer, PeerAction::ReqRespError);
                        let _ = self
                            .events_tx
                            .try_send(NetworkEvent::Error("invalid raw txlist response".into()));
                    }
                }
            },
            rr::Event::OutboundFailure { peer, error, .. } => {
                metrics::counter!("p2p_reqresp_error", "kind" => "raw_txlists", "reason" => "outbound_failure").increment(1);
                self.apply_reputation(peer, PeerAction::ReqRespError);
                let _ = self.events_tx.try_send(NetworkEvent::Error(format!(
                    "req-resp raw-txlist with {peer}: {error}"
                )));
            }
            rr::Event::InboundFailure { peer, error, .. } => {
                metrics::counter!("p2p_reqresp_error", "kind" => "raw_txlists", "reason" => "inbound_failure").increment(1);
                self.apply_reputation(peer, PeerAction::ReqRespError);
                let _ = self.events_tx.try_send(NetworkEvent::Error(format!(
                    "req-resp raw-txlist with {peer}: {error}"
                )));
            }
            rr::Event::ResponseSent { .. } => {}
        }
    }

    fn handle_head_rr_event(&mut self, ev: rr::Event<GetHeadRequest, PreconfHead>) {
        match ev {
            rr::Event::Message { peer, message, .. } => match message {
                rr::Message::Request { channel, .. } => {
                    if self.reputation.is_banned(&peer) {
                        metrics::counter!("p2p_reqresp_dropped", "kind" => "head", "reason" => "banned").increment(1);
                        return;
                    }
                    let _ =
                        self.events_tx.try_send(NetworkEvent::InboundHeadRequest { from: peer });
                    let _ = self
                        .swarm
                        .behaviour_mut()
                        .head_rr
                        .send_response(channel, self.head.clone());
                    metrics::counter!("p2p_reqresp_success", "kind" => "head", "direction" => "inbound").increment(1);
                    self.apply_reputation(peer, PeerAction::ReqRespSuccess);
                }
                rr::Message::Response { response, .. } => {
                    metrics::counter!("p2p_reqresp_success", "kind" => "head", "direction" => "outbound").increment(1);
                    self.apply_reputation(peer, PeerAction::ReqRespSuccess);
                    let _ = self
                        .events_tx
                        .try_send(NetworkEvent::ReqRespHead { from: peer, head: response });
                }
            },
            rr::Event::OutboundFailure { peer, error, .. } => {
                metrics::counter!("p2p_reqresp_error", "kind" => "head", "reason" => "outbound_failure").increment(1);
                self.apply_reputation(peer, PeerAction::ReqRespError);
                let _ = self
                    .events_tx
                    .try_send(NetworkEvent::Error(format!("req-resp head with {peer}: {error}")));
            }
            rr::Event::InboundFailure { peer, error, .. } => {
                metrics::counter!("p2p_reqresp_error", "kind" => "head", "reason" => "inbound_failure").increment(1);
                self.apply_reputation(peer, PeerAction::ReqRespError);
                let _ = self
                    .events_tx
                    .try_send(NetworkEvent::Error(format!("req-resp head with {peer}: {error}")));
            }
            rr::Event::ResponseSent { .. } => {}
        }
    }

    fn handle_command(&mut self, cmd: NetworkCommand) {
        match cmd {
            NetworkCommand::PublishCommitment(msg) => {
                let topic = self.topics.0.clone();
                if let Err(err) = self.publish_gossip(&topic, msg) {
                    metrics::counter!("p2p_gossip_publish_error", "kind" => "commitment")
                        .increment(1);
                    let _ = self
                        .events_tx
                        .try_send(NetworkEvent::Error(format!("gossip commitment: {err}")));
                }
            }
            NetworkCommand::PublishRawTxList(msg) => {
                let topic = self.topics.1.clone();
                if let Err(err) = self.publish_gossip(&topic, msg) {
                    metrics::counter!("p2p_gossip_publish_error", "kind" => "raw_txlists")
                        .increment(1);
                    let _ = self
                        .events_tx
                        .try_send(NetworkEvent::Error(format!("gossip raw-txlist: {err}")));
                }
            }
            NetworkCommand::RequestCommitments { start_block, max_count, peer } => {
                if let Some(target) = self.choose_peer(peer) {
                    let req = GetCommitmentsByNumberRequest {
                        start_block_number: start_block,
                        max_count,
                    };
                    let _ = self.swarm.behaviour_mut().commitments_rr.send_request(&target, req);
                }
            }
            NetworkCommand::RequestRawTxList { raw_tx_list_hash, peer } => {
                if let Some(target) = self.choose_peer(peer) {
                    let req = GetRawTxListRequest { raw_tx_list_hash };
                    let _ = self.swarm.behaviour_mut().raw_txlists_rr.send_request(&target, req);
                }
            }
            NetworkCommand::RequestHead { peer } => {
                if let Some(target) = self.choose_peer(peer) {
                    let req = GetHeadRequest::default();
                    let _ = self.swarm.behaviour_mut().head_rr.send_request(&target, req);
                }
            }
            NetworkCommand::UpdateHead { head } => {
                self.head = head;
            }
        }
    }

    fn handle_discovery_event(&mut self, event: DiscoveryEvent) {
        match event {
            DiscoveryEvent::MultiaddrFound(addr) => {
                // Avoid dialing peers we already banned (if multiaddr contains peer ID we could
                // extract; for now just dial and let libp2p dedup).
                #[cfg(feature = "kona-gater")]
                {
                    if let Some(peer) = Self::peer_id_from_multiaddr(&addr) {
                        if self.kona_gater.can_dial(&addr).is_err() {
                            metrics::counter!("p2p_dial_blocked", "source" => "kona_gater")
                                .increment(1);
                            return;
                        }
                        if self.reputation.is_banned(&peer) {
                            metrics::counter!("p2p_dial_blocked", "source" => "reputation")
                                .increment(1);
                            return;
                        }
                    }
                }
                let _ = self.swarm.dial(addr);
            }
            DiscoveryEvent::BootnodeFailed(err) => {
                let _ = self
                    .events_tx
                    .try_send(NetworkEvent::Error(format!("discovery bootnode: {err}")));
            }
            DiscoveryEvent::PeerDiscovered(_) => {}
        }
    }

    fn choose_peer(&mut self, preferred: Option<PeerId>) -> Option<PeerId> {
        if preferred.is_some() {
            return preferred;
        }
        self.swarm.connected_peers().find(|p| !self.reputation.is_banned(p)).cloned()
    }

    #[cfg(feature = "kona-gater")]
    fn peer_id_from_multiaddr(addr: &Multiaddr) -> Option<PeerId> {
        use libp2p::multiaddr::Protocol;
        addr.iter().find_map(|p| match p {
            Protocol::P2p(mh) => PeerId::from_multihash(mh.into()).ok(),
            _ => None,
        })
    }

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

    fn apply_reputation(&mut self, peer: PeerId, action: PeerAction) {
        let ev = self.reputation.apply(peer, action);
        if ev.is_banned && !ev.was_banned {
            metrics::counter!("p2p_reputation_ban").increment(1);
            // Update block list behaviour so new dials/inbounds are rejected and existing
            // connections closed.
            self.swarm.behaviour_mut().block_list.block_peer(ev.peer);
            #[cfg(feature = "kona-gater")]
            {
                self.kona_gater.block_peer(&ev.peer);
            }
            let _ = self.swarm.disconnect_peer_id(ev.peer);
        }
        if ev.is_greylisted && !ev.was_greylisted {
            metrics::counter!("p2p_reputation_greylist").increment(1);
        }
    }
}

impl Drop for NetworkDriver {
    fn drop(&mut self) {
        let _ = self.events_tx.try_send(NetworkEvent::Stopped);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{behaviour::NetBehaviour, builder::BuiltParts};
    use futures::task::noop_waker_ref;
    use libp2p::{
        Multiaddr, Transport,
        core::{transport::memory::MemoryTransport, upgrade},
        identity, noise, yamux,
    };
    use preconfirmation_types::{PreconfCommitment, Preconfirmation, SignedCommitment, Uint256};
    use ssz_rs::Vector;
    use std::{str::FromStr, task::Context};
    use tokio::time::Duration;

    async fn listen_on(driver: &mut NetworkDriver) -> Multiaddr {
        let addr: Multiaddr = Multiaddr::from_str("/ip4/127.0.0.1/tcp/0").unwrap();
        driver.swarm.listen_on(addr).unwrap();
        // Drive a few times to register the listener and obtain the bound address.
        for _ in 0..10 {
            pump_sync(driver);
            if let Some(addr) = driver.swarm.listeners().next().cloned() {
                return addr;
            }
            tokio::time::sleep(Duration::from_millis(50)).await;
        }
        driver.swarm.listeners().next().cloned().expect("listener addr")
    }

    fn pump_sync(driver: &mut NetworkDriver) {
        let w = noop_waker_ref();
        let mut cx = Context::from_waker(w);
        let _ = driver.poll(&mut cx);
    }

    async fn pump_async(driver: &mut NetworkDriver) {
        futures::future::poll_fn(|cx| {
            let _ = driver.poll(cx);
            std::task::Poll::Ready(())
        })
        .await;
    }

    /// Build transport/behaviour parts using the in-memory transport for deterministic tests.
    #[cfg(test)]
    fn build_memory_parts(chain_id: u64) -> BuiltParts {
        let keypair = identity::Keypair::generate_ed25519();
        let noise_config = noise::Config::new(&keypair).expect("noise config");
        let transport = MemoryTransport::default()
            .upgrade(upgrade::Version::V1Lazy)
            .authenticate(noise_config)
            .multiplex(yamux::Config::default())
            .boxed();

        let topics = (
            libp2p::gossipsub::IdentTopic::new(
                preconfirmation_types::topic_preconfirmation_commitments(chain_id),
            ),
            libp2p::gossipsub::IdentTopic::new(preconfirmation_types::topic_raw_txlists(
                chain_id,
            )),
        );
        let protocols = crate::codec::Protocols {
            commitments: crate::codec::SszProtocol(
                preconfirmation_types::protocol_get_commitments_by_number(chain_id),
            ),
            raw_txlists: crate::codec::SszProtocol(
                preconfirmation_types::protocol_get_raw_txlist(chain_id),
            ),
            head: crate::codec::SszProtocol(preconfirmation_types::protocol_get_head(chain_id)),
        };
        let behaviour = NetBehaviour::new(keypair.public(), topics.clone(), protocols);

        BuiltParts { keypair, transport, behaviour, topics }
    }

    /// Build a driver from pre-built parts (used for memory transport tests).
    fn driver_from_parts(parts: BuiltParts, cfg: &NetworkConfig) -> (NetworkDriver, NetworkHandle) {
        let peer_id = parts.keypair.public().to_peer_id();
        let config = libp2p::swarm::Config::with_tokio_executor();
        let swarm = Swarm::new(parts.transport, parts.behaviour, peer_id, config);

        let (events_tx, events_rx) = mpsc::channel(256);
        let (cmd_tx, cmd_rx) = mpsc::channel(256);
        let _ = events_tx.try_send(NetworkEvent::Started);

        (
            NetworkDriver {
                swarm,
                events_tx: events_tx.clone(),
                commands_rx: cmd_rx,
                topics: parts.topics,
                reputation: build_reputation_backend(ReputationConfig {
                    greylist_threshold: cfg.reputation_greylist,
                    ban_threshold: cfg.reputation_ban,
                    halflife: cfg.reputation_halflife,
                }),
                request_limiter: RequestRateLimiter::new(
                    cfg.request_window,
                    cfg.max_requests_per_window,
                ),
                discovery_rx: None,
                _discovery_task: None,
                connected_peers: 0,
                head: PreconfHead::default(),
                #[cfg(feature = "kona-gater")]
                kona_gater: kona_gossip::ConnectionGater::new(KonaGaterConfig::default()),
            },
            NetworkHandle { events: events_rx, commands: cmd_tx },
        )
    }

    fn sample_signed_commitment(sk: &secp256k1::SecretKey) -> SignedCommitment {
        let commitment = PreconfCommitment {
            preconf: Preconfirmation {
                eop: false,
                block_number: Uint256::from(1u64),
                timestamp: Uint256::from(1u64),
                gas_limit: Uint256::from(1u64),
                coinbase: Vector::try_from(vec![0u8; 20]).unwrap(),
                anchor_block_number: Uint256::from(1u64),
                raw_tx_list_hash: Vector::try_from(vec![0u8; 32]).unwrap(),
                parent_preconfirmation_hash: Vector::try_from(vec![0u8; 32]).unwrap(),
                submission_window_end: Uint256::from(1u64),
                prover_auth: Vector::try_from(vec![0u8; 20]).unwrap(),
                proposal_id: Uint256::from(1u64),
            },
            slasher_address: Vector::try_from(vec![0u8; 20]).unwrap(),
        };
        let sig = preconfirmation_types::sign_commitment(&commitment, sk).unwrap();
        SignedCommitment { commitment, signature: sig }
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 4)]
    async fn gossipsub_and_reqresp_roundtrip() {
        // Real TCP test: retried for stability. Still runs by default; will only be flaky on
        // heavily firewalled or resource-starved environments.
        let mut success = false;
        for _attempt in 0..3 {
            let mut cfg = NetworkConfig { enable_discovery: false, ..Default::default() };
            cfg.listen_addr.set_port(0);
            cfg.discv5_listen.set_port(0);
            let (driver1, mut handle1) = NetworkDriver::new(cfg.clone()).unwrap();
            let (driver2, mut handle2) = NetworkDriver::new(cfg).unwrap();

            let mut driver1 = driver1;
            let mut driver2 = driver2;

            let _addr1 = listen_on(&mut driver1).await;
            let addr2 = listen_on(&mut driver2).await;
            let peer1_id = *driver1.swarm.local_peer_id();
            let peer2_id = *driver2.swarm.local_peer_id();
            let mut addr2_full = addr2.clone();
            addr2_full.push(libp2p::multiaddr::Protocol::P2p(peer2_id.into()));

            // Single-direction dial to avoid simultaneous-dial races.
            driver1.swarm.dial(addr2_full.clone()).unwrap();

            // Drive swarms synchronously until connected
            let mut peer1_connected = false;
            let mut peer2_connected = false;
            for _ in 0..2000 {
                pump_async(&mut driver1).await;
                pump_async(&mut driver2).await;
                while let Ok(ev) = handle1.events.try_recv() {
                    if matches!(ev, NetworkEvent::PeerConnected(_)) {
                        peer1_connected = true;
                    }
                }
                while let Ok(ev) = handle2.events.try_recv() {
                    if matches!(ev, NetworkEvent::PeerConnected(_)) {
                        peer2_connected = true;
                    }
                }
                if peer1_connected && peer2_connected {
                    break;
                }
                tokio::time::sleep(Duration::from_millis(10)).await;
            }
            if !(peer1_connected && peer2_connected) {
                continue;
            }

            // Ensure explicit peers for gossipsub to avoid mesh lag.
            driver1.swarm.behaviour_mut().gossipsub.add_explicit_peer(&peer2_id);
            driver2.swarm.behaviour_mut().gossipsub.add_explicit_peer(&peer1_id);

            // Allow protocol negotiation and a couple of gossipsub heartbeats.
            for _ in 0..10 {
                pump_async(&mut driver1).await;
                pump_async(&mut driver2).await;
                tokio::time::sleep(Duration::from_millis(150)).await;
            }

            // Gossip from peer1 to peer2 with a valid signature so validation passes.
            let sk1 = secp256k1::SecretKey::new(&mut rand::thread_rng());
            let commit = sample_signed_commitment(&sk1);
            handle1.commands.send(NetworkCommand::PublishCommitment(commit.clone())).await.unwrap();

            let mut received = false;
            for _ in 0..2000 {
                pump_async(&mut driver1).await;
                pump_async(&mut driver2).await;
                if let Ok(ev) = handle2.events.try_recv() {
                    if let NetworkEvent::GossipSignedCommitment { msg, .. } = ev {
                        assert_eq!(msg, commit);
                        received = true;
                        break;
                    }
                }
                tokio::time::sleep(Duration::from_millis(10)).await;
            }
            if !received {
                continue;
            }

            // Req/Resp from peer1 -> peer2
            handle1
                .commands
                .send(NetworkCommand::RequestCommitments {
                    start_block: Uint256::from(0u64),
                    max_count: 1,
                    peer: None,
                })
                .await
                .unwrap();

            let mut got_resp = false;
            for _ in 0..2000 {
                pump_async(&mut driver1).await;
                pump_async(&mut driver2).await;
                if let Ok(ev) = handle1.events.try_recv() {
                    if let NetworkEvent::ReqRespCommitments { .. } = ev {
                        got_resp = true;
                        break;
                    }
                }
                tokio::time::sleep(Duration::from_millis(10)).await;
            }
            if got_resp {
                success = true;
                break;
            }
        }

        assert!(
            success,
            "real TCP roundtrip failed after retries; environment may block local TCP"
        );
    }

    #[tokio::test(flavor = "multi_thread", worker_threads = 2)]
    async fn memory_transport_gossip_reqresp_and_ban() {
        let cfg = NetworkConfig { enable_discovery: false, ..Default::default() };
        let parts1 = build_memory_parts(cfg.chain_id);
        let parts2 = build_memory_parts(cfg.chain_id);
        let (mut driver1, mut handle1) = driver_from_parts(parts1, &cfg);
        let (mut driver2, mut handle2) = driver_from_parts(parts2, &cfg);

        let addr1: Multiaddr = "/memory/1001".parse().unwrap();
        let addr2: Multiaddr = "/memory/1002".parse().unwrap();
        driver1.swarm.listen_on(addr1.clone()).unwrap();
        driver2.swarm.listen_on(addr2.clone()).unwrap();

        driver1.swarm.dial(addr2.clone()).unwrap();

        let mut connected = 0;
        for _ in 0..200 {
            pump_sync(&mut driver1);
            pump_sync(&mut driver2);
            while let Ok(ev) = handle1.events.try_recv() {
                if matches!(ev, NetworkEvent::PeerConnected(_)) {
                    connected |= 1;
                }
            }
            while let Ok(ev) = handle2.events.try_recv() {
                if matches!(ev, NetworkEvent::PeerConnected(_)) {
                    connected |= 2;
                }
            }
            if connected == 3 {
                break;
            }
            tokio::time::sleep(Duration::from_millis(5)).await;
        }
        assert_eq!(connected, 3, "memory peers failed to connect");

        // Allow gossipsub mesh/identify to settle.
        for _ in 0..20 {
            pump_sync(&mut driver1);
            pump_sync(&mut driver2);
            tokio::time::sleep(Duration::from_millis(5)).await;
        }

        // Gossip a valid signed commitment from peer1 to peer2.
        let sk1 = secp256k1::SecretKey::new(&mut rand::thread_rng());
        let signed = sample_signed_commitment(&sk1);
        handle1.commands.send(NetworkCommand::PublishCommitment(signed.clone())).await.unwrap();
        let mut got_gossip = false;
        for _ in 0..120 {
            pump_sync(&mut driver1);
            pump_sync(&mut driver2);
            if let Ok(NetworkEvent::GossipSignedCommitment { msg, .. }) = handle2.events.try_recv()
            {
                assert_eq!(msg, signed);
                got_gossip = true;
                break;
            }
            tokio::time::sleep(Duration::from_millis(5)).await;
        }
        assert!(got_gossip, "gossip did not arrive over memory transport");

        // Req/resp: peer1 requests commitments from peer2; peer2 auto-responds with default.
        let req =
            GetCommitmentsByNumberRequest { start_block_number: Uint256::from(1u64), max_count: 1 };
        handle1
            .commands
            .send(NetworkCommand::RequestCommitments {
                start_block: req.start_block_number.clone(),
                max_count: req.max_count,
                peer: Some(*driver2.swarm.local_peer_id()),
            })
            .await
            .unwrap();
        let mut got_resp = false;
        for _ in 0..50 {
            pump_sync(&mut driver1);
            pump_sync(&mut driver2);
            while let Ok(ev) = handle1.events.try_recv() {
                if matches!(ev, NetworkEvent::ReqRespCommitments { .. }) {
                    got_resp = true;
                    break;
                }
            }
            if got_resp {
                break;
            }
            tokio::time::sleep(Duration::from_millis(5)).await;
        }
        assert!(got_resp, "did not receive req/resp reply over memory transport");

        // Reputation ban: apply enough invalid actions to ban peer2, ensure disconnect and no
        // reconnect.
        let peer2 = *driver2.swarm.local_peer_id();
        for _ in 0..6 {
            driver1.apply_reputation(peer2, PeerAction::GossipInvalid);
        }
        for _ in 0..50 {
            pump_sync(&mut driver1);
            if !driver1.swarm.is_connected(&peer2) {
                break;
            }
            tokio::time::sleep(Duration::from_millis(2)).await;
        }
        assert!(driver1.reputation.is_banned(&peer2));
        assert!(!driver1.swarm.is_connected(&peer2));

        let _ = driver1.swarm.dial(addr2.clone());
        for _ in 0..20 {
            pump_sync(&mut driver1);
            if !driver1.swarm.is_connected(&peer2) {
                break;
            }
            tokio::time::sleep(Duration::from_millis(2)).await;
        }
        assert!(!driver1.swarm.is_connected(&peer2), "banned peer should not reconnect");
    }
}

//! Minimal libp2p network runtime for whitelist preconfirmation topics.

use std::{
    collections::{HashMap, HashSet},
    sync::Arc,
    time::{Duration, Instant},
};

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
        decode_unsafe_response_message, encode_envelope_ssz, encode_eos_request_message,
        encode_unsafe_payload_message, encode_unsafe_request_message,
        encode_unsafe_response_message,
    },
    error::{Result, WhitelistPreconfirmationDriverError},
    metrics::WhitelistPreconfirmationDriverMetrics,
};
use hashlink::LinkedHashMap;

/// Gossipsub behaviour type with an explicit topic allowlist filter.
type WhitelistGossipsub =
    gossipsub::Behaviour<gossipsub::IdentityTransform, gossipsub::WhitelistSubscriptionFilter>;

/// Maximum allowed gossip payload size after decompression.
const MAX_GOSSIP_SIZE_BYTES: usize = kona_gossip::MAX_GOSSIP_SIZE;
/// Prefix used in Go-compatible message-id hashing for valid snappy payloads.
const MESSAGE_ID_PREFIX_VALID_SNAPPY: [u8; 4] = [1, 0, 0, 0];
/// Prefix used in Go-compatible message-id hashing for invalid snappy payloads.
const MESSAGE_ID_PREFIX_INVALID_SNAPPY: [u8; 4] = [0, 0, 0, 0];
/// Capacity used for bounded in-memory duplicate guards.
const DUPLICATE_TRACKER_CAPACITY: usize = 1000;
/// Duplicate suppression window for repeated `requestPreconfBlocks` hashes.
const PRECONF_REQUEST_DUPLICATE_WINDOW: Duration = Duration::from_secs(45);
/// Duplicate suppression window for recently observed inbound `responsePreconfBlocks` hashes.
///
/// This network-edge cache only guards gossip ingress. The importer keeps a separate cache
/// using the same window to suppress outbound duplicate publishes (including local loopback).
pub(crate) const PRECONF_RESPONSE_SEEN_WINDOW: Duration = Duration::from_secs(10);
/// Per-peer request bucket refill rate, in tokens per minute.
const REQUEST_REFILL_PER_MIN: u32 = 200;
/// Per-peer request bucket max burst.
const REQUEST_MAX_TOKENS: f64 = REQUEST_REFILL_PER_MIN as f64;
/// Maximum acceptable duplicate sightings per block height for `preconfBlocks`.
const MAX_PRECONF_BLOCK_DUPLICATES_PER_HEIGHT: u64 = 10;
/// Maximum acceptable duplicate sightings per block height for `responsePreconfBlocks`.
const MAX_PRECONF_RESPONSE_DUPLICATES_PER_HEIGHT: u64 = 3;
/// Maximum distinct hashes tracked per block height in duplicate guards.
///
/// Bounds memory for adversarial traffic that spams unique hashes at one height.
const MAX_DISTINCT_HASHES_PER_HEIGHT: usize = 256;
/// Maximum acceptable sightings per EOS epoch before ignoring further requests.
const MAX_EOS_REQUESTS_PER_EPOCH: u64 = 3;
/// Interval for reconnect attempts to configured static peers.
const STATIC_PEER_REDIAL_INTERVAL: Duration = Duration::from_secs(60);

/// Validation decision for inbound gossip message admission at network edge.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum AdmissionDecision {
    /// Message should be forwarded to importer.
    Accept,
    /// Message should be ignored as an inbound duplicate.
    DuplicateLimited,
    /// Message should be ignored due to per-peer token-bucket throttling.
    RateLimited,
}

/// Per-peer token bucket state.
#[derive(Debug, Clone, Copy)]
struct RateBucket {
    /// Available token credit.
    credit: f64,
    /// Last refill timestamp.
    last_refill: Instant,
}

impl RateBucket {
    /// Create a full bucket at `now`.
    fn new(now: Instant) -> Self {
        Self { credit: REQUEST_MAX_TOKENS, last_refill: now }
    }

    /// Refill bucket credit based on elapsed time.
    fn refill(&mut self, now: Instant) {
        let elapsed = now.saturating_duration_since(self.last_refill).as_secs_f64();
        let refill_rate = f64::from(REQUEST_REFILL_PER_MIN) / 60.0;
        self.credit = (self.credit + (elapsed * refill_rate)).min(REQUEST_MAX_TOKENS);
        self.last_refill = now;
    }

    /// Consume one token from the bucket.
    fn consume_one(&mut self) -> bool {
        if self.credit < 1.0 {
            return false;
        }
        self.credit -= 1.0;
        true
    }
}

/// Bounded per-height duplicate tracker.
#[derive(Debug, Default)]
struct PerHeightDuplicateTracker {
    /// Duplicate counters keyed by block height and hash.
    by_height: LinkedHashMap<u64, HashMap<B256, u64>>,
}

impl PerHeightDuplicateTracker {
    /// Record a `(height, hash)` observation and decide whether to admit.
    ///
    /// `cap` is the maximum number of accepted observations per `(height, hash)` key.
    fn record_with_cap(&mut self, height: u64, hash: B256, cap: u64) -> AdmissionDecision {
        let mut seen = self.by_height.remove(&height).unwrap_or_default();
        let count = seen.get(&hash).copied().unwrap_or_default();
        if count == 0 && seen.len() >= MAX_DISTINCT_HASHES_PER_HEIGHT {
            self.by_height.insert(height, seen);
            self.evict_oldest();
            return AdmissionDecision::DuplicateLimited;
        }
        if count >= cap {
            self.by_height.insert(height, seen);
            self.evict_oldest();
            return AdmissionDecision::DuplicateLimited;
        }
        seen.insert(hash, count.saturating_add(1));
        self.by_height.insert(height, seen);
        self.evict_oldest();
        AdmissionDecision::Accept
    }

    /// Keep tracker bounded by height cardinality.
    fn evict_oldest(&mut self) {
        while self.by_height.len() > DUPLICATE_TRACKER_CAPACITY {
            let _ = self.by_height.pop_front();
        }
    }
}

/// Inbound validation and anti-spam state mirroring Go topic validators.
#[derive(Debug, Default)]
struct InboundValidationState {
    /// Per-peer request token buckets for `requestPreconfBlocks`.
    preconf_request_buckets: LinkedHashMap<PeerId, RateBucket>,
    /// Per-peer request token buckets for `requestEndOfSequencingPreconfBlocks`.
    eos_request_buckets: LinkedHashMap<PeerId, RateBucket>,
    /// Last-seen time for hash-based preconf requests.
    preconf_request_seen: LinkedHashMap<B256, Instant>,
    /// Last-seen time for inbound response hashes to suppress short-window gossip reprocessing.
    ///
    /// Outbound duplicate suppression lives in importer `response_seen_cache`.
    preconf_response_recent_seen: LinkedHashMap<B256, Instant>,
    /// Per-epoch seen counters for EOS requests.
    eos_request_seen: LinkedHashMap<u64, u64>,
    /// Duplicate tracker for `preconfBlocks`.
    preconf_payload_seen: PerHeightDuplicateTracker,
    /// Duplicate tracker for `responsePreconfBlocks`.
    preconf_response_seen: PerHeightDuplicateTracker,
}

impl InboundValidationState {
    /// Decide if an inbound `requestPreconfBlocks` should be admitted.
    fn admit_preconf_request(
        &mut self,
        from: PeerId,
        hash: B256,
        now: Instant,
    ) -> AdmissionDecision {
        self.prune_expired_request_hashes(now);
        if let Some(last_seen) = self.preconf_request_seen.get(&hash)
            && now.saturating_duration_since(*last_seen) < PRECONF_REQUEST_DUPLICATE_WINDOW
        {
            return AdmissionDecision::DuplicateLimited;
        }

        if !Self::consume_request_token(&mut self.preconf_request_buckets, from, now) {
            return AdmissionDecision::RateLimited;
        }

        self.preconf_request_seen.remove(&hash);
        self.preconf_request_seen.insert(hash, now);
        self.evict_oldest_seen_hashes();
        AdmissionDecision::Accept
    }

    /// Decide if an inbound `requestEndOfSequencingPreconfBlocks` should be admitted.
    fn admit_eos_request(&mut self, from: PeerId, epoch: u64, now: Instant) -> AdmissionDecision {
        let seen_count = self.eos_request_seen.get(&epoch).copied().unwrap_or_default();
        if seen_count >= MAX_EOS_REQUESTS_PER_EPOCH {
            return AdmissionDecision::DuplicateLimited;
        }

        if !Self::consume_request_token(&mut self.eos_request_buckets, from, now) {
            return AdmissionDecision::RateLimited;
        }

        self.eos_request_seen.remove(&epoch);
        self.eos_request_seen.insert(epoch, seen_count.saturating_add(1));
        self.evict_oldest_seen_epochs();
        AdmissionDecision::Accept
    }

    /// Decide if an inbound `preconfBlocks` payload should be admitted.
    fn admit_preconf_payload(&mut self, block_number: u64, block_hash: B256) -> AdmissionDecision {
        self.preconf_payload_seen.record_with_cap(
            block_number,
            block_hash,
            MAX_PRECONF_BLOCK_DUPLICATES_PER_HEIGHT,
        )
    }

    /// Decide if an inbound `responsePreconfBlocks` payload should be admitted.
    fn admit_preconf_response(
        &mut self,
        block_number: u64,
        block_hash: B256,
        now: Instant,
    ) -> AdmissionDecision {
        self.prune_expired_response_hashes(now);
        if let Some(last_seen) = self.preconf_response_recent_seen.get(&block_hash)
            && now.saturating_duration_since(*last_seen) < PRECONF_RESPONSE_SEEN_WINDOW
        {
            return AdmissionDecision::DuplicateLimited;
        }

        let decision = self.preconf_response_seen.record_with_cap(
            block_number,
            block_hash,
            MAX_PRECONF_RESPONSE_DUPLICATES_PER_HEIGHT,
        );
        if decision != AdmissionDecision::Accept {
            return decision;
        }

        self.preconf_response_recent_seen.remove(&block_hash);
        self.preconf_response_recent_seen.insert(block_hash, now);
        self.evict_oldest_response_seen_hashes();
        decision
    }

    /// Consume one token from a per-peer request bucket.
    fn consume_request_token(
        buckets: &mut LinkedHashMap<PeerId, RateBucket>,
        peer: PeerId,
        now: Instant,
    ) -> bool {
        let mut bucket = buckets.remove(&peer).unwrap_or_else(|| RateBucket::new(now));
        bucket.refill(now);
        let allowed = bucket.consume_one();
        buckets.insert(peer, bucket);
        while buckets.len() > DUPLICATE_TRACKER_CAPACITY {
            let _ = buckets.pop_front();
        }
        allowed
    }

    /// Remove expired request hash-window entries.
    fn prune_expired_request_hashes(&mut self, now: Instant) {
        let window = PRECONF_REQUEST_DUPLICATE_WINDOW;
        while let Some((_, seen_at)) = self.preconf_request_seen.iter().next() {
            if now.saturating_duration_since(*seen_at) < window {
                break;
            }
            let _ = self.preconf_request_seen.pop_front();
        }
    }

    /// Remove expired response hash-window entries.
    fn prune_expired_response_hashes(&mut self, now: Instant) {
        let window = PRECONF_RESPONSE_SEEN_WINDOW;
        while let Some((_, seen_at)) = self.preconf_response_recent_seen.iter().next() {
            if now.saturating_duration_since(*seen_at) < window {
                break;
            }
            let _ = self.preconf_response_recent_seen.pop_front();
        }
    }

    /// Keep seen-hash map bounded.
    fn evict_oldest_seen_hashes(&mut self) {
        while self.preconf_request_seen.len() > DUPLICATE_TRACKER_CAPACITY {
            let _ = self.preconf_request_seen.pop_front();
        }
    }

    /// Keep response seen-hash map bounded.
    fn evict_oldest_response_seen_hashes(&mut self) {
        while self.preconf_response_recent_seen.len() > DUPLICATE_TRACKER_CAPACITY {
            let _ = self.preconf_response_recent_seen.pop_front();
        }
    }

    /// Keep epoch-seen map bounded.
    fn evict_oldest_seen_epochs(&mut self) {
        while self.eos_request_seen.len() > DUPLICATE_TRACKER_CAPACITY {
            let _ = self.eos_request_seen.pop_front();
        }
    }
}

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
    gossipsub: WhitelistGossipsub,
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
        Self::spawn_with_identity(cfg, None)
    }

    /// Spawn the whitelist preconfirmation network task with an optional fixed identity key.
    pub fn spawn_with_identity(cfg: P2pConfig, local_identity_key: Option<String>) -> Result<Self> {
        let local_key = match local_identity_key {
            Some(raw) => parse_ed25519_private_key(&raw)?,
            None => identity::Keypair::generate_ed25519(),
        };
        let local_peer_id = local_key.public().to_peer_id();

        let topics = Topics::new(cfg.chain_id);
        let mut gossipsub = build_gossipsub(&topics)?;
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

        let static_peers = cfg.pre_dial_peers.clone();
        for peer in static_peers.iter().cloned() {
            dial_once(&mut swarm, &mut dialed_addrs, peer, "static peer");
        }

        for addr in bootnodes.dial_addrs {
            dial_once(&mut swarm, &mut dialed_addrs, addr, "bootnode");
        }

        let mut discovery_rx = if cfg.enable_discovery && !bootnodes.discovery_enrs.is_empty() {
            spawn_discovery(cfg.discovery_listen, bootnodes.discovery_enrs)
                .map_err(|err| {
                    warn!(error = %err, "failed to start whitelist preconfirmation discovery");
                })
                .ok()
        } else {
            if cfg.enable_discovery && bootnodes.discovery_enrs.is_empty() {
                tracing::info!(
                    "discovery enabled but no ENR bootnodes provided; skipping discv5 bootstrap"
                );
            } else if !cfg.enable_discovery && !bootnodes.discovery_enrs.is_empty() {
                warn!(
                    count = bootnodes.discovery_enrs.len(),
                    "discovery is disabled; skipping ENR bootnodes"
                );
            }
            None
        };

        let (event_tx, event_rx) = mpsc::channel(1024);
        let (command_tx, mut command_rx) = mpsc::channel(512);
        let local_peer_id_for_events = local_peer_id;
        let mut inbound_validation = InboundValidationState::default();

        let handle = tokio::spawn(async move {
            let mut static_peer_redial_tick = tokio::time::interval(STATIC_PEER_REDIAL_INTERVAL);
            static_peer_redial_tick.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
            let _ = static_peer_redial_tick.tick().await;

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
                                    metrics::counter!(
                                        WhitelistPreconfirmationDriverMetrics::NETWORK_OUTBOUND_PUBLISH_TOTAL,
                                        "topic" => "request_preconf_blocks",
                                        "result" => "publish_failed",
                                    )
                                    .increment(1);
                                    warn!(
                                        hash = %hash,
                                        error = %err,
                                        "failed to publish whitelist preconfirmation request"
                                    );
                                } else {
                                    metrics::counter!(
                                        WhitelistPreconfirmationDriverMetrics::NETWORK_OUTBOUND_PUBLISH_TOTAL,
                                        "topic" => "request_preconf_blocks",
                                        "result" => "published",
                                    )
                                    .increment(1);
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
                                            metrics::counter!(
                                                WhitelistPreconfirmationDriverMetrics::NETWORK_OUTBOUND_PUBLISH_TOTAL,
                                                "topic" => "response_preconf_blocks",
                                                "result" => "publish_failed",
                                            )
                                            .increment(1);
                                            warn!(
                                                hash = %hash,
                                                error = %err,
                                                "failed to publish whitelist preconfirmation response"
                                            );
                                        } else {
                                            metrics::counter!(
                                                WhitelistPreconfirmationDriverMetrics::NETWORK_OUTBOUND_PUBLISH_TOTAL,
                                                "topic" => "response_preconf_blocks",
                                                "result" => "published",
                                            )
                                            .increment(1);
                                        }
                                    }
                                    Err(err) => {
                                        metrics::counter!(
                                            WhitelistPreconfirmationDriverMetrics::NETWORK_OUTBOUND_PUBLISH_TOTAL,
                                            "topic" => "response_preconf_blocks",
                                            "result" => "encode_failed",
                                        )
                                        .increment(1);
                                        warn!(
                                            hash = %hash,
                                            error = %err,
                                            "failed to encode whitelist preconfirmation response"
                                        );
                                    }
                                }
                            }
                            NetworkCommand::PublishUnsafePayload { signature, envelope } => {
                                let hash = envelope.execution_payload.block_hash;
                                // Loop back locally-built payloads so importer caches can serve
                                // follow-up EOS catch-up requests even without peer echo.
                                let payload_bytes = encode_envelope_ssz(&envelope);
                                let local_event = NetworkEvent::UnsafePayload {
                                    from: local_peer_id_for_events,
                                    payload: DecodedUnsafePayload {
                                        wire_signature: signature,
                                        payload_bytes,
                                        envelope: (*envelope).clone(),
                                    },
                                };
                                forward_event(&event_tx, local_event).await?;

                                match encode_unsafe_payload_message(&signature, &envelope) {
                                    Ok(payload) => {
                                        if let Err(err) = swarm
                                            .behaviour_mut()
                                            .gossipsub
                                            .publish(topics.preconf_blocks.clone(), payload)
                                        {
                                            metrics::counter!(
                                                WhitelistPreconfirmationDriverMetrics::NETWORK_OUTBOUND_PUBLISH_TOTAL,
                                                "topic" => "preconf_blocks",
                                                "result" => "publish_failed",
                                            )
                                            .increment(1);
                                            warn!(
                                                hash = %hash,
                                                error = %err,
                                                "failed to publish whitelist preconfirmation payload"
                                            );
                                        } else {
                                            metrics::counter!(
                                                WhitelistPreconfirmationDriverMetrics::NETWORK_OUTBOUND_PUBLISH_TOTAL,
                                                "topic" => "preconf_blocks",
                                                "result" => "published",
                                            )
                                            .increment(1);
                                        }
                                    }
                                    Err(err) => {
                                        metrics::counter!(
                                            WhitelistPreconfirmationDriverMetrics::NETWORK_OUTBOUND_PUBLISH_TOTAL,
                                            "topic" => "preconf_blocks",
                                            "result" => "encode_failed",
                                        )
                                        .increment(1);
                                        warn!(
                                            hash = %hash,
                                            error = %err,
                                            "failed to encode whitelist preconfirmation payload"
                                        );
                                    }
                                }
                            }
                            NetworkCommand::PublishEndOfSequencingRequest { epoch } => {
                                let payload = encode_eos_request_message(epoch);
                                if let Err(err) = swarm
                                    .behaviour_mut()
                                    .gossipsub
                                    .publish(topics.eos_request.clone(), payload)
                                {
                                    metrics::counter!(
                                        WhitelistPreconfirmationDriverMetrics::NETWORK_OUTBOUND_PUBLISH_TOTAL,
                                        "topic" => "request_eos_preconf_blocks",
                                        "result" => "publish_failed",
                                    )
                                    .increment(1);
                                    warn!(
                                        epoch,
                                        error = %err,
                                        "failed to publish end-of-sequencing request"
                                    );
                                } else {
                                    metrics::counter!(
                                        WhitelistPreconfirmationDriverMetrics::NETWORK_OUTBOUND_PUBLISH_TOTAL,
                                        "topic" => "request_eos_preconf_blocks",
                                        "result" => "published",
                                    )
                                    .increment(1);
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
                    _ = static_peer_redial_tick.tick(), if !static_peers.is_empty() => {
                        for addr in static_peers.iter().cloned() {
                            let is_connected = peer_id_from_multiaddr(&addr)
                                .map(|peer| swarm.is_connected(&peer))
                                .unwrap_or(false);
                            if is_connected {
                                continue;
                            }
                            dial_retry(&mut swarm, addr, "static peer redial");
                        }
                    }
                    event = swarm.select_next_some() => {
                        handle_swarm_event(&mut swarm, event, &topics, &event_tx, &mut inbound_validation)
                            .await?;
                    }
                }
            }
        });

        Ok(Self { local_peer_id, event_rx, command_tx, handle })
    }
}

/// Build the gossipsub behaviour.
fn build_gossipsub(topics: &Topics) -> Result<WhitelistGossipsub> {
    let config = gossipsub::ConfigBuilder::default()
        .validate_messages()
        .validation_mode(gossipsub::ValidationMode::Anonymous)
        .heartbeat_interval(*kona_gossip::GOSSIP_HEARTBEAT)
        .duplicate_cache_time(*kona_gossip::SEEN_MESSAGES_TTL)
        .message_id_fn(message_id)
        .max_transmit_size(MAX_GOSSIP_SIZE_BYTES)
        .build()
        .map_err(to_p2p_err)?;

    let allowlisted_topics = [
        topics.preconf_blocks.hash(),
        topics.preconf_request.hash(),
        topics.preconf_response.hash(),
        topics.eos_request.hash(),
    ]
    .into_iter()
    .collect::<HashSet<_>>();
    let subscription_filter = gossipsub::WhitelistSubscriptionFilter(allowlisted_topics);

    gossipsub::Behaviour::new_with_subscription_filter(
        gossipsub::MessageAuthenticity::Anonymous,
        config,
        subscription_filter,
    )
    .map_err(to_p2p_err)
}

/// Parse an `enode://` URL into a multiaddr for direct dialing.
///
/// Accepts `enode://<hex-pubkey>@<ip>:<tcp-port>[?discport=<udp>]` and returns
/// `/ip4/{ip}/tcp/{port}` (or `/ip6/…`). The pubkey and optional discport query
/// are intentionally ignored — we only need the TCP dial address.
fn parse_enode_url(url: &str) -> Option<Multiaddr> {
    let rest = url.strip_prefix("enode://")?;
    let (_, host_part) = rest.split_once('@')?;
    let host_port = host_part.split('?').next()?;
    let sock: std::net::SocketAddr = host_port.parse().ok()?;
    let scheme = if sock.ip().is_ipv4() { "ip4" } else { "ip6" };
    format!("/{scheme}/{}/tcp/{}", sock.ip(), sock.port()).parse().ok()
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

        if value.starts_with("enode://") {
            match parse_enode_url(value) {
                Some(addr) => classified.dial_addrs.push(addr),
                None => warn!(bootnode = %value, "failed to parse enode:// URL"),
            }
            continue;
        }

        match value.parse::<Multiaddr>() {
            Ok(addr) => classified.dial_addrs.push(addr),
            Err(err) => {
                warn!(
                    bootnode = %value,
                    error = %err,
                    "invalid bootnode entry; expected ENR, enode://, or multiaddr"
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

    dial_addr(swarm, addr, source);
}

/// Dial a peer address, recording metrics regardless of prior attempts.
fn dial_retry(swarm: &mut Swarm<Behaviour>, addr: Multiaddr, source: &str) {
    dial_addr(swarm, addr, source);
}

/// Shared dial path with metrics/logging.
fn dial_addr(swarm: &mut Swarm<Behaviour>, addr: Multiaddr, source: &str) {
    metrics::counter!(
        WhitelistPreconfirmationDriverMetrics::NETWORK_DIAL_ATTEMPTS_TOTAL,
        "source" => source.to_string(),
    )
    .increment(1);

    if let Err(err) = swarm.dial(addr.clone()) {
        metrics::counter!(
            WhitelistPreconfirmationDriverMetrics::NETWORK_DIAL_FAILURES_TOTAL,
            "source" => source.to_string(),
        )
        .increment(1);
        warn!(%addr, source, error = %err, "failed to dial address");
    }
}

/// Extract a `PeerId` from a `/p2p/<peer-id>` multiaddr suffix.
fn peer_id_from_multiaddr(addr: &Multiaddr) -> Option<PeerId> {
    addr.iter().find_map(|protocol| match protocol {
        libp2p::multiaddr::Protocol::P2p(peer_id) => Some(peer_id),
        _ => None,
    })
}

/// Receive one discovery event, if discovery is enabled.
async fn recv_discovered_multiaddr(
    discovery_rx: &mut Option<mpsc::Receiver<Multiaddr>>,
) -> Option<Multiaddr> {
    discovery_rx.as_mut()?.recv().await
}

/// Handle a swarm event.
async fn handle_swarm_event(
    swarm: &mut Swarm<Behaviour>,
    event: libp2p::swarm::SwarmEvent<BehaviourEvent>,
    topics: &Topics,
    event_tx: &mpsc::Sender<NetworkEvent>,
    inbound_validation: &mut InboundValidationState,
) -> Result<()> {
    match event {
        libp2p::swarm::SwarmEvent::Behaviour(BehaviourEvent::Gossipsub(event)) => {
            handle_gossipsub_event(
                &mut swarm.behaviour_mut().gossipsub,
                *event,
                topics,
                event_tx,
                inbound_validation,
            )
            .await?;
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
    gossipsub: &mut WhitelistGossipsub,
    event: gossipsub::Event,
    topics: &Topics,
    event_tx: &mpsc::Sender<NetworkEvent>,
    inbound_validation: &mut InboundValidationState,
) -> Result<()> {
    let gossipsub::Event::Message { propagation_source, message_id, message } = event else {
        return Ok(());
    };

    let topic = &message.topic;
    let from = propagation_source;

    if *topic == topics.preconf_blocks.hash() {
        match decode_unsafe_payload_message(&message.data) {
            Ok(payload) => {
                let block_number = payload.envelope.execution_payload.block_number;
                let block_hash = payload.envelope.execution_payload.block_hash;
                if !admit_or_ignore_message(
                    gossipsub,
                    &message_id,
                    &from,
                    inbound_validation.admit_preconf_payload(block_number, block_hash),
                    "preconf_blocks",
                ) {
                    return Ok(());
                }

                forward_decoded_event(
                    gossipsub,
                    &message_id,
                    &from,
                    event_tx,
                    "preconf_blocks",
                    NetworkEvent::UnsafePayload { from, payload },
                )
                .await?;
            }
            Err(err) => {
                report_decode_failure(
                    gossipsub,
                    &message_id,
                    &from,
                    "preconf_blocks",
                    "decode_failed",
                );
                debug!(error = %err, "failed to decode unsafe payload");
            }
        }
        return Ok(());
    }

    if *topic == topics.preconf_response.hash() {
        match decode_unsafe_response_message(&message.data) {
            Ok(envelope) => {
                let block_number = envelope.execution_payload.block_number;
                let block_hash = envelope.execution_payload.block_hash;
                if !admit_or_ignore_message(
                    gossipsub,
                    &message_id,
                    &from,
                    inbound_validation.admit_preconf_response(
                        block_number,
                        block_hash,
                        Instant::now(),
                    ),
                    "response_preconf_blocks",
                ) {
                    return Ok(());
                }

                forward_decoded_event(
                    gossipsub,
                    &message_id,
                    &from,
                    event_tx,
                    "response_preconf_blocks",
                    NetworkEvent::UnsafeResponse { from, envelope },
                )
                .await?;
            }
            Err(err) => {
                report_decode_failure(
                    gossipsub,
                    &message_id,
                    &from,
                    "response_preconf_blocks",
                    "decode_failed",
                );
                debug!(error = %err, "failed to decode unsafe response");
            }
        }
        return Ok(());
    }

    if *topic == topics.preconf_request.hash() {
        if message.data.len() == 32 {
            let hash = B256::from_slice(&message.data);
            if !admit_or_ignore_message(
                gossipsub,
                &message_id,
                &from,
                inbound_validation.admit_preconf_request(from, hash, Instant::now()),
                "request_preconf_blocks",
            ) {
                return Ok(());
            }

            forward_decoded_event(
                gossipsub,
                &message_id,
                &from,
                event_tx,
                "request_preconf_blocks",
                NetworkEvent::UnsafeRequest { from, hash },
            )
            .await?;
        } else {
            report_decode_failure(
                gossipsub,
                &message_id,
                &from,
                "request_preconf_blocks",
                "invalid_length",
            );
            debug!(len = message.data.len(), "invalid preconf request payload length");
        }
        return Ok(());
    }

    if *topic == topics.eos_request.hash() {
        if let Some(epoch) = decode_eos_epoch(&message.data) {
            if !admit_or_ignore_message(
                gossipsub,
                &message_id,
                &from,
                inbound_validation.admit_eos_request(from, epoch, Instant::now()),
                "request_eos_preconf_blocks",
            ) {
                return Ok(());
            }

            forward_decoded_event(
                gossipsub,
                &message_id,
                &from,
                event_tx,
                "request_eos_preconf_blocks",
                NetworkEvent::EndOfSequencingRequest { from, epoch },
            )
            .await?;
        } else {
            report_decode_failure(
                gossipsub,
                &message_id,
                &from,
                "request_eos_preconf_blocks",
                "invalid_length",
            );
            debug!(len = message.data.len(), "invalid end-of-sequencing payload length");
        }
        return Ok(());
    }

    report_ignore_with_metric(gossipsub, &message_id, &from, "unknown", "ignored");
    debug!(topic = topic.as_str(), "ignoring message on unknown whitelist topic");
    Ok(())
}

/// Count one inbound gossipsub message result by topic.
fn record_inbound_message(topic: &'static str, result: &'static str) {
    metrics::counter!(
        WhitelistPreconfirmationDriverMetrics::NETWORK_INBOUND_MESSAGES_TOTAL,
        "topic" => topic,
        "result" => result,
    )
    .increment(1);
}

/// Report ignored message and emit corresponding inbound metric.
fn report_ignore_with_metric(
    gossipsub: &mut WhitelistGossipsub,
    message_id: &gossipsub::MessageId,
    from: &PeerId,
    topic: &'static str,
    result: &'static str,
) {
    report_message_validation(gossipsub, message_id, from, gossipsub::MessageAcceptance::Ignore);
    record_inbound_message(topic, result);
}

/// Report rejected message due to decode/shape failure and emit failure metrics.
fn report_decode_failure(
    gossipsub: &mut WhitelistGossipsub,
    message_id: &gossipsub::MessageId,
    from: &PeerId,
    topic: &'static str,
    result: &'static str,
) {
    report_message_validation(gossipsub, message_id, from, gossipsub::MessageAcceptance::Reject);
    record_inbound_message(topic, result);
    metrics::counter!(
        WhitelistPreconfirmationDriverMetrics::NETWORK_DECODE_FAILURES_TOTAL,
        "topic" => topic,
    )
    .increment(1);
}

/// Handle an admission decision, reporting Ignore + metrics when the message is not accepted.
fn admit_or_ignore_message(
    gossipsub: &mut WhitelistGossipsub,
    message_id: &gossipsub::MessageId,
    from: &PeerId,
    decision: AdmissionDecision,
    topic: &'static str,
) -> bool {
    match decision {
        AdmissionDecision::Accept => true,
        AdmissionDecision::DuplicateLimited => {
            report_ignore_with_metric(gossipsub, message_id, from, topic, "duplicate_limited");
            false
        }
        AdmissionDecision::RateLimited => {
            report_ignore_with_metric(gossipsub, message_id, from, topic, "rate_limited");
            false
        }
    }
}

/// Forward an already-decoded/admitted message and report gossipsub validation outcome.
async fn forward_decoded_event(
    gossipsub: &mut WhitelistGossipsub,
    message_id: &gossipsub::MessageId,
    from: &PeerId,
    event_tx: &mpsc::Sender<NetworkEvent>,
    topic: &'static str,
    event: NetworkEvent,
) -> Result<()> {
    record_inbound_message(topic, "decoded");
    if let Err(err) = forward_event(event_tx, event).await {
        report_message_validation(
            gossipsub,
            message_id,
            from,
            gossipsub::MessageAcceptance::Ignore,
        );
        return Err(err);
    }

    report_message_validation(gossipsub, message_id, from, gossipsub::MessageAcceptance::Accept);
    Ok(())
}

/// Report gossipsub message validation result for a previously received message.
fn report_message_validation(
    gossipsub: &mut WhitelistGossipsub,
    message_id: &gossipsub::MessageId,
    from: &PeerId,
    acceptance: gossipsub::MessageAcceptance,
) {
    if !gossipsub.report_message_validation_result(message_id, from, acceptance) {
        debug!(
            message_id = %message_id,
            peer = %from,
            "gossipsub message no longer in validation cache when reporting outcome"
        );
    }
}

/// Decode an end-of-sequencing request epoch from fixed-width big-endian bytes.
fn decode_eos_epoch(payload: &[u8]) -> Option<u64> {
    if payload.len() != std::mem::size_of::<u64>() {
        return None;
    }

    let mut bytes = [0u8; std::mem::size_of::<u64>()];
    bytes.copy_from_slice(payload);
    Some(u64::from_be_bytes(bytes))
}

/// Forward one decoded event to the importer with backpressure.
async fn forward_event(event_tx: &mpsc::Sender<NetworkEvent>, event: NetworkEvent) -> Result<()> {
    event_tx.send(event).await.map_err(|err| {
        metrics::counter!(WhitelistPreconfirmationDriverMetrics::NETWORK_FORWARD_FAILURES_TOTAL)
            .increment(1);
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

/// Parse a hex-encoded 32-byte ed25519 secret key into a libp2p identity keypair.
fn parse_ed25519_private_key(raw: &str) -> Result<identity::Keypair> {
    let stripped = raw.strip_prefix("0x").unwrap_or(raw);
    let mut bytes = alloy_primitives::hex::decode(stripped).map_err(|err| {
        WhitelistPreconfirmationDriverError::P2p(format!(
            "invalid hex in p2p network private key: {err}"
        ))
    })?;
    if bytes.len() != 32 {
        return Err(WhitelistPreconfirmationDriverError::P2p(format!(
            "p2p network private key must be 32 bytes, got {}",
            bytes.len()
        )));
    }

    identity::Keypair::ed25519_from_bytes(bytes.as_mut_slice()).map_err(|err| {
        WhitelistPreconfirmationDriverError::P2p(format!(
            "failed to decode p2p network private key: {err}"
        ))
    })
}

#[cfg(test)]
mod tests {
    use std::time::{Duration, Instant};

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
    fn parse_ed25519_private_key_accepts_hex_seed() {
        let key_bytes = [0x11u8; 32];
        let key_hex = alloy_primitives::hex::encode(key_bytes);

        let keypair_a = parse_ed25519_private_key(&key_hex).expect("valid private key");
        let keypair_b = parse_ed25519_private_key(&key_hex).expect("valid private key");
        assert_eq!(keypair_a.public().to_peer_id(), keypair_b.public().to_peer_id());
    }

    #[test]
    fn parse_ed25519_private_key_rejects_invalid_length() {
        let err = parse_ed25519_private_key("0xdeadbeef").expect_err("short key must fail");
        assert!(matches!(
            err,
            crate::error::WhitelistPreconfirmationDriverError::P2p(msg)
                if msg.contains("must be 32 bytes")
        ));
    }

    #[test]
    fn decode_eos_epoch_accepts_u64_be_bytes() {
        let epoch = 42u64;
        assert_eq!(decode_eos_epoch(&epoch.to_be_bytes()), Some(epoch));
    }

    #[test]
    fn decode_eos_epoch_rejects_non_u64_lengths() {
        assert_eq!(decode_eos_epoch(&[]), None);
        assert_eq!(decode_eos_epoch(&[0u8; 7]), None);
        assert_eq!(decode_eos_epoch(&[0u8; 9]), None);
    }

    #[test]
    fn inbound_validation_limits_duplicate_preconf_requests() {
        let mut state = InboundValidationState::default();
        let peer = PeerId::random();
        let hash = B256::from([0xabu8; 32]);
        let now = Instant::now();

        assert_eq!(state.admit_preconf_request(peer, hash, now), AdmissionDecision::Accept);
        assert_eq!(
            state.admit_preconf_request(peer, hash, now + Duration::from_secs(1)),
            AdmissionDecision::DuplicateLimited
        );
        assert_eq!(
            state.admit_preconf_request(
                peer,
                hash,
                now + PRECONF_REQUEST_DUPLICATE_WINDOW + Duration::from_secs(1),
            ),
            AdmissionDecision::Accept
        );
    }

    #[test]
    fn inbound_validation_rate_limits_requests_per_peer() {
        let mut state = InboundValidationState::default();
        let peer = PeerId::random();
        let now = Instant::now();

        for index in 0..REQUEST_REFILL_PER_MIN {
            let hash = B256::from(U256::from(index).to_be_bytes::<32>());
            assert_eq!(state.admit_preconf_request(peer, hash, now), AdmissionDecision::Accept);
        }

        let limited_hash = B256::from([0xedu8; 32]);
        assert_eq!(
            state.admit_preconf_request(peer, limited_hash, now),
            AdmissionDecision::RateLimited
        );
    }

    #[test]
    fn inbound_validation_uses_independent_rate_buckets_per_request_topic() {
        let mut state = InboundValidationState::default();
        let peer = PeerId::random();
        let now = Instant::now();

        for index in 0..REQUEST_REFILL_PER_MIN {
            let hash = B256::from(U256::from(index).to_be_bytes::<32>());
            assert_eq!(state.admit_preconf_request(peer, hash, now), AdmissionDecision::Accept);
        }

        assert_eq!(
            state.admit_preconf_request(peer, B256::from([0x11u8; 32]), now),
            AdmissionDecision::RateLimited
        );
        assert_eq!(state.admit_eos_request(peer, 1, now), AdmissionDecision::Accept);
    }

    #[test]
    fn inbound_validation_limits_per_epoch_eos_duplicates() {
        let mut state = InboundValidationState::default();
        let peer = PeerId::random();
        let epoch = 77u64;
        let now = Instant::now();

        for _ in 0..MAX_EOS_REQUESTS_PER_EPOCH {
            assert_eq!(state.admit_eos_request(peer, epoch, now), AdmissionDecision::Accept);
        }
        assert_eq!(state.admit_eos_request(peer, epoch, now), AdmissionDecision::DuplicateLimited);
    }

    #[test]
    fn inbound_validation_caps_duplicates_per_height() {
        let mut state = InboundValidationState::default();
        let height = 10;
        let hash = B256::from([0x44u8; 32]);
        let now = Instant::now();

        for _ in 0..MAX_PRECONF_BLOCK_DUPLICATES_PER_HEIGHT {
            assert_eq!(state.admit_preconf_payload(height, hash), AdmissionDecision::Accept);
        }
        assert_eq!(state.admit_preconf_payload(height, hash), AdmissionDecision::DuplicateLimited);

        for index in 0..MAX_PRECONF_RESPONSE_DUPLICATES_PER_HEIGHT {
            let at = now
                + Duration::from_secs((PRECONF_RESPONSE_SEEN_WINDOW.as_secs() + 1) * (index + 1));
            assert_eq!(state.admit_preconf_response(height, hash, at), AdmissionDecision::Accept);
        }
        let capped_at = now
            + Duration::from_secs(
                (PRECONF_RESPONSE_SEEN_WINDOW.as_secs() + 1)
                    * (MAX_PRECONF_RESPONSE_DUPLICATES_PER_HEIGHT + 2),
            );
        assert_eq!(
            state.admit_preconf_response(height, hash, capped_at),
            AdmissionDecision::DuplicateLimited
        );
    }

    #[test]
    fn inbound_validation_caps_distinct_hashes_per_height() {
        let mut state = InboundValidationState::default();
        let height = 1_234;

        for index in 0..MAX_DISTINCT_HASHES_PER_HEIGHT {
            let hash = B256::from(U256::from(index).to_be_bytes::<32>());
            assert_eq!(state.admit_preconf_payload(height, hash), AdmissionDecision::Accept);
        }

        let overflow_hash = B256::from([0xFEu8; 32]);
        assert_eq!(
            state.admit_preconf_payload(height, overflow_hash),
            AdmissionDecision::DuplicateLimited
        );

        let existing_hash = B256::from(U256::from(0u64).to_be_bytes::<32>());
        assert_eq!(state.admit_preconf_payload(height, existing_hash), AdmissionDecision::Accept);
    }

    #[test]
    fn inbound_validation_dedups_recent_response_hashes() {
        let mut state = InboundValidationState::default();
        let height = 99;
        let hash = B256::from([0x66u8; 32]);
        let now = Instant::now();

        assert_eq!(state.admit_preconf_response(height, hash, now), AdmissionDecision::Accept);
        assert_eq!(
            state.admit_preconf_response(height, hash, now + Duration::from_secs(1)),
            AdmissionDecision::DuplicateLimited
        );
        assert_eq!(
            state.admit_preconf_response(
                height,
                hash,
                now + PRECONF_RESPONSE_SEEN_WINDOW + Duration::from_secs(1),
            ),
            AdmissionDecision::Accept
        );
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
            gossipsub: WhitelistGossipsub,
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

        let mut gs = build_gossipsub(&Topics::new(chain_id)).expect("gossipsub config");
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
    async fn whitelist_network_loopbacks_published_unsafe_payload() {
        let mut cfg = P2pConfig::default();
        cfg.chain_id = 167_000;
        cfg.enable_discovery = false;
        cfg.enable_tcp = true;
        cfg.listen_addr = "127.0.0.1:0".parse().expect("listen addr");

        let mut whitelist_network = WhitelistNetwork::spawn(cfg).expect("spawn network");
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
            gossipsub: WhitelistGossipsub,
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

        let mut gs = build_gossipsub(&Topics::new(chain_id)).expect("gossipsub config");
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
            gossipsub: WhitelistGossipsub,
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

        let mut gs = build_gossipsub(&Topics::new(chain_id)).expect("gossipsub config");
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

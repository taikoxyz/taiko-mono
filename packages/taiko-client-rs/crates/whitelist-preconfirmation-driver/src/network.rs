//! Minimal libp2p network runtime for whitelist preconfirmation topics.

use std::{
    collections::{HashMap, HashSet},
    sync::Arc,
    time::{Duration, Instant},
};

use alloy_eips::{BlockId, BlockNumberOrTag};
use alloy_primitives::{Address, B256};
use alloy_provider::{
    Provider, RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers,
};
use futures::StreamExt;
use hashlink::LinkedHashMap;
use libp2p::{
    Multiaddr, PeerId, Swarm, Transport, core::upgrade, gossipsub, identify, identity, noise, ping,
    swarm::NetworkBehaviour, tcp, yamux,
};
use preconfirmation_net::{P2pConfig, spawn_discovery};
use sha2::{Digest, Sha256};
use tokio::{sync::mpsc, task::JoinHandle};
use tracing::{debug, warn};

use crate::{
    cache::WhitelistSequencerCache,
    codec::{
        DecodedUnsafePayload, WhitelistExecutionPayloadEnvelope, block_signing_hash,
        decode_unsafe_payload_message, decode_unsafe_response_message, encode_envelope_ssz,
        encode_eos_request_message, encode_unsafe_payload_message, encode_unsafe_request_message,
        encode_unsafe_response_message, recover_signer,
    },
    error::{Result, WhitelistPreconfirmationDriverError},
    metrics::WhitelistPreconfirmationDriverMetrics,
};
use bindings::preconf_whitelist::PreconfWhitelist::PreconfWhitelistInstance;
use rpc::client::Client as RpcClient;

type InboundWhitelistProvider = FillProvider<JoinedRecommendedFillers, RootProvider>;
type InboundWhitelistClient = RpcClient<InboundWhitelistProvider>;
type InboundWhitelistInstance = PreconfWhitelistInstance<InboundWhitelistProvider>;

/// Maximum allowed gossip payload size after decompression.
const MAX_GOSSIP_SIZE_BYTES: usize = kona_gossip::MAX_GOSSIP_SIZE;
const REQUEST_SEEN_WINDOW: Duration = Duration::from_secs(45);
const REQUEST_RATE_PER_MINUTE: f64 = 200.0;
const REQUEST_RATE_MAX_TOKENS: f64 = REQUEST_RATE_PER_MINUTE;
const REQUEST_RATE_REFILL_PER_SEC: f64 = REQUEST_RATE_PER_MINUTE / 60.0;
const MAX_RESPONSES_ACCEPTABLE: usize = 3;
const MAX_PRECONF_BLOCKS_PER_HEIGHT: usize = 10;
const PRECONF_INBOUND_LRU_CAPACITY: usize = 1000;
const MAX_STALE_FALLBACK_SECS: u64 = 12 * 64;
const SNAPSHOT_FETCH_MAX_ATTEMPTS: usize = 2;
/// Prefix used in Go-compatible message-id hashing for valid snappy payloads.
const MESSAGE_ID_PREFIX_VALID_SNAPPY: [u8; 4] = [1, 0, 0, 0];
/// Prefix used in Go-compatible message-id hashing for invalid snappy payloads.
const MESSAGE_ID_PREFIX_INVALID_SNAPPY: [u8; 4] = [0, 0, 0, 0];

#[derive(Debug)]
struct TokenBucket {
    tokens: f64,
    last_refill: Instant,
}

impl TokenBucket {
    fn new(now: Instant) -> Self {
        Self { tokens: REQUEST_RATE_MAX_TOKENS, last_refill: now }
    }

    fn refill(&mut self, now: Instant, refill_per_sec: f64, max_tokens: f64) {
        let elapsed = now.saturating_duration_since(self.last_refill).as_secs_f64();
        self.tokens = (self.tokens + elapsed * refill_per_sec).min(max_tokens);
        self.last_refill = now;
    }

    fn consume(&mut self, amount: f64) -> bool {
        if self.tokens < amount {
            return false;
        }
        self.tokens -= amount;
        true
    }
}

#[derive(Debug, Default)]
struct RateLimiter {
    buckets: HashMap<PeerId, TokenBucket>,
}

impl RateLimiter {
    fn prune(&mut self, now: Instant, window: Duration) {
        self.buckets
            .retain(|_, bucket| now.saturating_duration_since(bucket.last_refill) <= window);
    }

    fn allow(&mut self, from: PeerId, now: Instant) -> bool {
        self.prune(now, REQUEST_SEEN_WINDOW);

        let entry = self.buckets.entry(from).or_insert_with(|| TokenBucket::new(now));
        entry.refill(now, REQUEST_RATE_REFILL_PER_SEC, REQUEST_RATE_MAX_TOKENS);
        entry.consume(1.0)
    }
}

#[derive(Debug, Default)]
struct WindowedHashTracker {
    seen: LinkedHashMap<B256, Instant>,
}

impl WindowedHashTracker {
    fn is_seen(&mut self, hash: B256, now: Instant) -> bool {
        self.seen
            .retain(|_, seen_at| now.saturating_duration_since(*seen_at) < REQUEST_SEEN_WINDOW);
        self.seen.contains_key(&hash)
    }

    fn mark(&mut self, hash: B256, now: Instant) {
        self.seen.remove(&hash);
        self.seen.insert(hash, now);

        while self.seen.len() > PRECONF_INBOUND_LRU_CAPACITY {
            self.seen.pop_front();
        }
    }
}

#[derive(Debug, Default)]
struct HeightSeenTracker {
    seen_by_height: LinkedHashMap<u64, Vec<B256>>,
}

impl HeightSeenTracker {
    fn can_accept(&mut self, height: u64, hash: B256, max_per_height: usize) -> bool {
        if max_per_height == 0 {
            return false;
        }

        let hashes = self.seen_by_height.entry(height).or_insert_with(Vec::new);
        if hashes.len() > max_per_height {
            return false;
        }

        hashes.push(hash);
        if self.seen_by_height.len() > PRECONF_INBOUND_LRU_CAPACITY {
            self.seen_by_height.pop_front();
        }

        true
    }
}

#[derive(Debug, Default)]
struct EpochSeenTracker {
    seen_by_epoch: LinkedHashMap<u64, usize>,
}

impl EpochSeenTracker {
    fn can_accept(&self, epoch: u64, max_per_epoch: usize) -> bool {
        if max_per_epoch == 0 {
            return false;
        }

        match self.seen_by_epoch.get(&epoch) {
            Some(count) => *count <= max_per_epoch,
            None => true,
        }
    }

    fn mark(&mut self, epoch: u64) {
        let count = self.seen_by_epoch.entry(epoch).or_insert(0);
        *count += 1;

        if self.seen_by_epoch.len() > PRECONF_INBOUND_LRU_CAPACITY {
            self.seen_by_epoch.pop_front();
        }
    }
}

#[derive(Debug)]
struct CachedWhitelistedSequencers {
    current: Address,
    next: Address,
    any_from_cache: bool,
}

#[derive(Debug)]
struct CachedWhitelistSnapshot {
    current: Address,
    next: Address,
    current_epoch_start_timestamp: u64,
    block_timestamp: u64,
}

#[derive(Debug)]
struct InboundWhitelistFilter {
    whitelist: InboundWhitelistInstance,
    rpc_client: InboundWhitelistClient,
    sequencer_cache: WhitelistSequencerCache,
}

impl InboundWhitelistFilter {
    fn new(rpc_client: InboundWhitelistClient, whitelist_address: Address) -> Self {
        let whitelist =
            InboundWhitelistInstance::new(whitelist_address, rpc_client.l1_provider.clone());
        Self { whitelist, rpc_client, sequencer_cache: WhitelistSequencerCache::default() }
    }

    async fn ensure_signer_allowed(&mut self, signer: Address) -> Result<()> {
        let now = Instant::now();
        let result = self.cached_whitelist_sequencers(now).await?;

        if signer == result.current || signer == result.next {
            return Ok(());
        }

        if !result.any_from_cache {
            return Err(WhitelistPreconfirmationDriverError::InvalidSignature(format!(
                "signer {signer} is not current ({}) or next ({}) whitelist sequencer",
                result.current, result.next
            )));
        }

        if !self.sequencer_cache.allow_miss_refresh(now) {
            return Err(WhitelistPreconfirmationDriverError::InvalidSignature(format!(
                "signer {signer} is not current ({}) or next ({}) whitelist sequencer",
                result.current, result.next
            )));
        }

        debug!(
            %signer,
            cached_current = %result.current,
            cached_next = %result.next,
            "signer not in cached whitelist; re-fetching from L1"
        );
        self.sequencer_cache.invalidate();
        let fresh = self.cached_whitelist_sequencers(now).await?;
        if signer == fresh.current || signer == fresh.next {
            return Ok(());
        }

        Err(WhitelistPreconfirmationDriverError::InvalidSignature(format!(
            "signer {signer} is not current ({}) or next ({}) whitelist sequencer",
            fresh.current, fresh.next
        )))
    }

    async fn cached_whitelist_sequencers(
        &mut self,
        now: Instant,
    ) -> Result<CachedWhitelistedSequencers> {
        if let (Some(current), Some(next)) =
            (self.sequencer_cache.get_current(now), self.sequencer_cache.get_next(now))
        {
            return Ok(CachedWhitelistedSequencers { current, next, any_from_cache: true });
        }

        let snapshot = self.fetch_whitelist_snapshot_with_retry().await?;

        if let Err(err) = ensure_not_too_early_for_epoch(
            snapshot.block_timestamp,
            snapshot.current_epoch_start_timestamp,
        ) {
            if let Some((current, next)) = self
                .sequencer_cache
                .get_stale_pair_within(now, Duration::from_secs(MAX_STALE_FALLBACK_SECS))
            {
                debug!(
                    block_timestamp = snapshot.block_timestamp,
                    current_epoch_start_timestamp = snapshot.current_epoch_start_timestamp,
                    "using stale whitelist snapshot because latest block is before epoch start"
                );
                return Ok(CachedWhitelistedSequencers { current, next, any_from_cache: true });
            }
            return Err(err);
        }

        if !self.sequencer_cache.should_accept_block_timestamp(snapshot.block_timestamp) &&
            let Some((current, next)) = self
                .sequencer_cache
                .get_stale_pair_within(now, Duration::from_secs(MAX_STALE_FALLBACK_SECS))
        {
            debug!(
                block_timestamp = snapshot.block_timestamp,
                "ignoring regressive whitelist snapshot from lagging RPC node"
            );
            return Ok(CachedWhitelistedSequencers { current, next, any_from_cache: true });
        }

        self.sequencer_cache.set_pair(
            snapshot.current,
            snapshot.next,
            snapshot.current_epoch_start_timestamp,
            now,
        );

        Ok(CachedWhitelistedSequencers {
            current: snapshot.current,
            next: snapshot.next,
            any_from_cache: false,
        })
    }

    async fn fetch_whitelist_snapshot_with_retry(&self) -> Result<CachedWhitelistSnapshot> {
        for attempt in 1..=SNAPSHOT_FETCH_MAX_ATTEMPTS {
            match self.fetch_whitelist_snapshot().await {
                Ok(snapshot) => return Ok(snapshot),
                Err(err)
                    if attempt < SNAPSHOT_FETCH_MAX_ATTEMPTS &&
                        should_retry_snapshot_fetch(&err) =>
                {
                    debug!(
                        attempt,
                        max_attempts = SNAPSHOT_FETCH_MAX_ATTEMPTS,
                        error = %err,
                        "retrying whitelist snapshot fetch after transient inconsistency"
                    );
                }
                Err(err) => return Err(err),
            }
        }

        unreachable!("snapshot fetch loop must return on success or final error")
    }

    async fn fetch_whitelist_snapshot(&self) -> Result<CachedWhitelistSnapshot> {
        let latest_block = self
            .rpc_client
            .l1_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(|err| {
                whitelist_lookup_err(format!(
                    "failed to fetch latest block for whitelist snapshot: {err}"
                ))
            })?
            .ok_or_else(|| {
                whitelist_lookup_err(
                    "missing latest block while fetching whitelist snapshot".to_string(),
                )
            })?;

        let block_number = latest_block.header.number;
        let block_timestamp = latest_block.header.timestamp;
        let block_hash = latest_block.hash();

        let current_operator_fut = async {
            self.whitelist
                .getOperatorForCurrentEpoch()
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    whitelist_lookup_err(format!(
                        "failed to fetch current operator at block {block_number}: {err}"
                    ))
                })
        };
        let next_operator_fut = async {
            self.whitelist
                .getOperatorForNextEpoch()
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    whitelist_lookup_err(format!(
                        "failed to fetch next operator at block {block_number}: {err}"
                    ))
                })
        };
        let epoch_start_timestamp_fut = async {
            self.whitelist
                .epochStartTimestamp(Default::default())
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    whitelist_lookup_err(format!(
                        "failed to fetch epochStartTimestamp at block {block_number}: {err}"
                    ))
                })
        };

        let (current_proposer, next_proposer, current_epoch_start_timestamp) =
            tokio::try_join!(current_operator_fut, next_operator_fut, epoch_start_timestamp_fut,)?;

        let current_seq_fut = async {
            self.whitelist
                .operators(current_proposer)
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    whitelist_lookup_err(format!(
                        "failed to fetch current operators() entry at block {block_number}: {err}"
                    ))
                })
        };
        let next_seq_fut = async {
            self.whitelist
                .operators(next_proposer)
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    whitelist_lookup_err(format!(
                        "failed to fetch next operators() entry at block {block_number}: {err}"
                    ))
                })
        };
        let pinned_block_fut = async {
            self.rpc_client
                .l1_provider
                .get_block_by_number(BlockNumberOrTag::Number(block_number))
                .await
                .map_err(|err| {
                    whitelist_lookup_err(format!(
                        "failed to fetch pinned block {block_number} for whitelist verification: {err}"
                    ))
                })
        };

        let (current_seq, next_seq, pinned_block_opt): (
            bindings::preconf_whitelist::PreconfWhitelist::operatorsReturn,
            bindings::preconf_whitelist::PreconfWhitelist::operatorsReturn,
            _,
        ) = tokio::try_join!(current_seq_fut, next_seq_fut, pinned_block_fut)?;

        let pinned_block = pinned_block_opt.ok_or_else(|| {
            whitelist_lookup_err(format!(
                "missing pinned block {block_number} while verifying whitelist batches"
            ))
        })?;
        let pinned_block_hash = pinned_block.hash();
        if pinned_block_hash != block_hash {
            return Err(whitelist_lookup_err(format!(
                "block hash changed between whitelist batches at block {block_number}"
            )));
        }

        if current_seq.sequencerAddress == Address::ZERO ||
            next_seq.sequencerAddress == Address::ZERO
        {
            return Err(whitelist_lookup_err(
                "received zero address for whitelist sequencer".to_string(),
            ));
        }

        Ok(CachedWhitelistSnapshot {
            current: current_seq.sequencerAddress,
            next: next_seq.sequencerAddress,
            current_epoch_start_timestamp: u64::from(current_epoch_start_timestamp),
            block_timestamp,
        })
    }
}

/// Record and convert whitelist lookup failures into a driver error.
///
/// The helper centralizes metric updates for all snapshot/contract lookup failures.
fn whitelist_lookup_err(message: String) -> WhitelistPreconfirmationDriverError {
    metrics::counter!(WhitelistPreconfirmationDriverMetrics::WHITELIST_LOOKUP_FAILURES_TOTAL)
        .increment(1);
    WhitelistPreconfirmationDriverError::WhitelistLookup(message)
}

/// Return an error when the latest L1 block timestamp is before the epoch start.
///
/// This prevents callers from caching an epoch snapshot from an earlier epoch boundary.
fn ensure_not_too_early_for_epoch(
    block_timestamp: u64,
    current_epoch_start_timestamp: u64,
) -> Result<()> {
    if block_timestamp < current_epoch_start_timestamp {
        return Err(whitelist_lookup_err(format!(
            "whitelist batch returned block timestamp {block_timestamp} before epoch start \
             {current_epoch_start_timestamp}"
        )));
    }

    Ok(())
}

/// Classify whether a snapshot lookup error is transient and worth one retry.
fn should_retry_snapshot_fetch(err: &WhitelistPreconfirmationDriverError) -> bool {
    match err {
        WhitelistPreconfirmationDriverError::WhitelistLookup(message) => {
            let lower = message.to_ascii_lowercase();
            message.contains("block hash changed between whitelist batches") ||
                message.contains("missing pinned block") ||
                (message.contains("at block") &&
                    (lower.contains("not found") || lower.contains("unknown block")))
        }
        _ => false,
    }
}

#[derive(Debug, Default)]
struct GossipsubInboundState {
    chain_id: u64,
    request_rate: RateLimiter,
    request_seen: WindowedHashTracker,
    eos_rate: RateLimiter,
    eos_seen: EpochSeenTracker,
    preconf_seen_by_height: HeightSeenTracker,
    response_seen_by_height: HeightSeenTracker,
    whitelist_filter: Option<InboundWhitelistFilter>,
}

impl GossipsubInboundState {
    #[cfg(test)]
    fn new(chain_id: u64) -> Self {
        Self::new_with_whitelist_filter(chain_id, None, None)
    }

    fn new_with_whitelist_filter(
        chain_id: u64,
        l1_client: Option<InboundWhitelistClient>,
        whitelist_address: Option<Address>,
    ) -> Self {
        let whitelist_filter =
            l1_client.zip(whitelist_address).map(|(l1_client, whitelist_address)| {
                InboundWhitelistFilter::new(l1_client, whitelist_address)
            });

        Self {
            chain_id,
            request_rate: RateLimiter::default(),
            request_seen: WindowedHashTracker::default(),
            eos_rate: RateLimiter::default(),
            eos_seen: EpochSeenTracker::default(),
            preconf_seen_by_height: HeightSeenTracker::default(),
            response_seen_by_height: HeightSeenTracker::default(),
            whitelist_filter,
        }
    }

    fn validate_request(
        &mut self,
        from: PeerId,
        hash: B256,
        now: Instant,
    ) -> gossipsub::MessageAcceptance {
        if self.request_seen.is_seen(hash, now) {
            return gossipsub::MessageAcceptance::Ignore;
        }

        if !self.request_rate.allow(from, now) {
            return gossipsub::MessageAcceptance::Ignore;
        }

        self.request_seen.mark(hash, now);
        gossipsub::MessageAcceptance::Accept
    }

    fn validate_eos_request(
        &mut self,
        from: PeerId,
        epoch: u64,
        now: Instant,
    ) -> gossipsub::MessageAcceptance {
        if !self.eos_seen.can_accept(epoch, MAX_RESPONSES_ACCEPTABLE) {
            return gossipsub::MessageAcceptance::Ignore;
        }

        if !self.eos_rate.allow(from, now) {
            return gossipsub::MessageAcceptance::Ignore;
        }

        self.eos_seen.mark(epoch);

        gossipsub::MessageAcceptance::Accept
    }

    async fn validate_preconf_blocks(
        &mut self,
        payload: &DecodedUnsafePayload,
    ) -> gossipsub::MessageAcceptance {
        if payload.envelope.execution_payload.transactions.is_empty() ||
            payload.envelope.execution_payload.fee_recipient == Address::ZERO ||
            payload.envelope.execution_payload.block_number == 0
        {
            return gossipsub::MessageAcceptance::Reject;
        }

        let prehash = block_signing_hash(self.chain_id, payload.payload_bytes.as_slice());
        let signer = match recover_signer(prehash, &payload.wire_signature) {
            Ok(signer) => signer,
            Err(_) => return gossipsub::MessageAcceptance::Reject,
        };

        if let Some(filter) = self.whitelist_filter.as_mut() &&
            filter.ensure_signer_allowed(signer).await.is_err()
        {
            return gossipsub::MessageAcceptance::Reject;
        }

        let height = payload.envelope.execution_payload.block_number;
        let hash = payload.envelope.execution_payload.block_hash;

        if !self.preconf_seen_by_height.can_accept(height, hash, MAX_PRECONF_BLOCKS_PER_HEIGHT) {
            return gossipsub::MessageAcceptance::Ignore;
        }

        gossipsub::MessageAcceptance::Accept
    }

    async fn validate_response(
        &mut self,
        envelope: &crate::codec::WhitelistExecutionPayloadEnvelope,
    ) -> gossipsub::MessageAcceptance {
        let Some(signature) = envelope.signature else {
            return gossipsub::MessageAcceptance::Reject;
        };

        if envelope.execution_payload.transactions.is_empty() ||
            envelope.execution_payload.fee_recipient == Address::ZERO ||
            envelope.execution_payload.block_number == 0
        {
            return gossipsub::MessageAcceptance::Reject;
        }

        let prehash =
            block_signing_hash(self.chain_id, envelope.execution_payload.block_hash.as_slice());
        let signer = match recover_signer(prehash, &signature) {
            Ok(signer) => signer,
            Err(_) => return gossipsub::MessageAcceptance::Reject,
        };

        if let Some(filter) = self.whitelist_filter.as_mut() &&
            filter.ensure_signer_allowed(signer).await.is_err()
        {
            return gossipsub::MessageAcceptance::Reject;
        }

        let height = envelope.execution_payload.block_number;
        let hash = envelope.execution_payload.block_hash;
        if !self.response_seen_by_height.can_accept(height, hash, MAX_RESPONSES_ACCEPTABLE) {
            return gossipsub::MessageAcceptance::Ignore;
        }

        gossipsub::MessageAcceptance::Accept
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
    #[cfg(test)]
    pub fn spawn(cfg: P2pConfig) -> Result<Self> {
        Self::spawn_with_whitelist_filter(cfg, None, None)
    }

    pub(crate) fn spawn_with_whitelist_filter(
        cfg: P2pConfig,
        l1_client: Option<InboundWhitelistClient>,
        whitelist_address: Option<Address>,
    ) -> Result<Self> {
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

        let handle = tokio::spawn(async move {
            let mut inbound_validation_state = GossipsubInboundState::new_with_whitelist_filter(
                cfg.chain_id,
                l1_client,
                whitelist_address,
            );

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
                    event = swarm.select_next_some() => {
                        handle_swarm_event(
                            event,
                            &topics,
                            &event_tx,
                            &mut inbound_validation_state,
                            &mut swarm,
                        )
                        .await?;
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
        .validation_mode(gossipsub::ValidationMode::Permissive)
        .validate_messages()
        .heartbeat_interval(*kona_gossip::GOSSIP_HEARTBEAT)
        .duplicate_cache_time(*kona_gossip::SEEN_MESSAGES_TTL)
        .message_id_fn(message_id)
        .max_transmit_size(MAX_GOSSIP_SIZE_BYTES)
        .build()
        .map_err(to_p2p_err)?;

    gossipsub::Behaviour::new(gossipsub::MessageAuthenticity::Anonymous, config).map_err(to_p2p_err)
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
    inbound_validation_state: &mut GossipsubInboundState,
    swarm: &mut Swarm<Behaviour>,
) -> Result<()> {
    match event {
        libp2p::swarm::SwarmEvent::Behaviour(BehaviourEvent::Gossipsub(event)) => {
            handle_gossipsub_event(*event, topics, event_tx, inbound_validation_state, swarm)
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
    event: gossipsub::Event,
    topics: &Topics,
    event_tx: &mpsc::Sender<NetworkEvent>,
    inbound_validation_state: &mut GossipsubInboundState,
    swarm: &mut Swarm<Behaviour>,
) -> Result<()> {
    let gossipsub::Event::Message { propagation_source, message_id, message, .. } = event else {
        return Ok(());
    };

    let topic = &message.topic;
    let from = propagation_source;
    let now = Instant::now();

    let copy_acceptance =
        |acceptance: &gossipsub::MessageAcceptance| -> gossipsub::MessageAcceptance {
            match acceptance {
                gossipsub::MessageAcceptance::Accept => gossipsub::MessageAcceptance::Accept,
                gossipsub::MessageAcceptance::Ignore => gossipsub::MessageAcceptance::Ignore,
                gossipsub::MessageAcceptance::Reject => gossipsub::MessageAcceptance::Reject,
            }
        };

    let mut report = |acceptance: &gossipsub::MessageAcceptance| {
        let _ = swarm.behaviour_mut().gossipsub.report_message_validation_result(
            &message_id,
            &from,
            copy_acceptance(acceptance),
        );
    };
    let acceptance_label = |acceptance: &gossipsub::MessageAcceptance| match acceptance {
        gossipsub::MessageAcceptance::Accept => "accepted",
        gossipsub::MessageAcceptance::Ignore => "ignored",
        gossipsub::MessageAcceptance::Reject => "rejected",
    };

    if *topic == topics.preconf_blocks.hash() {
        let (acceptance, inbound_label) = match decode_unsafe_payload_message(&message.data) {
            Ok(payload) => {
                let acceptance = inbound_validation_state.validate_preconf_blocks(&payload).await;
                if matches!(acceptance, gossipsub::MessageAcceptance::Accept) &&
                    let Err(err) =
                        forward_event(event_tx, NetworkEvent::UnsafePayload { from, payload })
                            .await
                {
                    report(&gossipsub::MessageAcceptance::Reject);
                    return Err(err);
                }

                let inbound_label = acceptance_label(&acceptance);
                (acceptance, inbound_label)
            }
            Err(err) => {
                metrics::counter!(
                    WhitelistPreconfirmationDriverMetrics::NETWORK_DECODE_FAILURES_TOTAL,
                    "topic" => "preconf_blocks",
                )
                .increment(1);
                debug!(error = %err, "failed to decode unsafe payload");

                (gossipsub::MessageAcceptance::Reject, "decode_failed")
            }
        };

        metrics::counter!(
            WhitelistPreconfirmationDriverMetrics::NETWORK_INBOUND_MESSAGES_TOTAL,
            "topic" => "preconf_blocks",
            "result" => inbound_label,
        )
        .increment(1);
        report(&acceptance);
        return Ok(());
    }

    if *topic == topics.preconf_response.hash() {
        let (acceptance, inbound_label) = match decode_unsafe_response_message(&message.data) {
            Ok(envelope) => {
                let acceptance = inbound_validation_state.validate_response(&envelope).await;
                if matches!(acceptance, gossipsub::MessageAcceptance::Accept) &&
                    let Err(err) =
                        forward_event(event_tx, NetworkEvent::UnsafeResponse { from, envelope })
                            .await
                {
                    report(&gossipsub::MessageAcceptance::Reject);
                    return Err(err);
                }

                let inbound_label = acceptance_label(&acceptance);
                (acceptance, inbound_label)
            }
            Err(err) => {
                metrics::counter!(
                    WhitelistPreconfirmationDriverMetrics::NETWORK_DECODE_FAILURES_TOTAL,
                    "topic" => "response_preconf_blocks",
                )
                .increment(1);
                debug!(error = %err, "failed to decode unsafe response");

                (gossipsub::MessageAcceptance::Reject, "decode_failed")
            }
        };

        metrics::counter!(
            WhitelistPreconfirmationDriverMetrics::NETWORK_INBOUND_MESSAGES_TOTAL,
            "topic" => "response_preconf_blocks",
            "result" => inbound_label,
        )
        .increment(1);
        report(&acceptance);
        return Ok(());
    }

    if *topic == topics.preconf_request.hash() {
        let Some(hash) = decode_request_hash_exact(&message.data) else {
            metrics::counter!(
                WhitelistPreconfirmationDriverMetrics::NETWORK_DECODE_FAILURES_TOTAL,
                "topic" => "request_preconf_blocks",
            )
            .increment(1);
            let acceptance = gossipsub::MessageAcceptance::Reject;
            metrics::counter!(
                WhitelistPreconfirmationDriverMetrics::NETWORK_INBOUND_MESSAGES_TOTAL,
                "topic" => "request_preconf_blocks",
                "result" => acceptance_label(&acceptance),
            )
            .increment(1);
            report(&acceptance);
            return Ok(());
        };

        let acceptance = inbound_validation_state.validate_request(from, hash, now);
        if matches!(acceptance, gossipsub::MessageAcceptance::Accept) {
            forward_event(event_tx, NetworkEvent::UnsafeRequest { from, hash }).await?;
        }

        metrics::counter!(
            WhitelistPreconfirmationDriverMetrics::NETWORK_INBOUND_MESSAGES_TOTAL,
            "topic" => "request_preconf_blocks",
            "result" => acceptance_label(&acceptance),
        )
        .increment(1);
        report(&acceptance);
        return Ok(());
    }

    if *topic == topics.eos_request.hash() {
        let Some(epoch) = decode_eos_epoch_exact(&message.data) else {
            metrics::counter!(
                WhitelistPreconfirmationDriverMetrics::NETWORK_DECODE_FAILURES_TOTAL,
                "topic" => "request_eos_preconf_blocks",
            )
            .increment(1);
            let acceptance = gossipsub::MessageAcceptance::Reject;
            metrics::counter!(
                WhitelistPreconfirmationDriverMetrics::NETWORK_INBOUND_MESSAGES_TOTAL,
                "topic" => "request_eos_preconf_blocks",
                "result" => acceptance_label(&acceptance),
            )
            .increment(1);
            report(&acceptance);
            return Ok(());
        };

        let acceptance = inbound_validation_state.validate_eos_request(from, epoch, now);
        if matches!(acceptance, gossipsub::MessageAcceptance::Accept) {
            forward_event(event_tx, NetworkEvent::EndOfSequencingRequest { from, epoch }).await?;
        }

        metrics::counter!(
            WhitelistPreconfirmationDriverMetrics::NETWORK_INBOUND_MESSAGES_TOTAL,
            "topic" => "request_eos_preconf_blocks",
            "result" => acceptance_label(&acceptance),
        )
        .increment(1);
        report(&acceptance);
    }

    Ok(())
}

fn decode_eos_epoch_exact(payload: &[u8]) -> Option<u64> {
    if payload.len() != std::mem::size_of::<u64>() {
        return None;
    }

    let bytes: [u8; std::mem::size_of::<u64>()] = payload.try_into().ok()?;
    Some(u64::from_be_bytes(bytes))
}

fn decode_request_hash_exact(payload: &[u8]) -> Option<B256> {
    if payload.len() != std::mem::size_of::<B256>() {
        return None;
    }

    let bytes: [u8; std::mem::size_of::<B256>()] = payload.try_into().ok()?;
    Some(B256::from(bytes))
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

    fn decode_eos_epoch(payload: &[u8]) -> u64 {
        let mut bytes = [0u8; std::mem::size_of::<u64>()];
        let to_copy = payload.len().min(std::mem::size_of::<u64>());

        if to_copy > 0 {
            let source_start = payload.len() - to_copy;
            bytes[std::mem::size_of::<u64>() - to_copy..].copy_from_slice(&payload[source_start..]);
        }

        u64::from_be_bytes(bytes)
    }

    fn decode_request_hash(payload: &[u8]) -> B256 {
        let mut bytes = [0u8; std::mem::size_of::<B256>()];
        let to_copy = payload.len().min(std::mem::size_of::<B256>());

        if to_copy > 0 {
            let source_start = payload.len() - to_copy;
            bytes[std::mem::size_of::<B256>() - to_copy..]
                .copy_from_slice(&payload[source_start..]);
        }

        B256::from(bytes)
    }

    fn sample_preconf_payload() -> DecodedUnsafePayload {
        let envelope = sample_response_envelope();
        let payload_bytes = encode_envelope_ssz(&envelope);
        DecodedUnsafePayload { wire_signature: [0x11u8; 65], payload_bytes, envelope }
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
    fn height_seen_tracker_rejects_over_limit_and_skips_tracking_rejected_hashes() {
        let mut validation_state = GossipsubInboundState::new(167_000);

        assert!(validation_state.preconf_seen_by_height.can_accept(1, B256::from([1u8; 32]), 1));
        assert!(validation_state.preconf_seen_by_height.can_accept(1, B256::from([2u8; 32]), 1));
        assert!(!validation_state.preconf_seen_by_height.can_accept(1, B256::from([3u8; 32]), 1));
        assert_eq!(validation_state.preconf_seen_by_height.seen_by_height.len(), 1);
        assert_eq!(validation_state.preconf_seen_by_height.seen_by_height[&1].len(), 2);
        assert_eq!(
            validation_state.preconf_seen_by_height.seen_by_height[&1],
            vec![B256::from([1u8; 32]), B256::from([2u8; 32])]
        );

        assert!(!validation_state.preconf_seen_by_height.can_accept(2, B256::from([3u8; 32]), 0));
        assert_eq!(validation_state.preconf_seen_by_height.seen_by_height.len(), 1);
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

    #[tokio::test]
    async fn validate_preconf_blocks_rejects_empty_transaction_payload() {
        let mut validation_state = GossipsubInboundState::new(167_000);
        let mut payload = sample_preconf_payload();
        payload.envelope.execution_payload.transactions.clear();

        assert!(matches!(
            validation_state.validate_preconf_blocks(&payload).await,
            gossipsub::MessageAcceptance::Reject
        ));
    }

    #[tokio::test]
    async fn validate_preconf_blocks_rejects_invalid_signature() {
        let mut validation_state = GossipsubInboundState::new(167_000);
        let payload = sample_preconf_payload();

        assert!(matches!(
            validation_state.validate_preconf_blocks(&payload).await,
            gossipsub::MessageAcceptance::Reject
        ));
    }

    #[tokio::test]
    async fn validate_response_rejects_missing_signature() {
        let mut validation_state = GossipsubInboundState::new(167_000);
        let mut envelope = sample_response_envelope();
        envelope.signature = None;

        assert!(matches!(
            validation_state.validate_response(&envelope).await,
            gossipsub::MessageAcceptance::Reject
        ));
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
            ..P2pConfig::default()
        };

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
        let cfg = P2pConfig {
            chain_id: 167_000,
            enable_discovery: false,
            enable_tcp: true,
            listen_addr: "127.0.0.1:0".parse().expect("listen addr"),
            ..P2pConfig::default()
        };

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
            ..P2pConfig::default()
        };

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
            ..P2pConfig::default()
        };

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

//! Inbound message validation and rate-limiting for gossipsub topics.

use std::{
    collections::HashMap,
    time::{Duration, Instant},
};

use alloy_primitives::{Address, B256};
use hashlink::LinkedHashMap;
use libp2p::{PeerId, gossipsub};

use crate::codec::{DecodedUnsafePayload, block_signing_hash, recover_signer};

/// Time window for duplicate-seen hash tracking and request de-duplication.
const REQUEST_SEEN_WINDOW: Duration = Duration::from_secs(45);
/// Maximum request-rate in requests per minute for inbound gossipsub throttling.
const REQUEST_RATE_PER_MINUTE: f64 = 200.0;
/// Maximum number of tokens in each per-peer request limiter bucket.
const REQUEST_RATE_MAX_TOKENS: f64 = REQUEST_RATE_PER_MINUTE;
/// Request token refill rate in tokens-per-second.
const REQUEST_RATE_REFILL_PER_SEC: f64 = REQUEST_RATE_PER_MINUTE / 60.0;
/// Maximum responses accepted per epoch window.
const MAX_RESPONSES_ACCEPTABLE: usize = 3;
/// Maximum accepted preconfirmation payloads per execution layer height.
const MAX_PRECONF_BLOCKS_PER_HEIGHT: usize = 10;
/// Default bounded size for inbound dedupe and rate-limiter tracking maps.
const PRECONF_INBOUND_LRU_CAPACITY: usize = 1000;

#[derive(Debug)]
/// Token bucket state for a single peer.
struct TokenBucket {
    /// Remaining tokens in the bucket.
    tokens: f64,
    /// Last refill timestamp.
    last_refill: Instant,
}

impl TokenBucket {
    /// Construct a token bucket seeded to max capacity.
    fn new(now: Instant) -> Self {
        Self { tokens: REQUEST_RATE_MAX_TOKENS, last_refill: now }
    }

    /// Refill tokens based on elapsed wall time and max cap.
    fn refill(&mut self, now: Instant, refill_per_sec: f64, max_tokens: f64) {
        let elapsed = now.saturating_duration_since(self.last_refill).as_secs_f64();
        self.tokens = (self.tokens + elapsed * refill_per_sec).min(max_tokens);
        self.last_refill = now;
    }

    /// Attempt to spend one token; returns true when successful.
    fn consume(&mut self, amount: f64) -> bool {
        if self.tokens < amount {
            return false;
        }
        self.tokens -= amount;
        true
    }
}

#[derive(Debug, Default)]
/// Per-peer request-rate limiter.
pub(crate) struct RateLimiter {
    /// Active token buckets keyed by peer id.
    buckets: HashMap<PeerId, TokenBucket>,
}

impl RateLimiter {
    /// Allow only when peer has available request tokens.
    fn allow(&mut self, from: PeerId, now: Instant) -> bool {
        self.prune(now, REQUEST_SEEN_WINDOW);

        let entry = self.buckets.entry(from).or_insert_with(|| TokenBucket::new(now));
        entry.refill(now, REQUEST_RATE_REFILL_PER_SEC, REQUEST_RATE_MAX_TOKENS);
        entry.consume(1.0)
    }

    /// Drop buckets that have been inactive outside the configured window.
    fn prune(&mut self, now: Instant, window: Duration) {
        self.buckets
            .retain(|_, bucket| now.saturating_duration_since(bucket.last_refill) <= window);
    }
}

#[derive(Debug, Default)]
/// Hash tracker for seen request hashes.
struct WindowedHashTracker {
    /// Last seen timestamps for each hash.
    seen: LinkedHashMap<B256, Instant>,
}

impl WindowedHashTracker {
    /// Returns true when the hash was already seen inside the window.
    fn is_seen(&mut self, hash: B256, now: Instant) -> bool {
        self.seen
            .retain(|_, seen_at| now.saturating_duration_since(*seen_at) < REQUEST_SEEN_WINDOW);
        self.seen.contains_key(&hash)
    }

    /// Record a hash as seen at the given instant.
    fn mark(&mut self, hash: B256, now: Instant) {
        self.seen.remove(&hash);
        self.seen.insert(hash, now);

        while self.seen.len() > PRECONF_INBOUND_LRU_CAPACITY {
            self.seen.pop_front();
        }
    }
}

#[derive(Debug, Default)]
/// Height-window tracker for deduping payload hash per block height.
pub(crate) struct HeightSeenTracker {
    /// Seen hashes keyed by block height.
    pub(crate) seen_by_height: LinkedHashMap<u64, Vec<B256>>,
}

impl HeightSeenTracker {
    /// Whether another hash can be accepted for the supplied block height.
    pub(crate) fn can_accept(&mut self, height: u64, hash: B256, max_per_height: usize) -> bool {
        if self.seen_by_height.get(&height).is_some_and(|hashes| hashes.len() > max_per_height) {
            return false;
        }

        self.seen_by_height.entry(height).or_insert_with(Vec::new).push(hash);
        if self.seen_by_height.len() > PRECONF_INBOUND_LRU_CAPACITY {
            self.seen_by_height.pop_front();
        }

        true
    }
}

#[derive(Debug, Default)]
/// Epoch-window tracker for duplicate EOS request suppression.
pub(crate) struct EpochSeenTracker {
    /// Accepted EOS counts keyed by epoch.
    pub(crate) seen_by_epoch: LinkedHashMap<u64, usize>,
}

impl EpochSeenTracker {
    /// Whether another response for the epoch can still be accepted.
    pub(crate) fn can_accept(&self, epoch: u64, max_per_epoch: usize) -> bool {
        match self.seen_by_epoch.get(&epoch) {
            Some(count) => *count <= max_per_epoch,
            None => true,
        }
    }

    /// Increment EOS counter for the supplied epoch.
    pub(crate) fn mark(&mut self, epoch: u64) {
        let count = self.seen_by_epoch.entry(epoch).or_insert(0);
        *count += 1;

        if self.seen_by_epoch.len() > PRECONF_INBOUND_LRU_CAPACITY {
            self.seen_by_epoch.pop_front();
        }
    }
}

#[derive(Debug, Default)]
/// Aggregate state machine for inbound gossipsub message validation.
pub(crate) struct GossipsubInboundState {
    /// Chain ID for envelope signature domain.
    chain_id: u64,
    /// Explicit sequencer allowlist configured from CLI.
    sequencer_addresses: Vec<Address>,
    /// Whether to bypass sequencer allowlist checks.
    allow_all_sequencers: bool,
    /// Request-ratelimiter for `requestPreconfBlocks`.
    request_rate: RateLimiter,
    /// Duplicate filter for request payload hashes.
    request_seen: WindowedHashTracker,
    /// EOS request limiter per peer.
    eos_rate: RateLimiter,
    /// EOS duplicate filter by epoch.
    eos_seen: EpochSeenTracker,
    /// Deduplication by payload height for preconfirmation messages.
    pub(crate) preconf_seen_by_height: HeightSeenTracker,
    /// Deduplication by payload height for responses.
    response_seen_by_height: HeightSeenTracker,
}

impl GossipsubInboundState {
    /// Construct inbound state from p2p config with optional allow-all bypass.
    pub(crate) fn new_with_allow_all_sequencers(
        chain_id: u64,
        sequencer_addresses: Vec<Address>,
        allow_all_sequencers: bool,
    ) -> Self {
        Self {
            chain_id,
            sequencer_addresses,
            allow_all_sequencers,
            request_rate: RateLimiter::default(),
            request_seen: WindowedHashTracker::default(),
            eos_rate: RateLimiter::default(),
            eos_seen: EpochSeenTracker::default(),
            preconf_seen_by_height: HeightSeenTracker::default(),
            response_seen_by_height: HeightSeenTracker::default(),
        }
    }

    /// Validate a `requestPreconfBlocks` message.
    pub(crate) fn validate_request(
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

    /// Validate an EOS request message and apply quota limits.
    pub(crate) fn validate_eos_request(
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

    /// Validate a preconfirmation payload gossip message.
    pub(crate) fn validate_preconf_blocks(
        &mut self,
        payload: &DecodedUnsafePayload,
    ) -> gossipsub::MessageAcceptance {
        match self.validate_preconf_block_signer(&payload.wire_signature, &payload.payload_bytes) {
            gossipsub::MessageAcceptance::Accept => self.validate_preconf_block_payload(payload),
            other => other,
        }
    }

    /// Recover and validate signer for preconfirmation payloads.
    fn validate_preconf_block_signer(
        &mut self,
        wire_signature: &[u8; 65],
        payload_bytes: &[u8],
    ) -> gossipsub::MessageAcceptance {
        let prehash = block_signing_hash(self.chain_id, payload_bytes);
        let signer = match recover_signer(prehash, wire_signature) {
            Ok(signer) => signer,
            Err(_) => return gossipsub::MessageAcceptance::Reject,
        };

        self.validate_signer(signer)
    }

    /// Checks basic response envelope shape: non-empty transactions, non-zero
    /// fee recipient, and non-zero block number.
    pub(crate) fn validate_response_shape(
        envelope: &crate::codec::WhitelistExecutionPayloadEnvelope,
    ) -> bool {
        !envelope.execution_payload.transactions.is_empty() &&
            envelope.execution_payload.fee_recipient != Address::ZERO &&
            envelope.execution_payload.block_number != 0
    }

    /// Verifies that the envelope carries a valid signature from an allowed sequencer.
    pub(crate) fn verify_envelope_signer(
        &self,
        envelope: &crate::codec::WhitelistExecutionPayloadEnvelope,
    ) -> bool {
        let Some(signature) = envelope.signature else {
            return false;
        };

        let prehash =
            block_signing_hash(self.chain_id, envelope.execution_payload.block_hash.as_slice());

        let signer = match recover_signer(prehash, &signature) {
            Ok(signer) => signer,
            Err(_) => return false,
        };

        matches!(self.validate_signer(signer), gossipsub::MessageAcceptance::Accept)
    }

    /// Validate payload fields and per-height uniqueness.
    fn validate_preconf_block_payload(
        &mut self,
        payload: &DecodedUnsafePayload,
    ) -> gossipsub::MessageAcceptance {
        if !Self::validate_response_shape(&payload.envelope) {
            return gossipsub::MessageAcceptance::Reject;
        }

        let height = payload.envelope.execution_payload.block_number;
        let hash = payload.envelope.execution_payload.block_hash;

        if !self.preconf_seen_by_height.can_accept(height, hash, MAX_PRECONF_BLOCKS_PER_HEIGHT) {
            return gossipsub::MessageAcceptance::Ignore;
        }

        gossipsub::MessageAcceptance::Accept
    }

    /// Validate a response payload including signature and signer authorization.
    pub(crate) fn validate_response(
        &mut self,
        envelope: &crate::codec::WhitelistExecutionPayloadEnvelope,
    ) -> gossipsub::MessageAcceptance {
        if !Self::validate_response_shape(envelope) || !self.verify_envelope_signer(envelope) {
            return gossipsub::MessageAcceptance::Reject;
        }

        let height = envelope.execution_payload.block_number;
        let hash = envelope.execution_payload.block_hash;
        if !self.response_seen_by_height.can_accept(height, hash, MAX_RESPONSES_ACCEPTABLE) {
            return gossipsub::MessageAcceptance::Ignore;
        }

        gossipsub::MessageAcceptance::Accept
    }

    /// Validate a recovered signer against the static sequencer allowlist.
    fn validate_signer(&self, signer: Address) -> gossipsub::MessageAcceptance {
        if self.allow_all_sequencers || self.sequencer_addresses.contains(&signer) {
            gossipsub::MessageAcceptance::Accept
        } else {
            gossipsub::MessageAcceptance::Reject
        }
    }
}

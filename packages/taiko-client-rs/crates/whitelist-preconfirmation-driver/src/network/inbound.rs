//! Inbound validation state for the whitelist preconfirmation network.

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
/// Time window for response suppression after a matching response has been observed.
const RESPONSE_SEEN_WINDOW: Duration = Duration::from_secs(10);
/// Maximum request-rate in requests per minute for inbound gossipsub throttling.
const REQUEST_RATE_PER_MINUTE: f64 = 200.0;
/// Maximum number of tokens in each per-peer request limiter bucket.
const REQUEST_RATE_MAX_TOKENS: f64 = REQUEST_RATE_PER_MINUTE;
/// Request token refill rate in tokens-per-second.
const REQUEST_RATE_REFILL_PER_SEC: f64 = REQUEST_RATE_PER_MINUTE / 60.0;
/// Maximum responses accepted per epoch window.
const MAX_RESPONSES_ACCEPTABLE: usize = 3;
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
    pub(crate) fn allow(&mut self, from: PeerId, now: Instant) -> bool {
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
pub(crate) struct WindowedHashTracker {
    /// Retention window used when pruning stale hashes.
    window: Duration,
    /// Last seen timestamps for each hash.
    seen: LinkedHashMap<B256, Instant>,
}

impl WindowedHashTracker {
    /// Construct a hash tracker with the supplied retention window.
    pub(crate) fn new(window: Duration) -> Self {
        Self { window, seen: LinkedHashMap::new() }
    }

    /// Returns true when the hash was already seen inside the window.
    pub(crate) fn is_seen(&mut self, hash: B256, now: Instant) -> bool {
        self.seen.retain(|_, seen_at| now.saturating_duration_since(*seen_at) < self.window);
        self.seen.contains_key(&hash)
    }

    /// Record a hash as seen at the given instant.
    pub(crate) fn mark(&mut self, hash: B256, now: Instant) {
        self.seen.remove(&hash);
        self.seen.insert(hash, now);

        while self.seen.len() > PRECONF_INBOUND_LRU_CAPACITY {
            self.seen.pop_front();
        }
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
    /// Request-ratelimiter for `requestPreconfBlocks`.
    request_rate: RateLimiter,
    /// Duplicate filter for request payload hashes.
    request_seen: WindowedHashTracker,
    /// Duplicate filter for response payload hashes.
    response_seen: WindowedHashTracker,
    /// EOS request limiter per peer.
    eos_rate: RateLimiter,
    /// EOS duplicate filter by epoch.
    eos_seen: EpochSeenTracker,
}

impl GossipsubInboundState {
    /// Construct inbound state with signature-domain and dedupe/rate-limit tracking only.
    pub(crate) fn new(chain_id: u64) -> Self {
        Self {
            chain_id,
            request_rate: RateLimiter::default(),
            request_seen: WindowedHashTracker::new(REQUEST_SEEN_WINDOW),
            response_seen: WindowedHashTracker::new(RESPONSE_SEEN_WINDOW),
            eos_rate: RateLimiter::default(),
            eos_seen: EpochSeenTracker::default(),
        }
    }

    /// Construct inbound state from p2p config with optional allow-all bypass.
    pub(crate) fn new_with_allow_all_sequencers(
        chain_id: u64,
        _sequencer_addresses: Vec<Address>,
        _allow_all_sequencers: bool,
    ) -> Self {
        Self::new(chain_id)
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
        match recover_signer(prehash, wire_signature) {
            Ok(_) => gossipsub::MessageAcceptance::Accept,
            Err(_) => gossipsub::MessageAcceptance::Reject,
        }
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

    /// Verifies that the envelope carries a valid cryptographic signature.
    pub(crate) fn verify_envelope_signer(
        &self,
        envelope: &crate::codec::WhitelistExecutionPayloadEnvelope,
    ) -> bool {
        let Some(signature) = envelope.signature else {
            return false;
        };

        let prehash =
            block_signing_hash(self.chain_id, envelope.execution_payload.block_hash.as_slice());

        recover_signer(prehash, &signature).is_ok()
    }

    /// Validate payload fields and per-height uniqueness.
    fn validate_preconf_block_payload(
        &mut self,
        payload: &DecodedUnsafePayload,
    ) -> gossipsub::MessageAcceptance {
        if !Self::validate_response_shape(&payload.envelope) {
            return gossipsub::MessageAcceptance::Reject;
        }

        gossipsub::MessageAcceptance::Accept
    }

    /// Validate a response payload including signature and basic payload shape.
    pub(crate) fn validate_response(
        &mut self,
        envelope: &crate::codec::WhitelistExecutionPayloadEnvelope,
    ) -> gossipsub::MessageAcceptance {
        if !Self::validate_response_shape(envelope) || !self.verify_envelope_signer(envelope) {
            return gossipsub::MessageAcceptance::Reject;
        }

        gossipsub::MessageAcceptance::Accept
    }

    /// Record that a matching `responsePreconfBlocks` payload hash has been observed.
    pub(crate) fn mark_response_seen(&mut self, hash: B256, now: Instant) {
        self.response_seen.mark(hash, now);
    }

    /// Return true when a matching `responsePreconfBlocks` payload hash was seen recently.
    pub(crate) fn response_seen_recently(&mut self, hash: B256, now: Instant) -> bool {
        self.response_seen.is_seen(hash, now)
    }
}

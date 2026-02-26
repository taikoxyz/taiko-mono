//! Inbound validation and allowlist state for the whitelist preconfirmation network.

use std::{
    collections::HashMap,
    time::{Duration, Instant},
};

use alloy_primitives::{Address, B256};
use hashlink::LinkedHashMap;
use libp2p::{PeerId, gossipsub};

use crate::codec::{DecodedUnsafePayload, block_signing_hash, recover_signer};

/// Time window used to deduplicate recently seen request hashes.
const REQUEST_SEEN_WINDOW: Duration = Duration::from_secs(45);
/// Allowed requests per minute before peer throttling starts.
const REQUEST_RATE_PER_MINUTE: f64 = 200.0;
/// Maximum token bucket size for request-rate limiting.
const REQUEST_RATE_MAX_TOKENS: f64 = REQUEST_RATE_PER_MINUTE;
/// Request token refill rate, in tokens per second.
const REQUEST_RATE_REFILL_PER_SEC: f64 = REQUEST_RATE_PER_MINUTE / 60.0;
/// Maximum number of accepted response messages per epoch.
const MAX_RESPONSES_ACCEPTABLE: usize = 3;
/// Maximum number of accepted preconfirmation block messages per block height.
const MAX_PRECONF_BLOCKS_PER_HEIGHT: usize = 10;
/// Maximum number of entries retained by inbound LRU trackers.
const PRECONF_INBOUND_LRU_CAPACITY: usize = 1000;
/// Smallest amount of token state to recover while tracking request rates.
#[derive(Debug)]
struct TokenBucket {
    /// Remaining request tokens in this bucket.
    tokens: f64,
    /// Last time the bucket was refilled.
    last_refill: Instant,
}

impl TokenBucket {
    /// Builds a new token bucket initialized at full capacity.
    fn new(now: Instant) -> Self {
        Self { tokens: REQUEST_RATE_MAX_TOKENS, last_refill: now }
    }

    /// Replenishes tokens based on elapsed time.
    fn refill(&mut self, now: Instant, refill_per_sec: f64, max_tokens: f64) {
        let elapsed = now.saturating_duration_since(self.last_refill).as_secs_f64();
        self.tokens = (self.tokens + elapsed * refill_per_sec).min(max_tokens);
        self.last_refill = now;
    }

    /// Consumes a token amount and reports whether consumption succeeded.
    fn consume(&mut self, amount: f64) -> bool {
        if self.tokens < amount {
            return false;
        }
        self.tokens -= amount;
        true
    }
}

#[derive(Debug, Default)]
/// Tracks per-peer request token buckets.
pub(crate) struct RateLimiter {
    /// Current token buckets per peer id.
    buckets: HashMap<PeerId, TokenBucket>,
}

impl RateLimiter {
    /// Returns true if a peer is within request budget.
    pub(crate) fn allow(&mut self, from: PeerId, now: Instant) -> bool {
        self.prune(now, REQUEST_SEEN_WINDOW);

        let entry = self.buckets.entry(from).or_insert_with(|| TokenBucket::new(now));
        entry.refill(now, REQUEST_RATE_REFILL_PER_SEC, REQUEST_RATE_MAX_TOKENS);
        entry.consume(1.0)
    }

    /// Removes stale peer buckets outside the rolling window.
    fn prune(&mut self, now: Instant, window: Duration) {
        self.buckets
            .retain(|_, bucket| now.saturating_duration_since(bucket.last_refill) <= window);
    }
}

#[derive(Debug, Default)]
/// Tracks recently seen request hashes in a window with LRU eviction.
pub(crate) struct WindowedHashTracker {
    /// Map of hash -> last seen timestamp.
    seen: LinkedHashMap<B256, Instant>,
}

impl WindowedHashTracker {
    /// Checks whether a hash was seen recently.
    pub(crate) fn is_seen(&mut self, hash: B256, now: Instant) -> bool {
        self.seen
            .retain(|_, seen_at| now.saturating_duration_since(*seen_at) < REQUEST_SEEN_WINDOW);
        self.seen.contains_key(&hash)
    }

    /// Records a hash as seen at the provided time.
    pub(crate) fn mark(&mut self, hash: B256, now: Instant) {
        self.seen.remove(&hash);
        self.seen.insert(hash, now);

        while self.seen.len() > PRECONF_INBOUND_LRU_CAPACITY {
            self.seen.pop_front();
        }
    }
}

#[derive(Debug, Default)]
/// Tracks seen hashes for each block height in inbound preconf messages.
pub(crate) struct HeightSeenTracker {
    /// Map from block height to recent payload hashes.
    pub(crate) seen_by_height: LinkedHashMap<u64, Vec<B256>>,
}

impl HeightSeenTracker {
    /// Returns true if a hash for this height can be accepted.
    pub(crate) fn can_accept(&mut self, height: u64, hash: B256, max_per_height: usize) -> bool {
        if let Some(hashes) = self.seen_by_height.get(&height) &&
            hashes.len() > max_per_height
        {
            return false;
        }

        self.seen_by_height.entry(height).or_insert(Vec::new()).push(hash);
        if self.seen_by_height.len() > PRECONF_INBOUND_LRU_CAPACITY {
            self.seen_by_height.pop_front();
        }

        true
    }
}

#[derive(Debug, Default)]
/// Tracks counts per epoch for inbound EOS requests.
pub(crate) struct EpochSeenTracker {
    /// Map from epoch to seen request count.
    pub(crate) seen_by_epoch: LinkedHashMap<u64, usize>,
}

impl EpochSeenTracker {
    /// Returns true if another message for this epoch is allowed.
    pub(crate) fn can_accept(&self, epoch: u64, max_per_epoch: usize) -> bool {
        match self.seen_by_epoch.get(&epoch) {
            Some(count) => *count <= max_per_epoch,
            None => true,
        }
    }

    /// Increments seen count for an epoch.
    pub(crate) fn mark(&mut self, epoch: u64) {
        let count = self.seen_by_epoch.entry(epoch).or_insert(0);
        *count += 1;

        if self.seen_by_epoch.len() > PRECONF_INBOUND_LRU_CAPACITY {
            self.seen_by_epoch.pop_front();
        }
    }
}

#[derive(Debug, Default)]
/// Inbound gossipsub validation state for all preconfirmation message types.
pub(crate) struct GossipsubInboundState {
    /// Configured chain id used for message signing hash checks.
    chain_id: u64,
    /// Whether to accept messages from any sequencer regardless of allowlist.
    allow_all_sequencers: bool,
    /// Explicit allowlist of sequencer addresses.
    sequencer_addresses: Vec<Address>,
    /// Rate limiter for request topics.
    request_rate: RateLimiter,
    /// Recently seen request hashes.
    request_seen: WindowedHashTracker,
    /// Rate limiter for EOS request topics.
    eos_rate: RateLimiter,
    /// Seen tracker for EOS requests by epoch.
    eos_seen: EpochSeenTracker,
    /// Seen tracker for preconf blocks keyed by height.
    pub(crate) preconf_seen_by_height: HeightSeenTracker,
    /// Seen tracker for response messages keyed by height.
    response_seen_by_height: HeightSeenTracker,
}

impl GossipsubInboundState {
    /// Creates inbound state with the provided chain id and allowlist configuration.
    pub(crate) fn new(
        chain_id: u64,
        allow_all_sequencers: bool,
        sequencer_addresses: Vec<Address>,
    ) -> Self {
        Self {
            chain_id,
            allow_all_sequencers,
            sequencer_addresses,
            request_rate: RateLimiter::default(),
            request_seen: WindowedHashTracker::default(),
            eos_rate: RateLimiter::default(),
            eos_seen: EpochSeenTracker::default(),
            preconf_seen_by_height: HeightSeenTracker::default(),
            response_seen_by_height: HeightSeenTracker::default(),
        }
    }

    /// Validates an incoming request-preconfirmation payload.
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

    /// Validates an end-of-sequencing request by epoch and rate limits.
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

    /// Validates a preconfirmed block payload payload/signature/tracking.
    pub(crate) async fn validate_preconf_blocks(
        &mut self,
        payload: &DecodedUnsafePayload,
    ) -> gossipsub::MessageAcceptance {
        match self.validate_preconf_block_payload(payload).await {
            gossipsub::MessageAcceptance::Accept => {
                self.validate_preconf_block_signer(&payload.wire_signature, &payload.payload_bytes)
                    .await
            }
            other => other,
        }
    }

    /// Validates signer authenticity for a preconfirmation block.
    async fn validate_preconf_block_signer(
        &mut self,
        wire_signature: &[u8; 65],
        payload_bytes: &[u8],
    ) -> gossipsub::MessageAcceptance {
        let prehash = block_signing_hash(self.chain_id, payload_bytes);
        let signer = match recover_signer(prehash, wire_signature) {
            Ok(signer) => signer,
            Err(_) => return gossipsub::MessageAcceptance::Reject,
        };

        if !self.sequencer_is_allowed(&signer) {
            return gossipsub::MessageAcceptance::Reject;
        }

        gossipsub::MessageAcceptance::Accept
    }

    /// Returns true when the signer is allowed to send messages.
    fn sequencer_is_allowed(&self, signer: &Address) -> bool {
        self.allow_all_sequencers || self.sequencer_addresses.contains(signer)
    }

    /// Checks basic response envelope shape: non-empty transactions, non-zero
    /// fee recipient, and non-zero block number. Used by both the gossip and
    /// direct reqresp validation paths.
    pub(crate) fn validate_response_shape(
        envelope: &crate::codec::WhitelistExecutionPayloadEnvelope,
    ) -> bool {
        !envelope.execution_payload.transactions.is_empty() &&
            envelope.execution_payload.fee_recipient != Address::ZERO &&
            envelope.execution_payload.block_number != 0
    }

    /// Verifies that the envelope carries a valid signature from an allowed sequencer.
    ///
    /// This is the signer-only subset of [`validate_response`] and is used by the
    /// direct reqresp path to reject forged responses at the network layer before
    /// they reach the importer.
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

        self.sequencer_is_allowed(&signer)
    }

    /// Validates preconfirmation payload semantics and duplicate tracking.
    async fn validate_preconf_block_payload(
        &mut self,
        payload: &DecodedUnsafePayload,
    ) -> gossipsub::MessageAcceptance {
        if payload.envelope.execution_payload.transactions.is_empty() ||
            payload.envelope.execution_payload.fee_recipient == Address::ZERO ||
            payload.envelope.execution_payload.block_number == 0
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

    /// Validates an unsafe payload response envelope.
    pub(crate) async fn validate_response(
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
}

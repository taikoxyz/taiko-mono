//! Inbound message validation and rate-limiting for gossipsub topics.

use std::{
    collections::{HashMap, HashSet},
    sync::Arc,
    time::{Duration, Instant},
};

use arc_swap::ArcSwap;

use alloy_primitives::{Address, B256};
use hashlink::LinkedHashMap;
use libp2p::{PeerId, gossipsub};

use crate::codec::{DecodedUnsafePayload, block_signing_hash, recover_signer};

/// Idle window after which per-peer rate-limiter buckets are pruned.
const RATE_LIMITER_PRUNE_WINDOW: Duration = Duration::from_secs(45);
/// Maximum request-rate in requests per minute for inbound gossipsub throttling.
const REQUEST_RATE_PER_MINUTE: f64 = 200.0;
/// Maximum number of tokens in each per-peer request limiter bucket.
const REQUEST_RATE_MAX_TOKENS: f64 = REQUEST_RATE_PER_MINUTE;
/// Initial token balance granted to a newly observed peer.
///
/// Starting below the max bucket cap reduces burst amplification from
/// short-lived peers while still allowing a small immediate request burst.
const REQUEST_RATE_INITIAL_TOKENS: f64 = 40.0;
/// Request token refill rate in tokens-per-second.
const REQUEST_RATE_REFILL_PER_SEC: f64 = REQUEST_RATE_PER_MINUTE / 60.0;
/// Maximum responses accepted per epoch window.
const MAX_RESPONSES_ACCEPTABLE: usize = 3;
/// Maximum accepted preconfirmation payloads per execution layer height.
const MAX_PRECONF_BLOCKS_PER_HEIGHT: usize = 10;
/// Default bounded size for inbound dedupe and rate-limiter tracking maps.
const PRECONF_INBOUND_LRU_CAPACITY: usize = 1000;

/// Token bucket state for a single peer.
#[derive(Debug)]
struct TokenBucket {
    /// Remaining tokens in the bucket.
    tokens: f64,
    /// Last refill timestamp.
    last_refill: Instant,
}

impl TokenBucket {
    /// Construct a token bucket seeded to the configured initial balance.
    fn new(now: Instant) -> Self {
        Self { tokens: REQUEST_RATE_INITIAL_TOKENS, last_refill: now }
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

/// Per-peer request-rate limiter.
#[derive(Debug, Default)]
pub(crate) struct RateLimiter {
    /// Active token buckets keyed by peer id.
    buckets: HashMap<PeerId, TokenBucket>,
}

impl RateLimiter {
    /// Allow only when peer has available request tokens.
    fn allow(&mut self, from: PeerId, now: Instant) -> bool {
        self.prune(now, RATE_LIMITER_PRUNE_WINDOW);

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

/// Height-window tracker for deduping payload hash per block height.
#[derive(Debug, Default)]
pub(crate) struct HeightSeenTracker {
    /// Seen hashes keyed by block height.
    pub(crate) seen_by_height: LinkedHashMap<u64, Vec<B256>>,
}

impl HeightSeenTracker {
    /// Record one accepted hash for the supplied block height when capacity remains.
    ///
    /// Returns `true` only when the hash was recorded successfully.
    pub(crate) fn try_accept(&mut self, height: u64, hash: B256, max_per_height: usize) -> bool {
        if self.seen_by_height.get(&height).is_some_and(|hashes| hashes.len() >= max_per_height) {
            return false;
        }

        self.seen_by_height.entry(height).or_insert_with(Vec::new).push(hash);
        if self.seen_by_height.len() > PRECONF_INBOUND_LRU_CAPACITY {
            self.seen_by_height.pop_front();
        }

        true
    }
}

/// Epoch-window tracker for duplicate EOS request suppression.
#[derive(Debug, Default)]
pub(crate) struct EpochSeenTracker {
    /// Accepted EOS counts keyed by epoch.
    pub(crate) seen_by_epoch: LinkedHashMap<u64, usize>,
}

impl EpochSeenTracker {
    /// Whether another response for the epoch can still be accepted.
    pub(crate) fn can_accept(&self, epoch: u64, max_per_epoch: usize) -> bool {
        self.seen_by_epoch.get(&epoch).is_none_or(|count| *count < max_per_epoch)
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

/// Aggregate state machine for inbound gossipsub message validation.
#[derive(Debug)]
pub(crate) struct GossipsubInboundState {
    /// Chain ID for envelope signature domain.
    chain_id: u64,
    /// Lock-free shared set of allowed sequencer addresses, refreshed periodically from L1.
    operator_set: Arc<ArcSwap<HashSet<Address>>>,
    /// Request-ratelimiter for `requestPreconfBlocks`.
    request_rate: RateLimiter,
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
    /// Construct inbound state with a shared operator set for signer validation.
    pub(crate) fn new(chain_id: u64, operator_set: Arc<ArcSwap<HashSet<Address>>>) -> Self {
        Self {
            chain_id,
            operator_set,
            request_rate: RateLimiter::default(),
            eos_rate: RateLimiter::default(),
            eos_seen: EpochSeenTracker::default(),
            preconf_seen_by_height: HeightSeenTracker::default(),
            response_seen_by_height: HeightSeenTracker::default(),
        }
    }

    /// Validate a `requestPreconfBlocks` message.
    ///
    /// Repeated identical requests need no app-level dedupe: the message-id
    /// function hashes topic + data, so gossipsub's duplicate cache (120s)
    /// already drops them before they reach this handler. Only per-peer rate
    /// limiting remains.
    pub(crate) fn validate_request(
        &mut self,
        from: PeerId,
        now: Instant,
    ) -> gossipsub::MessageAcceptance {
        if !self.request_rate.allow(from, now) {
            return gossipsub::MessageAcceptance::Ignore;
        }

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

        accept_by_height(
            &mut self.preconf_seen_by_height,
            &payload.envelope,
            MAX_PRECONF_BLOCKS_PER_HEIGHT,
        )
    }

    /// Validate a response payload including signature and signer authorization.
    pub(crate) fn validate_response(
        &mut self,
        envelope: &crate::codec::WhitelistExecutionPayloadEnvelope,
    ) -> gossipsub::MessageAcceptance {
        if !Self::validate_response_shape(envelope) || !self.verify_envelope_signer(envelope) {
            return gossipsub::MessageAcceptance::Reject;
        }

        accept_by_height(&mut self.response_seen_by_height, envelope, MAX_RESPONSES_ACCEPTABLE)
    }

    /// Validate a recovered signer against the shared operator set.
    fn validate_signer(&self, signer: Address) -> gossipsub::MessageAcceptance {
        if self.operator_set.load().contains(&signer) {
            gossipsub::MessageAcceptance::Accept
        } else {
            gossipsub::MessageAcceptance::Reject
        }
    }
}

/// Record an envelope's height/hash in `tracker`, accepting unless capacity is full.
///
/// Returns [`gossipsub::MessageAcceptance::Accept`] when the hash was newly recorded
/// for its height, otherwise [`gossipsub::MessageAcceptance::Ignore`].
fn accept_by_height(
    tracker: &mut HeightSeenTracker,
    envelope: &crate::codec::WhitelistExecutionPayloadEnvelope,
    max_per_height: usize,
) -> gossipsub::MessageAcceptance {
    let height = envelope.execution_payload.block_number;
    let hash = envelope.execution_payload.block_hash;

    if tracker.try_accept(height, hash, max_per_height) {
        gossipsub::MessageAcceptance::Accept
    } else {
        gossipsub::MessageAcceptance::Ignore
    }
}

#[cfg(test)]
mod tests {
    use std::{collections::HashSet, sync::Arc, time::Duration};

    use alloy_primitives::{Address, B256};
    use arc_swap::ArcSwap;
    use libp2p::{PeerId, gossipsub::MessageAcceptance};

    use super::*;
    use crate::test_support::fixed_k_sign;

    /// Chain ID used across these tests; matches the signer domain.
    const CHAIN_ID: u64 = 167;

    /// `MessageAcceptance` does not implement `PartialEq` (it is defined in
    /// libp2p-gossipsub), so verdicts are compared by matching the `Accept`
    /// variant — the same pattern the handler itself uses (see
    /// `verify_envelope_signer`).
    fn is_accept(acceptance: MessageAcceptance) -> bool {
        matches!(acceptance, MessageAcceptance::Accept)
    }

    /// Builds an inbound state with the given operator addresses.
    fn state_with_operators(operators: &[Address]) -> GossipsubInboundState {
        let set: HashSet<Address> = operators.iter().copied().collect();
        GossipsubInboundState::new(CHAIN_ID, Arc::new(ArcSwap::from_pointee(set)))
    }

    /// Token bucket starts at 40 tokens and refills at 200/min: the initial
    /// burst is exactly 40, then requests are throttled until time passes.
    #[test]
    fn request_rate_allows_initial_burst_then_throttles() {
        let mut state = state_with_operators(&[]);
        let peer = PeerId::random();
        let start = Instant::now();

        for i in 0..40 {
            assert!(
                is_accept(state.validate_request(peer, start)),
                "request {i} within the 40-token initial burst must pass"
            );
        }
        assert!(
            !is_accept(state.validate_request(peer, start)),
            "41st request at t=0 must be throttled"
        );

        // 60s later the bucket refilled by 200 (capped at 200): a fresh burst passes.
        let later = start + Duration::from_secs(60);
        for i in 0..40 {
            assert!(
                is_accept(state.validate_request(peer, later)),
                "request {i} after refill must pass"
            );
        }
    }

    /// Rate limiting is per-peer: throttling peer A must not affect peer B.
    #[test]
    fn request_rate_is_per_peer() {
        let mut state = state_with_operators(&[]);
        let (a, b) = (PeerId::random(), PeerId::random());
        let now = Instant::now();
        for _ in 0..40 {
            state.validate_request(a, now);
        }
        assert!(!is_accept(state.validate_request(a, now)), "peer A is throttled");
        assert!(is_accept(state.validate_request(b, now)), "peer B is unaffected");
    }

    /// At most 10 distinct preconf blocks per height; the 11th distinct hash
    /// at the same height is refused, and duplicates never double-count.
    #[test]
    fn height_tracker_caps_at_ten_per_height() {
        let mut tracker = HeightSeenTracker::default();
        for i in 0..10u8 {
            assert!(tracker.try_accept(7, B256::repeat_byte(i), 10), "hash {i} under cap");
        }
        assert!(!tracker.try_accept(7, B256::repeat_byte(0xaa), 10), "11th hash refused");
        // A duplicate of an accepted hash is also refused (dedup, not re-count).
        assert!(!tracker.try_accept(7, B256::repeat_byte(0), 10), "duplicate refused");
        // Another height is unaffected.
        assert!(tracker.try_accept(8, B256::repeat_byte(0), 10));
    }

    /// EOS responses: 3 per epoch, then refused until a new epoch.
    #[test]
    fn epoch_tracker_caps_at_three_per_epoch() {
        let mut tracker = EpochSeenTracker::default();
        for _ in 0..3 {
            assert!(tracker.can_accept(5, 3));
            tracker.mark(5);
        }
        assert!(!tracker.can_accept(5, 3), "4th response in epoch 5 refused");
        assert!(tracker.can_accept(6, 3), "fresh epoch unaffected");

        // Accepting into epoch 6 must not re-open the exhausted epoch 5. The per-epoch
        // map makes this bleed-back structurally impossible today; the assert exists to
        // catch a future compaction to a single (last_epoch, count) pair, which would
        // silently reset the counter — and thus re-open old epochs — on any epoch change.
        tracker.mark(6);
        assert!(!tracker.can_accept(5, 3), "accepting epoch 6 must not re-open epoch 5");
    }

    /// Signs `payload_bytes` the way a publisher does and returns
    /// (wire_signature, recovered_signer_address). Self-consistent: the test
    /// registers the *recovered* address, so no v-byte convention is assumed.
    fn signed_payload(chain_id: u64, payload_bytes: &[u8]) -> ([u8; 65], Address) {
        let prehash = block_signing_hash(chain_id, payload_bytes);
        let signature = fixed_k_sign(prehash);
        let signer = recover_signer(prehash, &signature).expect("recoverable");
        (signature, signer)
    }

    /// An operator's signature is accepted; a non-operator's is rejected; a
    /// rotation via `ArcSwap::store` takes effect on the next message.
    ///
    /// `validate_preconf_block_signer` does not touch dedup state, but distinct
    /// payload bytes per call are used defensively so nothing but the operator
    /// set can decide the verdict.
    #[test]
    fn preconf_signer_gate_and_rotation() {
        let (signature, signer) = signed_payload(CHAIN_ID, b"payload-1");

        let set = Arc::new(ArcSwap::from_pointee(HashSet::from([signer])));
        let mut state = GossipsubInboundState::new(CHAIN_ID, set.clone());

        assert!(
            is_accept(state.validate_preconf_block_signer(&signature, b"payload-1")),
            "whitelisted signer accepted"
        );

        // Rotate the operator out (epoch boundary): a fresh signature over new
        // bytes from the same signer is now rejected.
        let (signature_2, signer_2) = signed_payload(CHAIN_ID, b"payload-2");
        assert_eq!(signer_2, signer, "same signer across payloads");
        set.store(Arc::new(HashSet::new()));
        assert!(
            !is_accept(state.validate_preconf_block_signer(&signature_2, b"payload-2")),
            "rotated-out signer rejected"
        );

        // Rotate back in: accepted again over yet-distinct bytes.
        let (signature_3, _) = signed_payload(CHAIN_ID, b"payload-3");
        set.store(Arc::new(HashSet::from([signer])));
        assert!(
            is_accept(state.validate_preconf_block_signer(&signature_3, b"payload-3")),
            "rotated-back-in signer accepted"
        );
    }

    /// A signature that recovers to an address absent from the operator set is
    /// rejected even when the recovery itself succeeds (pure signer gate).
    #[test]
    fn preconf_signer_gate_rejects_non_operator() {
        let (signature, signer) = signed_payload(CHAIN_ID, b"payload");
        // Operator set holds a different address, never the actual signer.
        let other = Address::repeat_byte(0xcd);
        assert_ne!(other, signer, "fixture must differ from the golden signer");

        let mut state = state_with_operators(&[other]);
        assert!(
            !is_accept(state.validate_preconf_block_signer(&signature, b"payload")),
            "signer absent from operator set must be rejected"
        );
    }
}

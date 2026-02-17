//! Inbound validation and allowlist state for the whitelist preconfirmation network.

use std::{
    collections::HashMap,
    time::{Duration, Instant},
};

use alloy_primitives::{Address, B256};
use hashlink::LinkedHashMap;
use libp2p::{PeerId, gossipsub};

use crate::{
    codec::{DecodedUnsafePayload, block_signing_hash, recover_signer},
};

const REQUEST_SEEN_WINDOW: Duration = Duration::from_secs(45);
const REQUEST_RATE_PER_MINUTE: f64 = 200.0;
const REQUEST_RATE_MAX_TOKENS: f64 = REQUEST_RATE_PER_MINUTE;
const REQUEST_RATE_REFILL_PER_SEC: f64 = REQUEST_RATE_PER_MINUTE / 60.0;
const MAX_RESPONSES_ACCEPTABLE: usize = 3;
const MAX_PRECONF_BLOCKS_PER_HEIGHT: usize = 10;
const PRECONF_INBOUND_LRU_CAPACITY: usize = 1000;
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
pub(crate) struct RateLimiter {
    buckets: HashMap<PeerId, TokenBucket>,
}

impl RateLimiter {
    fn allow(&mut self, from: PeerId, now: Instant) -> bool {
        self.prune(now, REQUEST_SEEN_WINDOW);

        let entry = self.buckets.entry(from).or_insert_with(|| TokenBucket::new(now));
        entry.refill(now, REQUEST_RATE_REFILL_PER_SEC, REQUEST_RATE_MAX_TOKENS);
        entry.consume(1.0)
    }

    fn prune(&mut self, now: Instant, window: Duration) {
        self.buckets
            .retain(|_, bucket| now.saturating_duration_since(bucket.last_refill) <= window);
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
pub(crate) struct HeightSeenTracker {
    pub(crate) seen_by_height: LinkedHashMap<u64, Vec<B256>>,
}

impl HeightSeenTracker {
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
pub(crate) struct EpochSeenTracker {
    pub(crate) seen_by_epoch: LinkedHashMap<u64, usize>,
}

impl EpochSeenTracker {
    pub(crate) fn can_accept(&self, epoch: u64, max_per_epoch: usize) -> bool {
        match self.seen_by_epoch.get(&epoch) {
            Some(count) => *count <= max_per_epoch,
            None => true,
        }
    }

    pub(crate) fn mark(&mut self, epoch: u64) {
        let count = self.seen_by_epoch.entry(epoch).or_insert(0);
        *count += 1;

        if self.seen_by_epoch.len() > PRECONF_INBOUND_LRU_CAPACITY {
            self.seen_by_epoch.pop_front();
        }
    }
}

#[derive(Debug, Default)]
pub(crate) struct GossipsubInboundState {
    chain_id: u64,
    allow_all_sequencers: bool,
    sequencer_addresses: Vec<Address>,
    request_rate: RateLimiter,
    request_seen: WindowedHashTracker,
    eos_rate: RateLimiter,
    eos_seen: EpochSeenTracker,
    pub(crate) preconf_seen_by_height: HeightSeenTracker,
    response_seen_by_height: HeightSeenTracker,
}

impl GossipsubInboundState {
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

    fn sequencer_is_allowed(&self, signer: &Address) -> bool {
        self.allow_all_sequencers || self.sequencer_addresses.contains(signer)
    }

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

    pub(crate) async fn validate_response(
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

        if !self.sequencer_is_allowed(&signer) {
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

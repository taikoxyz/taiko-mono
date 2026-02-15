//! Inbound validation and allowlist state for the whitelist preconfirmation network.

use std::{
    collections::HashMap,
    time::{Duration, Instant},
};

use alloy_eips::{BlockId, BlockNumberOrTag};
use alloy_primitives::{Address, B256};
use alloy_provider::{
    Provider, RootProvider,
    fillers::FillProvider,
    utils::JoinedRecommendedFillers,
};
use bindings::preconf_whitelist::PreconfWhitelist::{PreconfWhitelistInstance, operatorsReturn};
use hashlink::LinkedHashMap;
use libp2p::PeerId;
use libp2p::gossipsub;
use rpc::client::Client;
use tracing::debug;

use crate::codec::{
    block_signing_hash,
    recover_signer,
    DecodedUnsafePayload,
};
use crate::{
    cache::WhitelistSequencerCache,
    error::{Result, WhitelistPreconfirmationDriverError},
    metrics::WhitelistPreconfirmationDriverMetrics,
};

const REQUEST_SEEN_WINDOW: Duration = Duration::from_secs(45);
const REQUEST_RATE_PER_MINUTE: f64 = 200.0;
const REQUEST_RATE_MAX_TOKENS: f64 = REQUEST_RATE_PER_MINUTE;
const REQUEST_RATE_REFILL_PER_SEC: f64 = REQUEST_RATE_PER_MINUTE / 60.0;
const MAX_RESPONSES_ACCEPTABLE: usize = 3;
const MAX_PRECONF_BLOCKS_PER_HEIGHT: usize = 10;
const PRECONF_INBOUND_LRU_CAPACITY: usize = 1000;
/// Maximum age for stale-cache fallback when node timing data lags epoch start.
const MAX_STALE_FALLBACK_SECS: u64 = 12 * 64;
/// Retry once when whitelist snapshot fetch sees a transient inconsistency.
const SNAPSHOT_FETCH_MAX_ATTEMPTS: usize = 2;

pub(crate) type InboundWhitelistProvider = FillProvider<JoinedRecommendedFillers, RootProvider>;
pub(crate) type InboundWhitelistClient = Client<InboundWhitelistProvider>;

#[derive(Debug)]
pub(crate) struct InboundWhitelistFilter {
    whitelist: PreconfWhitelistInstance<InboundWhitelistProvider>,
    rpc_client: InboundWhitelistClient,
    sequencer_cache: WhitelistSequencerCache,
}

#[derive(Debug)]
struct CachedSequencers {
    current: Address,
    next: Address,
    /// True if at least one address came from cache rather than a fresh lookup.
    any_from_cache: bool,
}

#[derive(Debug, PartialEq, Eq)]
pub(crate) enum ResponseSignerDecision {
    Accept,
    Ignore,
    Reject,
}

#[derive(Debug)]
struct WhitelistSequencerSnapshot {
    current: Address,
    next: Address,
    current_epoch_start_timestamp: u64,
    block_timestamp: u64,
}

impl InboundWhitelistFilter {
    pub(crate) fn new(rpc_client: InboundWhitelistClient, whitelist_address: Address) -> Self {
        let whitelist = PreconfWhitelistInstance::new(whitelist_address, rpc_client.l1_provider.clone());

        Self {
            whitelist,
            rpc_client,
            sequencer_cache: WhitelistSequencerCache::default(),
        }
    }

    /// Ensure the signer is authorized by current/next whitelist sequencer snapshot.
    pub(crate) async fn ensure_signer_allowed(&mut self, signer: Address) -> Result<bool> {
        let now = Instant::now();
        let result = self.cached_whitelist_sequencers(now).await?;

        if signer == result.current || signer == result.next {
            return Ok(true);
        }

        if !result.any_from_cache {
            return Ok(false);
        }

        if !self.sequencer_cache.allow_miss_refresh(now) {
            debug!(
                %signer,
                cached_current = %result.current,
                cached_next = %result.next,
                "signer mismatch refresh cooldown active; rejecting without L1 re-fetch"
            );
            return Ok(false);
        }

        debug!(
            %signer,
            cached_current = %result.current,
            cached_next = %result.next,
            "signer not in cached whitelist; re-fetching from L1"
        );
        self.sequencer_cache.invalidate();
        let fresh = self.cached_whitelist_sequencers(now).await?;

        Ok(signer == fresh.current || signer == fresh.next)
    }

    pub(crate) async fn ensure_response_signer_allowed(
        &mut self,
        signer: Address,
    ) -> Result<ResponseSignerDecision> {
        let now = Instant::now();
        let result = self.cached_whitelist_sequencers(now).await?;

        if result.current == Address::ZERO && result.next == Address::ZERO {
            return Ok(ResponseSignerDecision::Ignore);
        }

        if signer == result.current || signer == result.next {
            return Ok(ResponseSignerDecision::Accept);
        }

        if !result.any_from_cache {
            return Ok(ResponseSignerDecision::Reject);
        }

        if !self.sequencer_cache.allow_miss_refresh(now) {
            debug!(
                %signer,
                cached_current = %result.current,
                cached_next = %result.next,
                "signer mismatch refresh cooldown active; rejecting response without L1 re-fetch"
            );
            return Ok(ResponseSignerDecision::Reject);
        }

        debug!(
            %signer,
            cached_current = %result.current,
            cached_next = %result.next,
            "signer not in cached response whitelist; re-fetching from L1"
        );
        self.sequencer_cache.invalidate();
        let fresh = self.cached_whitelist_sequencers(now).await?;

        if fresh.current == Address::ZERO && fresh.next == Address::ZERO {
            return Ok(ResponseSignerDecision::Ignore);
        }

        if signer == fresh.current || signer == fresh.next {
            return Ok(ResponseSignerDecision::Accept);
        }

        Ok(ResponseSignerDecision::Reject)
    }

    /// Return (current, next) sequencer addresses, using cache when available.
    async fn cached_whitelist_sequencers(
        &mut self,
        now: Instant,
    ) -> Result<CachedSequencers> {
        if let (Some(current), Some(next)) = (self.sequencer_cache.get_current(now), self.sequencer_cache.get_next(now))
        {
            return Ok(CachedSequencers { current, next, any_from_cache: true });
        }

        let snapshot = self.fetch_whitelist_snapshot_with_retry().await?;

        if let Err(err) =
            ensure_not_too_early_for_epoch(snapshot.block_timestamp, snapshot.current_epoch_start_timestamp)
        {
            if let Some((current, next)) = self
                .sequencer_cache
                .get_stale_pair_within(now, Duration::from_secs(MAX_STALE_FALLBACK_SECS))
            {
                debug!(
                    block_timestamp = snapshot.block_timestamp,
                    current_epoch_start_timestamp = snapshot.current_epoch_start_timestamp,
                    "using stale whitelist snapshot because latest block is before epoch start"
                );
                return Ok(CachedSequencers { current, next, any_from_cache: true });
            }
            return Err(err);
        }

        if !self.sequencer_cache.should_accept_block_timestamp(snapshot.block_timestamp)
            && let Some((current, next)) = self
                .sequencer_cache
                .get_stale_pair_within(now, Duration::from_secs(MAX_STALE_FALLBACK_SECS))
        {
            debug!(
                block_timestamp = snapshot.block_timestamp,
                "ignoring regressive whitelist snapshot from lagging RPC node"
            );
            return Ok(CachedSequencers { current, next, any_from_cache: true });
        }

        self.sequencer_cache.set_pair(
            snapshot.current,
            snapshot.next,
            snapshot.current_epoch_start_timestamp,
            now,
        );

        Ok(CachedSequencers {
            current: snapshot.current,
            next: snapshot.next,
            any_from_cache: false,
        })
    }

    /// Fetch current/next sequencer snapshot with retry after transient inconsistencies.
    async fn fetch_whitelist_snapshot_with_retry(&self) -> Result<WhitelistSequencerSnapshot> {
        for attempt in 1..=SNAPSHOT_FETCH_MAX_ATTEMPTS {
            match self.fetch_whitelist_snapshot().await {
                Ok(snapshot) => return Ok(snapshot),
                Err(err)
                    if attempt < SNAPSHOT_FETCH_MAX_ATTEMPTS
                        && should_retry_snapshot_fetch(&err) =>
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

    /// Fetch current/next sequencer snapshot pinned to a single L1 block height.
    async fn fetch_whitelist_snapshot(&self) -> Result<WhitelistSequencerSnapshot> {
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
            tokio::try_join!(current_operator_fut, next_operator_fut, epoch_start_timestamp_fut)?;

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
                        "failed to fetch pinned block {block_number} for whitelist verification: \
                         {err}"
                    ))
                })
        };

        let (current_seq, next_seq, pinned_block_opt): (operatorsReturn, operatorsReturn, _) =
            tokio::try_join!(current_seq_fut, next_seq_fut, pinned_block_fut)?;

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

        if current_seq.sequencerAddress == Address::ZERO && next_seq.sequencerAddress == Address::ZERO {
            debug!(
                current = %current_seq.sequencerAddress,
                next = %next_seq.sequencerAddress,
                block_number,
                "received empty whitelist sequencer snapshot"
            );
        }

        Ok(WhitelistSequencerSnapshot {
            current: current_seq.sequencerAddress,
            next: next_seq.sequencerAddress,
            current_epoch_start_timestamp: u64::from(current_epoch_start_timestamp),
            block_timestamp,
        })
    }
}

fn whitelist_lookup_err(message: String) -> WhitelistPreconfirmationDriverError {
    metrics::counter!(WhitelistPreconfirmationDriverMetrics::WHITELIST_LOOKUP_FAILURES_TOTAL)
        .increment(1);
    WhitelistPreconfirmationDriverError::WhitelistLookup(message)
}

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

fn should_retry_snapshot_fetch(err: &WhitelistPreconfirmationDriverError) -> bool {
    match err {
        WhitelistPreconfirmationDriverError::WhitelistLookup(message) => {
            let lower = message.to_ascii_lowercase();
            message.contains("block hash changed between whitelist batches")
                || message.contains("missing pinned block")
                || (message.contains("at block")
                    && (lower.contains("not found") || lower.contains("unknown block")))
        }
        _ => false,
    }
}

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
        if let Some(hashes) = self.seen_by_height.get(&height)
            && hashes.len() > max_per_height
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
    sequencer_addresses: Vec<Address>,
    sequencer_address: Address,
    whitelist_filter: Option<InboundWhitelistFilter>,
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
        sequencer_addresses: Vec<Address>,
        sequencer_address: Address,
        whitelist_filter: Option<InboundWhitelistFilter>,
    ) -> Self {
        Self {
            chain_id,
            sequencer_addresses,
            sequencer_address,
            whitelist_filter,
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
        match self
            .validate_preconf_block_signer(&payload.wire_signature, &payload.payload_bytes)
            .await
        {
            gossipsub::MessageAcceptance::Accept => {
                self.validate_preconf_block_payload(payload).await
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

        if let Some(whitelist_filter) = self.whitelist_filter.as_mut() {
            match whitelist_filter.ensure_signer_allowed(signer).await {
                Ok(true) => {}
                Ok(false) => return gossipsub::MessageAcceptance::Reject,
                Err(err) => {
                    debug!(
                        error = %err,
                        signer = %signer,
                        "whitelist lookup failed for inbound preconf block"
                    );
                    return gossipsub::MessageAcceptance::Reject;
                }
            }
        } else if !self.sequencer_addresses.is_empty() {
            if !self.sequencer_addresses.contains(&signer) {
                return gossipsub::MessageAcceptance::Reject;
            }
        } else if self.sequencer_address != Address::ZERO {
            if signer != self.sequencer_address {
                return gossipsub::MessageAcceptance::Reject;
            }
        } else {
            return gossipsub::MessageAcceptance::Reject;
        }

        gossipsub::MessageAcceptance::Accept
    }

    async fn validate_preconf_block_payload(
        &mut self,
        payload: &DecodedUnsafePayload,
    ) -> gossipsub::MessageAcceptance {
        if payload.envelope.execution_payload.transactions.is_empty()
            || payload.envelope.execution_payload.fee_recipient == Address::ZERO
            || payload.envelope.execution_payload.block_number == 0
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

        if envelope.execution_payload.transactions.is_empty()
            || envelope.execution_payload.fee_recipient == Address::ZERO
            || envelope.execution_payload.block_number == 0
        {
            return gossipsub::MessageAcceptance::Reject;
        }

        let prehash =
            block_signing_hash(self.chain_id, envelope.execution_payload.block_hash.as_slice());

        let signer = match recover_signer(prehash, &signature) {
            Ok(signer) => signer,
            Err(_) => return gossipsub::MessageAcceptance::Reject,
        };

        if let Some(whitelist_filter) = self.whitelist_filter.as_mut() {
            match whitelist_filter.ensure_response_signer_allowed(signer).await {
                Ok(ResponseSignerDecision::Accept) => {}
                Ok(ResponseSignerDecision::Ignore) => {
                    return gossipsub::MessageAcceptance::Ignore;
                }
                Ok(ResponseSignerDecision::Reject) => return gossipsub::MessageAcceptance::Reject,
                Err(err) => {
                    debug!(
                        error = %err,
                        signer = %signer,
                        "whitelist lookup failed for inbound preconf response"
                    );
                    return gossipsub::MessageAcceptance::Reject;
                }
            }
        } else if !self.sequencer_addresses.is_empty() {
            if !self.sequencer_addresses.contains(&signer) {
                return gossipsub::MessageAcceptance::Reject;
            }
        } else if self.sequencer_address != Address::ZERO {
            if signer != self.sequencer_address {
                return gossipsub::MessageAcceptance::Reject;
            }
        } else {
            return gossipsub::MessageAcceptance::Ignore;
        }

        let height = envelope.execution_payload.block_number;
        let hash = envelope.execution_payload.block_hash;
        if !self.response_seen_by_height.can_accept(height, hash, MAX_RESPONSES_ACCEPTABLE) {
            return gossipsub::MessageAcceptance::Ignore;
        }

        gossipsub::MessageAcceptance::Accept
    }
}

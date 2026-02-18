//! Inbound validation and allowlist state for the whitelist preconfirmation network.

use std::{
    collections::HashMap,
    time::{Duration, Instant},
};

use alloy_eips::{BlockId, BlockNumberOrTag};
use alloy_primitives::{Address, B256};
use alloy_provider::{
    Provider, RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers,
};
use bindings::preconf_whitelist::PreconfWhitelist::{PreconfWhitelistInstance, operatorsReturn};
use hashlink::LinkedHashMap;
use libp2p::{PeerId, gossipsub};
use rpc::client::Client;
use tracing::debug;

use crate::{
    cache::WhitelistSequencerCache,
    codec::{DecodedUnsafePayload, block_signing_hash, recover_signer},
    error::{Result, WhitelistPreconfirmationDriverError},
    metrics::WhitelistPreconfirmationDriverMetrics,
};

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
/// Maximum age for stale-cache fallback when node timing data lags epoch start.
const MAX_STALE_FALLBACK_SECS: u64 = 12 * 64;
/// Retry once when whitelist snapshot fetch sees a transient inconsistency.
const SNAPSHOT_FETCH_MAX_ATTEMPTS: usize = 2;

/// L1 provider alias used by whitelist filter RPC calls.
pub(crate) type InboundWhitelistProvider = FillProvider<JoinedRecommendedFillers, RootProvider>;
/// Inbound filter client alias used by whitelist validation logic.
pub(crate) type InboundWhitelistClient = Client<InboundWhitelistProvider>;

/// In-memory allowlist filter for signer authorization and snapshot validation.
#[derive(Debug)]
pub(crate) struct InboundWhitelistFilter {
    /// Cached contract binding for allowlist lookup RPC calls.
    whitelist: PreconfWhitelistInstance<InboundWhitelistProvider>,
    /// Whitelist RPC client used for sequencer batch lookups.
    rpc_client: InboundWhitelistClient,
    /// Shared sequencer snapshot cache backed by short-lived TTL rules.
    sequencer_cache: WhitelistSequencerCache,
}

/// Sequencer pair returned from cache fetch with cache-hit tracking.
#[derive(Debug)]
struct CachedSequencers {
    /// Currently active sequencer.
    current: Address,
    /// Next sequencer for the next epoch.
    next: Address,
    /// True if at least one address came from cache rather than a fresh lookup.
    any_from_cache: bool,
}

#[derive(Debug, PartialEq, Eq)]
/// Structured decision returned by whitelist signer checks.
pub(crate) enum ResponseSignerDecision {
    /// Signer is currently authorized.
    Accept,
    /// Signer is ignored because no snapshot is available.
    Ignore,
    /// Signer is unauthorized and should be rejected.
    Reject,
}

#[derive(Clone, Copy, Debug)]
/// Policy that controls snapshot-empty handling for signer checks.
enum SignerAuthorizationMode {
    /// Rejection on empty snapshot.
    /// Preconfirmation block validation maps zero snapshot to `Reject`.
    PreconfBlock,
    /// Ignore on empty snapshot.
    /// Response validation maps zero snapshot to `Ignore`.
    Response,
}

impl SignerAuthorizationMode {
    /// Whether this mode treats an empty snapshot as `Ignore`.
    const fn allow_empty_snapshot(self) -> bool {
        matches!(self, Self::Response)
    }
}

#[derive(Debug)]
/// Error class returned from snapshot fetch attempts.
enum SnapshotFetchError {
    /// Retry is safe on transient provider/chain inconsistency.
    Retryable(WhitelistPreconfirmationDriverError),
    /// Retry is not safe and should fail the lookup immediately.
    Fatal(WhitelistPreconfirmationDriverError),
}

impl From<SnapshotFetchError> for WhitelistPreconfirmationDriverError {
    fn from(err: SnapshotFetchError) -> Self {
        match err {
            SnapshotFetchError::Retryable(err) | SnapshotFetchError::Fatal(err) => err,
        }
    }
}

/// Build a snapshot-fetch error with fatality hint.
fn snapshot_fetch_error(message: String, retryable: bool) -> SnapshotFetchError {
    let error = whitelist_lookup_err(message);
    if retryable {
        SnapshotFetchError::Retryable(error)
    } else {
        SnapshotFetchError::Fatal(error)
    }
}

#[derive(Debug)]
/// Snapshot of sequencer addresses tied to a pinned block.
struct WhitelistSequencerSnapshot {
    /// Active sequencer address.
    current: Address,
    /// Next-sequencer address.
    next: Address,
    /// Epoch start timestamp for the cached operators.
    current_epoch_start_timestamp: u64,
    /// Block timestamp for the pinned block.
    block_timestamp: u64,
}

/// Inbound filter state for validating sequencer signatures.
impl InboundWhitelistFilter {
    /// Construct a new inbound whitelist filter.
    pub(crate) fn new(rpc_client: InboundWhitelistClient, whitelist_address: Address) -> Self {
        let whitelist =
            PreconfWhitelistInstance::new(whitelist_address, rpc_client.l1_provider.clone());

        Self { whitelist, rpc_client, sequencer_cache: WhitelistSequencerCache::default() }
    }

    /// Return (current, next) sequencer addresses, using cache when available.
    async fn cached_whitelist_sequencers(&mut self, now: Instant) -> Result<CachedSequencers> {
        if let (Some(current), Some(next)) =
            (self.sequencer_cache.get_current(now), self.sequencer_cache.get_next(now))
        {
            return Ok(CachedSequencers { current, next, any_from_cache: true });
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
                return Ok(CachedSequencers { current, next, any_from_cache: true });
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

    /// Resolve signer authorization with optional cache miss refresh.
    async fn ensure_signer_authorization(
        &mut self,
        signer: Address,
        mode: SignerAuthorizationMode,
    ) -> Result<ResponseSignerDecision> {
        let now = Instant::now();
        let snapshot = self.cached_whitelist_sequencers(now).await?;
        let decision = self.resolve_signer_decision(signer, &snapshot, mode);

        if decision != ResponseSignerDecision::Reject || !snapshot.any_from_cache {
            return Ok(decision);
        }

        if !self.sequencer_cache.allow_miss_refresh(now) {
            debug!(
                %signer,
                cached_current = %snapshot.current,
                cached_next = %snapshot.next,
                "signer mismatch refresh cooldown active; rejecting without L1 re-fetch"
            );
            return Ok(ResponseSignerDecision::Reject);
        }

        debug!(
            %signer,
            cached_current = %snapshot.current,
            cached_next = %snapshot.next,
            "signer not in cached whitelist; re-fetching from L1"
        );
        self.sequencer_cache.invalidate();
        let fresh = self.cached_whitelist_sequencers(now).await?;
        Ok(self.resolve_signer_decision(signer, &fresh, mode))
    }

    /// Convert a snapshot and mode into an allow/ignore/reject decision.
    fn resolve_signer_decision(
        &self,
        signer: Address,
        snapshot: &CachedSequencers,
        mode: SignerAuthorizationMode,
    ) -> ResponseSignerDecision {
        if signer == snapshot.current || signer == snapshot.next {
            return ResponseSignerDecision::Accept;
        }

        if mode.allow_empty_snapshot() &&
            snapshot.current == Address::ZERO &&
            snapshot.next == Address::ZERO
        {
            return ResponseSignerDecision::Ignore;
        }

        ResponseSignerDecision::Reject
    }

    /// Fetch current/next sequencer snapshot with retry after transient inconsistencies.
    async fn fetch_whitelist_snapshot_with_retry(
        &self,
    ) -> Result<WhitelistSequencerSnapshot> {
        for attempt in 1..=SNAPSHOT_FETCH_MAX_ATTEMPTS {
            match self.fetch_whitelist_snapshot().await {
                Ok(snapshot) => return Ok(snapshot),
                Err(SnapshotFetchError::Retryable(err))
                    if attempt < SNAPSHOT_FETCH_MAX_ATTEMPTS =>
                {
                    debug!(
                        attempt,
                        max_attempts = SNAPSHOT_FETCH_MAX_ATTEMPTS,
                        error = %err,
                        "retrying whitelist snapshot fetch after transient inconsistency"
                    );
                }
                Err(err) => return Err(err.into()),
            }
        }

        unreachable!("snapshot fetch loop must return on success or final error")
    }

    /// Fetch current/next sequencer snapshot from the current pinned L1 block.
    async fn fetch_whitelist_snapshot(
        &self,
    ) -> std::result::Result<WhitelistSequencerSnapshot, SnapshotFetchError> {
        let latest_block = self
            .rpc_client
            .l1_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(|err| {
                snapshot_fetch_error(
                    format!("failed to fetch latest block for whitelist snapshot: {err}"),
                    false,
                )
            })?
            .ok_or_else(|| {
                snapshot_fetch_error(
                    "missing latest block while fetching whitelist snapshot".to_string(),
                    false,
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
                    snapshot_fetch_error(
                        format!("failed to fetch current operator at block {block_number}: {err}"),
                        true,
                    )
                })
        };
        let next_operator_fut = async {
            self.whitelist
                .getOperatorForNextEpoch()
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    snapshot_fetch_error(
                        format!("failed to fetch next operator at block {block_number}: {err}"),
                        true,
                    )
                })
        };
        let epoch_start_timestamp_fut = async {
            self.whitelist
                .epochStartTimestamp(Default::default())
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    snapshot_fetch_error(
                        format!("failed to fetch epochStartTimestamp at block {block_number}: {err}"),
                        true,
                    )
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
                    snapshot_fetch_error(
                        format!(
                            "failed to fetch current operators() entry at block {block_number}: {err}"
                        ),
                        true,
                    )
                })
        };
        let next_seq_fut = async {
            self.whitelist
                .operators(next_proposer)
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    snapshot_fetch_error(
                        format!(
                            "failed to fetch next operators() entry at block {block_number}: {err}"
                        ),
                        true,
                    )
                })
        };
        let pinned_block_fut = async {
            self.rpc_client
                .l1_provider
                .get_block_by_number(BlockNumberOrTag::Number(block_number))
                .await
                .map_err(|err| {
                    snapshot_fetch_error(
                        format!(
                            "failed to fetch pinned block {block_number} for whitelist verification: \
                             {err}"
                        ),
                        true,
                    )
                })
        };

        let (current_seq, next_seq, pinned_block_opt): (operatorsReturn, operatorsReturn, _) =
            tokio::try_join!(current_seq_fut, next_seq_fut, pinned_block_fut)?;

        let pinned_block = pinned_block_opt.ok_or_else(|| {
            snapshot_fetch_error(
                format!(
                "missing pinned block {block_number} while verifying whitelist batches"
                ),
                true,
            )
        })?;
        let pinned_block_hash = pinned_block.hash();
        if pinned_block_hash != block_hash {
            return Err(snapshot_fetch_error(
                format!("block hash changed between whitelist batches at block {block_number}"),
                true,
            ));
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

/// Map a whitelist lookup failure into a typed driver error and increment metric.
fn whitelist_lookup_err(message: String) -> WhitelistPreconfirmationDriverError {
    metrics::counter!(WhitelistPreconfirmationDriverMetrics::WHITELIST_LOOKUP_FAILURES_TOTAL)
        .increment(1);
    WhitelistPreconfirmationDriverError::WhitelistLookup(message)
}

/// Validate that the fetched block timestamp is not before the epoch start.
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
    /// Single sequencer configured from CLI.
    sequencer_address: Address,
    /// Optional whitelist filter backed by L1.
    whitelist_filter: Option<InboundWhitelistFilter>,
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
    /// Construct inbound state from p2p and optional whitelist config.
    pub(crate) fn new(
        chain_id: u64,
        sequencer_addresses: Vec<Address>,
        sequencer_address: Address,
        whitelist_filter: Option<InboundWhitelistFilter>,
    ) -> Self {
        Self::new_with_allow_all_sequencers(
            chain_id,
            sequencer_addresses,
            sequencer_address,
            whitelist_filter,
            false,
        )
    }

    /// Construct inbound state from p2p and optional whitelist config.
    pub(crate) fn new_with_allow_all_sequencers(
        chain_id: u64,
        sequencer_addresses: Vec<Address>,
        sequencer_address: Address,
        whitelist_filter: Option<InboundWhitelistFilter>,
        allow_all_sequencers: bool,
    ) -> Self {
        Self {
            chain_id,
            sequencer_addresses,
            allow_all_sequencers,
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

    /// Recover and validate signer for preconfirmation payloads.
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

        self.validate_signer(signer, SignerAuthorizationMode::PreconfBlock).await
    }

    /// Validate payload fields and per-height uniqueness.
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

    /// Validate a response payload including signature and signer authorization.
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

        let acceptance = self.validate_signer(signer, SignerAuthorizationMode::Response).await;
        if !matches!(acceptance, gossipsub::MessageAcceptance::Accept) {
            return acceptance;
        }

        let height = envelope.execution_payload.block_number;
        let hash = envelope.execution_payload.block_hash;
        if !self.response_seen_by_height.can_accept(height, hash, MAX_RESPONSES_ACCEPTABLE) {
            return gossipsub::MessageAcceptance::Ignore;
        }

        gossipsub::MessageAcceptance::Accept
    }

    /// Validate a recovered signer according to filter or fallback config.
    async fn validate_signer(
        &mut self,
        signer: Address,
        mode: SignerAuthorizationMode,
    ) -> gossipsub::MessageAcceptance {
        if self.allow_all_sequencers {
            return gossipsub::MessageAcceptance::Accept;
        }

        if let Some(whitelist_filter) = self.whitelist_filter.as_mut() {
            match whitelist_filter.ensure_signer_authorization(signer, mode).await {
                Ok(decision) => self.map_signer_authorization(mode, decision),
                Err(err) => {
                    debug!(
                        error = %err,
                        signer = %signer,
                        "whitelist lookup failed for inbound signer validation"
                    );
                    gossipsub::MessageAcceptance::Reject
                }
            }
        } else {
            self.validate_signer_without_filter(signer, mode)
        }
    }

    /// Fallback signer validation when no whitelist filter is configured.
    fn validate_signer_without_filter(
        &self,
        signer: Address,
        mode: SignerAuthorizationMode,
    ) -> gossipsub::MessageAcceptance {
        if !self.sequencer_addresses.is_empty() {
            if self.sequencer_addresses.contains(&signer) {
                return gossipsub::MessageAcceptance::Accept;
            }
            gossipsub::MessageAcceptance::Reject
        } else if self.sequencer_address != Address::ZERO && signer == self.sequencer_address {
            gossipsub::MessageAcceptance::Accept
        } else if self.sequencer_address != Address::ZERO {
            gossipsub::MessageAcceptance::Reject
        } else {
            match mode {
                SignerAuthorizationMode::PreconfBlock => {
                    gossipsub::MessageAcceptance::Reject
                }
                SignerAuthorizationMode::Response => gossipsub::MessageAcceptance::Ignore,
            }
        }
    }

    /// Map internal decision enum onto gossipsub acceptance semantics.
    fn map_signer_authorization(
        &self,
        mode: SignerAuthorizationMode,
        decision: ResponseSignerDecision,
    ) -> gossipsub::MessageAcceptance {
        match (mode, decision) {
            (_, ResponseSignerDecision::Accept) => gossipsub::MessageAcceptance::Accept,
            (_, ResponseSignerDecision::Reject) => gossipsub::MessageAcceptance::Reject,
            (SignerAuthorizationMode::Response, ResponseSignerDecision::Ignore) => {
                gossipsub::MessageAcceptance::Ignore
            }
            (SignerAuthorizationMode::PreconfBlock, ResponseSignerDecision::Ignore) => {
                gossipsub::MessageAcceptance::Reject
            }
        }
    }
}

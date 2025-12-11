use std::sync::Arc;

use alloy::{eips::BlockId, sol_types::SolEvent};
use alloy_primitives::{Address, B256, U256};
use alloy_provider::Provider;
use alloy_rpc_types::{BlockNumberOrTag, Log, eth::Block as RpcBlock};
use async_trait::async_trait;
use bindings::{
    lookahead_store::LookaheadStore::{Blacklisted, LookaheadPosted, Unblacklisted},
    preconf_whitelist::PreconfWhitelist::{
        OperatorAdded, OperatorRemoved, PreconfWhitelistInstance,
    },
};
use dashmap::DashMap;
use event_scanner::EventFilter;
use tokio::sync::broadcast;
use tracing::warn;

use crate::preconfirmation::lookahead::resolver::epoch::current_unix_timestamp;

use super::{
    super::{
        PreconfSignerResolver,
        client::LookaheadClient,
        error::{LookaheadError, Result},
    },
    epoch::{
        MAX_BACKWARD_STEPS, SECONDS_IN_EPOCH, earliest_allowed_timestamp,
        earliest_allowed_timestamp_at, epoch_start_for, genesis_timestamp_for_chain,
        latest_allowed_timestamp_at,
    },
    timeline::{
        BlacklistEvent, BlacklistFlag, BlacklistTimeline, FallbackEvent, FallbackTimelineStore,
    },
    types::{
        CachedLookaheadEpoch, LookaheadBroadcast, LookaheadEpochUpdate, SlotOrigin,
        pick_slot_origin,
    },
};

/// Sliding resolver that answers “who should commit at this timestamp?” using cached lookahead
/// events, historical blacklist timelines, and whitelist fallbacks.
#[derive(Clone)]
pub struct LookaheadResolver<P: Provider + Clone + Send + Sync + 'static> {
    /// Thin contract client helpers (Inbox/LookaheadStore).
    pub(crate) client: LookaheadClient<P>,
    /// Preconf whitelist contract instance for fallback selection.
    pub(crate) preconf_whitelist: PreconfWhitelistInstance<P>,
    /// Provider for block lookups to snapshot whitelist fallbacks.
    pub(crate) provider: P,
    /// Chronological history of whitelist fallback operators keyed by timestamp.
    pub(crate) fallback_timeline: FallbackTimelineStore,
    /// Sliding window of cached epochs keyed by epoch start timestamp.
    pub(crate) cache: Arc<DashMap<u64, CachedLookaheadEpoch>>,
    /// Time-aware blacklist history keyed by operator registration root.
    pub(crate) blacklist_history: Arc<DashMap<B256, BlacklistTimeline>>,
    /// Maximum cached epochs (derived from on-chain lookahead buffer size).
    lookahead_buffer_size: usize,
    /// Beacon genesis timestamp for the connected chain.
    genesis_timestamp: u64,
    /// Optional broadcast sender for lookahead updates (epochs and blacklist changes).
    broadcast_tx: Option<broadcast::Sender<LookaheadBroadcast>>,
}

impl<P> LookaheadResolver<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Build a resolver backed by the given Inbox address and provider, inferring the beacon
    /// genesis timestamp from the chain ID.
    pub(crate) async fn build(inbox_address: Address, provider: P) -> Result<Self> {
        let chain_id = provider
            .get_chain_id()
            .await
            .map_err(|err| LookaheadError::EventDecode(err.to_string()))?;

        let genesis_timestamp =
            genesis_timestamp_for_chain(chain_id).ok_or(LookaheadError::UnknownChain(chain_id))?;

        Self::build_with_genesis(inbox_address, provider, genesis_timestamp).await
    }

    /// Build a resolver backed by the given Inbox address and provider with an explicit genesis
    /// timestamp, bypassing chain ID inference (useful for custom networks).
    pub(crate) async fn build_with_genesis(
        inbox_address: Address,
        provider: P,
        genesis_timestamp: u64,
    ) -> Result<Self> {
        let client = LookaheadClient::new(inbox_address, provider.clone()).await?;

        let lookahead_cfg = client
            .lookahead_store()
            .getLookaheadStoreConfig()
            .call()
            .await
            .map_err(LookaheadError::Lookahead)?;

        let preconf_whitelist = PreconfWhitelistInstance::new(
            client
                .lookahead_store()
                .preconfWhitelist()
                .call()
                .await
                .map_err(LookaheadError::Lookahead)?,
            provider.clone(),
        );

        Ok(Self {
            client,
            preconf_whitelist,
            provider,
            fallback_timeline: FallbackTimelineStore::new(),
            cache: Arc::new(DashMap::new()),
            blacklist_history: Arc::new(DashMap::new()),
            lookahead_buffer_size: lookahead_cfg.lookaheadBufferSize as usize,
            genesis_timestamp,
            broadcast_tx: None,
        })
    }

    /// Build an event filter for `LookaheadPosted` plus blacklist/unblacklist events emitted by the
    /// resolved LookaheadStore.
    pub fn lookahead_filter(&self) -> EventFilter {
        EventFilter::new()
            .contract_addresses([
                self.client.lookahead_store_address(),
                self.preconf_whitelist_address(),
            ])
            .event(LookaheadPosted::SIGNATURE)
            .event(Unblacklisted::SIGNATURE)
            .event(Blacklisted::SIGNATURE)
            .event(OperatorAdded::SIGNATURE)
            .event(OperatorRemoved::SIGNATURE)
    }

    /// Number of epochs cached, matching the on-chain lookahead buffer size.
    pub(crate) fn lookahead_buffer_size(&self) -> usize {
        self.lookahead_buffer_size
    }

    /// Enable a broadcast channel for lookahead updates; clones share the sender. Returns a
    /// receiver for updates.
    pub fn enable_broadcast_channel(
        &mut self,
        capacity: usize,
    ) -> broadcast::Receiver<LookaheadBroadcast> {
        let (tx, rx) = broadcast::channel(capacity);
        self.broadcast_tx = Some(tx);
        rx
    }

    /// Subscribe to lookahead updates if broadcasting is enabled.
    pub fn subscribe(&self) -> Option<broadcast::Receiver<LookaheadBroadcast>> {
        self.broadcast_tx.as_ref().map(|tx| tx.subscribe())
    }

    /// Ingest a batch of logs and update the in-memory cache plus live blacklist state.
    /// `Log` must include the block number so fallback operators can be snapshotted at the same
    /// state as the lookahead event.
    pub async fn ingest_logs<I>(&self, logs: I) -> Result<()>
    where
        I: IntoIterator<Item = Log>,
    {
        for log in logs.into_iter() {
            let Some(first_topic) = log.topics().first().copied() else { continue };
            // Partition by contract: LookaheadStore drives lookahead cache + blacklist timelines;
            // PreconfWhitelist drives the live fallback timeline used when no valid slot exists.
            let is_lookahead = log.address() == self.client.lookahead_store_address();
            let is_whitelist = log.address() == self.preconf_whitelist_address();
            let block_number = log.block_number.ok_or(LookaheadError::MissingLogField {
                field: "block_number",
                context: "ingesting LookaheadPosted",
            })?;
            let block_timestamp = log.block_timestamp.ok_or(LookaheadError::MissingLogField {
                field: "block_timestamp",
                context: "ingesting LookaheadPosted",
            })?;

            if is_lookahead {
                // LookaheadStore events update epoch cache and blacklist state; these are the
                // primary inputs for picking committers without further RPCs.
                if first_topic == LookaheadPosted::SIGNATURE_HASH {
                    let event = LookaheadPosted::decode_raw_log(
                        log.topics().to_vec(),
                        log.data().data.as_ref(),
                    )
                    .map_err(|err| LookaheadError::EventDecode(err.to_string()))?;

                    self.store_epoch(event, block_number, block_timestamp).await?;
                } else if first_topic == Blacklisted::SIGNATURE_HASH {
                    // Blacklist events mark a slot's registration root as unusable going forward
                    // and broadcast the change if listeners are attached.
                    let event = Blacklisted::decode_raw_log(
                        log.topics().to_vec(),
                        log.data().data.as_ref(),
                    )
                    .map_err(|err| LookaheadError::EventDecode(err.to_string()))?;
                    self.record_blacklist_event(
                        event.operatorRegistrationRoot,
                        event.timestamp.to(),
                    )?;
                    if let Some(tx) = &self.broadcast_tx &&
                        let Err(err) = tx.send(LookaheadBroadcast::Blacklisted {
                            root: event.operatorRegistrationRoot,
                        })
                    {
                        warn!(?err, "failed to broadcast blacklist event");
                    }
                } else if first_topic == Unblacklisted::SIGNATURE_HASH {
                    // Unblacklist events restore eligibility for the registration root.
                    let event = Unblacklisted::decode_raw_log(
                        log.topics().to_vec(),
                        log.data().data.as_ref(),
                    )
                    .map_err(|err| LookaheadError::EventDecode(err.to_string()))?;
                    self.record_unblacklist_event(
                        event.operatorRegistrationRoot,
                        event.timestamp.to(),
                    )?;
                    if let Some(tx) = &self.broadcast_tx &&
                        let Err(err) = tx.send(LookaheadBroadcast::Unblacklisted {
                            root: event.operatorRegistrationRoot,
                        })
                    {
                        warn!(?err, "failed to broadcast unblacklist event");
                    }
                } else {
                    warn!(topic = ?first_topic, "unrecognized lookahead log topic");
                }
            } else if is_whitelist {
                // Whitelist events adjust the fallback operator timeline so gap/blacklist paths
                // mirror on-chain selection mid-epoch.
                if first_topic == OperatorRemoved::SIGNATURE_HASH ||
                    first_topic == OperatorAdded::SIGNATURE_HASH
                {
                    self.record_whitelist_event(block_number, block_timestamp).await?;
                } else {
                    warn!(topic = ?first_topic, "unrecognized whitelist log topic");
                }
            }
        }

        Ok(())
    }

    /// Record a blacklist event for an operator and prune history to the allowed lookback window.
    fn record_blacklist_event(&self, root: B256, at: u64) -> Result<()> {
        let cutoff = earliest_allowed_timestamp(self.genesis_timestamp)?;
        let mut timeline = self.blacklist_history.entry(root).or_default();
        timeline.apply(BlacklistEvent { at, flag: BlacklistFlag::Listed });
        timeline.prune_before(cutoff);
        Ok(())
    }

    /// Record an unblacklist event for an operator and prune history to the allowed lookback
    /// window.
    fn record_unblacklist_event(&self, root: B256, at: u64) -> Result<()> {
        let cutoff = earliest_allowed_timestamp(self.genesis_timestamp)?;
        let mut timeline = self.blacklist_history.entry(root).or_default();
        timeline.apply(BlacklistEvent { at, flag: BlacklistFlag::Cleared });
        timeline.prune_before(cutoff);
        Ok(())
    }

    /// Cache a newly observed `LookaheadPosted` event for quick timestamp lookups, capturing the
    /// whitelist fallback operator at the same block so resolution mirrors on-chain state.
    pub(crate) async fn store_epoch(
        &self,
        event: LookaheadPosted,
        block_number: u64,
        block_timestamp: u64,
    ) -> Result<()> {
        // Snapshot whitelist state at the event block state.
        let fallback_current = self.snapshot_whitelist(block_number).await?;

        let epoch_start = event.epochTimestamp.to::<u64>();

        // Record baseline fallback for the epoch anchored at the epoch boundary (not the post
        // block) so it activates only when that epoch begins.
        self.record_fallback_baseline(epoch_start, epoch_start, fallback_current).await?;

        // Insert or update the cached epoch entry.
        let cached = CachedLookaheadEpoch {
            slots: Arc::new(event.lookaheadSlots),
            fallback_whitelist: fallback_current,
            block_timestamp,
        };

        // Store in the cache keyed by epoch start timestamp.
        self.cache.insert(epoch_start, cached.clone());

        // Broadcast the epoch update if channel is enabled.
        if let Some(tx) = &self.broadcast_tx &&
            let Err(err) = tx.send(LookaheadBroadcast::Epoch(LookaheadEpochUpdate {
                epoch_start,
                epoch: cached,
            }))
        {
            warn!(?err, "failed to broadcast epoch update");
        }

        // Evict oldest entries once we exceed the on-chain lookahead buffer. We keep one extra
        // entry to cover the current+next epoch window (mirror of contract ring buffer behavior).
        // Cache size is bounded by on-chain ring buffer, so O(n) scan is acceptable here.
        while self.cache.len() > self.lookahead_buffer_size + 1 {
            if let Some(oldest) = self.cache.iter().map(|e| *e.key()).min() {
                self.cache.remove(&oldest);
            } else {
                break;
            }
        }

        Ok(())
    }

    /// Snapshot the whitelist fallback operator at a specific block, mirroring on-chain state used
    /// when the lookahead event was emitted.
    async fn snapshot_whitelist(&self, block: u64) -> Result<Address> {
        let current_query = self
            .preconf_whitelist
            .getOperatorForNextEpoch()
            .block(BlockId::Number(block.into()))
            .call()
            .await
            .map_err(LookaheadError::PreconfWhitelist)?;

        Ok(current_query)
    }

    /// Record the current-epoch whitelist operator at the provided block into the fallback
    /// timeline, keyed by the epoch that contains the block timestamp.
    async fn record_whitelist_event(&self, block_number: u64, block_timestamp: u64) -> Result<()> {
        let epoch_start = epoch_start_for(block_timestamp, self.genesis_timestamp);
        let next_epoch_start = epoch_start.saturating_add(SECONDS_IN_EPOCH);

        let current_epoch_operator = self.whitelist_operator_at(block_number).await?;
        let next_epoch_operator = self
            .preconf_whitelist
            .getOperatorForNextEpoch()
            .block(BlockId::Number(block_number.into()))
            .call()
            .await
            .map_err(LookaheadError::PreconfWhitelist)?;

        // Apply the operator change to the fallback timeline, pruning history to the allowed
        // lookback window. Current epoch takes effect at the event block; next epoch at the epoch
        // boundary so it cannot retroactively affect the current epoch.
        self.fallback_timeline
            .apply(FallbackEvent { at: block_timestamp, operator: current_epoch_operator });
        self.fallback_timeline
            .apply(FallbackEvent { at: next_epoch_start, operator: next_epoch_operator });

        self.fallback_timeline.prune_before(earliest_allowed_timestamp(self.genesis_timestamp)?);

        // Ensure baselines exist even if the first observed change is a removal.
        self.fallback_timeline.ensure_baseline(epoch_start, current_epoch_operator);
        self.fallback_timeline.ensure_baseline(next_epoch_start, next_epoch_operator);
        Ok(())
    }

    /// Resolve the expected committer for a given L1 timestamp (seconds since epoch).
    ///
    /// Resolution rules (parity with `LookaheadStore._determineProposerContext`) without runtime
    /// network I/O, evaluating blacklist state at the queried timestamp:
    /// - If the epoch has no lookahead slots (including epochs that already started but never
    ///   posted lookahead), use the cached current-epoch whitelist operator for the whole epoch
    ///   (`_handleEmptyCurrentLookahead`).
    /// - Otherwise pick the first slot whose timestamp is >= the queried timestamp
    ///   (`_handleSameEpochProposer` selection); if none exist and the first slot of the next epoch
    ///   is still ahead of `ts`, use that first slot (`_handleCrossEpochProposer`); otherwise fall
    ///   back to the cached current-epoch whitelist.
    /// - If the chosen slot was blacklisted at the queried timestamp (tracked via historical
    ///   events), fall back to the cached current-epoch whitelist.
    /// - Timestamps earlier than `earliest_allowed_timestamp` (one full epoch behind "now") are
    ///   rejected as `TooOld`; timestamps at or beyond `latest_allowed_timestamp` (end of the
    ///   current epoch) are rejected as `TooNew`.
    pub async fn committer_for_timestamp(&self, timestamp: U256) -> Result<Address> {
        // Convert timestamp to u64 and check genesis boundary.
        let ts = u64::try_from(timestamp)
            .map_err(|_| LookaheadError::EventDecode("timestamp does not fit u64".into()))?;

        // Timestamps before genesis cannot be resolved.
        if ts < self.genesis_timestamp {
            return Err(LookaheadError::BeforeGenesis(ts));
        }

        // Get current time for bounding lookups.
        let now = current_unix_timestamp()?;

        // Reject timestamps older than the configured lookback window to avoid unbounded lookups.
        let earliest_allowed = earliest_allowed_timestamp_at(now, self.genesis_timestamp);
        if ts < earliest_allowed {
            return Err(LookaheadError::TooOld(ts));
        }

        // Reject timestamps beyond the current epoch window; resolver only serves up to "now"
        // epoch.
        let latest_allowed = latest_allowed_timestamp_at(now, self.genesis_timestamp);
        if ts >= latest_allowed {
            return Err(LookaheadError::TooNew(ts));
        }

        // Calculate epoch boundaries.
        let epoch_start = epoch_start_for(ts, self.genesis_timestamp);
        let next_epoch_start = epoch_start.saturating_add(SECONDS_IN_EPOCH);

        // Get cached epochs if available.
        let current = self.cache.get(&epoch_start).map(|entry| entry.clone());
        let next = self.cache.get(&next_epoch_start).map(|entry| entry.clone());

        // Ensure current epoch data is available. If the epoch has already started but no
        // lookahead was posted, fall back to the current whitelist operator and cache an empty
        // epoch to mirror `_handleEmptyCurrentLookahead`.
        let curr_epoch = if let Some(epoch) = current {
            epoch
        } else {
            self.synthetic_empty_epoch(epoch_start, now).await?
        };

        // Resolve based on selection and blacklist status.
        match pick_slot_origin(ts, &curr_epoch.slots, next.as_ref().map(|n| n.slots.as_slice())) {
            // Select from current epoch slots.
            Some(SlotOrigin::Current(idx)) => {
                let slot = &curr_epoch.slots[idx];
                // Check blacklist status.
                if self.was_blacklisted_at(slot.registrationRoot, ts) {
                    return self
                        .resolve_fallback(ts, epoch_start, curr_epoch.fallback_whitelist)
                        .await;
                }
                Ok(slot.committer)
            }
            // Select from next epoch slots.
            Some(SlotOrigin::Next(idx)) => {
                let next_epoch = next.ok_or(LookaheadError::MissingLookahead(next_epoch_start))?;
                let slot =
                    next_epoch.slots.get(idx).ok_or(LookaheadError::CorruptLookaheadCache {
                        epoch_start: next_epoch_start,
                        index: idx,
                        len: next_epoch.slots.len(),
                    })?;
                // Check blacklist status.
                if self.was_blacklisted_at(slot.registrationRoot, ts) {
                    return self
                        .resolve_fallback(ts, epoch_start, curr_epoch.fallback_whitelist)
                        .await;
                }
                Ok(slot.committer)
            }
            // Fallback to current epoch whitelist operator.
            None => self.resolve_fallback(ts, epoch_start, curr_epoch.fallback_whitelist).await,
        }
    }

    /// Return whether the operator registration root was blacklisted at the provided timestamp.
    fn was_blacklisted_at(&self, registration_root: B256, ts: u64) -> bool {
        self.blacklist_history
            .get(&registration_root)
            .is_some_and(|timeline| timeline.was_blacklisted_at(ts))
    }

    /// Resolve the whitelist fallback operator for the given timestamp using the live timeline,
    /// inserting the provided baseline when no history exists for the epoch.
    async fn resolve_fallback(
        &self,
        ts: u64,
        epoch_start: u64,
        baseline: Address,
    ) -> Result<Address> {
        self.fallback_timeline.prune_before(earliest_allowed_timestamp(self.genesis_timestamp)?);
        self.fallback_timeline.ensure_baseline(epoch_start, baseline);
        Ok(self.fallback_timeline.operator_at(ts).unwrap_or(baseline))
    }

    /// Locate a block whose timestamp is within the given epoch window `[epoch_start,
    /// epoch_start + SECONDS_IN_EPOCH)`. Returns the full block if found.
    async fn block_within_epoch(&self, epoch_start: u64) -> Result<Option<RpcBlock>> {
        let epoch_end = epoch_start.saturating_add(SECONDS_IN_EPOCH);

        // Start from the latest block to reduce reorg risk (see basic head-hash check below).
        let latest = self
            .provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(|err| LookaheadError::EventDecode(err.to_string()))?;

        let Some(block) = latest else { return Ok(None) };
        let mut curr_num = block.number();
        let mut curr_ts = block.header.timestamp;

        if curr_ts < epoch_start {
            return Ok(None);
        }
        if curr_ts < epoch_end {
            return Ok(Some(block));
        }

        // Step backwards one block at a time (bounded) to find any block inside the epoch window.
        let mut attempts = 0u16;
        while curr_num > 0 && attempts < MAX_BACKWARD_STEPS {
            curr_num = curr_num.saturating_sub(1);

            let maybe_block = self
                .provider
                .get_block_by_number(BlockNumberOrTag::Number(curr_num))
                .await
                .map_err(|err| LookaheadError::EventDecode(err.to_string()))?;

            let Some(new_block) = maybe_block else { break };
            curr_ts = new_block.header.timestamp;
            if curr_ts < epoch_start {
                return Ok(None);
            }
            if curr_ts < epoch_end {
                return Ok(Some(new_block));
            }
            attempts = attempts.saturating_add(1);
        }

        Ok(None)
    }

    /// Snapshot the whitelist operator for the current epoch at the specified block.
    async fn whitelist_operator_at(&self, block_number: u64) -> Result<Address> {
        self.preconf_whitelist
            .getOperatorForCurrentEpoch()
            .block(BlockId::Number(block_number.into()))
            .call()
            .await
            .map_err(LookaheadError::PreconfWhitelist)
    }

    /// Record a baseline fallback for the epoch if none exists before `epoch_start`.
    async fn record_fallback_baseline(
        &self,
        epoch_start: u64,
        at: u64,
        operator: Address,
    ) -> Result<()> {
        self.fallback_timeline.apply(FallbackEvent { at, operator });
        self.fallback_timeline.prune_before(earliest_allowed_timestamp(self.genesis_timestamp)?);
        self.fallback_timeline.ensure_baseline(epoch_start, operator);
        Ok(())
    }

    /// Return the address of the preconfirmation whitelist contract.
    fn preconf_whitelist_address(&self) -> Address {
        *self.preconf_whitelist.address()
    }

    /// Materialize and cache an empty epoch entry when the *current* epoch has started but no
    /// lookahead was posted, mirroring `_handleEmptyCurrentLookahead` behavior. Past epochs should
    /// not be synthesized; if invoked after the epoch end, treat it as missing lookahead.
    async fn synthetic_empty_epoch(
        &self,
        epoch_start: u64,
        now: u64,
    ) -> Result<CachedLookaheadEpoch> {
        if now < epoch_start {
            return Err(LookaheadError::MissingLookahead(epoch_start));
        }
        if now >= epoch_start.saturating_add(SECONDS_IN_EPOCH) {
            return Err(LookaheadError::MissingLookahead(epoch_start));
        }

        let block = match self.block_within_epoch(epoch_start).await? {
            Some(block) => block,
            None => return Err(LookaheadError::MissingLookahead(epoch_start)),
        };

        let fallback_current = self
            .preconf_whitelist
            .getOperatorForCurrentEpoch()
            .block(BlockId::Number(block.number().into()))
            .call()
            .await
            .map_err(LookaheadError::PreconfWhitelist)?;

        self.record_fallback_baseline(epoch_start, block.header.timestamp, fallback_current)
            .await?;

        let cached = CachedLookaheadEpoch {
            slots: Arc::new(vec![]),
            fallback_whitelist: fallback_current,
            block_timestamp: block.header.timestamp,
        };
        self.cache.insert(epoch_start, cached.clone());
        Ok(cached)
    }
}

#[async_trait]
impl<P> PreconfSignerResolver for LookaheadResolver<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Return the address allowed to sign the commitment covering `l2_block_timestamp`.
    async fn signer_for_timestamp(&self, l2_block_timestamp: U256) -> Result<Address> {
        self.committer_for_timestamp(l2_block_timestamp).await
    }
}

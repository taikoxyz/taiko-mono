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

use crate::preconfirmation::lookahead::{
    PreconfSlotInfo,
    client::LookaheadClient,
    resolver::{BlockReader, LookaheadStoreClient, WhitelistClient},
};

use crate::preconfirmation::lookahead::resolver::epoch::current_unix_timestamp;

use super::{
    super::{
        PreconfSignerResolver,
        error::{LookaheadError, Result},
    },
    epoch::{
        MAX_BACKWARD_STEPS, SECONDS_IN_EPOCH, SECONDS_IN_SLOT, earliest_allowed_timestamp,
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
pub struct LookaheadResolver {
    /// Lookahead store API abstraction.
    pub(crate) client: Arc<dyn LookaheadStoreClient>,
    /// Preconf whitelist abstraction.
    pub(crate) preconf_whitelist: Arc<dyn WhitelistClient>,
    /// Block reader abstraction.
    pub(crate) block_reader: Arc<dyn BlockReader>,
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

impl LookaheadResolver {
    /// Build a resolver backed by the given Inbox address and provider, inferring the beacon
    /// genesis timestamp from the chain ID.
    pub(crate) async fn build<P>(inbox_address: Address, provider: P) -> Result<Self>
    where
        P: Provider + Clone + Send + Sync + 'static,
    {
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
    pub(crate) async fn build_with_genesis<P>(
        inbox_address: Address,
        provider: P,
        genesis_timestamp: u64,
    ) -> Result<Self>
    where
        P: Provider + Clone + Send + Sync + 'static,
    {
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

        let store_client: Arc<dyn LookaheadStoreClient> =
            Arc::new(OnchainLookaheadStoreClient::new(client.clone()));
        let whitelist_client: Arc<dyn WhitelistClient> =
            Arc::new(OnchainWhitelistClient::new(preconf_whitelist));
        let block_reader: Arc<dyn BlockReader> = Arc::new(OnchainBlockReader::new(provider));

        Ok(Self {
            client: store_client,
            preconf_whitelist: whitelist_client,
            block_reader,
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
    #[must_use = "filter must be passed to a scanner"]
    pub fn lookahead_filter(&self) -> EventFilter {
        EventFilter::new()
            .contract_addresses([self.client.address(), self.preconf_whitelist.address()])
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
    #[must_use = "receiver must be stored to receive updates"]
    pub fn enable_broadcast_channel(
        &mut self,
        capacity: usize,
    ) -> broadcast::Receiver<LookaheadBroadcast> {
        let (tx, rx) = broadcast::channel(capacity);
        self.broadcast_tx = Some(tx);
        rx
    }

    /// Subscribe to lookahead updates if broadcasting is enabled.
    #[must_use = "receiver must be stored to receive updates"]
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
            let block_number = log.block_number.ok_or(LookaheadError::MissingLogField {
                field: "block_number",
                context: "ingesting LookaheadPosted",
            })?;
            let block_timestamp = match log.block_timestamp {
                Some(ts) => ts,
                None => self.fetch_block_timestamp(block_number).await?,
            };

            if log.address() == self.client.address() {
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
            } else if log.address() == self.preconf_whitelist.address() {
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
        // Snapshot whitelist state at the event block: use the operator designated for the epoch
        // being posted (next-epoch operator at this block).
        let fallback_current = self.preconf_whitelist.next_operator(block_number).await?;

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

    /// Record the current-epoch whitelist operator at the provided block into the fallback
    /// timeline, keyed by the epoch that contains the block timestamp.
    async fn record_whitelist_event(&self, block_number: u64, block_timestamp: u64) -> Result<()> {
        let epoch_start = epoch_start_for(block_timestamp, self.genesis_timestamp);
        let next_epoch_start = epoch_start.saturating_add(SECONDS_IN_EPOCH);

        let current_epoch_operator = self.whitelist_operator_at(block_number).await?;
        let next_epoch_operator = self.preconf_whitelist.next_operator(block_number).await?;

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

    /// Fetch block timestamp from the provider, wrapping errors as `BlockLookup`.
    async fn fetch_block_timestamp(&self, block_number: u64) -> Result<u64> {
        self.block_reader
            .block_by_number(block_number)
            .await
            .map_err(|err| LookaheadError::BlockLookup { block_number, reason: err.to_string() })?
            .ok_or(LookaheadError::BlockLookup {
                block_number,
                reason: "missing block data".into(),
            })
            .map(|block| block.header.timestamp)
    }

    /// Resolve the expected signer plus submission window end for a given L1 timestamp
    /// (seconds since epoch).
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
    ///   events), fall back to the cached current-epoch whitelist but preserve the slot timestamp
    ///   as the submission window end.
    /// - Timestamps earlier than `earliest_allowed_timestamp` (one full epoch behind "now") are
    ///   rejected as `TooOld`; timestamps at or beyond `latest_allowed_timestamp` (end of the
    ///   current epoch) are rejected as `TooNew`.
    pub async fn slot_info_for_timestamp(&self, timestamp: U256) -> Result<PreconfSlotInfo> {
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
                    let signer = self
                        .resolve_fallback(ts, epoch_start, curr_epoch.fallback_whitelist)
                        .await?;
                    return Ok(PreconfSlotInfo { signer, submission_window_end: slot.timestamp });
                }
                Ok(PreconfSlotInfo {
                    signer: slot.committer,
                    submission_window_end: slot.timestamp,
                })
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
                    let signer = self
                        .resolve_fallback(ts, epoch_start, curr_epoch.fallback_whitelist)
                        .await?;
                    return Ok(PreconfSlotInfo { signer, submission_window_end: slot.timestamp });
                }
                Ok(PreconfSlotInfo {
                    signer: slot.committer,
                    submission_window_end: slot.timestamp,
                })
            }
            // Fallback to current epoch whitelist operator.
            None => {
                let signer =
                    self.resolve_fallback(ts, epoch_start, curr_epoch.fallback_whitelist).await?;
                Ok(PreconfSlotInfo {
                    signer,
                    submission_window_end: U256::from(
                        next_epoch_start.saturating_sub(SECONDS_IN_SLOT),
                    ),
                })
            }
        }
    }

    /// Resolve the expected committer for a given L1 timestamp (seconds since epoch).
    pub async fn committer_for_timestamp(&self, timestamp: U256) -> Result<Address> {
        Ok(self.slot_info_for_timestamp(timestamp).await?.signer)
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

        let Some(block) = self.block_reader.latest_block().await? else { return Ok(None) };
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

            let maybe_block = self.block_reader.block_by_number(curr_num).await?;

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
        self.preconf_whitelist.current_operator(block_number).await
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

        let fallback_current = self.preconf_whitelist.current_operator(block.number()).await?;

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
impl PreconfSignerResolver for LookaheadResolver {
    /// Return the address allowed to sign the commitment covering `l2_block_timestamp`.
    async fn signer_for_timestamp(&self, l2_block_timestamp: U256) -> Result<Address> {
        self.committer_for_timestamp(l2_block_timestamp).await
    }

    /// Return the signer plus canonical submission window end for `l2_block_timestamp`.
    async fn slot_info_for_timestamp(&self, l2_block_timestamp: U256) -> Result<PreconfSlotInfo> {
        self.slot_info_for_timestamp(l2_block_timestamp).await
    }
}

/// Production adapter for block reads over a concrete provider.
#[derive(Clone)]
struct OnchainBlockReader<P> {
    /// Underlying provider used for block RPCs.
    provider: P,
}

impl<P> OnchainBlockReader<P> {
    /// Create a block reader over the provided provider.
    fn new(provider: P) -> Self {
        Self { provider }
    }
}

#[async_trait]
impl<P> BlockReader for OnchainBlockReader<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    async fn latest_block(&self) -> Result<Option<RpcBlock>> {
        self.provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(|err| LookaheadError::EventDecode(err.to_string()))
    }

    async fn block_by_number(&self, number: u64) -> Result<Option<RpcBlock>> {
        self.provider
            .get_block_by_number(BlockNumberOrTag::Number(number))
            .await
            .map_err(|err| LookaheadError::EventDecode(err.to_string()))
    }
}

/// Production adapter for whitelist contract calls.
#[derive(Clone)]
struct OnchainWhitelistClient<P> {
    /// Bound preconf whitelist contract instance.
    inner: PreconfWhitelistInstance<P>,
}

impl<P> OnchainWhitelistClient<P> {
    /// Create a whitelist adapter around the given contract instance.
    fn new(inner: PreconfWhitelistInstance<P>) -> Self {
        Self { inner }
    }
}

#[async_trait]
impl<P> WhitelistClient for OnchainWhitelistClient<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Return the PreconfWhitelist contract address.
    fn address(&self) -> Address {
        *self.inner.address()
    }

    /// Call `PreconfWhitelist.getOperatorForCurrentEpoch` at the given block number.
    async fn current_operator(&self, block_number: u64) -> Result<Address> {
        self.inner
            .getOperatorForCurrentEpoch()
            .block(BlockId::Number(block_number.into()))
            .call()
            .await
            .map_err(LookaheadError::PreconfWhitelist)
    }

    /// Get the next epoch's operator at the given block number.
    async fn next_operator(&self, block_number: u64) -> Result<Address> {
        self.inner
            .getOperatorForNextEpoch()
            .block(BlockId::Number(block_number.into()))
            .call()
            .await
            .map_err(LookaheadError::PreconfWhitelist)
    }
}

/// Production adapter for lookahead store access.
#[derive(Clone)]
struct OnchainLookaheadStoreClient<P: Provider + Clone + Send + Sync + 'static> {
    /// Bound lookahead client (Inbox + LookaheadStore helpers).
    client: LookaheadClient<P>,
}

impl<P: Provider + Clone + Send + Sync + 'static> OnchainLookaheadStoreClient<P> {
    /// Create a lookahead store adapter over the given client.
    fn new(client: LookaheadClient<P>) -> Self {
        Self { client }
    }
}

#[async_trait]
impl<P> LookaheadStoreClient for OnchainLookaheadStoreClient<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Return the LookaheadStore contract address.
    fn address(&self) -> Address {
        self.client.lookahead_store_address()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    // Uint import retained if additional fake configs need big ints; currently unused.
    use bindings::lookahead_store::ILookaheadStore::LookaheadSlot as BindingLookaheadSlot;
    use dashmap::DashMap;
    use tokio::runtime::Runtime;

    #[derive(Clone, Default)]
    struct FakeBlockReader {
        latest: RpcBlock,
        blocks: DashMap<u64, RpcBlock>,
    }

    #[async_trait]
    impl BlockReader for FakeBlockReader {
        async fn latest_block(&self) -> Result<Option<RpcBlock>> {
            Ok(Some(self.latest.clone()))
        }

        async fn block_by_number(&self, number: u64) -> Result<Option<RpcBlock>> {
            Ok(self.blocks.get(&number).map(|b| b.clone()))
        }
    }

    #[derive(Clone, Default)]
    struct FakeWhitelist {
        current: Address,
        next: Address,
        addr: Address,
    }

    #[async_trait]
    impl WhitelistClient for FakeWhitelist {
        fn address(&self) -> Address {
            self.addr
        }

        async fn current_operator(&self, _block_number: u64) -> Result<Address> {
            Ok(self.current)
        }

        async fn next_operator(&self, _block_number: u64) -> Result<Address> {
            Ok(self.next)
        }
    }

    #[derive(Clone, Default)]
    struct FakeStore {
        addr: Address,
    }

    #[async_trait]
    impl LookaheadStoreClient for FakeStore {
        fn address(&self) -> Address {
            self.addr
        }
    }

    fn make_block(number: u64, timestamp: u64) -> RpcBlock {
        let mut block: RpcBlock = RpcBlock::default();
        block.header.number = number;
        block.header.timestamp = timestamp;
        block
    }

    fn test_resolver_with_cache(
        cache: DashMap<u64, CachedLookaheadEpoch>,
        fallback_timeline: FallbackTimelineStore,
        blacklist_history: DashMap<B256, BlacklistTimeline>,
        lookahead_buffer_size: usize,
        genesis_timestamp: u64,
        block_reader: FakeBlockReader,
        whitelist: FakeWhitelist,
        store: FakeStore,
    ) -> LookaheadResolver {
        LookaheadResolver {
            client: Arc::new(store),
            preconf_whitelist: Arc::new(whitelist),
            block_reader: Arc::new(block_reader),
            fallback_timeline,
            cache: Arc::new(cache),
            blacklist_history: Arc::new(blacklist_history),
            lookahead_buffer_size,
            genesis_timestamp,
            broadcast_tx: None,
        }
    }

    #[test]
    fn committer_happy_path_current_epoch_slot() {
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let now = current_unix_timestamp().unwrap();
            let epoch_start = epoch_start_for(now, 0);
            let slot_ts = now;
            let committer = Address::from([0xaa; 20]);
            let slot = BindingLookaheadSlot {
                timestamp: U256::from(slot_ts),
                committer,
                registrationRoot: B256::ZERO,
                validatorLeafIndex: U256::ZERO,
            };
            let cached = CachedLookaheadEpoch {
                slots: Arc::new(vec![slot]),
                fallback_whitelist: Address::from([0xbb; 20]),
                block_timestamp: epoch_start,
            };
            let cache = DashMap::new();
            cache.insert(epoch_start, cached);

            let latest_block = make_block(100, now);
            let blocks = DashMap::new();
            blocks.insert(100, latest_block.clone());

            let resolver = test_resolver_with_cache(
                cache,
                FallbackTimelineStore::new(),
                DashMap::new(),
                2,
                0,
                FakeBlockReader { latest: latest_block, blocks },
                FakeWhitelist {
                    current: Address::from([0xcc; 20]),
                    next: Address::from([0xdd; 20]),
                    addr: Address::from([0x12; 20]),
                },
                FakeStore { addr: Address::from([0x56; 20]) },
            );

            let result = resolver.committer_for_timestamp(U256::from(slot_ts)).await.unwrap();
            assert_eq!(result, committer);
        });
    }

    #[test]
    fn committer_fallback_on_empty_epoch() {
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let now = current_unix_timestamp().unwrap();
            let epoch_start = epoch_start_for(now, 0);
            let fallback = Address::from([0xef; 20]);
            let cached = CachedLookaheadEpoch {
                slots: Arc::new(vec![]),
                fallback_whitelist: fallback,
                block_timestamp: epoch_start,
            };
            let cache = DashMap::new();
            cache.insert(epoch_start, cached);

            let latest_block = make_block(200, now);
            let blocks = DashMap::new();
            blocks.insert(200, latest_block.clone());

            let resolver = test_resolver_with_cache(
                cache,
                FallbackTimelineStore::new(),
                DashMap::new(),
                2,
                0,
                FakeBlockReader { latest: latest_block, blocks },
                FakeWhitelist {
                    current: fallback,
                    next: fallback,
                    addr: Address::from([0x9a; 20]),
                },
                FakeStore { addr: Address::from([0x56; 20]) },
            );

            let result = resolver.committer_for_timestamp(U256::from(now)).await.unwrap();
            assert_eq!(result, fallback);
        });
    }

    #[test]
    fn committer_cross_epoch_selects_next_epoch_slot() {
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let now = current_unix_timestamp().unwrap();
            let genesis = now.saturating_sub(SECONDS_IN_EPOCH * 4);
            let epoch_start = epoch_start_for(now, genesis);
            let next_epoch_start = epoch_start.saturating_add(SECONDS_IN_EPOCH);

            // Current epoch: one slot earlier than ts; should force cross-epoch selection.
            let fallback_current = Address::from([0xaa; 20]);
            let slot_curr = BindingLookaheadSlot {
                timestamp: U256::from(epoch_start + 1),
                committer: Address::from([0xcc; 20]),
                registrationRoot: B256::ZERO,
                validatorLeafIndex: U256::ZERO,
            };
            let cached_current = CachedLookaheadEpoch {
                slots: Arc::new(vec![slot_curr]),
                fallback_whitelist: fallback_current,
                block_timestamp: epoch_start,
            };

            // Next epoch: first slot ahead of the queried timestamp.
            let next_slot_ts = next_epoch_start.saturating_add(10);
            let committer_next = Address::from([0xbb; 20]);
            let slot_next = BindingLookaheadSlot {
                timestamp: U256::from(next_slot_ts),
                committer: committer_next,
                registrationRoot: B256::ZERO,
                validatorLeafIndex: U256::ZERO,
            };
            let cached_next = CachedLookaheadEpoch {
                slots: Arc::new(vec![slot_next]),
                fallback_whitelist: Address::from([0xcc; 20]),
                block_timestamp: next_epoch_start,
            };

            let cache = DashMap::new();
            cache.insert(epoch_start, cached_current);
            cache.insert(next_epoch_start, cached_next);

            let latest_block = make_block(400, now);
            let blocks = DashMap::new();

            let resolver = test_resolver_with_cache(
                cache,
                FallbackTimelineStore::new(),
                DashMap::new(),
                2,
                genesis,
                FakeBlockReader { latest: latest_block, blocks },
                FakeWhitelist {
                    current: fallback_current,
                    next: committer_next,
                    addr: Address::from([0x9a; 20]),
                },
                FakeStore { addr: Address::from([0x56; 20]) },
            );

            // Query inside current epoch but after the only current slot; should pick next-epoch
            // slot.
            let query_ts = epoch_start + (SECONDS_IN_EPOCH / 2);
            let result = resolver.committer_for_timestamp(U256::from(query_ts)).await.unwrap();
            assert_eq!(result, committer_next);
        });
    }

    #[test]
    fn committer_blacklisted_slot_falls_back() {
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let now = current_unix_timestamp().unwrap();
            let epoch_start = epoch_start_for(now, 0);
            let slot_ts = now;
            let committer = Address::from([0xaa; 20]);
            let root = B256::from([1u8; 32]);
            let slot = BindingLookaheadSlot {
                timestamp: U256::from(slot_ts),
                committer,
                registrationRoot: root,
                validatorLeafIndex: U256::ZERO,
            };
            let fallback = Address::from([0xee; 20]);
            let cached = CachedLookaheadEpoch {
                slots: Arc::new(vec![slot]),
                fallback_whitelist: fallback,
                block_timestamp: epoch_start,
            };
            let cache = DashMap::new();
            cache.insert(epoch_start, cached);

            let latest_block = make_block(300, now);
            let blocks = DashMap::new();

            // Blacklist the slot's registration root at the query timestamp.
            let mut bl = BlacklistTimeline::default();
            bl.apply(BlacklistEvent { at: slot_ts, flag: BlacklistFlag::Listed });
            let blacklist_history = {
                let map = DashMap::new();
                map.insert(root, bl);
                map
            };

            let resolver = test_resolver_with_cache(
                cache,
                FallbackTimelineStore::new(),
                blacklist_history,
                2,
                0,
                FakeBlockReader { latest: latest_block, blocks },
                FakeWhitelist {
                    current: fallback,
                    next: fallback,
                    addr: Address::from([0x9a; 20]),
                },
                FakeStore { addr: Address::from([0x56; 20]) },
            );

            let result = resolver.committer_for_timestamp(U256::from(slot_ts)).await.unwrap();
            assert_eq!(result, fallback);
        });
    }

    #[test]
    fn slot_info_same_epoch_returns_slot_timestamp() {
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let now = current_unix_timestamp().unwrap();
            let epoch_start = epoch_start_for(now, 0);
            let slot_ts = now;
            let committer = Address::from([0xaa; 20]);
            let slot = BindingLookaheadSlot {
                timestamp: U256::from(slot_ts),
                committer,
                registrationRoot: B256::ZERO,
                validatorLeafIndex: U256::ZERO,
            };
            let cached = CachedLookaheadEpoch {
                slots: Arc::new(vec![slot]),
                fallback_whitelist: Address::from([0xbb; 20]),
                block_timestamp: epoch_start,
            };
            let cache = DashMap::new();
            cache.insert(epoch_start, cached);

            let latest_block = make_block(101, now);
            let blocks = DashMap::new();
            blocks.insert(101, latest_block.clone());

            let resolver = test_resolver_with_cache(
                cache,
                FallbackTimelineStore::new(),
                DashMap::new(),
                2,
                0,
                FakeBlockReader { latest: latest_block, blocks },
                FakeWhitelist {
                    current: Address::from([0xcc; 20]),
                    next: Address::from([0xdd; 20]),
                    addr: Address::from([0x12; 20]),
                },
                FakeStore { addr: Address::from([0x56; 20]) },
            );

            let info = resolver.slot_info_for_timestamp(U256::from(slot_ts)).await.unwrap();
            assert_eq!(info.signer, committer);
            assert_eq!(info.submission_window_end, U256::from(slot_ts));
        });
    }

    #[test]
    fn slot_info_fallback_empty_epoch_returns_epoch_end_minus_slot() {
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let now = current_unix_timestamp().unwrap();
            let epoch_start = epoch_start_for(now, 0);
            let next_epoch_start = epoch_start.saturating_add(SECONDS_IN_EPOCH);
            let fallback = Address::from([0xef; 20]);
            let cached = CachedLookaheadEpoch {
                slots: Arc::new(vec![]),
                fallback_whitelist: fallback,
                block_timestamp: epoch_start,
            };
            let cache = DashMap::new();
            cache.insert(epoch_start, cached);

            let latest_block = make_block(202, now);
            let blocks = DashMap::new();
            blocks.insert(202, latest_block.clone());

            let resolver = test_resolver_with_cache(
                cache,
                FallbackTimelineStore::new(),
                DashMap::new(),
                2,
                0,
                FakeBlockReader { latest: latest_block, blocks },
                FakeWhitelist {
                    current: fallback,
                    next: fallback,
                    addr: Address::from([0x9a; 20]),
                },
                FakeStore { addr: Address::from([0x56; 20]) },
            );

            let info = resolver.slot_info_for_timestamp(U256::from(now)).await.unwrap();
            assert_eq!(info.signer, fallback);
            assert_eq!(
                info.submission_window_end,
                U256::from(next_epoch_start.saturating_sub(SECONDS_IN_SLOT))
            );
        });
    }

    #[test]
    fn slot_info_blacklisted_keeps_window_end_but_falls_back_signer() {
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let now = current_unix_timestamp().unwrap();
            let epoch_start = epoch_start_for(now, 0);
            let slot_ts = now;
            let committer = Address::from([0xaa; 20]);
            let root = B256::from([1u8; 32]);
            let slot = BindingLookaheadSlot {
                timestamp: U256::from(slot_ts),
                committer,
                registrationRoot: root,
                validatorLeafIndex: U256::ZERO,
            };
            let fallback = Address::from([0xee; 20]);
            let cached = CachedLookaheadEpoch {
                slots: Arc::new(vec![slot]),
                fallback_whitelist: fallback,
                block_timestamp: epoch_start,
            };
            let cache = DashMap::new();
            cache.insert(epoch_start, cached);

            let latest_block = make_block(303, now);
            let blocks = DashMap::new();

            let mut bl = BlacklistTimeline::default();
            bl.apply(BlacklistEvent { at: slot_ts, flag: BlacklistFlag::Listed });
            let blacklist_history = {
                let map = DashMap::new();
                map.insert(root, bl);
                map
            };

            let resolver = test_resolver_with_cache(
                cache,
                FallbackTimelineStore::new(),
                blacklist_history,
                2,
                0,
                FakeBlockReader { latest: latest_block, blocks },
                FakeWhitelist {
                    current: fallback,
                    next: fallback,
                    addr: Address::from([0x9a; 20]),
                },
                FakeStore { addr: Address::from([0x56; 20]) },
            );

            let info = resolver.slot_info_for_timestamp(U256::from(slot_ts)).await.unwrap();
            assert_eq!(info.signer, fallback);
            assert_eq!(info.submission_window_end, U256::from(slot_ts));
        });
    }

    #[test]
    fn committer_errors_on_too_old_timestamp() {
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let now = current_unix_timestamp().unwrap();
            // Position genesis two epochs back so earliest_allowed is well above zero.
            let genesis = now.saturating_sub(SECONDS_IN_EPOCH * 2);
            let earliest_allowed = earliest_allowed_timestamp_at(now, genesis);
            let too_old_ts = earliest_allowed.saturating_sub(1);

            let latest_block = make_block(1, now);
            let blocks = DashMap::new();

            let resolver = test_resolver_with_cache(
                DashMap::new(),
                FallbackTimelineStore::new(),
                DashMap::new(),
                2,
                genesis,
                FakeBlockReader { latest: latest_block, blocks },
                FakeWhitelist {
                    current: Address::from([0x01; 20]),
                    next: Address::from([0x02; 20]),
                    addr: Address::from([0x03; 20]),
                },
                FakeStore { addr: Address::from([0x04; 20]) },
            );

            let result = resolver.committer_for_timestamp(U256::from(too_old_ts)).await;
            assert!(matches!(result, Err(LookaheadError::TooOld(ts)) if ts == too_old_ts));
        });
    }

    #[test]
    fn committer_errors_on_too_new_timestamp() {
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let now = current_unix_timestamp().unwrap();
            let genesis = now.saturating_sub(SECONDS_IN_EPOCH * 2);
            let latest_allowed = latest_allowed_timestamp_at(now, genesis);
            let too_new_ts = latest_allowed;

            let latest_block = make_block(2, now);
            let blocks = DashMap::new();

            let resolver = test_resolver_with_cache(
                DashMap::new(),
                FallbackTimelineStore::new(),
                DashMap::new(),
                2,
                genesis,
                FakeBlockReader { latest: latest_block, blocks },
                FakeWhitelist {
                    current: Address::from([0x11; 20]),
                    next: Address::from([0x12; 20]),
                    addr: Address::from([0x13; 20]),
                },
                FakeStore { addr: Address::from([0x14; 20]) },
            );

            let result = resolver.committer_for_timestamp(U256::from(too_new_ts)).await;
            assert!(matches!(result, Err(LookaheadError::TooNew(ts)) if ts == too_new_ts));
        });
    }

    #[test]
    fn committer_synthesizes_empty_epoch_when_missing_cache() {
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let now = current_unix_timestamp().unwrap();
            let genesis = now.saturating_sub(SECONDS_IN_EPOCH * 2);
            let epoch_start = epoch_start_for(now, genesis);

            // Provide a latest block that sits inside the current epoch window so
            // `block_within_epoch` can materialize an empty epoch.
            let latest_block = make_block(10, epoch_start + 10);
            let blocks = DashMap::new();

            let fallback = Address::from([0xaa; 20]);

            let resolver = test_resolver_with_cache(
                DashMap::new(),
                FallbackTimelineStore::new(),
                DashMap::new(),
                2,
                genesis,
                FakeBlockReader { latest: latest_block, blocks },
                FakeWhitelist {
                    current: fallback,
                    next: fallback,
                    addr: Address::from([0xbb; 20]),
                },
                FakeStore { addr: Address::from([0xcc; 20]) },
            );

            let result = resolver.committer_for_timestamp(U256::from(epoch_start + 20)).await;
            assert_eq!(result.unwrap(), fallback);
        });
    }

    #[test]
    fn ingest_logs_populates_cache_and_resolves_slot() {
        let rt = Runtime::new().unwrap();
        rt.block_on(async {
            let now = current_unix_timestamp().unwrap();
            let genesis = now.saturating_sub(SECONDS_IN_EPOCH * 3);
            let epoch_start = epoch_start_for(now, genesis);
            let slot_ts = epoch_start + 10;
            let committer = Address::from([0x21; 20]);
            let root = B256::from([2u8; 32]);

            // Build a LookaheadPosted log with one slot.
            let slot = BindingLookaheadSlot {
                timestamp: U256::from(slot_ts),
                committer,
                registrationRoot: root,
                validatorLeafIndex: U256::ZERO,
            };
            let store_addr = Address::from([0x44; 20]);
            let event = LookaheadPosted {
                epochTimestamp: U256::from(epoch_start),
                lookaheadHash: B256::ZERO,
                lookaheadSlots: vec![slot],
            };
            let log_data = event.encode_log_data();
            let inner = alloy_primitives::Log::new_unchecked(
                store_addr,
                log_data.topics().to_vec(),
                log_data.data.clone(),
            );
            let block_number = 123u64;
            let log = Log {
                inner,
                block_hash: None,
                block_number: Some(block_number),
                block_timestamp: Some(epoch_start),
                transaction_hash: None,
                transaction_index: None,
                log_index: None,
                removed: false,
            };

            // Resolver with empty cache; ingest will populate.
            let latest_block = make_block(block_number, now);
            let blocks = DashMap::new();
            let fallback = Address::from([0x55; 20]);

            let resolver = test_resolver_with_cache(
                DashMap::new(),
                FallbackTimelineStore::new(),
                DashMap::new(),
                2,
                genesis,
                FakeBlockReader { latest: latest_block, blocks },
                FakeWhitelist {
                    current: fallback,
                    next: fallback,
                    addr: Address::from([0x33; 20]),
                },
                FakeStore { addr: store_addr },
            );

            resolver.ingest_logs(vec![log]).await.unwrap();

            let result = resolver.committer_for_timestamp(U256::from(slot_ts)).await.unwrap();
            assert_eq!(result, committer);
        });
    }
}

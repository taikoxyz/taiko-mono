use std::sync::Arc;

use alloy::{eips::BlockId, sol_types::SolEvent};
use alloy_primitives::{Address, B256, U256};
use alloy_provider::Provider;
use alloy_rpc_types::{BlockNumberOrTag, Log};
use bindings::{
    lookahead_store::LookaheadStore::{Blacklisted, LookaheadPosted, Unblacklisted},
    preconf_whitelist::PreconfWhitelist::PreconfWhitelistInstance,
};
use dashmap::DashMap;
use event_scanner::EventFilter;
use tokio::{
    runtime::{Builder, Handle},
    sync::broadcast,
};
use tracing::warn;

use crate::preconfirmation::lookahead::resolver::epoch::current_unix_timestamp;

use super::{
    super::{
        PreconfSignerResolver,
        client::LookaheadClient,
        error::{LookaheadError, Result},
    },
    epoch::{
        MAX_BACKWARD_STEPS, SECONDS_IN_EPOCH, earliest_allowed_timestamp, epoch_start_for,
        genesis_timestamp_for_chain, latest_allowed_timestamp,
    },
    timeline::{BlacklistEvent, BlacklistFlag, BlacklistTimeline},
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
    /// Sliding window of cached epochs keyed by epoch start timestamp.
    pub(crate) cache: Arc<DashMap<u64, CachedLookaheadEpoch>>,
    /// Time-aware blacklist history keyed by operator registration root.
    pub(crate) blacklist_history: Arc<DashMap<B256, BlacklistTimeline>>,
    /// Maximum cached epochs (derived from on-chain lookahead buffer size).
    lookahead_buffer_size: usize,
    /// Beacon genesis timestamp for the connected chain.
    genesis_timestamp: u64,
    /// Optional broadcast sender for lookahead updates (epochs and blacklist changes).
    epoch_tx: Option<broadcast::Sender<LookaheadBroadcast>>,
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
            cache: Arc::new(DashMap::new()),
            blacklist_history: Arc::new(DashMap::new()),
            lookahead_buffer_size: lookahead_cfg.lookaheadBufferSize as usize,
            genesis_timestamp,
            epoch_tx: None,
        })
    }

    /// Build an event filter for `LookaheadPosted` plus blacklist/unblacklist events emitted by the
    /// resolved LookaheadStore.
    pub fn lookahead_filter(&self) -> EventFilter {
        EventFilter::new()
            .contract_address(self.client.lookahead_store_address())
            .event(LookaheadPosted::SIGNATURE)
            .event(Unblacklisted::SIGNATURE)
            .event(Blacklisted::SIGNATURE)
    }

    /// Number of epochs cached, matching the on-chain lookahead buffer size.
    pub(crate) fn lookahead_buffer_size(&self) -> usize {
        self.lookahead_buffer_size
    }

    /// Enable a broadcast channel; clones share the sender. Returns a receiver for updates.
    pub fn enable_epoch_channel(
        &mut self,
        capacity: usize,
    ) -> broadcast::Receiver<LookaheadBroadcast> {
        let (tx, rx) = broadcast::channel(capacity);
        self.epoch_tx = Some(tx);
        rx
    }

    /// Subscribe to epoch updates if broadcasting is enabled.
    pub fn subscribe(&self) -> Option<broadcast::Receiver<LookaheadBroadcast>> {
        self.epoch_tx.as_ref().map(|tx| tx.subscribe())
    }

    /// Ingest a batch of logs and update the in-memory cache plus live blacklist state.
    /// `Log` must include the block number so fallback operators can be snapshotted at the same
    /// state as the lookahead event.
    pub async fn ingest_logs<I>(&self, logs: I) -> Result<()>
    where
        I: IntoIterator<Item = Log>,
    {
        for log in logs.into_iter() {
            if log.address() != self.client.lookahead_store_address() {
                continue;
            }

            let Some(first_topic) = log.topics().first().copied() else { continue };

            // Decode and handle each event type.
            if first_topic == LookaheadPosted::SIGNATURE_HASH {
                // Decode the lookahead posted event and store it.
                let event = LookaheadPosted::decode_raw_log(
                    log.topics().to_vec(),
                    log.data().data.as_ref(),
                )
                .map_err(|err| LookaheadError::EventDecode(err.to_string()))?;

                self.store_epoch(event, log.block_number).await?;
            } else if first_topic == Blacklisted::SIGNATURE_HASH {
                // Decode and apply blacklist event.
                let event =
                    Blacklisted::decode_raw_log(log.topics().to_vec(), log.data().data.as_ref())
                        .map_err(|err| LookaheadError::EventDecode(err.to_string()))?;
                self.record_blacklist_event(event.operatorRegistrationRoot, event.timestamp.to())?;
                // Broadcast blacklist update if channel is enabled.
                if let Some(tx) = &self.epoch_tx {
                    let _ = tx.send(LookaheadBroadcast::Blacklisted {
                        root: event.operatorRegistrationRoot,
                    });
                }
            } else if first_topic == Unblacklisted::SIGNATURE_HASH {
                // Decode and apply unblacklist event.
                let event =
                    Unblacklisted::decode_raw_log(log.topics().to_vec(), log.data().data.as_ref())
                        .map_err(|err| LookaheadError::EventDecode(err.to_string()))?;
                self.record_unblacklist_event(
                    event.operatorRegistrationRoot,
                    event.timestamp.to(),
                )?;
                // Broadcast unblacklist update if channel is enabled.
                if let Some(tx) = &self.epoch_tx {
                    let _ = tx.send(LookaheadBroadcast::Unblacklisted {
                        root: event.operatorRegistrationRoot,
                    });
                }
            } else {
                warn!(topic = ?first_topic, "unrecognized log topic");
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
        block_number: Option<u64>,
    ) -> Result<()> {
        // Ensure we have the block number for snapshotting.
        let block = block_number.ok_or_else(|| {
            LookaheadError::EventDecode("lookahead log missing block number".into())
        })?;

        // Snapshot whitelist state at the event block state.
        let fallback_current = self.snapshot_whitelist(block).await?;

        // Insert or update the cached epoch entry.
        let cached = CachedLookaheadEpoch {
            slots: Arc::new(event.lookaheadSlots),
            fallback_whitelist: fallback_current,
        };

        // Store in the cache keyed by epoch start timestamp.
        let epoch_start = event.epochTimestamp.to::<u64>();
        self.cache.insert(epoch_start, cached.clone());

        // Broadcast the epoch update if channel is enabled.
        if let Some(tx) = &self.epoch_tx {
            let _ = tx.send(LookaheadBroadcast::Epoch(LookaheadEpochUpdate {
                epoch_start,
                epoch: cached,
            }));
        }

        // Evict oldest entries beyond buffer size.
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
    /// - Timestamps older than one epoch before the current epoch start are rejected as `TooOld`.
    pub async fn committer_for_timestamp(&self, timestamp: U256) -> Result<Address> {
        // Convert timestamp to u64 and check genesis boundary.
        let ts = u64::try_from(timestamp)
            .map_err(|_| LookaheadError::EventDecode("timestamp does not fit u64".into()))?;

        // Timestamps before genesis cannot be resolved.
        if ts < self.genesis_timestamp {
            return Err(LookaheadError::BeforeGenesis(ts));
        }

        // Reject timestamps older than the configured lookback window to avoid unbounded lookups.
        let earliest_allowed = earliest_allowed_timestamp(self.genesis_timestamp)?;
        if ts < earliest_allowed {
            return Err(LookaheadError::TooOld(ts));
        }

        // Reject timestamps beyond the current epoch window; resolver only serves up to "now" epoch.
        let latest_allowed = latest_allowed_timestamp(self.genesis_timestamp)?;
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
            self.synthetic_empty_epoch(epoch_start).await?
        };

        // Resolve based on selection and blacklist status.
        match pick_slot_origin(ts, &curr_epoch.slots, next.as_ref().map(|n| n.slots.as_slice())) {
            // Select from current epoch slots.
            Some(SlotOrigin::Current(idx)) => {
                let slot = &curr_epoch.slots[idx];
                // Check blacklist status.
                if self.was_blacklisted_at(slot.registrationRoot, ts) {
                    return Ok(curr_epoch.fallback_whitelist);
                }
                Ok(slot.committer)
            }
            // Select from next epoch slots.
            Some(SlotOrigin::Next(idx)) => {
                let next_epoch = next.ok_or(LookaheadError::MissingLookahead(next_epoch_start))?;
                let slot = next_epoch
                    .slots
                    .get(idx)
                    .ok_or(LookaheadError::MissingLookahead(next_epoch_start))?;
                // Check blacklist status.
                if self.was_blacklisted_at(slot.registrationRoot, ts) {
                    return Ok(curr_epoch.fallback_whitelist);
                }
                Ok(slot.committer)
            }
            // Fallback to current epoch whitelist operator.
            None => Ok(curr_epoch.fallback_whitelist),
        }
    }

    /// Return whether the operator registration root was blacklisted at the provided timestamp.
    fn was_blacklisted_at(&self, registration_root: B256, ts: u64) -> bool {
        self.blacklist_history
            .get(&registration_root)
            .is_some_and(|timeline| timeline.was_blacklisted_at(ts))
    }

    /// Locate a block whose timestamp is within the given epoch window `[epoch_start,
    /// epoch_start + SECONDS_IN_EPOCH)`. Returns the block number if found.
    async fn block_within_epoch(&self, epoch_start: u64) -> Result<Option<u64>> {
        let epoch_end = epoch_start.saturating_add(SECONDS_IN_EPOCH);

        // Start from the latest block to reduce reorg risk.
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
            return Ok(Some(curr_num));
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
                return Ok(Some(new_block.number()));
            }
            attempts = attempts.saturating_add(1);
        }

        Ok(None)
    }

    /// Materialize and cache an empty epoch entry when the epoch has started but no lookahead was
    /// posted, mirroring `_handleEmptyCurrentLookahead` behavior.
    async fn synthetic_empty_epoch(&self, epoch_start: u64) -> Result<CachedLookaheadEpoch> {
        if current_unix_timestamp()? < epoch_start {
            return Err(LookaheadError::MissingLookahead(epoch_start));
        }

        let block_number = self.block_within_epoch(epoch_start).await?;
        let Some(block_number) = block_number else {
            return Err(LookaheadError::MissingLookahead(epoch_start));
        };

        let fallback_current = self
            .preconf_whitelist
            .getOperatorForCurrentEpoch()
            .block(BlockId::Number(block_number.into()))
            .call()
            .await
            .map_err(LookaheadError::PreconfWhitelist)?;

        let cached =
            CachedLookaheadEpoch { slots: Arc::new(vec![]), fallback_whitelist: fallback_current };
        self.cache.insert(epoch_start, cached.clone());
        Ok(cached)
    }
}

impl<P> PreconfSignerResolver for LookaheadResolver<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Blocking convenience wrapper around `committer_for_timestamp` to satisfy the synchronous
    /// `PreconfSignerResolver` trait. Mirrors resolver behavior including empty-epoch fallback and
    /// live blacklist checks.
    fn signer_for_timestamp(&self, l2_block_timestamp: U256) -> Result<Address> {
        if let Ok(handle) = Handle::try_current() {
            handle.block_on(self.committer_for_timestamp(l2_block_timestamp))
        } else {
            Builder::new_current_thread()
                .enable_all()
                .build()
                .map_err(|err| LookaheadError::EventDecode(err.to_string()))?
                .block_on(self.committer_for_timestamp(l2_block_timestamp))
        }
    }
}

use std::sync::Arc;

use alloy::{eips::BlockId, sol_types::SolEvent};
use alloy_primitives::{Address, U256};
use alloy_provider::Provider;
use alloy_rpc_types::Log;
use bindings::{
    lookahead_store::LookaheadStore::LookaheadPosted,
    preconf_whitelist::PreconfWhitelist::PreconfWhitelistInstance,
};
use dashmap::DashMap;
use event_scanner::EventFilter;
use futures::future::try_join_all;
use tokio::{
    runtime::{Builder, Handle},
    sync::broadcast,
};
use tracing::debug;

use super::{
    LookaheadSlot, PreconfSignerResolver,
    client::LookaheadClient,
    error::{LookaheadError, Result},
};

/// Duration of a single preconfirmation slot in seconds.
pub const SECONDS_IN_SLOT: u64 = 12;
/// Duration of one epoch in seconds (32 slots).
pub const SECONDS_IN_EPOCH: u64 = SECONDS_IN_SLOT * 32;

#[derive(Clone)]
enum Selection {
    /// A concrete committer was found for the queried timestamp.
    Slot(LookaheadSlot),
    /// No slot covers the timestamp; fall back according to epoch context.
    Fallback(FallbackEpoch),
}

/// Which epoch's whitelist operator should be used for fallback resolution.
#[derive(Clone, Copy)]
enum FallbackEpoch {
    /// Fall back using the current epoch's whitelist operator.
    Current,
    /// Fall back using the next epoch's whitelist operator.
    Next,
}

/// Cached lookahead data for a single epoch.
#[derive(Clone, Debug)]
pub struct CachedLookaheadEpoch {
    /// Ordered lookahead slots for an epoch as emitted by `LookaheadPosted`.
    slots: Arc<Vec<LookaheadSlot>>, // slots are already ordered on-chain
    /// Snapshot of the whitelist operator for this epoch when the lookahead was observed.
    fallback_whitelist: Option<Address>,
    /// Snapshot of the whitelist operator for the *next* epoch at the same observation point.
    fallback_whitelist_next: Option<Address>,
    /// Per-slot blacklist flags, computed at ingest using the LookaheadPosted block. Aligned with
    /// `slots`.
    slot_blacklisted: Arc<Vec<bool>>,
}

impl CachedLookaheadEpoch {
    /// Read-only view of ordered slots for this epoch.
    pub fn slots(&self) -> &[LookaheadSlot] {
        &self.slots
    }

    /// Blacklist flags aligned with [`slots`].
    pub fn blacklist_flags(&self) -> &[bool] {
        &self.slot_blacklisted
    }

    /// Whitelist fallback captured for this epoch at ingest time.
    pub fn fallback_whitelist(&self) -> Option<Address> {
        self.fallback_whitelist
    }

    /// Whitelist fallback for the next epoch captured at the same block.
    pub fn fallback_whitelist_next(&self) -> Option<Address> {
        self.fallback_whitelist_next
    }
}

/// Epoch update broadcast structure.
#[derive(Clone, Debug)]
pub struct LookaheadEpochUpdate {
    /// Epoch start timestamp (seconds since UNIX_EPOCH).
    pub epoch_start: u64,
    /// Cached epoch data.
    pub epoch: CachedLookaheadEpoch,
}

/// Maintains a sliding cache of lookahead epochs and resolves the expected committer for a
/// timestamp using `LookaheadPosted` events plus on-chain blacklist / whitelist fallbacks.
#[derive(Clone)]
pub struct LookaheadResolver<P: Provider + Clone + Send + Sync + 'static> {
    /// Thin contract client helpers (Inbox/LookaheadStore).
    pub(crate) client: LookaheadClient<P>,
    /// Preconf whitelist contract instance for fallback selection.
    preconf_whitelist: PreconfWhitelistInstance<P>,
    /// Sliding window of cached epochs keyed by epoch start timestamp.
    cache: Arc<DashMap<u64, CachedLookaheadEpoch>>,
    /// Maximum cached epochs (derived from on-chain lookahead buffer size).
    lookahead_buffer_size: usize,
    /// Beacon genesis timestamp for the connected chain.
    genesis_timestamp: u64,
    /// Optional broadcast sender for epoch updates.
    epoch_tx: Option<broadcast::Sender<LookaheadEpochUpdate>>,
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
            cache: Arc::new(DashMap::new()),
            lookahead_buffer_size: lookahead_cfg.lookaheadBufferSize as usize,
            genesis_timestamp,
            epoch_tx: None,
        })
    }

    /// Build an event filter for `LookaheadPosted` events emitted by the resolved LookaheadStore.
    pub fn lookahead_filter(&self) -> EventFilter {
        EventFilter::new()
            .contract_address(self.client.lookahead_store_address())
            .event(LookaheadPosted::SIGNATURE)
    }

    /// Number of epochs cached, matching the on-chain lookahead buffer size.
    pub(crate) fn lookahead_buffer_size(&self) -> usize {
        self.lookahead_buffer_size
    }

    /// Enable an epoch broadcast channel; clones share the sender. Returns a receiver for updates.
    pub fn enable_epoch_channel(
        &mut self,
        capacity: usize,
    ) -> broadcast::Receiver<LookaheadEpochUpdate> {
        let (tx, rx) = broadcast::channel(capacity);
        self.epoch_tx = Some(tx);
        rx
    }

    /// Subscribe to epoch updates if broadcasting is enabled.
    pub fn subscribe(&self) -> Option<broadcast::Receiver<LookaheadEpochUpdate>> {
        self.epoch_tx.as_ref().map(|tx| tx.subscribe())
    }

    /// Ingest a batch of logs and update the in-memory cache.
    /// Returns the number of `LookaheadPosted` events applied.
    /// Ingest lookahead logs and update cache/snapshots. `Log` must include the block number so
    /// fallback operators can be snapshotted at the same state as the lookahead event.
    pub async fn ingest_logs<I>(&self, logs: I) -> Result<usize>
    where
        I: IntoIterator<Item = Log>,
    {
        let mut applied = 0usize;
        for log in logs.into_iter() {
            if log.address() != self.client.lookahead_store_address() {
                continue;
            }

            let event =
                LookaheadPosted::decode_raw_log(log.topics().to_vec(), log.data().data.as_ref())
                    .map_err(|err| LookaheadError::EventDecode(err.to_string()))?;

            self.store_epoch(event, log.block_number).await?;
            applied += 1;
        }

        debug!(applied, "lookahead logs ingested");
        Ok(applied)
    }

    /// Cache a newly observed `LookaheadPosted` event for quick timestamp lookups, capturing
    /// whitelist fallback operators at the event's block so later resolution can
    /// avoid additional on-chain calls and stay consistent with the block where the lookahead was
    /// posted.
    pub(crate) async fn store_epoch(
        &self,
        event: LookaheadPosted,
        block_number: Option<u64>,
    ) -> Result<()> {
        // Ensure we have the block number for snapshotting.
        let block = block_number.ok_or_else(|| {
            LookaheadError::EventDecode("lookahead log missing block number".into())
        })?;

        // Snapshot whitelist and blacklist state at the event block state.
        let ((fallback_current, fallback_next), slot_blacklisted) = tokio::try_join!(
            self.snapshot_whitelist(block),
            self.precompute_blacklist_flags(&event.lookaheadSlots, block)
        )?;

        // Insert or update the cached epoch entry.
        let cached = CachedLookaheadEpoch {
            slots: Arc::new(event.lookaheadSlots),
            fallback_whitelist: fallback_current,
            fallback_whitelist_next: fallback_next,
            slot_blacklisted: Arc::new(slot_blacklisted),
        };

        // Store in the cache keyed by epoch start timestamp.
        let epoch_start = event.epochTimestamp.to::<u64>();
        self.cache.insert(epoch_start, cached.clone());

        // Broadcast the epoch update if channel is enabled.
        if let Some(tx) = &self.epoch_tx {
            let _ = tx.send(LookaheadEpochUpdate { epoch_start, epoch: cached });
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

    /// Snapshot whitelist fallback operators at a specific block, mirroring the state used when the
    /// lookahead event was emitted. Returns (current_epoch, next_epoch).
    async fn snapshot_whitelist(&self, block: u64) -> Result<(Option<Address>, Option<Address>)> {
        let current_query = self
            .preconf_whitelist
            .getOperatorForCurrentEpoch()
            .block(BlockId::Number(block.into()));
        let next_query =
            self.preconf_whitelist.getOperatorForNextEpoch().block(BlockId::Number(block.into()));

        // Run both queries concurrently.
        let (current, next) = tokio::join!(current_query.call(), next_query.call());

        Ok((
            Some(current.map_err(LookaheadError::PreconfWhitelist)?),
            Some(next.map_err(LookaheadError::PreconfWhitelist)?),
        ))
    }

    /// Precompute blacklist flags for a batch of slots at a specific block.
    async fn precompute_blacklist_flags(
        &self,
        slots: &[LookaheadSlot],
        block: u64,
    ) -> Result<Vec<bool>> {
        // Prepare tasks to query blacklist status for each slot's registration root.
        let futs = slots.iter().map(|slot| async move {
            self.client
                .lookahead_store()
                .isOperatorBlacklisted(slot.registrationRoot)
                .block(BlockId::Number(block.into()))
                .call()
                .await
                .map_err(LookaheadError::Blacklist)
        });

        // Run queries concurrently and collect results.
        try_join_all(futs).await
    }

    /// Resolve the expected committer for a given L1 timestamp (seconds since epoch).
    ///
    /// Steps:
    /// - Floor the timestamp to an epoch boundary using the configured genesis (no slot
    ///   realignment).
    /// - Load cached lookahead for current/next epochs if present.
    /// - Pick the first slot covering `ts`; if none, try the first slot of next epoch; otherwise
    ///   enter fallback.
    /// - If the chosen slot was marked blacklisted at ingest (snapshot taken at the log block when
    ///   available), fall back to the cached whitelist operator; otherwise return the slot
    ///   committer. If no slot applies, use the cached whitelist fallback for the appropriate
    ///   epoch, fetching live only when the cache lacks a snapshot.
    pub async fn committer_for_timestamp(&self, timestamp: U256) -> Result<Address> {
        // Convert timestamp to u64 and check genesis boundary.
        let ts = u64::try_from(timestamp)
            .map_err(|_| LookaheadError::EventDecode("timestamp does not fit u64".into()))?;

        // Timestamps before genesis cannot be resolved.
        if ts < self.genesis_timestamp {
            return Err(LookaheadError::BeforeGenesis(ts));
        }

        // Calculate epoch boundaries.
        let epoch_start = epoch_start_for(ts, self.genesis_timestamp);
        let next_epoch_start = epoch_start.saturating_add(SECONDS_IN_EPOCH);

        // Get cached epochs if available.
        let current = self.cache.get(&epoch_start).map(|entry| entry.clone());
        let next = self.cache.get(&next_epoch_start).map(|entry| entry.clone());

        // Determine which epoch's whitelist to use for fallback.
        let fallback_epoch = fallback_epoch_for(ts, self.genesis_timestamp);

        // Choose a slot or fallback.
        let selection = match current.as_ref() {
            None => Selection::Fallback(fallback_epoch),
            Some(curr_epoch) => select_slot(ts, curr_epoch, next.as_ref(), fallback_epoch),
        };

        match selection {
            Selection::Slot(slot) => {
                // Slot found; blacklist check is precomputed in the cached epoch.
                let is_blacklisted = current
                    .as_ref()
                    .and_then(|curr| {
                        curr.slots
                            .iter()
                            .position(|s| s.registrationRoot == slot.registrationRoot)
                            .and_then(|idx| curr.slot_blacklisted.get(idx).copied())
                    })
                    .or_else(|| {
                        next.as_ref().and_then(|nxt| {
                            nxt.slots
                                .iter()
                                .position(|s| s.registrationRoot == slot.registrationRoot)
                                .and_then(|idx| nxt.slot_blacklisted.get(idx).copied())
                        })
                    })
                    .unwrap_or(false);

                if is_blacklisted {
                    if let Some(addr) =
                        cached_fallback(fallback_epoch, current.as_ref(), next.as_ref())
                    {
                        return Ok(addr);
                    }
                    return self.fallback_operator(fallback_epoch).await;
                }
                Ok(slot.committer)
            }
            Selection::Fallback(fallback_choice) => {
                // No slot covers this timestamp; use cached fallback when present.
                if let Some(addr) =
                    cached_fallback(fallback_choice, current.as_ref(), next.as_ref())
                {
                    return Ok(addr);
                }
                self.fallback_operator(fallback_choice).await
            }
        }
    }

    /// Resolve the whitelist fallback operator for the requested epoch context.
    async fn fallback_operator(&self, fallback: FallbackEpoch) -> Result<Address> {
        let result = match fallback {
            FallbackEpoch::Current => {
                self.preconf_whitelist.getOperatorForCurrentEpoch().call().await
            }
            FallbackEpoch::Next => self.preconf_whitelist.getOperatorForNextEpoch().call().await,
        };

        result.map_err(LookaheadError::PreconfWhitelist)
    }
}

impl<P> PreconfSignerResolver for LookaheadResolver<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Blocking convenience wrapper around `committer_for_timestamp` to satisfy the synchronous
    /// `PreconfSignerResolver` trait.
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

/// Helper to choose the slot covering `ts` within cached epochs, or decide to fall back.
///
/// Selection rules (mirrors on-chain lookahead use):
/// - Walk the current epoch's slots (already ordered by timestamp) and pick the first slot whose
///   timestamp is >= `ts`.
/// - If no slot in the current epoch qualifies, try the first slot of the next epoch (if cached)
///   and only if `ts` is before or equal to that first-slot timestamp.
/// - Otherwise return a fallback marker so caller can use whitelist operators for the appropriate
///   epoch.
fn select_slot(
    ts: u64,
    current: &CachedLookaheadEpoch,
    next: Option<&CachedLookaheadEpoch>,
    fallback_epoch: FallbackEpoch,
) -> Selection {
    // No slots in current epoch; must fall back.
    if current.slots.is_empty() {
        return Selection::Fallback(fallback_epoch);
    }

    // Slots are ordered by timestamp on-chain; linear scan for first slot >= ts.
    let slots = &*current.slots;
    let mut idx = None;
    for (i, slot) in slots.iter().enumerate() {
        let slot_ts = slot.timestamp.to::<u64>();
        if ts <= slot_ts {
            idx = Some(i);
            break;
        }
    }

    // Found a slot in current epoch.
    if let Some(i) = idx {
        return Selection::Slot(slots[i].clone());
    }

    // No slot left in current epoch; consult first slot of next epoch if present.
    if let Some(next_epoch) = next &&
        let Some(first) = next_epoch.slots.first() &&
        ts <= first.timestamp.to::<u64>()
    {
        return Selection::Slot(first.clone());
    }

    Selection::Fallback(fallback_epoch)
}

/// Decide whether a timestamp should fall back to the current-epoch or next-epoch whitelist
/// operator.
///
/// In practice this returns `Current`, because the timestamp always falls within its own epoch
/// window; `Next` is retained for symmetry but is only reachable if callers supply a timestamp
/// beyond the computed epoch boundary.
fn fallback_epoch_for(ts: u64, genesis_timestamp: u64) -> FallbackEpoch {
    let epoch_start = epoch_start_for(ts, genesis_timestamp);
    let next_epoch_start = epoch_start.saturating_add(SECONDS_IN_EPOCH);

    if ts >= next_epoch_start { FallbackEpoch::Next } else { FallbackEpoch::Current }
}

/// Return a cached fallback operator for the requested epoch if present.
fn cached_fallback(
    fallback: FallbackEpoch,
    current: Option<&CachedLookaheadEpoch>,
    next: Option<&CachedLookaheadEpoch>,
) -> Option<Address> {
    match fallback {
        FallbackEpoch::Current => current.and_then(|c| c.fallback_whitelist),
        FallbackEpoch::Next => next
            .and_then(|c| c.fallback_whitelist)
            .or_else(|| next.and_then(|c| c.fallback_whitelist_next)),
    }
}

/// Return the epoch start boundary (in seconds) that contains `ts`.
///
/// Assumes the provided `genesis_timestamp` is already aligned to the slot/epoch boundary; we do
/// not snap misaligned timestamps up to the next 12-second multiple. Calculation simply floors to
/// the nearest epoch based on the given genesis.
fn epoch_start_for(ts: u64, genesis_timestamp: u64) -> u64 {
    let elapsed = ts.saturating_sub(genesis_timestamp);
    let epochs = elapsed / SECONDS_IN_EPOCH;
    genesis_timestamp + epochs * SECONDS_IN_EPOCH
}

/// Return the beacon genesis timestamp for known chains.
///
/// Mappings are derived from `LibPreconfConstants` and `LibNetwork`:
/// - 1: Ethereum mainnet (1_606_824_023)
/// - 17_000: Holesky (1_695_902_400)
/// - 560_048: Hoodi (1_742_213_400)
///
/// Any other chain ID yields `None` and surfaces as `UnknownChain` to callers.
fn genesis_timestamp_for_chain(chain_id: u64) -> Option<u64> {
    match chain_id {
        1 => Some(1_606_824_023),
        17_000 => Some(1_695_902_400),
        560_048 => Some(1_742_213_400),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use alloy_primitives::B256;

    use super::*;

    #[test]
    fn epoch_start_floors_relative_to_genesis() {
        let genesis = 1_000;
        assert_eq!(epoch_start_for(genesis, genesis), genesis);
        assert_eq!(epoch_start_for(genesis + 5, genesis), genesis);
        assert_eq!(epoch_start_for(genesis + SECONDS_IN_SLOT, genesis), genesis);
        assert_eq!(epoch_start_for(genesis + SECONDS_IN_EPOCH - 1, genesis), genesis);
        assert_eq!(
            epoch_start_for(genesis + SECONDS_IN_EPOCH + 1, genesis),
            genesis + SECONDS_IN_EPOCH
        );
    }

    #[test]
    fn genesis_timestamp_known_and_unknown() {
        assert_eq!(genesis_timestamp_for_chain(1), Some(1_606_824_023));
        assert_eq!(genesis_timestamp_for_chain(17_000), Some(1_695_902_400));
        assert_eq!(genesis_timestamp_for_chain(99999), None);
    }

    #[test]
    fn fallback_epoch_relies_on_target_timestamp() {
        let genesis = 1_000;
        let ts = genesis + SECONDS_IN_SLOT;
        let ts_next_epoch_start = genesis + SECONDS_IN_EPOCH;

        assert!(matches!(fallback_epoch_for(ts, genesis), FallbackEpoch::Current));
        assert!(matches!(fallback_epoch_for(ts_next_epoch_start, genesis), FallbackEpoch::Current));
    }

    #[test]
    fn cached_fallback_uses_epoch_aligned_snapshot() {
        let addr_curr = Address::from([0x11u8; 20]);

        let current = CachedLookaheadEpoch {
            slots: Arc::new(vec![]),
            fallback_whitelist: Some(addr_curr),
            fallback_whitelist_next: Some(addr_curr),
            slot_blacklisted: Arc::new(vec![]),
        };

        assert_eq!(cached_fallback(FallbackEpoch::Current, Some(&current), None), Some(addr_curr));
        assert_eq!(
            cached_fallback(FallbackEpoch::Next, Some(&current), Some(&current)),
            Some(addr_curr)
        );
    }

    #[test]
    fn select_slot_uses_first_matching_or_fallback() {
        let current = CachedLookaheadEpoch {
            slots: Arc::new(vec![
                LookaheadSlot {
                    timestamp: U256::from(200),
                    committer: Address::ZERO,
                    registrationRoot: B256::ZERO,
                    validatorLeafIndex: U256::ZERO,
                },
                LookaheadSlot {
                    timestamp: U256::from(220),
                    committer: Address::from([1u8; 20]),
                    registrationRoot: B256::ZERO,
                    validatorLeafIndex: U256::ZERO,
                },
            ]),
            fallback_whitelist: None,
            fallback_whitelist_next: None,
            slot_blacklisted: Arc::new(vec![false, false]),
        };

        let selected = select_slot(205, &current, None, FallbackEpoch::Current);
        match selected {
            Selection::Slot(slot) => assert_eq!(slot.committer, Address::from([1u8; 20])),
            _ => panic!("expected slot"),
        }

        let fallback = select_slot(300, &current, None, FallbackEpoch::Next);
        assert!(matches!(fallback, Selection::Fallback(FallbackEpoch::Next)));
    }

    fn resolve_from_cache<F>(
        cache: &DashMap<u64, CachedLookaheadEpoch>,
        genesis: u64,
        ts: u64,
        is_blacklisted: F,
    ) -> Address
    where
        F: Fn(B256, Option<u64>) -> bool,
    {
        let epoch_start = epoch_start_for(ts, genesis);
        let next_epoch_start = epoch_start.saturating_add(SECONDS_IN_EPOCH);

        let current = cache.get(&epoch_start).map(|entry| entry.clone());
        let next = cache.get(&next_epoch_start).map(|entry| entry.clone());

        let fallback_epoch = fallback_epoch_for(ts, genesis);
        let selection = match current.as_ref() {
            None => Selection::Fallback(fallback_epoch),
            Some(curr_epoch) => select_slot(ts, curr_epoch, next.as_ref(), fallback_epoch),
        };

        match selection {
            Selection::Slot(slot) => {
                if is_blacklisted(slot.registrationRoot, None) {
                    if let Some(addr) =
                        cached_fallback(fallback_epoch, current.as_ref(), next.as_ref())
                    {
                        return addr;
                    }
                    panic!("missing fallback for blacklisted slot")
                }
                slot.committer
            }
            Selection::Fallback(fallback_choice) => {
                if let Some(addr) =
                    cached_fallback(fallback_choice, current.as_ref(), next.as_ref())
                {
                    return addr;
                }
                panic!("missing fallback for empty epoch")
            }
        }
    }

    #[tokio::test]
    async fn slot_blacklisted_at_log_block_falls_back() {
        let fallback = Address::from([0xAAu8; 20]);
        let committer = Address::from([0xBBu8; 20]);
        let registration_root = B256::from([0xCCu8; 32]);

        let cache = DashMap::new();
        cache.insert(
            1_000,
            CachedLookaheadEpoch {
                slots: Arc::new(vec![LookaheadSlot {
                    timestamp: U256::from(1_000),
                    committer,
                    registrationRoot: registration_root,
                    validatorLeafIndex: U256::ZERO,
                }]),
                fallback_whitelist: Some(fallback),
                fallback_whitelist_next: Some(fallback),
                slot_blacklisted: Arc::new(vec![true]),
            },
        );

        let got = resolve_from_cache(&cache, 1_000, 1_000, |_, _| true);

        assert_eq!(got, fallback);
    }

    #[tokio::test]
    async fn slot_blacklisted_after_log_block_keeps_committer() {
        let fallback = Address::from([0xAAu8; 20]);
        let committer = Address::from([0xBBu8; 20]);
        let registration_root = B256::from([0xCCu8; 32]);

        let cache = DashMap::new();
        cache.insert(
            2_000,
            CachedLookaheadEpoch {
                slots: Arc::new(vec![LookaheadSlot {
                    timestamp: U256::from(2_000),
                    committer,
                    registrationRoot: registration_root,
                    validatorLeafIndex: U256::ZERO,
                }]),
                fallback_whitelist: Some(fallback),
                fallback_whitelist_next: Some(fallback),
                slot_blacklisted: Arc::new(vec![false]),
            },
        );

        let got = resolve_from_cache(&cache, 2_000, 2_000, |_, _| false);

        assert_eq!(got, committer);
    }
}

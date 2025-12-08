use std::{
    sync::Arc,
    time::{SystemTime, UNIX_EPOCH},
};

use alloy::{eips::BlockId, sol_types::SolEvent};
use alloy_primitives::{Address, B256, U256};
use alloy_provider::Provider;
use alloy_rpc_types::Log;
use bindings::{
    lookahead_store::LookaheadStore::LookaheadPosted,
    preconf_whitelist::PreconfWhitelist::PreconfWhitelistInstance,
};
use dashmap::DashMap;
use event_scanner::EventFilter;
use tokio::runtime::{Builder, Handle};
use tracing::debug;

use super::{
    LookaheadSlot, PreconfSignerResolver,
    client::LookaheadClient,
    error::{LookaheadError, Result},
};

/// Duration of a single preconfirmation slot in seconds.
const SECONDS_IN_SLOT: u64 = 12;
/// Duration of one epoch in seconds (32 slots).
const SECONDS_IN_EPOCH: u64 = SECONDS_IN_SLOT * 32;

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
#[derive(Clone)]
struct CachedLookaheadEpoch {
    /// Ordered lookahead slots for an epoch as emitted by `LookaheadPosted`.
    slots: Arc<Vec<LookaheadSlot>>, // slots are already ordered on-chain
    /// Snapshot of the whitelist operator for this epoch (current) at the log block, if known.
    fallback_current: Option<Address>,
    /// Snapshot of the next-epoch whitelist operator at the log block, if known.
    fallback_next: Option<Address>,
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

    /// Ingest a batch of logs (e.g. from event-scanner) and update the in-memory cache.
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

            self.store_epoch(event, log.block_number).await;
            applied += 1;
        }

        debug!(applied, "lookahead logs ingested");
        Ok(applied)
    }

    /// Cache a newly observed `LookaheadPosted` event for quick timestamp lookups, capturing
    /// whitelist fallback operators at the event's block if available so later resolution can
    /// avoid additional on-chain calls and stay consistent with the block where the lookahead was
    /// posted.
    pub(crate) async fn store_epoch(&self, event: LookaheadPosted, block_number: Option<u64>) {
        let snapshots = if let Some(block) = block_number {
            self.snapshot_whitelist(block).await.unwrap_or_default()
        } else {
            (None, None)
        };

        // Insert or update the cached epoch entry.
        self.cache.insert(
            event.epochTimestamp.to::<u64>(),
            CachedLookaheadEpoch {
                slots: Arc::new(event.lookaheadSlots),
                fallback_current: snapshots.0,
                fallback_next: snapshots.1,
            },
        );

        // Evict oldest entries beyond buffer size.
        while self.cache.len() > self.lookahead_buffer_size + 1 {
            if let Some(oldest) = self.cache.iter().map(|e| *e.key()).min() {
                self.cache.remove(&oldest);
            } else {
                break;
            }
        }
    }

    /// Snapshot whitelist fallback operators at a specific block, mirroring the state used when
    /// the lookahead event was emitted. Returns (current_epoch, next_epoch).
    async fn snapshot_whitelist(&self, block: u64) -> Result<(Option<Address>, Option<Address>)> {
        let block_tag = BlockId::Number(block.into());
        let current_builder = self.preconf_whitelist.getOperatorForCurrentEpoch().block(block_tag);

        let next_builder = self.preconf_whitelist.getOperatorForNextEpoch().block(block_tag);

        let current_fut = current_builder.call();
        let next_fut = next_builder.call();

        let (current, next) = tokio::join!(current_fut, next_fut);

        Ok((current.ok(), next.ok()))
    }

    /// Resolve the expected committer for a given L1 timestamp (seconds since epoch).
    ///
    /// Steps:
    /// - Floor the timestamp to an epoch boundary using the configured genesis (no slot
    ///   realignment).
    /// - Load cached lookahead for current/next epochs if present.
    /// - Pick the first slot covering `ts`; if none, try the first slot of next epoch; otherwise
    ///   enter fallback.
    /// - If the chosen slot is blacklisted or no slot exists, use the cached whitelist fallback
    ///   operator for the appropriate epoch when available; otherwise fetch it live from
    ///   PreconfWhitelist (`getOperatorForCurrentEpoch`/`getOperatorForNextEpoch`).
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

        let fallback_epoch = fallback_epoch_for(ts, self.genesis_timestamp);
        // Choose a slot or fallback.
        let selection = match current.as_ref() {
            None => Selection::Fallback(fallback_epoch),
            Some(curr_epoch) => select_slot(ts, curr_epoch, next.as_ref(), fallback_epoch),
        };

        match selection {
            Selection::Slot(slot) => {
                // Slot found; blacklist check determines whether we fall back instead.
                if self.is_blacklisted(slot.registrationRoot).await? {
                    if let Some(addr) =
                        self.cached_fallback(fallback_epoch, current.as_ref(), next.as_ref())
                    {
                        return Ok(addr);
                    }
                    return self.fallback_operator(fallback_epoch).await;
                }
                Ok(slot.committer)
            }
            Selection::Fallback(which) => {
                // No slot covers this timestamp; use cached fallback when present.
                if let Some(addr) = self.cached_fallback(which, current.as_ref(), next.as_ref()) {
                    return Ok(addr);
                }
                self.fallback_operator(which).await
            }
        }
    }

    /// Return a cached fallback operator for the requested epoch if present.
    fn cached_fallback(
        &self,
        which: FallbackEpoch,
        current: Option<&CachedLookaheadEpoch>,
        next: Option<&CachedLookaheadEpoch>,
    ) -> Option<Address> {
        match which {
            FallbackEpoch::Current => current.and_then(|c| c.fallback_current),
            FallbackEpoch::Next => next.and_then(|c| c.fallback_next),
        }
    }

    /// Resolve the whitelist fallback operator for the requested epoch context.
    async fn fallback_operator(&self, which: FallbackEpoch) -> Result<Address> {
        let result = match which {
            FallbackEpoch::Current => {
                self.preconf_whitelist.getOperatorForCurrentEpoch().call().await
            }
            FallbackEpoch::Next => self.preconf_whitelist.getOperatorForNextEpoch().call().await,
        };

        result.map_err(LookaheadError::PreconfWhitelist)
    }

    /// Check whether a registration root is currently blacklisted on-chain.
    async fn is_blacklisted(&self, registration_root: B256) -> Result<bool> {
        self.client
            .lookahead_store()
            .isOperatorBlacklisted(registration_root)
            .call()
            .await
            .map_err(LookaheadError::Blacklist)
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
/// Mirrors LookaheadStore/PreconfWhitelist behavior: when there is no covering lookahead slot (or
/// the slot is blacklisted), the current epoch uses `getOperatorForCurrentEpoch`, while timestamps
/// already in the *next* epoch use `getOperatorForNextEpoch`. We derive this by comparing the
/// queried timestamp to the boundary of the current epoch computed from the local wall clock
/// (genesis-aligned); anything at or beyond the next-epoch start gets the next-epoch fallback.
fn fallback_epoch_for(ts: u64, genesis_timestamp: u64) -> FallbackEpoch {
    let now = SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(ts);
    let current_epoch_start = epoch_start_for(now, genesis_timestamp);
    let next_epoch_start = current_epoch_start.saturating_add(SECONDS_IN_EPOCH);

    if ts >= next_epoch_start { FallbackEpoch::Next } else { FallbackEpoch::Current }
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
            fallback_current: None,
            fallback_next: None,
        };

        let selected = select_slot(205, &current, None, FallbackEpoch::Current);
        match selected {
            Selection::Slot(slot) => assert_eq!(slot.committer, Address::from([1u8; 20])),
            _ => panic!("expected slot"),
        }

        let fallback = select_slot(300, &current, None, FallbackEpoch::Next);
        assert!(matches!(fallback, Selection::Fallback(FallbackEpoch::Next)));
    }
}

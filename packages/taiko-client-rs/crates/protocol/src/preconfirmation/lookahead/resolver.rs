use std::{
    sync::Arc,
    time::{SystemTime, UNIX_EPOCH},
};

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

use super::{
    LookaheadSlot, PreconfSignerResolver,
    client::LookaheadClient,
    error::{LookaheadError, Result},
};

/// Duration of a single preconfirmation slot in seconds.
pub const SECONDS_IN_SLOT: u64 = 12;
/// Duration of one epoch in seconds (32 slots).
pub const SECONDS_IN_EPOCH: u64 = SECONDS_IN_SLOT * 32;

/// Cached lookahead data for a single epoch.
#[derive(Clone, Debug)]
pub struct CachedLookaheadEpoch {
    /// Ordered lookahead slots for an epoch as emitted by `LookaheadPosted`.
    pub slots: Arc<Vec<LookaheadSlot>>,
    /// Snapshot of the whitelist operator for this epoch at the block that emitted the
    /// `LookaheadPosted` event. Used as a deterministic fallback when lookahead is empty or a slot
    /// is later deemed unusable.
    pub fallback_whitelist: Address,
}

impl CachedLookaheadEpoch {
    /// Read-only view of ordered slots for this epoch.
    pub fn slots(&self) -> &[LookaheadSlot] {
        &self.slots
    }

    /// Blacklist flags are tracked separately via live events.
    /// Whitelist fallback captured for this epoch at ingest time.
    pub fn fallback_whitelist(&self) -> Address {
        self.fallback_whitelist
    }
}

/// Broadcast messages emitted by the resolver.
#[derive(Clone, Debug)]
pub enum LookaheadBroadcast {
    /// Newly cached epoch data.
    Epoch(LookaheadEpochUpdate),
    /// Operator registration root was blacklisted.
    Blacklisted { root: B256 },
    /// Operator registration root was removed from blacklist.
    Unblacklisted { root: B256 },
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
/// timestamp using `LookaheadPosted` events plus live blacklist/unblacklist events and whitelist
/// fallbacks.
#[derive(Clone)]
pub struct LookaheadResolver<P: Provider + Clone + Send + Sync + 'static> {
    /// Thin contract client helpers (Inbox/LookaheadStore).
    pub(crate) client: LookaheadClient<P>,
    /// Preconf whitelist contract instance for fallback selection.
    preconf_whitelist: PreconfWhitelistInstance<P>,
    /// Provider for block lookups to snapshot whitelist fallbacks.
    provider: P,
    /// Sliding window of cached epochs keyed by epoch start timestamp.
    cache: Arc<DashMap<u64, CachedLookaheadEpoch>>,
    /// Live blacklist state keyed by operator registration root.
    blacklisted: Arc<DashMap<B256, ()>>,
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
            blacklisted: Arc::new(DashMap::new()),
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
                self.blacklisted.insert(event.operatorRegistrationRoot, ());
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
                self.blacklisted.remove(&event.operatorRegistrationRoot);
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
    /// network I/O:
    /// - If the epoch has no lookahead slots (including epochs that already started but never
    ///   posted lookahead), use the cached current-epoch whitelist operator for the whole epoch
    ///   (`_handleEmptyCurrentLookahead`).
    /// - Otherwise pick the first slot whose timestamp is >= the queried timestamp
    ///   (`_handleSameEpochProposer` selection); if none exist and the first slot of the next epoch
    ///   is still ahead of `ts`, use that first slot (`_handleCrossEpochProposer`); otherwise fall
    ///   back to the cached current-epoch whitelist.
    /// - If the chosen slot is currently blacklisted (tracked live via events), fall back to the
    ///   cached current-epoch whitelist.
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

        // Ensure current epoch data is available. If the epoch has already started but no
        // lookahead was posted, fall back to the current whitelist operator and cache an empty
        // epoch to mirror `_handleEmptyCurrentLookahead`. Future epochs without lookahead still
        // surface as missing to callers.
        let curr_epoch = if let Some(epoch) = current {
            epoch
        } else {
            let now = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .map_err(|err| LookaheadError::EventDecode(err.to_string()))?
                .as_secs();

            // If the queried epoch is still in the future, surface as missing; otherwise treat it
            // as an empty-current-epoch case and fall back to the cached whitelist operator.
            if now < epoch_start {
                return Err(LookaheadError::MissingLookahead(epoch_start));
            }

            // Find a block within this epoch to snapshot the whitelist state.
            let block_number = self.block_within_epoch(epoch_start).await?;
            let Some(block_number) = block_number else {
                return Err(LookaheadError::MissingLookahead(epoch_start));
            };

            // Snapshot the whitelist operator at that block.
            let fallback_current = self
                .preconf_whitelist
                .getOperatorForCurrentEpoch()
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(LookaheadError::PreconfWhitelist)?;

            // Cache an empty epoch entry.
            let cached = CachedLookaheadEpoch {
                slots: Arc::new(vec![]),
                fallback_whitelist: fallback_current,
            };
            self.cache.insert(epoch_start, cached.clone());
            cached
        };

        // Select the appropriate slot origin and index.
        let selection =
            pick_slot_origin(ts, &curr_epoch.slots, next.as_ref().map(|n| n.slots.as_slice()));

        // Resolve based on selection and blacklist status.
        match selection {
            Some(SlotOrigin::Current(idx)) => {
                let slot = &curr_epoch.slots[idx];
                // Check blacklist status.
                if self.is_blacklisted(slot.registrationRoot) {
                    return Ok(curr_epoch.fallback_whitelist);
                }
                Ok(slot.committer)
            }
            Some(SlotOrigin::Next(idx)) => {
                let next_epoch = next.ok_or(LookaheadError::MissingLookahead(next_epoch_start))?;
                let slot = next_epoch
                    .slots
                    .get(idx)
                    .ok_or(LookaheadError::MissingLookahead(next_epoch_start))?;
                // Check blacklist status.
                if self.is_blacklisted(slot.registrationRoot) {
                    return Ok(curr_epoch.fallback_whitelist);
                }
                Ok(slot.committer)
            }
            None => Ok(curr_epoch.fallback_whitelist),
        }
    }

    /// Return whether the operator registration root is currently blacklisted.
    fn is_blacklisted(&self, registration_root: B256) -> bool {
        self.blacklisted.contains_key(&registration_root)
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
        while curr_num > 0 && attempts < 1024 {
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

/// Identifies which cached epoch supplies the slot for a timestamp.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum SlotOrigin {
    /// Slot comes from the current epoch cache; carries index into `slots`.
    Current(usize),
    /// Slot comes from the next epoch cache; carries index into that epoch's `slots`.
    Next(usize),
}

/// Choose the first applicable lookahead slot for the timestamp, returning its origin and index.
///
/// Slots are ordered on-chain; pick the earliest slot with timestamp >= ts. If none in current
/// epoch, allow the first slot of next epoch if its timestamp is still ahead of ts; otherwise none.
fn pick_slot_origin(
    ts: u64,
    current_slots: &[LookaheadSlot],
    next_slots: Option<&[LookaheadSlot]>,
) -> Option<SlotOrigin> {
    // If the current epoch has no lookahead slots, contract logic falls back to the whitelist for
    // the whole epoch (`_handleEmptyCurrentLookahead`); do not borrow from the next epoch.
    if current_slots.is_empty() {
        return None;
    }

    // Find the first current epoch slot >= ts.
    if let Some((idx, _)) =
        current_slots.iter().enumerate().find(|(_, slot)| ts <= slot.timestamp.to::<u64>())
    {
        return Some(SlotOrigin::Current(idx));
    }

    // No current epoch slot matched; check the first slot of the next epoch if available.
    if let Some(next) = next_slots &&
        let Some(first) = next.first() &&
        ts <= first.timestamp.to::<u64>()
    {
        return Some(SlotOrigin::Next(0));
    }

    // No suitable slot found.
    None
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
    fn cached_fallback_uses_epoch_aligned_snapshot() {
        let addr_curr = Address::from([0x11u8; 20]);

        let current =
            CachedLookaheadEpoch { slots: Arc::new(vec![]), fallback_whitelist: addr_curr };

        assert_eq!(current.fallback_whitelist, addr_curr);
    }

    #[test]
    fn pick_slot_prefers_current_then_next_first() {
        let current = vec![
            LookaheadSlot {
                timestamp: U256::from(200),
                committer: Address::from([1u8; 20]),
                registrationRoot: B256::ZERO,
                validatorLeafIndex: U256::ZERO,
            },
            LookaheadSlot {
                timestamp: U256::from(240),
                committer: Address::from([2u8; 20]),
                registrationRoot: B256::ZERO,
                validatorLeafIndex: U256::ZERO,
            },
        ];

        let next_first = LookaheadSlot {
            timestamp: U256::from(400),
            committer: Address::from([3u8; 20]),
            registrationRoot: B256::ZERO,
            validatorLeafIndex: U256::ZERO,
        };

        let picked = pick_slot_origin(210, &current, Some(&[next_first.clone()])).expect("slot");
        assert_eq!(picked, SlotOrigin::Current(1));

        let picked_next =
            pick_slot_origin(300, &current, Some(&[next_first.clone()])).expect("next slot");
        assert_eq!(picked_next, SlotOrigin::Next(0));

        let none = pick_slot_origin(500, &current, Some(&[next_first]));
        assert!(none.is_none());
    }

    #[test]
    fn pick_slot_falls_back_when_current_empty_even_if_next_present() {
        let next_first = LookaheadSlot {
            timestamp: U256::from(400),
            committer: Address::from([3u8; 20]),
            registrationRoot: B256::ZERO,
            validatorLeafIndex: U256::ZERO,
        };

        let picked = pick_slot_origin(210, &[], Some(&[next_first]));
        assert!(picked.is_none());
    }
}

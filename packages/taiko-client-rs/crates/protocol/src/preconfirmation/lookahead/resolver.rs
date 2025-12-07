use std::{
    collections::BTreeMap,
    sync::Arc,
    time::{SystemTime, UNIX_EPOCH},
};

use alloy::sol_types::SolEvent;
use alloy_primitives::{Address, B256, U256};
use alloy_provider::Provider;
use alloy_rpc_types::Log;
use bindings::{
    lookahead_store::LookaheadStore::LookaheadPosted,
    preconf_whitelist::PreconfWhitelist::PreconfWhitelistInstance,
};
use event_scanner::EventFilter;
use tokio::{
    runtime::{Builder, Handle},
    sync::RwLock,
};

use super::{
    PreconfSignerResolver,
    client::LookaheadClient,
    error::{LookaheadError, Result},
    types::LookaheadSlot,
};

/// Duration of a single preconfirmation slot in seconds (mirrors `LibPreconfConstants`).
const SECONDS_IN_SLOT: u64 = 12;
/// Duration of one epoch in seconds (32 slots).
const SECONDS_IN_EPOCH: u64 = SECONDS_IN_SLOT * 32;

/// Cached lookahead data for a single epoch.
#[derive(Clone)]
struct CachedLookaheadEpoch {
    /// Ordered lookahead slots for an epoch as emitted by `LookaheadPosted`.
    slots: Arc<Vec<LookaheadSlot>>, // slots are already ordered on-chain
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
    cache: Arc<RwLock<BTreeMap<u64, CachedLookaheadEpoch>>>,
    /// Maximum cached epochs (derived from on-chain lookahead buffer size).
    lookahead_buffer_size: usize,
    /// Beacon genesis timestamp for the connected chain.
    genesis_timestamp: u64,
}

impl<P> LookaheadResolver<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Construct a resolver backed by the given Inbox address and provider.
    ///
    /// The resolver eagerly resolves the LookaheadStore and PreconfWhitelist addresses from the
    /// Inbox config and primes epoch arithmetic from the chain ID.
    pub async fn new(inbox_address: Address, provider: P) -> Result<Self> {
        let client = LookaheadClient::new(inbox_address, provider.clone()).await?;

        let lookahead_cfg = client
            .lookahead_store()
            .getLookaheadStoreConfig()
            .call()
            .await
            .map_err(LookaheadError::Lookahead)?;

        let preconf_address = client
            .lookahead_store()
            .preconfWhitelist()
            .call()
            .await
            .map_err(LookaheadError::Lookahead)?;

        let preconf_whitelist = PreconfWhitelistInstance::new(preconf_address, provider.clone());

        let chain_id = provider
            .get_chain_id()
            .await
            .map_err(|err| LookaheadError::EventDecode(err.to_string()))?;

        let genesis_timestamp =
            genesis_timestamp_for_chain(chain_id).ok_or(LookaheadError::UnknownChain(chain_id))?;

        Ok(Self {
            client,
            preconf_whitelist,
            cache: Arc::new(RwLock::new(BTreeMap::new())),
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

    /// Ingest a batch of logs (e.g. from event-scanner) and update the in-memory cache.
    /// Returns the number of `LookaheadPosted` events applied.
    pub async fn ingest_logs<I>(&self, logs: I) -> Result<usize>
    where
        I: IntoIterator<Item = Log>,
    {
        let mut applied = 0usize;
        for log in logs.into_iter() {
            if log.address() != self.client.lookahead_store_address() {
                continue;
            }

            let topics: Vec<B256> = log.topics().to_vec();
            let data = log.data().data.as_ref();

            let maybe_event = <LookaheadPosted as SolEvent>::decode_raw_log(&topics, data)
                .map_err(|err| LookaheadError::EventDecode(err.to_string()))?;

            self.store_epoch(maybe_event).await;
            applied += 1;
        }

        Ok(applied)
    }

    /// Resolve the expected committer for a given L1 timestamp (seconds since epoch).
    pub async fn committer_for_timestamp(&self, timestamp: U256) -> Result<Address> {
        let ts = u64::try_from(timestamp)
            .map_err(|_| LookaheadError::EventDecode("timestamp does not fit u64".into()))?;

        if ts < self.genesis_timestamp {
            return Err(LookaheadError::BeforeGenesis(ts));
        }

        let epoch_start = epoch_start_for(ts, self.genesis_timestamp);
        let next_epoch_start = epoch_start.saturating_add(SECONDS_IN_EPOCH);

        let (current, next) = {
            let cache = self.cache.read().await;
            (cache.get(&epoch_start).cloned(), cache.get(&next_epoch_start).cloned())
        };

        let fallback_epoch = fallback_epoch_for(ts, self.genesis_timestamp);
        let selection = match current.as_ref() {
            None => Selection::Fallback(fallback_epoch),
            Some(curr_epoch) => select_slot(ts, curr_epoch, next.as_ref(), fallback_epoch),
        };

        match selection {
            Selection::Slot(slot) => {
                if self.is_blacklisted(slot.registrationRoot).await? {
                    return self.fallback_operator(fallback_epoch).await;
                }
                Ok(slot.committer)
            }
            Selection::Fallback(which) => self.fallback_operator(which).await,
        }
    }

    /// Cache a newly observed `LookaheadPosted` event for quick timestamp lookups.
    pub(crate) async fn store_epoch(&self, event: LookaheadPosted) {
        let epoch_ts = event.epochTimestamp.to::<u64>();
        let slots = Arc::new(event.lookaheadSlots);

        let mut cache = self.cache.write().await;
        cache.insert(epoch_ts, CachedLookaheadEpoch { slots });

        // Evict oldest entries beyond buffer size (keep an extra future epoch slot)
        while cache.len() > self.lookahead_buffer_size + 1 {
            if let Some(oldest) = cache.keys().next().cloned() {
                cache.remove(&oldest);
            } else {
                break;
            }
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

/// Helper to choose the slot covering `ts` within cached epochs, or decide to fall back.
fn select_slot(
    ts: u64,
    current: &CachedLookaheadEpoch,
    next: Option<&CachedLookaheadEpoch>,
    fallback_epoch: FallbackEpoch,
) -> Selection {
    if current.slots.is_empty() {
        return Selection::Fallback(fallback_epoch);
    }

    // Slots are ordered by timestamp on-chain; binary search for first slot >= ts.
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

/// Decide whether to treat a timestamp as belonging to the current or next epoch for fallback.
fn fallback_epoch_for(ts: u64, genesis_timestamp: u64) -> FallbackEpoch {
    let now = SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(ts);
    let current_epoch_start = epoch_start_for(now, genesis_timestamp);
    let next_epoch_start = current_epoch_start.saturating_add(SECONDS_IN_EPOCH);

    if ts >= next_epoch_start { FallbackEpoch::Next } else { FallbackEpoch::Current }
}

/// Return the epoch start boundary (in seconds) that contains `ts`.
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
/// - 7_014_190_335: Helder (1_718_967_660)
/// - 560_048: Hoodi (1_742_213_400)
///
/// Any other chain ID yields `None` and surfaces as `UnknownChain` to callers.
fn genesis_timestamp_for_chain(chain_id: u64) -> Option<u64> {
    match chain_id {
        1 => Some(1_606_824_023),
        17_000 => Some(1_695_902_400),
        7_014_190_335 => Some(1_718_967_660),
        560_048 => Some(1_742_213_400),
        _ => None,
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

//! Completed authenticated proposal reads retained across cancelled rounds.
use super::{App, Rejection};
use crate::{
    engine::Engine,
    envelope::AnchorWitness,
    fallback::{FallbackKeys, fetch_fallback_keys},
    forced::{self, ForcedEntry, ForcedError},
    l1::{L1Error, L1Source, ReadBounded, layout::inbox},
    store::AppState,
    types::{AccountWitness, AnchorState},
};
use alloy_primitives::{Address, B256, Bytes, U256};
use std::{
    collections::{BTreeMap, HashMap},
    future::Future,
    sync::{Arc, Mutex, MutexGuard, PoisonError},
    time::Duration,
};
use tokio::{sync::watch, task::JoinHandle};

/// At most one anchor, entry proof and authenticated transaction for the pending proposal, the
/// key-to-seat words read for the committed parent's missing validators, and the fallback key
/// lists the height's proposals needed.
/// These raw reads are proposer-independent and retain only their authenticated root/entry keys.
/// Headers, payload builds and singleton verdicts are never cached here: every preparation derives
/// the certified proposer's expected header and rebuilds even when payout addresses are shared.
#[derive(Debug, Default)]
pub(super) struct PreparationCache {
    /// Whole key-to-seat words by the parent hash whose post-state holds them and the address
    /// they belong to; a word at a fixed block hash never changes, so every handler of the
    /// height reuses it.
    pub(super) seat_words: BTreeMap<(B256, Address), U256>,
    /// Anchor proof; reuse requires a freshly matching header hash.
    pub(super) anchor: Option<AnchorWitness>,
    /// The number and L1 timestamp of the last own `finalized` block whose header the proposer
    /// read to tell whether its parent's anchor aged out (CONS-3.3-4). A finalized header never
    /// changes, so it is read once per finality advance.
    pub(super) finalized_time: Option<(u64, u64)>,
    /// Entry proof bound to its state root and queue index.
    entry: Option<CachedForcedEntry>,
    /// One bounded proof read surviving cancellation of its waiting round.
    entry_flight: Option<FetchTask<(B256, u64), CachedForcedEntry>>,
    /// Bytes authenticated against the exact proven entry identity.
    transaction: Option<(ForcedEntry, Bytes)>,
    /// One bounded event read keyed by the complete proven entry.
    transaction_flight: Option<FetchTask<ForcedEntry, Bytes>>,
    /// The fallback key lists the height's proposals fetched because the committed state held
    /// none under the hash their anchors prove, by that hash, each hashing to it: the
    /// in-memory lists `FinalizeBlock` decides with. Only anchors final in the own L1 view
    /// reach them, so they are at most one per distinct list those L1 blocks hold; `Commit`
    /// drops them all, its state keeping the one the committed anchor proves.
    fallback_keys: HashMap<B256, FallbackKeys>,
    /// One list fetch, keyed by the list's hash, surviving cancellation of its waiting round
    /// and `Commit` (a list's hash names it at every height): a deep log scan that outlasts one
    /// proposal's budget completes for a later one.
    fallback_flight: Option<FetchTask<B256, FallbackKeys>>,
}

/// Proven queue entry and its original storage witness.
#[derive(Clone, Debug)]
pub(super) struct CachedForcedEntry {
    /// Authentication root.
    pub(super) state_root: B256,
    /// Two-slot proof to carry in the envelope.
    pub(super) witness: AccountWitness,
    /// Decoded authenticated metadata.
    pub(super) proven: ForcedEntry,
}

/// Cloneable failures passed across an owned fetch task.
#[derive(Clone, Debug)]
enum FetchFailure {
    /// L1 read failure.
    L1(L1Error),
    /// Invalid proof or bytes.
    Forced(ForcedError),
    /// Bounded read expired.
    Timeout(&'static str),
    /// The own L1 gave no fallback key list with this hash; the task logged why.
    FallbackKeys(B256),
}
impl From<FetchFailure> for Rejection {
    /// Restores the handler's failure classification.
    fn from(failure: FetchFailure) -> Self {
        match failure {
            FetchFailure::L1(e) => Self::L1(e),
            FetchFailure::Forced(e) => Self::Forced(e),
            FetchFailure::Timeout(e) => Self::Timeout(e),
            FetchFailure::FallbackKeys(hash) => Self::FallbackKeysUnavailable(hash),
        }
    }
}
/// One bounded task whose result stays available if the round waiting for it is cancelled.
/// Dropping it (context replacement, Commit for a read tied to the height, or App drop) aborts
/// unfinished I/O.
#[derive(Debug)]
struct FetchTask<K, T> {
    /// Exact context under which the result is valid.
    key: K,
    /// Finished result, or `None` until the owned task publishes it.
    result: watch::Receiver<Option<Result<T, FetchFailure>>>,
    /// Owned task; never detached when its context becomes obsolete.
    task: JoinHandle<()>,
}

impl<K, T: Clone + Send + Sync + 'static> FetchTask<K, T> {
    /// Whether a completed read failed after its originating round stopped waiting. A later
    /// round starts fresh instead of spending its proposal opportunity on the obsolete error.
    fn failed(&self) -> bool {
        self.result.borrow().as_ref().is_some_and(Result::is_err)
    }

    /// Starts one read under its per-read limit. The proposal's separate deadline only cancels
    /// its receiver, allowing this read to complete for a later round.
    fn spawn(
        key: K,
        after: Duration,
        what: &'static str,
        fetch: impl Future<Output = Result<T, FetchFailure>> + Send + 'static,
    ) -> Self {
        Self::spawn_unbounded(key, async move {
            tokio::time::timeout(after, fetch).await.unwrap_or(Err(FetchFailure::Timeout(what)))
        })
    }

    /// Starts one fetch with no deadline of its own, for a fetch that bounds each of its reads
    /// and may need many of them.
    fn spawn_unbounded(
        key: K,
        fetch: impl Future<Output = Result<T, FetchFailure>> + Send + 'static,
    ) -> Self {
        let (sender, result) = watch::channel(None);
        let task = tokio::spawn(async move {
            let _ = sender.send(Some(fetch.await));
        });
        Self { key, result, task }
    }

    /// The task's result, once it completed successfully.
    fn succeeded(&self) -> Option<T> {
        self.result.borrow().as_ref().and_then(|result| result.as_ref().ok().cloned())
    }
}

impl<K, T> Drop for FetchTask<K, T> {
    /// Cancels any read that no longer belongs to the app's current preparation context.
    fn drop(&mut self) {
        self.task.abort();
    }
}

/// Waits for a task's verified result without holding the cache mutex across an await.
async fn wait_for_fetch<T: Clone>(
    mut result: watch::Receiver<Option<Result<T, FetchFailure>>>,
) -> Result<T, Rejection> {
    loop {
        let completed = result.borrow().clone();
        if let Some(completed) = completed {
            return completed.map_err(Into::into);
        }
        result.changed().await.map_err(|_| {
            Rejection::L1(L1Error::Rpc("proposal fetch task stopped without a result".into()))
        })?;
    }
}

/// Locks completed reads without keeping the guard across I/O. A poisoned holder cannot weaken
/// consensus validation, which still authenticates every reused witness.
fn lock(cache: &Mutex<PreparationCache>) -> MutexGuard<'_, PreparationCache> {
    cache.lock().unwrap_or_else(PoisonError::into_inner)
}

impl<L: L1Source, E: Engine> App<L, E> {
    /// Locks the cache without holding its guard across I/O.
    pub(super) fn preparation_cache(&self) -> MutexGuard<'_, PreparationCache> {
        lock(&self.preparation_cache)
    }
    /// Clears proofs, seat words and fetched fallback key lists after commit while retaining
    /// only bytes for the still-pending entry and any fallback key list fetch.
    pub(super) fn prepare_next_height(&self, state: &AppState) {
        let mut cache = self.preparation_cache();
        let transaction =
            cache.transaction.take().filter(|(entry, _)| entry.index == state.forced_cursor);
        let transaction_flight = cache
            .transaction_flight
            .take()
            .filter(|flight| flight.key.index == state.forced_cursor);
        let fallback_flight = cache.fallback_flight.take();
        *cache = PreparationCache {
            transaction,
            transaction_flight,
            fallback_flight,
            ..Default::default()
        };
    }

    /// Makes sure this node holds the fallback key list whose hash `anchor` proves before a
    /// block on that anchor, which is final in the own L1 view, is decided on top of `state`.
    ///
    /// A list the committed state holds, or one a proposal of this height already fetched,
    /// needs no read. Otherwise the own L1 serves it ([`fetch_fallback_keys`] at the anchor,
    /// each read within [`AppOptions::list_read_timeout`](super::AppOptions::list_read_timeout)
    /// and the scan as a whole unbounded) in one task that outlives a round that stops waiting
    /// for it, and the list is kept for `FinalizeBlock`
    /// ([`App::prefetched_fallback_keys`]). While the own L1 cannot give it, for want of a list
    /// with that hash or through a failed read, the task logs why and this is
    /// [`Rejection::FallbackKeysUnavailable`]: a liveness pause, never a verdict on the block.
    pub(super) async fn prefetch_fallback_keys(
        &self,
        state: &AppState,
        anchor: &AnchorState,
    ) -> Result<(), Rejection> {
        let hash = anchor.inbox.fallback_keys_hash;
        if state.fallback_keys.contains_key(&hash) {
            return Ok(());
        }
        let result = {
            let mut cache = self.preparation_cache();
            if cache.fallback_keys.contains_key(&hash) {
                return Ok(());
            }
            if cache
                .fallback_flight
                .as_ref()
                .is_none_or(|flight| flight.key != hash || flight.failed())
            {
                let l1 =
                    ReadBounded { l1: Arc::clone(&self.l1), limit: self.opts.list_read_timeout() };
                let (inbox, at, at_number) = (self.params.inbox, anchor.hash, anchor.number);
                let fetch = async move {
                    fetch_fallback_keys(&l1, inbox, hash, at, at_number, 0).await.map_err(|error| {
                        tracing::warn!(%hash, %error, "the own L1 gives no fallback key list yet");
                        FetchFailure::FallbackKeys(hash)
                    })
                };
                cache.fallback_flight = Some(FetchTask::spawn_unbounded(hash, fetch));
            }
            cache.fallback_flight.as_ref().expect("task just initialized").result.clone()
        };
        let completed = wait_for_fetch(result).await;
        let mut cache = self.preparation_cache();
        if cache.fallback_flight.as_ref().is_some_and(|flight| flight.key == hash) {
            cache.fallback_flight = None;
        }
        cache.fallback_keys.insert(hash, completed?);
        Ok(())
    }

    /// The fallback key list with hash `hash` that a proposal of this height fetched
    /// ([`App::prefetch_fallback_keys`]), if any: one kept, or the result of a completed fetch
    /// no round waited for to the end.
    pub(super) fn prefetched_fallback_keys(&self, hash: B256) -> Option<FallbackKeys> {
        let cache = self.preparation_cache();
        cache.fallback_keys.get(&hash).cloned().or_else(|| {
            cache.fallback_flight.as_ref().filter(|flight| flight.key == hash)?.succeeded()
        })
    }
    /// Reuses a verified proof, or one owned in-flight proof, for this exact root and cursor.
    /// Failed tasks are discarded so a later round can retry a recovered L1 endpoint.
    pub(super) async fn forced_entry(
        &self,
        anchor: &AnchorState,
        index: u64,
    ) -> Result<CachedForcedEntry, Rejection> {
        let key = (anchor.state_root, index);
        let result = {
            let mut cache = self.preparation_cache();
            if let Some(entry) =
                cache.entry.as_ref().filter(|e| (e.state_root, e.proven.index) == key)
            {
                return Ok(entry.clone());
            }
            if cache.entry_flight.as_ref().is_none_or(|flight| flight.key != key || flight.failed())
            {
                let l1 = Arc::clone(&self.l1);
                let (inbox, number) = (self.params.inbox, anchor.number);
                let fetch = async move {
                    let slots = inbox::forced_inclusion_entry_slots(index);
                    let witness = l1
                        .account_witness(inbox, &slots, number)
                        .await
                        .map_err(FetchFailure::L1)?;
                    let proven = forced::verify_entry(key.0, &witness, inbox, index)
                        .map_err(FetchFailure::Forced)?;
                    Ok(CachedForcedEntry { state_root: key.0, witness, proven })
                };
                cache.entry_flight = Some(FetchTask::spawn(
                    key,
                    self.opts.l1_timeout,
                    "forced inclusion entry read",
                    fetch,
                ));
            }
            cache.entry_flight.as_ref().expect("task just initialized").result.clone()
        };
        let completed = wait_for_fetch(result).await;
        let mut cache = self.preparation_cache();
        cache.entry_flight = None;
        let entry = completed?;
        cache.entry = Some(entry.clone());
        Ok(entry)
    }

    /// Retrieves exact admission bytes and authenticates them before retaining a completed read.
    /// An entry that governance recovery blanked (its hash is `keccak256("")`) has the empty
    /// string as its bytes, known without reading its admission log.
    pub(super) async fn forced_transaction(&self, entry: ForcedEntry) -> Result<Bytes, Rejection> {
        if entry.tx_hash == alloy_consensus::constants::KECCAK_EMPTY {
            return Ok(Bytes::new());
        }
        let result = {
            let mut cache = self.preparation_cache();
            if let Some((_, tx)) = cache.transaction.as_ref().filter(|(known, _)| *known == entry) {
                return Ok(tx.clone());
            }
            if cache
                .transaction_flight
                .as_ref()
                .is_none_or(|flight| flight.key != entry || flight.failed())
            {
                let l1 = Arc::clone(&self.l1);
                let inbox = self.params.inbox;
                let fetch = async move {
                    let tx = l1
                        .forced_transaction(inbox, entry.index, entry.l1_block)
                        .await
                        .map_err(FetchFailure::L1)?;
                    if tx.len() > forced::MAX_FORCED_TX_BYTES {
                        return Err(FetchFailure::Forced(ForcedError::TxTooLarge {
                            size: tx.len(),
                            max: forced::MAX_FORCED_TX_BYTES,
                        }));
                    }
                    let got = alloy_primitives::keccak256(&tx);
                    if got != entry.tx_hash {
                        return Err(FetchFailure::Forced(ForcedError::TxHashMismatch {
                            expected: entry.tx_hash,
                            got,
                        }));
                    }
                    Ok(tx)
                };
                cache.transaction_flight = Some(FetchTask::spawn(
                    entry,
                    self.opts.l1_timeout,
                    "forced transaction read",
                    fetch,
                ));
            }
            cache.transaction_flight.as_ref().expect("initialized").result.clone()
        };
        let tx = wait_for_fetch(result).await?;
        let mut cache = self.preparation_cache();
        cache.transaction_flight = None;
        cache.transaction = Some((entry, tx.clone()));
        Ok(tx)
    }
}

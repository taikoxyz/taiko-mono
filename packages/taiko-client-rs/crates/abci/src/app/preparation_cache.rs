//! Bounded, node-local completed proposal reads, retained across cancelled rounds.

use std::{
    future::Future,
    sync::{Arc, Mutex, MutexGuard, PoisonError, Weak},
    time::Duration,
};

use alloy_primitives::{B256, Bytes};
use tokio::{sync::watch, task::JoinHandle};

use super::{App, Rejection};
use crate::{
    engine::Engine,
    envelope::AnchorWitness,
    forced::{self, ForcedEntry, ForcedError},
    l1::{L1Error, L1Source, blobs::BlobSource, layout::inbox},
    store::AppState,
    types::{AccountWitness, AnchorState},
};

/// At most one authenticated anchor, forced entry and blob for the pending height. These are
/// local preparation hints only: every candidate still passes the ordinary consensus checks.
/// `Commit` clears all of it except what serves the entry at the committed cursor
/// ([`App::prepare_next_height`]), whose blob every validator then prefetches.
#[derive(Debug, Default)]
pub(super) struct PreparationCache {
    /// Anchor proof paired with its raw header; reuse requires a fresh matching header hash.
    pub(super) anchor: Option<AnchorWitness>,
    /// Entry proof bound to the L1 state root and queue cursor that authenticated it.
    pub(super) entry: Option<CachedForcedEntry>,
    /// Raw blob accepted only after its commitment matched the requested versioned hash.
    pub(super) blob: Option<CachedBlob>,
    /// One forced-entry proof task, bound to its authentication root and cursor.
    entry_flight: Option<FetchTask<(B256, u64), CachedForcedEntry>>,
    /// One blob fetch and commitment verification, bound to its immutable versioned hash.
    blob_flight: Option<FetchTask<B256, CachedBlob>>,
    /// Verified facts of a queue entry, by index: a queue entry never changes once saved, so
    /// they hold under every later anchor whose tail covers the index.
    pub(super) known_entry: Option<ForcedEntry>,
    /// A background read of the entry at the committed cursor that, once verified, records it
    /// and starts its blob fetch ([`App::prepare_next_height`]).
    entry_prefetch: Option<EntryPrefetch>,
}

/// One owned background entry read, keyed by its queue index; dropping it aborts the read.
#[derive(Debug)]
struct EntryPrefetch {
    /// The queue index read.
    index: u64,
    /// The read, which records the entry and starts its blob fetch.
    task: JoinHandle<()>,
}

impl Drop for EntryPrefetch {
    /// Cancels a read the committed cursor no longer needs.
    fn drop(&mut self) {
        self.task.abort();
    }
}

/// A forced inclusion blob available now, or the result of its owned fetch.
enum BlobRead {
    /// Commitment-verified bytes retained by an earlier read.
    Retained(Bytes),
    /// The pending or completed result of the one fetch for the requested hash.
    InFlight(watch::Receiver<Option<Result<CachedBlob, FetchFailure>>>),
}

/// One completed, verified forced queue read.
#[derive(Clone, Debug)]
pub(super) struct CachedForcedEntry {
    /// Root against which the entry proof verified.
    pub(super) state_root: B256,
    /// Queue index whose exact storage slots were proven.
    pub(super) index: u64,
    /// Authenticated storage witness, carried unchanged in the proposal.
    pub(super) witness: AccountWitness,
    /// Entry decoded from the verified witness.
    pub(super) proven: ForcedEntry,
}

/// One completed blob read; its versioned hash is immutable across rounds and anchors.
#[derive(Clone, Debug)]
pub(super) struct CachedBlob {
    /// KZG versioned hash verified by the forced inclusion rule.
    pub(super) hash: B256,
    /// The full raw blob.
    pub(super) bytes: Bytes,
}

/// Cloneable task errors preserve the rejection label without duplicating arbitrary errors
/// from the rest of proposal validation.
#[derive(Clone, Debug)]
enum FetchFailure {
    /// A proof read failed.
    L1(L1Error),
    /// A proof did not authenticate the required queue entry.
    Forced(ForcedError),
    /// A blob source failed, or its blob failed commitment verification.
    Blob(String),
    /// The underlying read exceeded its own deadline, independently of the proposal deadline.
    Timeout(&'static str),
}

impl From<FetchFailure> for Rejection {
    /// Restores the handler's ordinary failure classification after a shared task finishes.
    fn from(failure: FetchFailure) -> Self {
        match failure {
            FetchFailure::L1(error) => Self::L1(error),
            FetchFailure::Forced(error) => Self::Forced(error),
            FetchFailure::Blob(error) => Self::BlobUnavailable(error),
            FetchFailure::Timeout(what) => Self::Timeout(what),
        }
    }
}

/// One bounded task whose result stays available if the round waiting for it is cancelled.
/// Dropping it (context replacement, Commit or App drop) aborts unfinished I/O.
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
        let (sender, result) = watch::channel(None);
        let task = tokio::spawn(async move {
            let completed = tokio::time::timeout(after, fetch)
                .await
                .unwrap_or(Err(FetchFailure::Timeout(what)));
            let _ = sender.send(Some(completed));
        });
        Self { key, result, task }
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
    /// Locks completed reads without keeping the guard across I/O.
    pub(super) fn preparation_cache(&self) -> MutexGuard<'_, PreparationCache> {
        lock(&self.preparation_cache)
    }

    /// At `Commit`, with `state` newly committed: drops the per-height reads and keeps only what
    /// serves the entry at the committed cursor, when the committed anchor's queue holds one;
    /// after a live decision (`live`; not a replay or block sync, whose entries are long settled)
    /// prefetches that entry's blob ([`App::prefetch_forced_blob`]).
    pub(super) fn prepare_next_height(&self, state: &AppState, live: bool) {
        let anchor = &state.anchor;
        let cursor = (state.forced_cursor < anchor.inbox.forced_inclusion_tail)
            .then_some(state.forced_cursor);
        let mut cache = self.preparation_cache();
        let known = cache.known_entry.filter(|entry| Some(entry.index) == cursor);
        let hash = known.map(|entry| entry.blob_hash);
        let blob = cache.blob.take().filter(|blob| Some(blob.hash) == hash);
        let blob_flight = cache.blob_flight.take().filter(|flight| Some(flight.key) == hash);
        let entry_prefetch = cache
            .entry_prefetch
            .take()
            .filter(|read| known.is_none() && Some(read.index) == cursor);
        *cache = PreparationCache {
            blob,
            blob_flight,
            known_entry: known,
            entry_prefetch,
            ..Default::default()
        };
        drop(cache);
        if live {
            self.prefetch_forced_blob(state);
        }
    }

    /// Makes sure the blob of the entry at `state`'s committed cursor, if the committed anchor's
    /// queue holds one that has not expired, is retained or being fetched in the background
    /// within the blob deadline: from the facts a decided block proved or this node read before,
    /// or else after a background read of the entry under the committed anchor. A failed read or
    /// fetch is restarted.
    ///
    /// Runs at a live `Commit` and at every `ProcessProposal`, which every node (full nodes
    /// included) handles in each round that delivers a proposal while it is not locked on a block,
    /// empty proposals included. Every
    /// node therefore holds, or has been fetching since the entry reached the cursor under a
    /// committed anchor, the blob of an entry by the time it falls due, an entry queued behind
    /// others or a restarted node included, rather than each proposer starting a fetch on its
    /// own turn while the chain stalls. An entry first seen already due under a newer anchor is
    /// left to the proposals that choose that anchor.
    pub(super) fn prefetch_forced_blob(&self, state: &AppState) {
        let anchor = &state.anchor;
        if state.forced_cursor >= anchor.inbox.forced_inclusion_tail {
            return;
        }
        let index = state.forced_cursor;
        let mut cache = self.preparation_cache();
        match cache.known_entry.filter(|entry| entry.index == index) {
            Some(entry) if !forced::is_expired(&entry, anchor.timestamp) => {
                start_blob_flight(&mut cache, &self.blobs, self.opts.blob_timeout, &entry);
            }
            Some(_) => {}
            None => {
                let running = cache
                    .entry_prefetch
                    .as_ref()
                    .is_some_and(|read| read.index == index && !read.task.is_finished());
                if !running {
                    cache.entry_prefetch = Some(self.spawn_entry_prefetch(anchor, index));
                }
            }
        }
    }

    /// Reads entry `index` under `anchor` in the background, within the L1 deadline; once it
    /// verifies, records it and, unless it expired, starts its blob fetch, provided the cache
    /// still waits for this read. A failed read is restarted by the next refresh. The task holds
    /// the cache weakly, so dropping the app aborts it.
    fn spawn_entry_prefetch(&self, anchor: &AnchorState, index: u64) -> EntryPrefetch {
        let (cache, l1, blobs) = (
            Arc::downgrade(&self.preparation_cache),
            Arc::clone(&self.l1),
            Arc::clone(&self.blobs),
        );
        let (inbox, l1_timeout, blob_timeout) =
            (self.params.inbox, self.opts.l1_timeout, self.opts.blob_timeout);
        let anchor = anchor.clone();
        let task = tokio::spawn(async move {
            let slots = inbox::forced_inclusion_entry_slots(index);
            let read =
                tokio::time::timeout(l1_timeout, l1.account_witness(inbox, &slots, anchor.number));
            let entry = match read.await {
                Ok(Ok(witness)) => forced::verify_entry(anchor.state_root, &witness, inbox, index),
                Ok(Err(error)) => return tracing::debug!(%error, index, "entry prefetch failed"),
                Err(_) => return tracing::debug!(index, "entry prefetch timed out"),
            };
            let entry = match entry {
                Ok(entry) => entry,
                Err(error) => return tracing::warn!(%error, index, "prefetched entry unverified"),
            };
            let Some(cache) = Weak::upgrade(&cache) else { return };
            let mut cache = lock(&cache);
            // A `Commit` that moved the cursor (or a refresh that replaced this read) after it
            // finished reading must not see its outdated result.
            if cache.entry_prefetch.as_ref().is_none_or(|read| read.index != index) {
                return;
            }
            cache.known_entry = Some(entry);
            if !forced::is_expired(&entry, anchor.timestamp) {
                start_blob_flight(&mut cache, &blobs, blob_timeout, &entry);
            }
        });
        EntryPrefetch { index, task }
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
            if let Some(entry) = cache.entry.as_ref().filter(|e| (e.state_root, e.index) == key) {
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
                    Ok(CachedForcedEntry { state_root: key.0, index, witness, proven })
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
        cache.known_entry = Some(entry.proven);
        cache.entry = Some(entry.clone());
        Ok(entry)
    }

    /// Reuses one verified blob or one bounded fetch spanning rounds and, once prefetched,
    /// heights. A hash change aborts the old fetch, and only commitment-checked bytes are
    /// published or retained.
    pub(super) async fn fetch_forced_blob(&self, entry: &ForcedEntry) -> Result<Bytes, Rejection> {
        let started = start_blob_flight(
            &mut self.preparation_cache(),
            &self.blobs,
            self.opts.blob_timeout,
            entry,
        );
        let result = match started {
            BlobRead::Retained(bytes) => return Ok(bytes),
            BlobRead::InFlight(result) => result,
        };
        let completed = wait_for_fetch(result).await;
        let mut cache = self.preparation_cache();
        if cache.blob_flight.as_ref().is_some_and(|flight| flight.key == entry.blob_hash) {
            cache.blob_flight = None;
        }
        let blob = completed?;
        cache.blob = Some(blob.clone());
        Ok(blob.bytes)
    }
}

/// The retained blob of `entry`, or the result of its one fetch, which this starts (within
/// `timeout`, the blob deadline) unless one for the same hash is running or has succeeded; a
/// failed fetch is replaced.
fn start_blob_flight(
    cache: &mut PreparationCache,
    blobs: &Arc<dyn BlobSource>,
    timeout: Duration,
    entry: &ForcedEntry,
) -> BlobRead {
    let key = entry.blob_hash;
    if let Some(blob) = cache.blob.as_ref().filter(|blob| blob.hash == key) {
        return BlobRead::Retained(blob.bytes.clone());
    }
    if cache.blob_flight.as_ref().is_none_or(|flight| flight.key != key || flight.failed()) {
        let source = Arc::clone(blobs);
        let entry = *entry;
        let fetch = async move {
            let bytes = source.blob(entry.timestamp, key).await.map_err(FetchFailure::Blob)?;
            forced::derive_tx_list(&entry, &bytes)
                .map_err(|error| FetchFailure::Blob(error.to_string()))?;
            Ok(CachedBlob { hash: key, bytes })
        };
        cache.blob_flight =
            Some(FetchTask::spawn(key, timeout, "forced inclusion blob read", fetch));
    }
    BlobRead::InFlight(cache.blob_flight.as_ref().expect("task just initialized").result.clone())
}

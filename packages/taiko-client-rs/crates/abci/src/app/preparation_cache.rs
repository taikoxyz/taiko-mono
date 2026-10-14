//! Bounded, node-local completed proposal reads, retained across cancelled rounds.

use std::{
    future::Future,
    sync::{Arc, MutexGuard, PoisonError},
    time::Duration,
};

use alloy_primitives::{B256, Bytes};
use tokio::{sync::watch, task::JoinHandle};

use super::{App, Rejection};
use crate::{
    engine::Engine,
    envelope::AnchorWitness,
    forced::{self, ForcedEntry, ForcedError},
    l1::{L1Error, L1Source, layout::inbox},
    types::{AccountWitness, AnchorState},
};

/// At most one authenticated anchor, forced entry and blob for the pending height. These are
/// local preparation hints only: every candidate still passes the ordinary consensus checks.
/// `Commit` clears all of it except the blob of a pending entry a decided block proved
/// ([`PreparationCache::reset_for_commit`]).
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
    /// The versioned hash whose blob (retained or in flight) the next `Commit` keeps: that of
    /// the pending entry the block being finalized proved ([`App::prefetch_forced_blob`]).
    retain_blob: Option<B256>,
}

impl PreparationCache {
    /// Clears the per-height reads at `Commit`, keeping only the blob, retained or in flight,
    /// [`App::prefetch_forced_blob`] marked: a versioned hash names immutable bytes, so they stay
    /// valid at every later height, and the fetch keeps running toward the height the entry
    /// falls due at. Any other unfinished read is aborted.
    pub(super) fn reset_for_commit(&mut self) {
        let keep = self.retain_blob.take();
        let blob = self.blob.take().filter(|blob| Some(blob.hash) == keep);
        let blob_flight = self.blob_flight.take().filter(|flight| Some(flight.key) == keep);
        *self = Self { blob, blob_flight, ..Self::default() };
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

impl<L: L1Source, E: Engine> App<L, E> {
    /// Locks completed reads without keeping the guard across I/O. A poisoned holder cannot
    /// weaken consensus validation, which still authenticates every reused witness.
    pub(super) fn preparation_cache(&self) -> MutexGuard<'_, PreparationCache> {
        self.preparation_cache.lock().unwrap_or_else(PoisonError::into_inner)
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
        cache.entry = Some(entry.clone());
        Ok(entry)
    }

    /// Reuses one verified blob or one bounded fetch spanning rounds and, once prefetched,
    /// heights. A hash change aborts the old fetch, and only commitment-checked bytes are
    /// published or retained.
    pub(super) async fn fetch_forced_blob(&self, entry: &ForcedEntry) -> Result<Bytes, Rejection> {
        let result = match self.start_forced_blob(&mut self.preparation_cache(), entry) {
            BlobRead::Retained(bytes) => return Ok(bytes),
            BlobRead::InFlight(result) => result,
        };
        let completed = wait_for_fetch(result).await;
        let mut cache = self.preparation_cache();
        cache.blob_flight = None;
        let blob = completed?;
        cache.blob = Some(blob.clone());
        Ok(blob.bytes)
    }

    /// Starts fetching the blob of `entry`, a pending forced inclusion entry the block being
    /// finalized proved, without waiting for it, and marks it to survive the next `Commit`.
    ///
    /// Every validator thereby fetches the blob while the entry is still pending, within the
    /// blob deadline rather than a proposal's: whichever validator proposes once the entry falls
    /// due holds it already, instead of each proposer starting its own fetch on its turn while
    /// the chain stalls. An entry already due when first proven (a short delay, or an anchor
    /// catching up after lag), or whose decision this node replayed, is fetched by proposers
    /// alone.
    pub(super) fn prefetch_forced_blob(&self, entry: &ForcedEntry) {
        let mut cache = self.preparation_cache();
        self.start_forced_blob(&mut cache, entry);
        cache.retain_blob = Some(entry.blob_hash);
    }

    /// The retained blob of `entry`, or the result of its one fetch, which this starts (within
    /// [`AppOptions::blob_timeout`](super::AppOptions)) unless one for the same hash is running
    /// or has succeeded; a failed fetch is replaced.
    fn start_forced_blob(&self, cache: &mut PreparationCache, entry: &ForcedEntry) -> BlobRead {
        let key = entry.blob_hash;
        if let Some(blob) = cache.blob.as_ref().filter(|blob| blob.hash == key) {
            return BlobRead::Retained(blob.bytes.clone());
        }
        if cache.blob_flight.as_ref().is_none_or(|flight| flight.key != key || flight.failed()) {
            let source = Arc::clone(&self.blobs);
            let entry = *entry;
            let fetch = async move {
                let bytes = source.blob(entry.timestamp, key).await.map_err(FetchFailure::Blob)?;
                forced::derive_tx_list(&entry, &bytes)
                    .map_err(|error| FetchFailure::Blob(error.to_string()))?;
                Ok(CachedBlob { hash: key, bytes })
            };
            cache.blob_flight = Some(FetchTask::spawn(
                key,
                self.opts.blob_timeout,
                "forced inclusion blob read",
                fetch,
            ));
        }
        BlobRead::InFlight(
            cache.blob_flight.as_ref().expect("task just initialized").result.clone(),
        )
    }
}

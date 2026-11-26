//! The node's own L1 source as the app holds it: every read passes through unchanged, and each
//! `finalized` answer is noted with the instant it was first seen, for the proposer's anchor
//! hold (CONS-3.3-4).

use std::{
    collections::BTreeMap,
    ops::Deref,
    sync::{Mutex, PoisonError},
};

use alloy_primitives::{Address, B256, Bytes, U256};
use async_trait::async_trait;
use tokio::time::{Duration, Instant};

use crate::{
    l1::{L1Error, L1Source, RawL1Header},
    types::AccountWitness,
};

/// How many distinct `finalized` numbers above the committed anchor [`OwnL1`] remembers. Each
/// is one advance of the own L1's finality while the committed anchor stayed below it: about
/// eleven between two moves 1,024 blocks apart at 4 s blocks and 384 s epochs, so the bound only
/// matters while the chain makes no progress, and evicting the lowest number then only drops a
/// block that a newer settled sighting supersedes.
const MAX_SIGHTINGS: usize = 64;

/// The node's own L1 source `L`, remembering when its `finalized` answer first showed each
/// number.
///
/// The app reads the own L1 only through it: the checkpoint trust worker about once a second
/// on every node, validator or full node (SYNC-9-6a), `ProcessProposal`'s finality checks, the
/// fallback key list fetches and `PrepareProposal`. So the proposer's anchor hold counts from
/// the first time this node's own L1 showed a block as finalized, whether or not the node has
/// proposed since ([`OwnL1::settled_finalized_above`]). It derefs to `L`.
#[derive(Debug)]
pub struct OwnL1<L> {
    /// The source every read is passed to.
    inner: L,
    /// The first instant each `finalized` number was read, at most [`MAX_SIGHTINGS`] of them.
    sightings: Mutex<BTreeMap<u64, Instant>>,
}

impl<L> OwnL1<L> {
    /// Wraps `inner` with no sighting yet.
    pub(super) fn new(inner: L) -> Self {
        Self { inner, sightings: Mutex::default() }
    }

    /// Notes that the own L1 reported `number` as finalized now, unless it did before.
    fn note_finalized(&self, number: u64) {
        let mut seen = self.sightings.lock().unwrap_or_else(PoisonError::into_inner);
        seen.entry(number).or_insert_with(Instant::now);
        while seen.len() > MAX_SIGHTINGS {
            seen.pop_first();
        }
    }

    /// The newest finalized number above `floor`, the committed anchor, that the own L1 first
    /// reported at least `hold` ago: a block that validators whose view is slightly behind have
    /// also seen finalized (RECOV-8-5). Sightings at or below `floor` are dropped: a later
    /// committed anchor is never lower.
    pub(super) fn settled_finalized_above(&self, floor: u64, hold: Duration) -> Option<u64> {
        let mut seen = self.sightings.lock().unwrap_or_else(PoisonError::into_inner);
        match floor.checked_add(1) {
            Some(above) => *seen = seen.split_off(&above),
            None => seen.clear(),
        }
        seen.iter().rev().find(|(_, first)| first.elapsed() >= hold).map(|(number, _)| *number)
    }
}

impl<L> Deref for OwnL1<L> {
    type Target = L;

    /// The wrapped source.
    fn deref(&self) -> &L {
        &self.inner
    }
}

#[async_trait]
impl<L: L1Source> L1Source for OwnL1<L> {
    /// The wrapped source's answer, noted with the instant it was first seen.
    async fn finalized_number(&self) -> Result<u64, L1Error> {
        let number = self.inner.finalized_number().await?;
        self.note_finalized(number);
        Ok(number)
    }

    /// Passed through.
    async fn canonical_hash(&self, number: u64) -> Result<B256, L1Error> {
        self.inner.canonical_hash(number).await
    }

    /// Passed through.
    async fn header(&self, number: u64) -> Result<RawL1Header, L1Error> {
        self.inner.header(number).await
    }

    /// Passed through.
    async fn account_witness(
        &self,
        address: Address,
        slots: &[B256],
        block: u64,
    ) -> Result<AccountWitness, L1Error> {
        self.inner.account_witness(address, slots, block).await
    }

    /// Passed through.
    async fn finalized_unzen_hash(
        &self,
        inbox: Address,
        hash: B256,
    ) -> Result<Option<B256>, L1Error> {
        self.inner.finalized_unzen_hash(inbox, hash).await
    }

    /// Passed through.
    async fn call_at(&self, address: Address, input: Bytes, hash: B256) -> Result<Bytes, L1Error> {
        self.inner.call_at(address, input, hash).await
    }

    /// Passed through.
    async fn inbox_logs(
        &self,
        inbox: Address,
        topic0: B256,
        topic1: B256,
        from: u64,
        to: u64,
    ) -> Result<Vec<Bytes>, L1Error> {
        self.inner.inbox_logs(inbox, topic0, topic1, from, to).await
    }

    /// Passed through.
    async fn forced_transaction(
        &self,
        inbox: Address,
        index: u64,
        l1_block: u64,
    ) -> Result<Bytes, L1Error> {
        self.inner.forced_transaction(inbox, index, l1_block).await
    }

    /// Passed through.
    async fn storage_at(&self, address: Address, slot: B256, block: u64) -> Result<U256, L1Error> {
        self.inner.storage_at(address, slot, block).await
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::MockL1;

    /// Every `finalized` read is noted once, at its first sighting; the settled block is the
    /// newest one first seen at least the hold ago; sightings at or below the committed anchor
    /// are dropped, and at most [`MAX_SIGHTINGS`] are kept, the lowest evicted.
    #[tokio::test(start_paused = true)]
    async fn finalized_sightings_keep_the_first_instant_above_the_anchor() {
        let hold = Duration::from_secs(12);
        let l1 = OwnL1::new(MockL1::new(64));
        assert_eq!(l1.settled_finalized_above(63, Duration::ZERO), None);
        assert_eq!(l1.finalized_number().await, Ok(64));
        tokio::time::advance(Duration::from_secs(5)).await;
        assert_eq!(l1.finalized_number().await, Ok(64), "a repeated answer keeps its instant");
        l1.set_finalized(96);
        assert_eq!(l1.finalized_number().await, Ok(96));
        assert_eq!(l1.settled_finalized_above(63, Duration::ZERO), Some(96), "no hold: the newest");
        assert_eq!(l1.settled_finalized_above(63, Duration::from_secs(5)), Some(64));
        assert_eq!(l1.settled_finalized_above(63, hold), None, "64 was first seen 5 s ago");
        tokio::time::advance(Duration::from_secs(7)).await;
        assert_eq!(l1.settled_finalized_above(63, hold), Some(64), "first seen 12 s ago");
        assert_eq!(l1.settled_finalized_above(64, hold), None, "64 pruned; 96 seen 7 s ago");
        assert_eq!(l1.settled_finalized_above(63, Duration::ZERO), Some(96), "64 stays pruned");
        tokio::time::advance(Duration::from_secs(5)).await;
        assert_eq!(l1.settled_finalized_above(63, hold), Some(96));
        assert_eq!(l1.settled_finalized_above(96, Duration::ZERO), None);
        assert_eq!(l1.settled_finalized_above(u64::MAX, Duration::ZERO), None);

        for number in 100..100 + MAX_SIGHTINGS as u64 + 10 {
            l1.set_finalized(number);
            l1.finalized_number().await.unwrap();
        }
        let seen = l1.sightings.lock().unwrap();
        assert_eq!(seen.len(), MAX_SIGHTINGS);
        assert_eq!(seen.first_key_value().map(|(n, _)| *n), Some(110));
    }
}

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
use tokio::time::Instant;

use crate::{
    l1::{L1Error, L1Source, RawL1Header},
    types::AccountWitness,
};

/// How many distinct `finalized` numbers above the committed anchor [`OwnL1`] remembers. Each
/// is one advance of the own L1's finality while the committed anchor stayed below it, so the
/// bound only matters while the chain makes no progress; evicting the lowest number then can
/// only make a later hold start later, by at most one finality advance.
const MAX_SIGHTINGS: usize = 64;

/// The node's own L1 source `L`, remembering when its `finalized` answer first showed each
/// number.
///
/// The app reads the own L1 only through it: the checkpoint trust worker about once a second
/// on every node, validator or full node (SYNC-9-6a), `ProcessProposal`'s finality checks, the
/// committee-witness discovery and `PrepareProposal`. So the proposer's anchor hold counts from
/// the first time this node's own L1 showed a block above the committed anchor as finalized,
/// whether or not the node has proposed since ([`OwnL1::first_finalized_above`]). It derefs to
/// `L`.
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

    /// The first instant at which the own L1 reported a finalized number above `floor`, the
    /// committed anchor. Sightings at or below it are dropped: a later committed anchor is never
    /// lower.
    pub(super) fn first_finalized_above(&self, floor: u64) -> Option<Instant> {
        let mut seen = self.sightings.lock().unwrap_or_else(PoisonError::into_inner);
        match floor.checked_add(1) {
            Some(above) => *seen = seen.split_off(&above),
            None => seen.clear(),
        }
        seen.values().min().copied()
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
    use std::time::Duration;

    use super::*;
    use crate::test_utils::MockL1;

    /// Every `finalized` read is noted once, at its first sighting; sightings at or below the
    /// committed anchor are dropped, and at most [`MAX_SIGHTINGS`] are kept, the lowest evicted.
    #[tokio::test(start_paused = true)]
    async fn finalized_sightings_keep_the_first_instant_above_the_anchor() {
        let l1 = OwnL1::new(MockL1::new(64));
        let start = Instant::now();
        assert_eq!(l1.first_finalized_above(63), None);
        assert_eq!(l1.finalized_number().await, Ok(64));
        tokio::time::advance(Duration::from_secs(5)).await;
        assert_eq!(l1.finalized_number().await, Ok(64), "a repeated answer keeps its instant");
        l1.set_finalized(96);
        assert_eq!(l1.finalized_number().await, Ok(96));
        assert_eq!(l1.first_finalized_above(63), Some(start));
        assert_eq!(l1.first_finalized_above(64), Some(start + Duration::from_secs(5)));
        assert_eq!(l1.first_finalized_above(63), Some(start + Duration::from_secs(5)), "pruned");
        assert_eq!(l1.first_finalized_above(96), None);
        assert_eq!(l1.first_finalized_above(u64::MAX), None);

        for number in 100..100 + MAX_SIGHTINGS as u64 + 10 {
            l1.set_finalized(number);
            l1.finalized_number().await.unwrap();
        }
        let seen = l1.sightings.lock().unwrap();
        assert_eq!(seen.len(), MAX_SIGHTINGS);
        assert_eq!(seen.first_key_value().map(|(n, _)| *n), Some(110));
    }
}

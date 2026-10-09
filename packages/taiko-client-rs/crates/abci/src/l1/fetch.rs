//! Discovery of the committee witness from the node's own L1 (spec §6.4, amendment A1).
//!
//! A proposer at `H_e` and the `abci-genesis` builder both need the [`CommitteeWitness`] of a
//! target epoch: the last registry checkpoint at or before the cutoff, all of its entries, and
//! the proofs of [`snapshot_slots`] at the parent anchor. The checkpoint index and the entries are
//! found with unproven storage reads; [`verify_snapshot`](crate::committee::verify_snapshot) later
//! checks them against the proven `entriesRoot`, so a lying L1 node can only make the witness
//! fail verification, never pass with other content.

use std::{future::Future, time::Duration};

use alloy_primitives::{B256, U256};

use super::{
    layout::{registry, word_u32, word_u64},
    source::{L1Error, L1Source},
};
use crate::{
    committee::{self, CommitteeError, Snapshot, snapshot_slots},
    config::ChainParams,
    envelope::CommitteeWitness,
    types::RegistryEntry,
};

/// Why a committee witness could not be built.
#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum FetchError {
    /// An L1 read failed.
    #[error(transparent)]
    L1(#[from] L1Error),
    /// An L1 read (named by the value) exceeded the per-read deadline.
    #[error("{0} timed out")]
    Timeout(&'static str),
    /// A registry storage word read during discovery is unusable; the value says how.
    #[error("registry discovery failed: {0}")]
    Registry(String),
    /// The cutoff is undefined, or no committee derives from the discovered snapshot.
    #[error(transparent)]
    Committee(#[from] CommitteeError),
}

/// Builds the committee witness for `target_epoch` against the parent anchor `parent_anchor`,
/// reading the node's own L1 without deadlines.
///
/// See [`build_committee_witness_within`] for the steps.
pub async fn build_committee_witness<L: L1Source + ?Sized>(
    l1: &L,
    params: &ChainParams,
    parent_anchor: u64,
    target_epoch: u64,
) -> Result<CommitteeWitness, FetchError> {
    Discovery { l1, params, read_timeout: None }.witness(parent_anchor, target_epoch).await
}

/// Builds the committee witness for `target_epoch` against the parent anchor `parent_anchor`,
/// bounding every single L1 read by `read_timeout` ([`FetchError::Timeout`] otherwise).
///
/// Computes the cutoff from `parent_anchor`; discovers, with unproven storage reads at
/// `parent_anchor`, the last checkpoint `i` whose `l1Block` is at or before the cutoff (binary
/// search; checkpoint 0 when none is, which verification then rejects) and its `count`; reads
/// its entries at L1 block `checkpoints[i].l1Block`; proves `snapshot_slots(i, i + 1 < length)`
/// at `parent_anchor`; and derives the record the witness claims.
pub async fn build_committee_witness_within<L: L1Source + ?Sized>(
    l1: &L,
    params: &ChainParams,
    parent_anchor: u64,
    target_epoch: u64,
    read_timeout: Duration,
) -> Result<CommitteeWitness, FetchError> {
    Discovery { l1, params, read_timeout: Some(read_timeout) }
        .witness(parent_anchor, target_epoch)
        .await
}

/// One committee-witness discovery over an L1 source.
struct Discovery<'a, L: ?Sized> {
    /// The node's own L1.
    l1: &'a L,
    /// The chain parameters (registry address, cutoff grid and lag, derivation parameters).
    params: &'a ChainParams,
    /// The deadline of each single L1 read; `None` waits indefinitely.
    read_timeout: Option<Duration>,
}

impl<L: L1Source + ?Sized> Discovery<'_, L> {
    /// The committee witness for `target` against the parent anchor `n_p` (see
    /// [`build_committee_witness_within`]).
    async fn witness(&self, n_p: u64, target: u64) -> Result<CommitteeWitness, FetchError> {
        let params = self.params;
        let cutoff = committee::cutoff(n_p, params.cutoff_grid, params.cutoff_lag)?;

        let length = self.registry_word(registry::length_slot(), n_p).await?;
        let length = u64::try_from(length).map_err(|_| {
            FetchError::Registry(format!("checkpoints.length {length} exceeds u64"))
        })?;
        // Invariant: checkpoints below `lo` are at or before the cutoff, from `hi` on after it.
        let (mut lo, mut hi) = (0u64, length);
        while lo < hi {
            let mid = lo + (hi - lo) / 2;
            let head = self.registry_word(registry::checkpoint_slots(mid)[0], n_p).await?;
            if word_u64(head, 0) <= cutoff {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        let index = lo.saturating_sub(1);
        let head = self.registry_word(registry::checkpoint_slots(index)[0], n_p).await?;
        let (l1_block, count) = (word_u64(head, 0), word_u32(head, 64));

        let mut entries = Vec::new();
        for j in 0..u64::from(count) {
            let [pubkey, stake, packed] = registry::entry_slots(j);
            let packed = self.registry_word(packed, l1_block).await?;
            entries.push(RegistryEntry {
                pubkey: B256::from(self.registry_word(pubkey, l1_block).await?),
                eff_stake: self.registry_word(stake, l1_block).await?,
                active_from_l1: word_u64(packed, 0),
                exit_effective_l1: word_u64(packed, 64),
                last_heartbeat_at: word_u64(packed, 128),
            });
        }

        let has_next = index.checked_add(1).is_some_and(|next| next < length);
        let slots = snapshot_slots(index, has_next);
        let proof = self
            .read("registry proof read", self.l1.account_witness(params.registry, &slots, n_p))
            .await?;
        let snapshot = Snapshot { checkpoint_index: index, l1_block, entries };
        let (record, _) = committee::derive(&snapshot, cutoff, target, params)?;
        Ok(CommitteeWitness { record, registry: proof, entries: snapshot.entries })
    }

    /// The raw registry storage word at `slot` as of L1 block `block`.
    async fn registry_word(&self, slot: B256, block: u64) -> Result<U256, FetchError> {
        self.read("registry storage read", self.l1.storage_at(self.params.registry, slot, block))
            .await
    }

    /// Runs one L1 read, within the per-read deadline when one is set.
    async fn read<T>(
        &self,
        what: &'static str,
        fut: impl Future<Output = Result<T, L1Error>>,
    ) -> Result<T, FetchError> {
        match self.read_timeout {
            None => Ok(fut.await?),
            Some(limit) => match tokio::time::timeout(limit, fut).await {
                Ok(result) => Ok(result?),
                Err(_) => Err(FetchError::Timeout(what)),
            },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        schedule::Schedule,
        test_utils::{Fixture, L1Call, TestState},
    };

    /// Against the fixture's L1, discovery rebuilds exactly the genesis committee witness.
    #[tokio::test]
    async fn rebuilds_the_fixture_genesis_committee_witness() {
        let fx = Fixture::genesis(3);
        let l1 = fx.l1();
        let witness = build_committee_witness(&l1, &fx.params, fx.activation.l1_0, Schedule::E0)
            .await
            .expect("the fixture registry yields a witness");
        assert_eq!(witness, fx.witness.committee);

        let within = build_committee_witness_within(
            &l1,
            &fx.params,
            fx.activation.l1_0,
            Schedule::E0,
            Duration::from_secs(1),
        )
        .await;
        assert_eq!(within, Ok(fx.witness.committee.clone()));
    }

    /// Every read is bounded on its own; the deadline names the read that stalled.
    #[tokio::test(start_paused = true)]
    async fn a_stalled_read_times_out() {
        let fx = Fixture::genesis(1);
        let l1 = fx.l1();
        l1.state().delay = Some(Duration::from_secs(5));
        let err = build_committee_witness_within(
            &l1,
            &fx.params,
            fx.activation.l1_0,
            Schedule::E0,
            Duration::from_secs(4),
        )
        .await;
        assert_eq!(err, Err(FetchError::Timeout("registry storage read")));
    }

    #[tokio::test]
    async fn l1_failures_and_unusable_words_are_errors() {
        let fx = Fixture::genesis(1);
        let l1 = fx.l1();
        l1.state().fail = Some(L1Error::Rpc("down".into()));
        let err = build_committee_witness(&l1, &fx.params, fx.activation.l1_0, 0).await;
        assert_eq!(err, Err(FetchError::L1(L1Error::Rpc("down".into()))));

        // A registry whose checkpoints.length does not fit u64.
        let l1 = fx.l1();
        let registry_account = (
            fx.params.registry,
            1,
            U256::ZERO,
            B256::ZERO,
            vec![(registry::length_slot(), U256::MAX)],
        );
        l1.state().states.insert(fx.activation.l1_0, TestState::new(vec![registry_account]));
        let err = build_committee_witness(&l1, &fx.params, fx.activation.l1_0, 0).await;
        assert!(matches!(err, Err(FetchError::Registry(_))), "{err:?}");
        assert_eq!(l1.calls().len(), 1, "discovery stops at the bad length");
        assert!(matches!(l1.calls()[0], L1Call::StorageAt { .. }));
    }
}

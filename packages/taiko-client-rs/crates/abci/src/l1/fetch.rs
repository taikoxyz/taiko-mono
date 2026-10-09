//! Discovery of the committee witness from the node's own L1 (spec §6.4, amendment A1).
//!
//! A proposer at `H_e` and the `abci-genesis` builder both need the [`CommitteeWitness`] of a
//! target epoch: the last registry checkpoint at or before the cutoff, all of its entries, and
//! the proofs of [`snapshot_slots`] at the parent anchor. The checkpoint index and the entries are
//! found with unproven reads; [`verify_snapshot`](crate::committee::verify_snapshot) later checks
//! them against the proven `entriesRoot`, so a lying L1 node can only make the witness fail
//! verification, never pass with other content.
//!
//! The entries are read in batches ([`ENTRY_BATCH`] per `account_witness` call, proofs unused) at
//! the newest L1 block that still holds the snapshot, so discovery never needs state older than
//! the cutoff (an archive node only once the cutoff leaves the node's state window).

use std::{collections::BTreeMap, future::Future, time::Duration};

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

/// Registry entries read per `account_witness` call during discovery: one call for any
/// realistic registry, while bounding a single request (and what an unproven `count` from the
/// L1 node makes the proposer allocate at once).
const ENTRY_BATCH: u64 = 128;

/// The most entries discovery reads for one checkpoint: a larger `count` is
/// [`FetchError::Registry`], refused before any entry is read.
///
/// `count` is an unproven read from the node's own L1, and `abci-genesis` runs without an overall
/// deadline, so a buggy L1 node claiming up to `u32::MAX` entries could otherwise drive millions
/// of reads. The cap bounds discovery at `MAX_REGISTRY_ENTRIES / ENTRY_BATCH` = 32 entry reads.
/// Entries are append-only (an exited bond keeps its index), so it bounds every bond ever
/// registered, far above the committee cap `n_max` (128 on the devnet); a registry growing past
/// it needs a client release raising it.
pub const MAX_REGISTRY_ENTRIES: u32 = 4096;

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
/// search, each checkpoint word read once; checkpoint 0 when none is, which verification then
/// rejects) and its `count` (at most [`MAX_REGISTRY_ENTRIES`], [`FetchError::Registry`]
/// otherwise); reads its entries in batches of [`ENTRY_BATCH`] at the newest block
/// that still holds that snapshot, `min(parent_anchor, checkpoints[i + 1].l1Block − 1)` when a
/// next checkpoint exists and `parent_anchor` otherwise (the registry appends a checkpoint in
/// every L1 block that changes an entry, so the entries stay checkpoint `i`'s until the next one;
/// that block is after the cutoff, i.e. at most `cutoff_lag + cutoff_grid` blocks before
/// `parent_anchor`); proves `snapshot_slots(i, i + 1 < length)` at `parent_anchor`; and derives
/// the record the witness claims.
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
        let mut heads = BTreeMap::new();
        // Invariant: checkpoints below `lo` are at or before the cutoff, from `hi` on after it.
        let (mut lo, mut hi) = (0u64, length);
        while lo < hi {
            let mid = lo + (hi - lo) / 2;
            if word_u64(self.head(&mut heads, mid, n_p).await?, 0) <= cutoff {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        let index = lo.saturating_sub(1);
        let head = self.head(&mut heads, index, n_p).await?;
        let (l1_block, count) = (word_u64(head, 0), word_u32(head, 64));
        if count > MAX_REGISTRY_ENTRIES {
            return Err(FetchError::Registry(format!(
                "checkpoint {index} claims {count} entries, above the discovery cap of \
                 {MAX_REGISTRY_ENTRIES}"
            )));
        }

        let next = index.checked_add(1).filter(|next| *next < length);
        let entries_block = match next {
            Some(next) => {
                let next_l1_block = word_u64(self.head(&mut heads, next, n_p).await?, 0);
                n_p.min(next_l1_block.saturating_sub(1))
            }
            None => n_p,
        };
        let entries = self.entries(count, entries_block).await?;

        let slots = snapshot_slots(index, next.is_some());
        let proof = self
            .read("registry proof read", self.l1.account_witness(params.registry, &slots, n_p))
            .await?;
        let snapshot = Snapshot { checkpoint_index: index, l1_block, entries };
        let (record, _) = committee::derive(&snapshot, cutoff, target, params)?;
        Ok(CommitteeWitness { record, registry: proof, entries: snapshot.entries })
    }

    /// The packed `l1Block | count << 64` word of `checkpoints[i]` as of L1 block `n_p`, read at
    /// most once per discovery (`heads` remembers the words already read).
    async fn head(
        &self,
        heads: &mut BTreeMap<u64, U256>,
        i: u64,
        n_p: u64,
    ) -> Result<U256, FetchError> {
        if let Some(word) = heads.get(&i) {
            return Ok(*word);
        }
        let word = self.registry_word(registry::checkpoint_slots(i)[0], n_p).await?;
        heads.insert(i, word);
        Ok(word)
    }

    /// The first `count` registry entries as stored at L1 block `block`, read with one
    /// `account_witness` call per [`ENTRY_BATCH`] entries (the proofs are not needed).
    ///
    /// A response for other slots than requested is [`FetchError::Registry`].
    async fn entries(&self, count: u32, block: u64) -> Result<Vec<RegistryEntry>, FetchError> {
        let count = u64::from(count);
        let mut entries = Vec::new();
        let mut start = 0;
        while start < count {
            let end = count.min(start + ENTRY_BATCH);
            let slots: Vec<B256> = (start..end).flat_map(registry::entry_slots).collect();
            let witness = self
                .read(
                    "registry entries read",
                    self.l1.account_witness(self.params.registry, &slots, block),
                )
                .await?;
            if !witness.storage.iter().map(|p| p.slot).eq(slots.iter().copied()) {
                return Err(FetchError::Registry(format!(
                    "the entries read at block {block} answered other slots than requested"
                )));
            }
            for words in witness.storage.chunks_exact(3) {
                let packed = words[2].value;
                entries.push(RegistryEntry {
                    pubkey: B256::from(words[0].value),
                    eff_stake: words[1].value,
                    active_from_l1: word_u64(packed, 0),
                    exit_effective_l1: word_u64(packed, 64),
                    last_heartbeat_at: word_u64(packed, 128),
                });
            }
            start = end;
        }
        Ok(entries)
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
        committee::verify_committee_witness,
        schedule::Schedule,
        test_utils::{Fixture, L1Call, MockL1, RegistryStorage, TestState, sample_entries},
    };

    /// The L1 block a call reads, if any.
    fn block_of(call: &L1Call) -> Option<u64> {
        match call {
            L1Call::Finalized => None,
            L1Call::CanonicalHash(block) |
            L1Call::Header(block) |
            L1Call::AccountWitness { block, .. } |
            L1Call::StorageAt { block, .. } => Some(*block),
        }
    }

    /// The registry storage slots of entries `0..n`, in read order.
    fn entry_slots(n: u64) -> Vec<B256> {
        (0..n).flat_map(registry::entry_slots).collect()
    }

    /// One checkpoint with three entries costs four reads: `checkpoints.length`, the one head
    /// the search needs, every entry in one batch, and the snapshot proof.
    #[tokio::test]
    async fn discovery_reads_the_entries_in_one_batch() {
        let fx = Fixture::genesis(3);
        let l1 = fx.l1();
        let n_p = fx.activation.l1_0;
        build_committee_witness(&l1, &fx.params, n_p, Schedule::E0).await.expect("witness");
        let registry_address = fx.params.registry;
        assert_eq!(
            l1.calls(),
            [
                L1Call::StorageAt {
                    address: registry_address,
                    slot: registry::length_slot(),
                    block: n_p
                },
                L1Call::StorageAt {
                    address: registry_address,
                    slot: registry::checkpoint_slots(0)[0],
                    block: n_p
                },
                L1Call::AccountWitness {
                    address: registry_address,
                    slots: entry_slots(3),
                    block: n_p
                },
                L1Call::AccountWitness {
                    address: registry_address,
                    slots: snapshot_slots(0, false),
                    block: n_p
                },
            ]
        );
    }

    /// Without a later checkpoint the snapshot's entries are still in storage at the parent
    /// anchor, so discovery reads only that block, however old the checkpoint is.
    #[tokio::test]
    async fn the_last_checkpoint_is_read_at_the_parent_anchor() {
        let fx = Fixture::genesis(3);
        let l1 = MockL1::new(70);
        let header = fx.plant_l1_block(&l1, 70, &fx.inbox, &fx.registry);
        let witness =
            build_committee_witness(&l1, &fx.params, 70, 1).await.expect("block 70 suffices");
        assert_eq!(witness.record.checkpoint_index, 0);
        assert_eq!(witness.entries, sample_entries(3));
        assert!(l1.calls().iter().all(|c| block_of(c) == Some(70)), "{:?}", l1.calls());
        let (record, _) =
            verify_committee_witness(header.state_root(), &fx.params, &witness, 70, 1)
                .expect("the witness verifies");
        assert_eq!(record, witness.record);
    }

    /// With a checkpoint after the cutoff, the entries are read at the newest block that still
    /// holds the chosen snapshot: the block before that next checkpoint, which lies after the
    /// cutoff (so at most `cutoff_lag + cutoff_grid` blocks before the parent anchor).
    #[tokio::test]
    async fn entries_are_read_just_before_the_next_checkpoint() {
        let fx = Fixture::genesis(3);
        let params = ChainParams { cutoff_lag: 5, ..fx.params.clone() };
        let (old, new) = (sample_entries(3), sample_entries(4));
        let at_19 = RegistryStorage { checkpoints: vec![(10, old.clone())] };
        let at_22 = RegistryStorage { checkpoints: vec![(10, old.clone()), (20, new)] };
        let l1 = MockL1::new(22);
        fx.plant_l1_block(&l1, 19, &fx.inbox, &at_19);
        let header = fx.plant_l1_block(&l1, 22, &fx.inbox, &at_22);

        // Cutoff 22 - 5 = 17: checkpoint 0 (block 10) is the snapshot, checkpoint 1 (block 20)
        // follows it, so the entries are read at min(22, 20 - 1) = 19.
        let witness = build_committee_witness(&l1, &params, 22, 1).await.expect("witness");
        assert_eq!(witness.record.cutoff_l1_block, 17);
        assert_eq!(witness.record.checkpoint_index, 0);
        assert_eq!(witness.entries, old);
        let calls = l1.calls();
        let at_block = |block| calls.iter().filter(|c| block_of(c) == Some(block)).count();
        assert_eq!(
            calls.iter().filter(|c| block_of(c) == Some(19)).collect::<Vec<_>>(),
            [&L1Call::AccountWitness {
                address: params.registry,
                slots: entry_slots(3),
                block: 19
            }]
        );
        assert_eq!(calls.len(), at_block(19) + at_block(22), "no other block is read");
        verify_committee_witness(header.state_root(), &params, &witness, 22, 1)
            .expect("the witness verifies at the parent anchor");
    }

    /// A large registry is read in batches of [`ENTRY_BATCH`] entries per call.
    #[tokio::test]
    async fn entries_are_read_in_bounded_batches() {
        let fx = Fixture::genesis(1);
        let n = ENTRY_BATCH + 2;
        let entries = sample_entries(usize::try_from(n).unwrap());
        let storage = RegistryStorage { checkpoints: vec![(64, entries.clone())] };
        let l1 = MockL1::new(64);
        fx.plant_l1_block(&l1, 64, &fx.inbox, &storage);
        let witness = build_committee_witness(&l1, &fx.params, 64, 1).await.expect("witness");
        assert_eq!(witness.entries, entries);
        let batches: Vec<Vec<B256>> = l1
            .calls()
            .into_iter()
            .filter_map(|c| match c {
                L1Call::AccountWitness { slots, .. } if slots != snapshot_slots(0, false) => {
                    Some(slots)
                }
                _ => None,
            })
            .collect();
        let all = entry_slots(n);
        let split = usize::try_from(3 * ENTRY_BATCH).unwrap();
        assert_eq!(batches, [all[..split].to_vec(), all[split..].to_vec()]);
    }

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

    /// The L1 state of a registry with one checkpoint (at L1 block 1) whose head claims `count`
    /// entries, none of them stored.
    fn registry_claiming(fx: &Fixture, count: u32) -> TestState {
        let head = U256::from(1u64) | (U256::from(count) << 64);
        TestState::new(vec![(
            fx.params.registry,
            1,
            U256::ZERO,
            B256::ZERO,
            vec![
                (registry::length_slot(), U256::from(1u64)),
                (registry::checkpoint_slots(0)[0], head),
            ],
        )])
    }

    /// `count` is an unproven read and `abci-genesis` has no overall deadline: a checkpoint
    /// claiming more than [`MAX_REGISTRY_ENTRIES`] entries is refused before any entry is read.
    #[tokio::test]
    async fn a_registry_count_above_the_cap_is_refused_unread() {
        let fx = Fixture::genesis(1);
        let n_p = fx.activation.l1_0;
        for count in [MAX_REGISTRY_ENTRIES + 1, u32::MAX] {
            let l1 = fx.l1();
            l1.state().states.insert(n_p, registry_claiming(&fx, count));
            let err = build_committee_witness(&l1, &fx.params, n_p, 0).await;
            assert!(
                matches!(&err, Err(FetchError::Registry(msg)) if msg.contains(&count.to_string())),
                "{count}: {err:?}"
            );
            assert_eq!(
                l1.calls().len(),
                2,
                "{count}: only checkpoints.length and the head are read: {:?}",
                l1.calls()
            );
        }
    }

    /// A checkpoint claiming exactly [`MAX_REGISTRY_ENTRIES`] entries is still read, in
    /// `MAX_REGISTRY_ENTRIES / ENTRY_BATCH` batches.
    #[tokio::test]
    async fn a_registry_count_at_the_cap_is_read() {
        let fx = Fixture::genesis(1);
        let n_p = fx.activation.l1_0;
        let l1 = fx.l1();
        l1.state().states.insert(n_p, registry_claiming(&fx, MAX_REGISTRY_ENTRIES));
        let err = build_committee_witness(&l1, &fx.params, n_p, 0).await;
        assert!(!matches!(err, Err(FetchError::Registry(_))), "{err:?}");
        let batches = l1
            .calls()
            .iter()
            .filter(|c| {
                matches!(c, L1Call::AccountWitness { slots, .. } if *slots != snapshot_slots(0, false))
            })
            .count();
        assert_eq!(batches as u64, u64::from(MAX_REGISTRY_ENTRIES) / ENTRY_BATCH);
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

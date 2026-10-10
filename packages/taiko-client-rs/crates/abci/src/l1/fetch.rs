//! Discovery of the committee witness from the node's own L1, reading the registry's
//! `checkpoints` and live `entries` arrays (see `l1::layout::registry`).
//!
//! A proposer at `H_e` and the `abci-genesis` builder both need the [`CommitteeWitness`] of a
//! target epoch: the last registry checkpoint at or before the cutoff, all of its entries, and
//! the proofs of [`snapshot_slots`] at the parent anchor. A proposer takes the cutoff from the
//! parent anchor, floored at the genesis cutoff ([`build_committee_witness`],
//! [`committee::snapshot_cutoff`](crate::committee::snapshot_cutoff)); the genesis builder takes
//! the Inbox's `genesisCutoff` as is and proves at `L1_0` ([`build_committee_witness_at_cutoff`]).
//! The checkpoint index and the entries are found with unproven reads;
//! [`verify_snapshot`](crate::committee::verify_snapshot) later checks them against the proven
//! `entriesRoot`, so a lying L1 node can only make the witness fail verification, never pass with
//! other content.
//!
//! The entries are read in batches ([`ENTRY_BATCH`] per `account_witness` call, proofs unused,
//! up to [`ENTRY_READS_IN_FLIGHT`] calls at once) at the newest L1 block that still holds the
//! snapshot, so discovery never needs state older than the cutoff (an archive node only once the
//! cutoff leaves the node's state window). A proposer's discovery cut short keeps its finished
//! reads, from which its next attempt against the same parent anchor resumes.

use std::{
    collections::HashMap,
    future::Future,
    ops::Range,
    sync::{Mutex, MutexGuard, PoisonError},
    time::Duration,
};

use alloy_primitives::{B256, U256};
use futures::{StreamExt, TryStreamExt, stream};

use super::{
    layout::{registry, word_u32, word_u64},
    source::{L1Error, L1Source},
};
use crate::{
    committee::{self, CommitteeError, Snapshot, snapshot_slots},
    config::ChainParams,
    envelope::CommitteeWitness,
    schedule::Schedule,
    types::RegistryEntry,
};

/// Registry entries read per `account_witness` call during discovery: one call for any
/// realistic registry, while bounding a single request (and what an unproven `count` from the
/// L1 node makes the proposer allocate at once).
const ENTRY_BATCH: u64 = 128;

/// The most entry-batch reads discovery keeps in flight at once: enough to overlap the round trips
/// of a large registry, few enough not to flood the L1 node.
const ENTRY_READS_IN_FLIGHT: usize = 4;

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

/// The finished registry reads of a committee-witness discovery against one parent anchor that
/// has not ended yet, so that an attempt cut short (a read past its deadline, or the whole
/// discovery dropped, as `PrepareProposal`'s overall deadline does) resumes where it stopped
/// instead of starting over.
///
/// `PrepareProposal`'s deadline does not grow with the round, so without this a discovery that
/// needs longer than it from scratch would never finish. The reads are kept by parent anchor
/// alone, as none depends on the target epoch; another parent anchor starts afresh. They stay
/// unproven like every discovery read (verifying the built witness still decides), and a discovery
/// that ends in any other way (a witness, an L1 or registry error) forgets them, so a bad answer
/// is not replayed.
#[derive(Debug, Default)]
pub(crate) struct DiscoveryProgress(Mutex<Reads>);

impl DiscoveryProgress {
    /// Forgets every kept read.
    pub(crate) fn clear(&self) {
        *self.lock() = Reads::default();
    }

    /// The kept reads, which hold no invariant a panicking holder could break.
    fn lock(&self) -> MutexGuard<'_, Reads> {
        self.0.lock().unwrap_or_else(PoisonError::into_inner)
    }
}

/// The reads a [`DiscoveryProgress`] keeps.
#[derive(Debug, Default)]
struct Reads {
    /// The parent anchor `n_p` the reads were made for; `None` before the first discovery.
    parent_anchor: Option<u64>,
    /// Registry storage words by slot (`checkpoints.length`, checkpoint heads) at `parent_anchor`.
    words: HashMap<B256, U256>,
    /// Entry batches, by the L1 block they were read at and their index range.
    batches: HashMap<(u64, Range<u64>), Vec<RegistryEntry>>,
}

/// Builds the committee witness for `target_epoch` against the parent anchor `parent_anchor`,
/// reading the node's own L1 without deadlines.
///
/// In order:
/// - the cutoff, computed from `parent_anchor` and floored at `schedule.genesis_cutoff`
///   ([`committee::snapshot_cutoff`]);
/// - with unproven storage reads at `parent_anchor`, the last checkpoint `i` whose `l1Block` is at
///   or before the cutoff (binary search, each checkpoint word read once; checkpoint 0 when none
///   is, which verification then rejects) and its `count` (at most [`MAX_REGISTRY_ENTRIES`],
///   [`FetchError::Registry`] otherwise);
/// - its entries, unproven, in batches of [`ENTRY_BATCH`] ([`ENTRY_READS_IN_FLIGHT`] at once), at
///   the newest block that still holds that snapshot: `parent_anchor` when `i` is the last
///   checkpoint, else `min(parent_anchor, checkpoints[i + 1].l1Block − 1)`. The registry appends a
///   checkpoint in every L1 block that changes an entry, so the entries stay checkpoint `i`'s until
///   the next one, whose block is after the cutoff, i.e. at most `cutoff_lag + cutoff_grid` blocks
///   before `parent_anchor` (the floor only moves the cutoff later);
/// - the proof of `snapshot_slots(i, i + 1 < length)` at `parent_anchor`;
/// - the record the witness claims, derived from the snapshot under `schedule`.
pub async fn build_committee_witness<L: L1Source + ?Sized>(
    l1: &L,
    params: &ChainParams,
    schedule: &Schedule,
    parent_anchor: u64,
    target_epoch: u64,
) -> Result<CommitteeWitness, FetchError> {
    let progress = DiscoveryProgress::default();
    Discovery { l1, params, schedule, cutoff: None, read_timeout: None, progress: &progress }
        .witness(parent_anchor, target_epoch)
        .await
}

/// [`build_committee_witness`] with the given `cutoff` instead of the one of the parent anchor:
/// the snapshot is the last checkpoint with `l1Block <= cutoff` (no lag, no grid), and every read
/// [`build_committee_witness`] makes at the parent anchor is made at L1 block `block`.
///
/// This builds the genesis committee `e_0`'s witness, with `block = L1_0` and
/// `cutoff = genesisCutoff`, as
/// [`verify_committee_witness_at_cutoff`](crate::committee::verify_committee_witness_at_cutoff)
/// checks it. The entries are read at the newest block that still holds the snapshot, which is
/// at or after `cutoff` but, unlike a proposer's, not bounded by the cutoff lag and grid: as old
/// as `genesisCutoff` in the worst case.
///
/// Precondition: `cutoff <= block`. A snapshot at a later cutoff is not final at `block` (a
/// checkpoint may still be written after `block` and at or before `cutoff`), so its witness
/// would prove a snapshot the registry can still change.
pub async fn build_committee_witness_at_cutoff<L: L1Source + ?Sized>(
    l1: &L,
    params: &ChainParams,
    schedule: &Schedule,
    block: u64,
    cutoff: u64,
    target_epoch: u64,
) -> Result<CommitteeWitness, FetchError> {
    let progress = DiscoveryProgress::default();
    Discovery {
        l1,
        params,
        schedule,
        cutoff: Some(cutoff),
        read_timeout: None,
        progress: &progress,
    }
    .witness(block, target_epoch)
    .await
}

/// [`build_committee_witness`], bounding every single L1 read by `read_timeout`
/// ([`FetchError::Timeout`] otherwise) and resuming from, and adding to, the reads `progress`
/// kept for `parent_anchor`.
///
/// A read past its deadline keeps `progress`; any other end clears it ([`DiscoveryProgress`]).
pub(crate) async fn build_committee_witness_within<L: L1Source + ?Sized>(
    l1: &L,
    params: &ChainParams,
    schedule: &Schedule,
    parent_anchor: u64,
    target_epoch: u64,
    read_timeout: Duration,
    progress: &DiscoveryProgress,
) -> Result<CommitteeWitness, FetchError> {
    Discovery { l1, params, schedule, cutoff: None, read_timeout: Some(read_timeout), progress }
        .witness(parent_anchor, target_epoch)
        .await
}

/// One committee-witness discovery over an L1 source.
struct Discovery<'a, L: ?Sized> {
    /// The node's own L1.
    l1: &'a L,
    /// The chain parameters (registry address, cutoff grid and lag, derivation parameters).
    params: &'a ChainParams,
    /// The chain's epoch schedule, which the heartbeat eligibility of the derivation and the
    /// genesis-cutoff floor of an anchored cutoff read.
    schedule: &'a Schedule,
    /// The snapshot cutoff; `None` derives it from the parent anchor
    /// ([`committee::snapshot_cutoff`]: the cutoff lag and grid, floored at the genesis cutoff).
    cutoff: Option<u64>,
    /// The deadline of each single L1 read; `None` waits indefinitely.
    read_timeout: Option<Duration>,
    /// The reads earlier, unfinished attempts made; every finished read is added at once.
    progress: &'a DiscoveryProgress,
}

impl<L: L1Source + ?Sized> Discovery<'_, L> {
    /// The committee witness for `target` against the parent anchor `n_p` (see
    /// [`build_committee_witness`]): resumes from the kept reads of `n_p` (forgetting those of
    /// another parent anchor), and forgets them again unless a read timed out.
    async fn witness(&self, n_p: u64, target: u64) -> Result<CommitteeWitness, FetchError> {
        {
            let mut reads = self.progress.lock();
            if reads.parent_anchor != Some(n_p) {
                *reads = Reads { parent_anchor: Some(n_p), ..Reads::default() };
            }
        }
        let result = self.discover(n_p, target).await;
        if !matches!(result, Err(FetchError::Timeout(_))) {
            self.progress.clear();
        }
        result
    }

    /// The discovery steps of [`build_committee_witness`].
    async fn discover(&self, n_p: u64, target: u64) -> Result<CommitteeWitness, FetchError> {
        let params = self.params;
        let cutoff = match self.cutoff {
            Some(cutoff) => cutoff,
            None => committee::snapshot_cutoff(n_p, self.schedule, params)?,
        };

        let length = self.registry_word(registry::length_slot(), n_p).await?;
        let length = u64::try_from(length).map_err(|_| {
            FetchError::Registry(format!("checkpoints.length {length} exceeds u64"))
        })?;
        // Invariant: checkpoints below `lo` are at or before the cutoff, from `hi` on after it.
        let (mut lo, mut hi) = (0u64, length);
        while lo < hi {
            let mid = lo + (hi - lo) / 2;
            if word_u64(self.head(mid, n_p).await?, 0) <= cutoff {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        let index = lo.saturating_sub(1);
        let head = self.head(index, n_p).await?;
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
                let next_l1_block = word_u64(self.head(next, n_p).await?, 0);
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
        let (record, _) = committee::derive(&snapshot, cutoff, target, self.schedule, params)?;
        Ok(CommitteeWitness { record, registry: proof, entries: snapshot.entries })
    }

    /// The packed `l1Block | count << 64` word of `checkpoints[i]` as of the parent anchor `n_p`.
    async fn head(&self, i: u64, n_p: u64) -> Result<U256, FetchError> {
        self.registry_word(registry::checkpoint_slots(i)[0], n_p).await
    }

    /// The first `count` registry entries as stored at L1 block `block`, read with one
    /// `account_witness` call per [`ENTRY_BATCH`] entries (the proofs are not needed), at most
    /// [`ENTRY_READS_IN_FLIGHT`] calls at once; the first failing batch fails the read.
    async fn entries(&self, count: u32, block: u64) -> Result<Vec<RegistryEntry>, FetchError> {
        let count = u64::from(count);
        let ranges = (0..count.div_ceil(ENTRY_BATCH))
            .map(|i| i * ENTRY_BATCH..count.min((i + 1) * ENTRY_BATCH));
        let batches: Vec<Vec<RegistryEntry>> = stream::iter(ranges)
            .map(|batch| self.entry_batch(batch, block))
            .buffered(ENTRY_READS_IN_FLIGHT)
            .try_collect()
            .await?;
        Ok(batches.concat())
    }

    /// The registry entries with indices in `batch` as stored at L1 block `block`: kept by an
    /// earlier attempt, or read with one `account_witness` call (and kept).
    ///
    /// A response for other slots than requested is [`FetchError::Registry`].
    async fn entry_batch(
        &self,
        batch: Range<u64>,
        block: u64,
    ) -> Result<Vec<RegistryEntry>, FetchError> {
        let key = (block, batch.clone());
        let kept = self.progress.lock().batches.get(&key).cloned();
        if let Some(entries) = kept {
            return Ok(entries);
        }
        let slots: Vec<B256> = batch.flat_map(registry::entry_slots).collect();
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
        let entries: Vec<RegistryEntry> = witness
            .storage
            .chunks_exact(3)
            .map(|words| {
                let packed = words[2].value;
                RegistryEntry {
                    pubkey: B256::from(words[0].value),
                    eff_stake: words[1].value,
                    active_from_l1: word_u64(packed, 0),
                    exit_effective_l1: word_u64(packed, 64),
                    last_heartbeat_at: word_u64(packed, 128),
                    last_heartbeat_seq: word_u64(packed, 192),
                }
            })
            .collect();
        self.progress.lock().batches.insert(key, entries.clone());
        Ok(entries)
    }

    /// The raw registry storage word at `slot` as of the parent anchor `n_p`: kept by an earlier
    /// read of this or an unfinished attempt, or read (and kept).
    async fn registry_word(&self, slot: B256, n_p: u64) -> Result<U256, FetchError> {
        let kept = self.progress.lock().words.get(&slot).copied();
        if let Some(word) = kept {
            return Ok(word);
        }
        let word = self
            .read("registry storage read", self.l1.storage_at(self.params.registry, slot, n_p))
            .await?;
        self.progress.lock().words.insert(slot, word);
        Ok(word)
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
        committee::{verify_committee_witness, verify_committee_witness_at_cutoff},
        schedule::Schedule,
        test_utils::{
            Fixture, GenesisSpec, L1Call, MockL1, RegistryStorage, TestState, anchor_at,
            sample_entries,
        },
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
        build_committee_witness(&l1, &fx.params, &fx.schedule(), n_p, Schedule::E0)
            .await
            .expect("witness");
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
        let witness = build_committee_witness(&l1, &fx.params, &fx.schedule(), 70, 1)
            .await
            .expect("block 70 suffices");
        assert_eq!(witness.record.checkpoint_index, 0);
        assert_eq!(witness.entries, sample_entries(3));
        assert!(l1.calls().iter().all(|c| block_of(c) == Some(70)), "{:?}", l1.calls());
        let (record, _) = verify_committee_witness(
            &anchor_at(70, header.state_root()),
            &fx.schedule(),
            &fx.params,
            &witness,
            1,
        )
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
        // No genesis-cutoff floor: this parent anchor predates the fixture's `L1_0`.
        let schedule = Schedule { genesis_cutoff: 0, ..fx.schedule() };
        let (old, new) = (sample_entries(3), sample_entries(4));
        let at_19 = RegistryStorage { checkpoints: vec![(10, old.clone())] };
        let at_22 = RegistryStorage { checkpoints: vec![(10, old.clone()), (20, new)] };
        let l1 = MockL1::new(22);
        fx.plant_l1_block(&l1, 19, &fx.inbox, &at_19);
        let header = fx.plant_l1_block(&l1, 22, &fx.inbox, &at_22);

        // Cutoff 22 - 5 = 17: checkpoint 0 (block 10) is the snapshot, checkpoint 1 (block 20)
        // follows it, so the entries are read at min(22, 20 - 1) = 19.
        let witness =
            build_committee_witness(&l1, &params, &schedule, 22, 1).await.expect("witness");
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
        verify_committee_witness(
            &anchor_at(22, header.state_root()),
            &schedule,
            &params,
            &witness,
            1,
        )
        .expect("the witness verifies at the parent anchor");
    }

    /// A proposer's discovery floors the anchored cutoff at the genesis cutoff: under the
    /// regression genesis (`L1_0 = 64`, lag 5, grid 1, genesis cutoff 63, entries active from
    /// 62), `e_0 + 1` is discovered at `max(cutoff(64) = 59, 63) = 63`, where every entry is
    /// eligible, and the witness verifies through the genesis anchor.
    #[tokio::test]
    async fn the_anchored_cutoff_is_floored_at_the_genesis_cutoff() {
        let fx = Fixture::build(GenesisSpec::active_after_lagged_l1_0_cutoff(2));
        let l1_0 = fx.activation.l1_0;
        let witness = build_committee_witness(&fx.l1(), &fx.params, &fx.schedule(), l1_0, 1)
            .await
            .expect("e_0 + 1 derives at the floored cutoff");
        assert_eq!(witness.record.cutoff_l1_block, fx.activation.genesis_cutoff);
        assert_eq!(witness.record.checkpoint_index, 0);
        assert_eq!(witness.entries, fx.registry.checkpoints[0].1);
        let (record, members) = verify_committee_witness(
            &fx.anchor_state(&fx.l1(), l1_0, None),
            &fx.schedule(),
            &fx.params,
            &witness,
            1,
        )
        .expect("the witness verifies through the genesis anchor");
        assert_eq!(record, witness.record);
        assert_eq!(members.len(), 2);

        // Without the floor the lagged cutoff 59 precedes every entry's activation.
        let unfloored = Schedule { genesis_cutoff: 0, ..fx.schedule() };
        let err = build_committee_witness(&fx.l1(), &fx.params, &unfloored, l1_0, 1).await;
        assert_eq!(err, Err(FetchError::Committee(CommitteeError::Empty)));
    }

    /// An explicit cutoff is taken as is: no lag, no grid (with lag 5 and grid 4 the parent anchor
    /// 64 would give cutoff 56, before every checkpoint). The parent-anchor reads are made at the
    /// given block, and the entries at the newest block that still holds the snapshot.
    #[tokio::test]
    async fn an_explicit_cutoff_is_taken_as_is() {
        let fx = Fixture::genesis(3);
        let params = ChainParams { cutoff_lag: 5, cutoff_grid: 4, ..fx.params.clone() };
        let (old, new) = (sample_entries(3), sample_entries(4));
        let at_61 = RegistryStorage { checkpoints: vec![(60, old.clone())] };
        let at_64 = RegistryStorage { checkpoints: vec![(60, old.clone()), (62, new)] };
        let l1 = MockL1::new(64);
        fx.plant_l1_block(&l1, 61, &fx.inbox, &at_61);
        let header = fx.plant_l1_block(&l1, 64, &fx.inbox, &at_64);

        // Cutoff 61: checkpoint 0 (block 60) is the snapshot, checkpoint 1 (block 62) follows it,
        // so the entries are read at min(64, 62 - 1) = 61.
        let witness =
            build_committee_witness_at_cutoff(&l1, &params, &fx.schedule(), 64, 61, Schedule::E0)
                .await
                .expect("witness");
        assert_eq!(witness.record.cutoff_l1_block, 61);
        assert_eq!(witness.record.checkpoint_index, 0);
        assert_eq!(witness.entries, old);
        let calls = l1.calls();
        assert_eq!(
            calls.iter().filter(|c| block_of(c) == Some(61)).collect::<Vec<_>>(),
            [&L1Call::AccountWitness {
                address: params.registry,
                slots: entry_slots(3),
                block: 61
            }]
        );
        assert!(calls.iter().all(|c| matches!(block_of(c), Some(61 | 64))), "{calls:?}");
        let (record, _) = verify_committee_witness_at_cutoff(
            header.state_root(),
            61,
            &fx.schedule(),
            &params,
            &witness,
            Schedule::E0,
        )
        .expect("the witness verifies at the explicit cutoff");
        assert_eq!(record, witness.record);
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
        let witness =
            build_committee_witness(&l1, &fx.params, &fx.schedule(), 64, 1).await.expect("witness");
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

    /// Against the fixture's L1, discovery at the genesis cutoff rebuilds exactly the genesis
    /// committee witness. Through the parent anchor `L1_0` (cutoff 64 under the devnet's lag 0
    /// and grid 1) it finds the same snapshot; only the record's cutoff differs.
    #[tokio::test]
    async fn rebuilds_the_fixture_genesis_committee_witness() {
        let fx = Fixture::genesis(3);
        let l1 = fx.l1();
        let l1_0 = fx.activation.l1_0;
        let witness = build_committee_witness_at_cutoff(
            &l1,
            &fx.params,
            &fx.schedule(),
            l1_0,
            fx.activation.genesis_cutoff,
            Schedule::E0,
        )
        .await
        .expect("the fixture registry yields a witness");
        assert_eq!(witness, fx.witness.committee);

        let anchored = build_committee_witness(&l1, &fx.params, &fx.schedule(), l1_0, Schedule::E0)
            .await
            .expect("the fixture registry yields a witness");
        assert_eq!(anchored.record.cutoff_l1_block, l1_0);
        assert_eq!(
            CommitteeWitness { record: fx.witness.committee.record.clone(), ..anchored.clone() },
            fx.witness.committee
        );
        let within = build_committee_witness_within(
            &l1,
            &fx.params,
            &fx.schedule(),
            l1_0,
            Schedule::E0,
            Duration::from_secs(1),
            &DiscoveryProgress::default(),
        )
        .await;
        assert_eq!(within, Ok(anchored));
    }

    /// The entry batches are read concurrently, at most four at a time, and still yield the
    /// entries in index order.
    #[tokio::test(start_paused = true)]
    async fn entry_batches_are_read_concurrently_but_bounded() {
        let bound = ENTRY_READS_IN_FLIGHT;
        let fx = Fixture::genesis(1);
        let n = 6 * ENTRY_BATCH + 1; // seven batches
        let entries = sample_entries(usize::try_from(n).unwrap());
        let storage = RegistryStorage { checkpoints: vec![(64, entries.clone())] };
        let l1 = MockL1::new(64);
        fx.plant_l1_block(&l1, 64, &fx.inbox, &storage);
        l1.state().delay = Some(Duration::from_secs(1));

        let start = tokio::time::Instant::now();
        let progress = DiscoveryProgress::default();
        let witness = build_committee_witness_within(
            &l1,
            &fx.params,
            &fx.schedule(),
            64,
            1,
            Duration::from_secs(5),
            &progress,
        )
        .await
        .expect("witness");
        assert_eq!(witness.entries, entries);
        assert_eq!(l1.state().max_in_flight, bound);
        // checkpoints.length, the head, two waves of entry reads, the proof: 5 s instead of 10 s.
        assert_eq!(start.elapsed(), Duration::from_secs(5));
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
            &fx.schedule(),
            fx.activation.l1_0,
            Schedule::E0,
            Duration::from_secs(4),
            &DiscoveryProgress::default(),
        )
        .await;
        assert_eq!(err, Err(FetchError::Timeout("registry storage read")));
    }

    /// Discovers committee `e_0`'s witness against `n_p` on `l1` with reads bounded by `limit`,
    /// resuming from `progress`.
    async fn resume(
        fx: &Fixture,
        l1: &MockL1,
        n_p: u64,
        limit: Duration,
        progress: &DiscoveryProgress,
    ) -> Result<CommitteeWitness, FetchError> {
        build_committee_witness_within(
            l1,
            &fx.params,
            &fx.schedule(),
            n_p,
            Schedule::E0,
            limit,
            progress,
        )
        .await
    }

    /// Starts a discovery against `n_p` with one read per second and drops it after 1.5 s, once
    /// `checkpoints.length` has answered; leaves the call log empty.
    async fn drop_after_the_length_read(
        fx: &Fixture,
        l1: &MockL1,
        n_p: u64,
        progress: &DiscoveryProgress,
    ) {
        l1.state().calls.clear();
        l1.state().delay = Some(Duration::from_secs(1));
        let attempt = resume(fx, l1, n_p, Duration::from_secs(5), progress);
        assert!(tokio::time::timeout(Duration::from_millis(1_500), attempt).await.is_err());
        let calls = std::mem::take(&mut l1.state().calls);
        assert_eq!(
            calls,
            [L1Call::StorageAt {
                address: fx.params.registry,
                slot: registry::length_slot(),
                block: n_p
            }]
        );
        l1.state().delay = None;
    }

    /// A discovery dropped midway (as `PrepareProposal`'s deadline drops it) or failing on a read
    /// past its deadline keeps its finished reads: the next attempt against the same parent
    /// anchor reads only the rest. A finished discovery forgets them.
    #[tokio::test(start_paused = true)]
    async fn an_unfinished_discovery_resumes_from_its_finished_reads() {
        let fx = Fixture::genesis(3);
        let l1 = fx.l1();
        let n_p = fx.activation.l1_0;
        let progress = DiscoveryProgress::default();
        let limit = Duration::from_secs(5);

        let expected =
            build_committee_witness(&fx.l1(), &fx.params, &fx.schedule(), n_p, Schedule::E0).await;
        drop_after_the_length_read(&fx, &l1, n_p, &progress).await;
        assert_eq!(resume(&fx, &l1, n_p, limit, &progress).await, expected);
        assert_eq!(l1.calls().len(), 3, "the head, the entries and the proof: {:?}", l1.calls());
        l1.state().calls.clear();
        resume(&fx, &l1, n_p, limit, &progress).await.expect("the witness builds");
        assert_eq!(l1.calls().len(), 4, "a finished discovery starts the next one afresh");

        // The head read times out; the length read stays kept.
        drop_after_the_length_read(&fx, &l1, n_p, &progress).await;
        l1.state().delay = Some(Duration::from_secs(3));
        let short = Duration::from_secs(2);
        let err = resume(&fx, &l1, n_p, short, &progress).await;
        assert_eq!(err, Err(FetchError::Timeout("registry storage read")));
        l1.state().delay = None;
        l1.state().calls.clear();
        resume(&fx, &l1, n_p, limit, &progress).await.expect("the witness builds");
        assert_eq!(l1.calls().len(), 3, "{:?}", l1.calls());
    }

    /// An L1 error forgets the kept reads, and so does a discovery against another parent anchor.
    #[tokio::test(start_paused = true)]
    async fn other_failures_and_another_parent_anchor_start_afresh() {
        let fx = Fixture::genesis(3);
        let l1 = fx.l1();
        let n_p = fx.activation.l1_0;
        let progress = DiscoveryProgress::default();
        let limit = Duration::from_secs(5);

        drop_after_the_length_read(&fx, &l1, n_p, &progress).await;
        l1.state().fail = Some(L1Error::Rpc("down".into()));
        let err = resume(&fx, &l1, n_p, limit, &progress).await;
        assert_eq!(err, Err(FetchError::L1(L1Error::Rpc("down".into()))));
        l1.state().fail = None;
        l1.state().calls.clear();
        resume(&fx, &l1, n_p, limit, &progress).await.expect("the witness builds");
        assert_eq!(l1.calls().len(), 4, "the length is read again: {:?}", l1.calls());

        let other = n_p + 6;
        fx.plant_l1_block(&l1, other, &fx.inbox, &fx.registry);
        drop_after_the_length_read(&fx, &l1, n_p, &progress).await;
        resume(&fx, &l1, other, limit, &progress).await.expect("the witness builds");
        assert!(l1.calls().iter().all(|c| block_of(c) == Some(other)), "{:?}", l1.calls());
        assert_eq!(l1.calls().len(), 4, "{:?}", l1.calls());
        l1.state().calls.clear();
        resume(&fx, &l1, n_p, limit, &progress).await.expect("the witness builds");
        assert_eq!(l1.calls().len(), 4, "{:?}", l1.calls());
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
            let err = build_committee_witness(&l1, &fx.params, &fx.schedule(), n_p, 0).await;
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
        let err = build_committee_witness(&l1, &fx.params, &fx.schedule(), n_p, 0).await;
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
        let err =
            build_committee_witness(&l1, &fx.params, &fx.schedule(), fx.activation.l1_0, 0).await;
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
        let err =
            build_committee_witness(&l1, &fx.params, &fx.schedule(), fx.activation.l1_0, 0).await;
        assert!(matches!(err, Err(FetchError::Registry(_))), "{err:?}");
        assert_eq!(l1.calls().len(), 1, "discovery stops at the bad length");
        assert!(matches!(l1.calls()[0], L1Call::StorageAt { .. }));
    }
}

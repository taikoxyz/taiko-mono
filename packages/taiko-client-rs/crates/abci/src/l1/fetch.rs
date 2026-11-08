//! Discovery of registry witnesses from L1 RPC, followed by independent pure verification.
//!
//! Runtime discovery selects and proves at the committed parent anchor. Explicit-cutoff discovery
//! serves genesis and authenticated host proof jobs. The proving block must cover the cutoff.
//! Checkpoint binary search and historical entry reads are untrusted until their complete root
//! verifies; entries may require archive state well before the proving block.

use std::{collections::HashMap, future::Future, ops::Range, time::Duration};

use alloy_primitives::{B256, U256};
use futures::{StreamExt, TryStreamExt, stream};

use super::{
    layout::{registry, word_u8, word_u48},
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

/// The most entry-batch reads discovery keeps in flight at once: enough to overlap the round trips
/// of a large registry, few enough not to flood the L1 node.
const ENTRY_READS_IN_FLIGHT: usize = 4;

/// The most entries discovery reads for one checkpoint: a larger `count` is
/// [`FetchError::Registry`], refused before any entry is read.
///
/// `count` is an unproven read from the node's own L1, and `abci-genesis` runs without an overall
/// deadline, so a buggy L1 node claiming up to `u32::MAX` entries could otherwise drive millions
/// of reads. The cap bounds discovery at `MAX_REGISTRY_ENTRIES / ENTRY_BATCH` = 32 entry reads.
/// The registry reuses a withdrawn bond's slot, so `count` is the most bonds ever unwithdrawn at
/// once (exited ones included), far above the committee cap `n_max` (128 on the devnet); a
/// registry growing past it needs a client release raising it.
pub const MAX_REGISTRY_ENTRIES: u32 = 4096;

/// Why a committee witness could not be built.
#[derive(Clone, Debug, thiserror::Error, PartialEq, Eq)]
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

/// [`build_committee_witness_within`] without read deadlines.
#[cfg(test)]
pub(crate) async fn build_committee_witness<L: L1Source + ?Sized>(
    l1: &L,
    params: &ChainParams,
    parent_anchor: u64,
    target_epoch: u64,
) -> Result<CommitteeWitness, FetchError> {
    Discovery { l1, params, cutoff: None, read_timeout: None }
        .witness(parent_anchor, target_epoch)
        .await
}

/// The committee witness for `target_epoch` with the given explicit historical `cutoff`, reading
/// the node's own L1 without deadlines: the snapshot is the last checkpoint with
/// `l1Block <= cutoff` (no lag, no grid), and every read [`build_committee_witness_within`] makes
/// at the parent anchor is made at L1 block `block`.
///
/// This builds the genesis committee `e_0`'s witness, with `block = L1_0` and
/// `cutoff = genesisCutoff`, as
/// [`verify_committee_witness_at_cutoff`](crate::committee::verify_committee_witness_at_cutoff)
/// checks it. The entries are read at the newest block that still holds the snapshot, which is
/// at or after `cutoff`: as old
/// as `genesisCutoff` in the worst case.
///
/// Precondition: `cutoff <= block`. A snapshot at a later cutoff is not final at `block` (a
/// checkpoint may still be written after `block` and at or before `cutoff`), so its witness
/// would prove a snapshot the registry can still change.
pub async fn build_committee_witness_at_cutoff<L: L1Source + ?Sized>(
    l1: &L,
    params: &ChainParams,
    block: u64,
    cutoff: u64,
    target_epoch: u64,
) -> Result<CommitteeWitness, FetchError> {
    Discovery { l1, params, cutoff: Some(cutoff), read_timeout: None }
        .witness(block, target_epoch)
        .await
}

/// Builds the committee witness for `target_epoch` against the parent anchor `parent_anchor`,
/// bounding every single L1 read by `read_timeout` ([`FetchError::Timeout`] otherwise).
///
/// In order:
/// - the supplied committed parent anchor number as the snapshot cutoff;
/// - the last registry checkpoint at or before it, found by binary search;
/// - the complete entries read at the proving block or just before the successor checkpoint;
/// - checkpoint and successor storage proofs at the proving block.
///
/// Every result is independently checked by the pure committee verifier. Historical entry
/// discovery needs the own L1 to serve historical state (SYNC-9-16); an explicit historical
/// snapshot is never advanced by its later proving block.
///
/// Each call starts afresh: the app runs it once per switch context in the background, past any
/// proposal deadline, and restarts a failed one from scratch after its backoff.
pub(crate) async fn build_committee_witness_within<L: L1Source + ?Sized>(
    l1: &L,
    params: &ChainParams,
    parent_anchor: u64,
    target_epoch: u64,
    read_timeout: Duration,
) -> Result<CommitteeWitness, FetchError> {
    Discovery { l1, params, cutoff: None, read_timeout: Some(read_timeout) }
        .witness(parent_anchor, target_epoch)
        .await
}

/// `base` re-proved under the state root of L1 block `block`: the same record and entries,
/// with the registry account and [`snapshot_slots`] proofs read at `block`.
///
/// Registry checkpoints are append-only, so the snapshot `base` selected at its cutoff is the
/// same at any proving block at or after that cutoff. Only the proofs depend on the block's
/// root, plus whether a next checkpoint exists there. Two reads, each within `read_timeout`:
/// `checkpoints.length`, then the proof. Like every discovery result, the witness is unverified.
pub(crate) async fn reprove_committee_witness<L: L1Source + ?Sized>(
    l1: &L,
    params: &ChainParams,
    base: &CommitteeWitness,
    block: u64,
    read_timeout: Duration,
) -> Result<CommitteeWitness, FetchError> {
    let discovery = Discovery {
        l1,
        params,
        cutoff: Some(base.record.cutoff_l1_block),
        read_timeout: Some(read_timeout),
    };
    let length = discovery.registry_word(registry::length_slot(), block).await?;
    let index = base.record.checkpoint_index;
    let has_next = U256::from(index) + U256::from(1) < length;
    let slots = snapshot_slots(index, has_next);
    let proof = discovery
        .read("registry proof read", l1.account_witness(params.registry, &slots, block))
        .await?;
    Ok(CommitteeWitness {
        record: base.record.clone(),
        registry: proof,
        entries: base.entries.clone(),
    })
}

/// One committee-witness discovery over an L1 source.
struct Discovery<'a, L: ?Sized> {
    /// The node's own L1.
    l1: &'a L,
    /// The chain parameters (registry address and derivation parameters).
    params: &'a ChainParams,
    /// Explicit snapshot cutoff for genesis/host jobs; `None` selects the supplied parent number.
    cutoff: Option<u64>,
    /// The deadline of each single L1 read; `None` waits indefinitely.
    read_timeout: Option<Duration>,
}

impl<L: L1Source + ?Sized> Discovery<'_, L> {
    /// The committee witness for `target` against the parent anchor `n_p` (see
    /// [`build_committee_witness_within`]).
    async fn witness(&self, n_p: u64, target: u64) -> Result<CommitteeWitness, FetchError> {
        let params = self.params;
        let cutoff = self.cutoff.unwrap_or(n_p);

        if cutoff > n_p {
            return Err(CommitteeError::CutoffAfterAnchor { cutoff, anchor: n_p }.into());
        }
        let length = self.registry_word(registry::length_slot(), n_p).await?;
        let length = u64::try_from(length).map_err(|_| {
            FetchError::Registry(format!("checkpoints.length {length} exceeds u64"))
        })?;
        // The checkpoint heads read so far: the search's last probes are the snapshot's head and
        // its successor's, so neither is read twice.
        let mut heads = HashMap::new();
        // Invariant: checkpoints below `lo` are at or before the cutoff, from `hi` on after it.
        let (mut lo, mut hi) = (0u64, length);
        while lo < hi {
            let mid = lo + (hi - lo) / 2;
            if word_u48(self.head(mid, n_p, &mut heads).await?, 0) <= cutoff {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        let index = lo.saturating_sub(1);
        let head = self.head(index, n_p, &mut heads).await?;
        let (l1_block, count) = (word_u48(head, 0), word_u48(head, 48));
        if count > u64::from(MAX_REGISTRY_ENTRIES) {
            return Err(FetchError::Registry(format!(
                "checkpoint {index} claims {count} entries, above the discovery cap of \
                 {MAX_REGISTRY_ENTRIES}"
            )));
        }

        let next = index.checked_add(1).filter(|next| *next < length);
        let entries_block = match next {
            Some(next) => {
                let next_l1_block = word_u48(self.head(next, n_p, &mut heads).await?, 0);
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

    /// The packed `l1Block | count << 48` word of `checkpoints[i]` as of the parent anchor `n_p`:
    /// kept in `heads` once read, or read (and kept).
    async fn head(
        &self,
        i: u64,
        n_p: u64,
        heads: &mut HashMap<u64, U256>,
    ) -> Result<U256, FetchError> {
        if let Some(word) = heads.get(&i) {
            return Ok(*word);
        }
        let word = self.registry_word(registry::checkpoint_slots(i)[0], n_p).await?;
        heads.insert(i, word);
        Ok(word)
    }

    /// The first `count` registry entries as stored at L1 block `block`, read with one
    /// `account_witness` call per [`ENTRY_BATCH`] entries (the proofs are not needed), at most
    /// [`ENTRY_READS_IN_FLIGHT`] calls at once; the first failing batch fails the read.
    async fn entries(&self, count: u64, block: u64) -> Result<Vec<RegistryEntry>, FetchError> {
        let ranges = (0..count.div_ceil(ENTRY_BATCH))
            .map(|i| i * ENTRY_BATCH..count.min((i + 1) * ENTRY_BATCH));
        let batches: Vec<Vec<RegistryEntry>> = stream::iter(ranges)
            .map(|batch| self.entry_batch(batch, block))
            .buffered(ENTRY_READS_IN_FLIGHT)
            .try_collect()
            .await?;
        Ok(batches.concat())
    }

    /// The registry entries with indices in `batch` as stored at L1 block `block`, read with one
    /// `account_witness` call.
    ///
    /// A response for other slots than requested is [`FetchError::Registry`].
    async fn entry_batch(
        &self,
        batch: Range<u64>,
        block: u64,
    ) -> Result<Vec<RegistryEntry>, FetchError> {
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
        Ok(witness
            .storage
            .as_chunks::<3>()
            .0
            .iter()
            .map(|words| {
                let packed = words[2].value;
                RegistryEntry {
                    ck_prefix: word_u8(packed, 0),
                    ck_x: B256::from(words[0].value),
                    eff_stake: words[1].value,
                    active_from_l1: word_u48(packed, 8),
                    exit_effective_l1: word_u48(packed, 56),
                }
            })
            .collect())
    }

    /// The raw registry storage word at `slot` as of the parent anchor `n_p`.
    async fn registry_word(&self, slot: B256, n_p: u64) -> Result<U256, FetchError> {
        self.read("registry storage read", self.l1.storage_at(self.params.registry, slot, n_p))
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
            L1Call::ForcedTransaction { l1_block, .. } => Some(*l1_block),
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
        let n_p = fx.genesis.l1_0;
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
            verify_committee_witness(&anchor_at(70, header.state_root()), &fx.params, &witness, 1)
                .expect("the witness verifies");
        assert_eq!(record, witness.record);
    }

    /// An explicit historical snapshot reads entries just before the successor checkpoint,
    /// while authenticating metadata under its later covering proving root.
    #[tokio::test]
    async fn entries_are_read_just_before_the_next_checkpoint() {
        let fx = Fixture::genesis(3);
        let params = fx.params.clone();
        // This explicit historical snapshot predates the fixture's `L1_0`.
        let (old, new) = (sample_entries(3), sample_entries(4));
        let at_19 = RegistryStorage { checkpoints: vec![(10, old.clone())] };
        let at_22 = RegistryStorage { checkpoints: vec![(10, old.clone()), (20, new)] };
        let l1 = MockL1::new(22);
        fx.plant_l1_block(&l1, 19, &fx.inbox, &at_19);
        let header = fx.plant_l1_block(&l1, 22, &fx.inbox, &at_22);

        // Explicit snapshot 17: checkpoint 0 (block 10) is the snapshot, checkpoint 1 (block 20)
        // follows it, so the entries are read at min(22, 20 - 1) = 19.
        let witness =
            build_committee_witness_at_cutoff(&l1, &params, 22, 17, 1).await.expect("witness");
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
        verify_committee_witness_at_cutoff(header.state_root(), 17, &params, &witness, 1)
            .expect("the witness verifies at the parent anchor");
    }

    /// Runtime discovery takes the actual parent number even when the genesis cutoff is older.
    #[tokio::test]
    async fn runtime_snapshot_is_the_supplied_parent_number() {
        let fx = Fixture::build(GenesisSpec::eligible_at_explicit_genesis_snapshot(2));
        let l1_0 = fx.genesis.l1_0;
        let witness =
            build_committee_witness(&fx.l1(), &fx.params, l1_0, 1).await.expect("parent snapshot");
        assert_eq!(witness.record.cutoff_l1_block, 64);
        assert_ne!(witness.record.cutoff_l1_block, fx.genesis.genesis_cutoff);
        let (_, members) =
            verify_committee_witness(&fx.anchor_state(&fx.l1(), l1_0), &fx.params, &witness, 1)
                .unwrap();
        assert_eq!(members.len(), 2);
    }

    /// An explicit historical snapshot is taken as is, independent of the runtime parent.
    /// The parent-anchor reads are made at the given block, and the entries at the newest block
    /// that still holds the snapshot.
    #[tokio::test]
    async fn an_explicit_cutoff_is_taken_as_is() {
        let fx = Fixture::genesis(3);
        let params = fx.params.clone();
        let (old, new) = (sample_entries(3), sample_entries(4));
        let at_61 = RegistryStorage { checkpoints: vec![(60, old.clone())] };
        let at_64 = RegistryStorage { checkpoints: vec![(60, old.clone()), (62, new)] };
        let l1 = MockL1::new(64);
        fx.plant_l1_block(&l1, 61, &fx.inbox, &at_61);
        let header = fx.plant_l1_block(&l1, 64, &fx.inbox, &at_64);

        // Cutoff 61: checkpoint 0 (block 60) is the snapshot, checkpoint 1 (block 62) follows it,
        // so the entries are read at min(64, 62 - 1) = 61.
        let witness = build_committee_witness_at_cutoff(&l1, &params, 64, 61, Schedule::E0)
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
            &params,
            &witness,
            Schedule::E0,
        )
        .expect("the witness verifies at the explicit cutoff");
        assert_eq!(record, witness.record);
    }

    /// A witness discovered at cutoff 61 is re-proved at later blocks with the checkpoint count
    /// and one proof, equal to discovering it there: at 63 checkpoint 0 is still the last, and at
    /// 64 checkpoint 1 (block 62) follows it.
    #[tokio::test]
    async fn a_reproved_witness_equals_the_discovery_at_its_block() {
        let fx = Fixture::genesis(3);
        let params = fx.params.clone();
        let (old, new) = (sample_entries(3), sample_entries(4));
        let first = RegistryStorage { checkpoints: vec![(60, old.clone())] };
        let joined = RegistryStorage { checkpoints: vec![(60, old.clone()), (62, new)] };
        let l1 = MockL1::new(64);
        fx.plant_l1_block(&l1, 61, &fx.inbox, &first);
        fx.plant_l1_block(&l1, 63, &fx.inbox, &first);
        fx.plant_l1_block(&l1, 64, &fx.inbox, &joined);
        let base = build_committee_witness_at_cutoff(&l1, &params, 61, 61, Schedule::E0)
            .await
            .expect("witness");

        for (block, has_next) in [(63, false), (64, true)] {
            l1.state().calls.clear();
            let reproved =
                reprove_committee_witness(&l1, &params, &base, block, Duration::from_secs(1))
                    .await
                    .expect("re-proved");
            assert_eq!(
                l1.calls(),
                [
                    L1Call::StorageAt {
                        address: params.registry,
                        slot: registry::length_slot(),
                        block
                    },
                    L1Call::AccountWitness {
                        address: params.registry,
                        slots: snapshot_slots(0, has_next),
                        block
                    },
                ]
            );
            let discovered =
                build_committee_witness_at_cutoff(&l1, &params, block, 61, Schedule::E0)
                    .await
                    .expect("witness");
            assert_eq!(reproved, discovered, "block {block}");
        }
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

    /// Against the fixture's L1, discovery at the genesis cutoff rebuilds exactly the genesis
    /// committee witness. Runtime-style discovery at `L1_0` instead carries its supplied parent
    /// number, while preserving the same complete entries.
    #[tokio::test]
    async fn rebuilds_the_fixture_genesis_committee_witness() {
        let fx = Fixture::genesis(3);
        let l1 = fx.l1();
        let l1_0 = fx.genesis.l1_0;
        let witness = build_committee_witness_at_cutoff(
            &l1,
            &fx.params,
            l1_0,
            fx.genesis.genesis_cutoff,
            Schedule::E0,
        )
        .await
        .expect("the fixture registry yields a witness");
        assert_eq!(witness, fx.witness.committee);

        let anchored = build_committee_witness(&l1, &fx.params, l1_0, Schedule::E0)
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
            l1_0,
            Schedule::E0,
            Duration::from_secs(1),
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
        let witness =
            build_committee_witness_within(&l1, &fx.params, 64, 1, Duration::from_secs(5))
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
            fx.genesis.l1_0,
            Schedule::E0,
            Duration::from_secs(4),
        )
        .await;
        assert_eq!(err, Err(FetchError::Timeout("registry storage read")));
    }

    /// The L1 state of a registry with one checkpoint (at L1 block 1) whose head claims `count`
    /// entries with only their canonical recipient words stored.
    fn registry_claiming(fx: &Fixture, count: u32) -> TestState {
        let head = U256::from(1u64) | (U256::from(count) << 48);
        let mut words = vec![
            (registry::length_slot(), U256::from(1u64)),
            (registry::checkpoint_slots(0)[0], head),
        ];
        // Let discovery decode a capacity-sized fixture fully before its root is rejected.
        if count <= MAX_REGISTRY_ENTRIES {
            words.extend((0..u64::from(count)).map(|i| (registry::entry_slots(i)[2], U256::ZERO)));
        }
        TestState::new(vec![(fx.params.registry, 1, U256::ZERO, B256::ZERO, words)])
    }

    /// `count` is an unproven read and `abci-genesis` has no overall deadline: a checkpoint
    /// claiming more than [`MAX_REGISTRY_ENTRIES`] entries is refused before any entry is read.
    #[tokio::test]
    async fn a_registry_count_above_the_cap_is_refused_unread() {
        let fx = Fixture::genesis(1);
        let n_p = fx.genesis.l1_0;
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
        let n_p = fx.genesis.l1_0;
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
        let err = build_committee_witness(&l1, &fx.params, fx.genesis.l1_0, 0).await;
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
        l1.state().states.insert(fx.genesis.l1_0, TestState::new(vec![registry_account]));
        let err = build_committee_witness(&l1, &fx.params, fx.genesis.l1_0, 0).await;
        assert!(matches!(err, Err(FetchError::Registry(_))), "{err:?}");
        assert_eq!(l1.calls().len(), 1, "discovery stops at the bad length");
        assert!(matches!(l1.calls()[0], L1Call::StorageAt { .. }));
    }
}

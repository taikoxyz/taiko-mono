//! Committee derivation from staking-registry snapshots (layout in
//! [`l1::layout::registry`](crate::l1::layout::registry)). No I/O.
//!
//! A committee witness proves one registry checkpoint (`checkpoints.length`, `checkpoints[i]`
//! and, when it exists, `checkpoints[i + 1].l1Block`) plus all of that checkpoint's entries.
//! [`verify_snapshot`] checks that the checkpoint is the last one at or before the cutoff and that
//! the entries hash to its `entriesRoot`; [`derive`] then applies eligibility (with the MEM-13
//! heartbeat rule of [`heartbeat_floor`]), one member per pubkey (the lowest `bondId` wins), the
//! `N_MAX` cap and the voting-power mapping to build the [`CommitteeRecord`] and its members.
//! Both are pure, so the guest can run them unchanged.
//!
//! The snapshot cutoff of epoch `e_0` is the Inbox's `genesisCutoff`; every later epoch's is
//! [`snapshot_cutoff`](crate::committee::snapshot_cutoff): the parent anchor's lagged, gridded
//! [`cutoff`](crate::committee::cutoff), floored at `genesisCutoff`. Without the floor, a
//! `genesisCutoff` above `cutoff(L1_0)` would let `e_0` derive while `e_0 + 1`, derived at `H_0`
//! from the genesis anchor `L1_0`, might find no entry active yet: a permanent halt right after
//! an irreversible activation.
//!
//! A derivation failure at `H_e` is permanent: the cutoff and the snapshot checkpoint follow from
//! the committed parent's anchor, so no block at `H_e` can ever carry a valid committee witness,
//! and only a recovery generation restarts the chain (no eligible entry, [`CommitteeError::Empty`],
//! is such a halt). Hence [`derive`] does not reject a snapshot with a duplicate pubkey, which one
//! squatting bond copying a sitting validator's key would create: it drops the later entries. The
//! registry contract must still refuse a pubkey that any non-exited entry holds (see
//! `l1::layout`); the node's rule is defence in depth.
//!
//! Every hash is `keccak256`; `abi.encode` of static types is the concatenation of 32-byte
//! big-endian words, and `bytes32` domain tags are right-padded ASCII.

use std::collections::BTreeMap;

use alloy_primitives::{Address, B256, U256, keccak256, ruint::UintTryFrom};

use crate::{
    config::ChainParams,
    envelope::CommitteeWitness,
    l1::{
        layout::{registry, word_u32, word_u64},
        mpt::{MptError, verify_account_witness},
    },
    schedule::Schedule,
    types::{AnchorState, CommitteeRecord, Member, RegistryEntry},
};

/// The committee record `encodingVersion` this crate derives.
pub const ENCODING_VERSION: u8 = 1;

/// Upper bound on a committee's total voting power: CometBFT's `MaxTotalVotingPower`,
/// `(2^63 − 1) / 8`.
pub const MAX_TOTAL_POWER: u64 = (i64::MAX as u64) / 8;

/// `LOOKAHEAD_EPOCHS` of #22262 (normative, not tunable): MEM-13 evaluates the heartbeats of
/// epoch `e`'s committee at the start of the L1-side epoch `e − LOOKAHEAD_EPOCHS`.
pub const LOOKAHEAD_EPOCHS: u64 = 2;

/// `bytes32("ETNA_REG_ENTRY")`: domain tag of registry entry leaves.
const REG_ENTRY_TAG: B256 = tag(b"ETNA_REG_ENTRY");
/// `bytes32("ETNA_SET_KEY")`: domain tag of the MEM-08 member sort key.
const SET_KEY_TAG: B256 = tag(b"ETNA_SET_KEY");
/// `bytes32("ETNA_SET_LEAF")`: domain tag of MEM-08 set leaves.
const SET_LEAF_TAG: B256 = tag(b"ETNA_SET_LEAF");
/// `bytes32("ETNA_SET_NODE")`: domain tag of MEM-08 inner nodes.
const SET_NODE_TAG: B256 = tag(b"ETNA_SET_NODE");
/// `bytes32("ETNA_COMMITTEE_V1")`: domain tag of the committee record hash.
const RECORD_TAG: B256 = tag(b"ETNA_COMMITTEE_V1");

/// Why a committee witness, snapshot or derivation was rejected.
#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum CommitteeError {
    /// The witness proves an account other than the configured staking registry.
    #[error("witness proves {got}, expected the registry at {expected}")]
    WrongContract {
        /// The configured registry address (chain constant).
        expected: Address,
        /// The address the witness proves.
        got: Address,
    },
    /// The account or storage proofs do not verify, or prove the wrong slot set.
    #[error(transparent)]
    Mpt(#[from] MptError),
    /// The cutoff grid `G` is zero.
    #[error("cutoff grid must be >= 1")]
    ZeroCutoffGrid,
    /// The parent's anchor number is below the cutoff lag, so no lagged cutoff exists
    /// ([`cutoff`] only: [`snapshot_cutoff`] then takes the genesis cutoff).
    #[error("parent anchor {parent_anchor} is below the cutoff lag {lag}")]
    AnchorBelowLag {
        /// The parent block's anchor L1 block number `n_p`.
        parent_anchor: u64,
        /// The configured cutoff lag `LAG`, in L1 blocks.
        lag: u64,
    },
    /// The claimed checkpoint index is not below `checkpoints.length`.
    #[error("checkpoint {index} does not exist (registry holds {length})")]
    CheckpointOutOfRange {
        /// The claimed checkpoint index (`record.checkpoint_index`).
        index: u64,
        /// The proven `checkpoints.length`.
        length: U256,
    },
    /// The witness proves `checkpoints[index + 1]` although it does not exist, or omits it
    /// although it does.
    #[error(
        "checkpoint {index} of {length}: next-checkpoint proof present = {proven}, \
         but a next checkpoint exists = {}",
        !proven
    )]
    NextCheckpointMismatch {
        /// The claimed checkpoint index.
        index: u64,
        /// The proven `checkpoints.length`.
        length: U256,
        /// Whether the witness carries the next checkpoint's proof.
        proven: bool,
    },
    /// The claimed checkpoint was written after the cutoff.
    #[error("checkpoint at L1 block {l1_block} is after the cutoff {cutoff}")]
    CheckpointAfterCutoff {
        /// The checkpoint's `l1Block`.
        l1_block: u64,
        /// The cutoff `C`, an L1 block number.
        cutoff: u64,
    },
    /// The next checkpoint was written at or before the cutoff, so the claimed one is not the
    /// last checkpoint with `l1Block <= C`.
    #[error("next checkpoint at L1 block {l1_block} is not after the cutoff {cutoff}")]
    NextCheckpointNotAfterCutoff {
        /// The next checkpoint's `l1Block`.
        l1_block: u64,
        /// The cutoff `C`, an L1 block number.
        cutoff: u64,
    },
    /// The witness carries a different number of entries than the checkpoint's `count`.
    #[error("checkpoint holds {expected} entries, witness carries {got}")]
    EntryCountMismatch {
        /// The proven `count`.
        expected: u32,
        /// The number of entries in the witness.
        got: usize,
    },
    /// The witnessed entries do not hash to the checkpoint's `entriesRoot`.
    #[error("entries hash to {got}, checkpoint entriesRoot is {expected}")]
    EntriesRootMismatch {
        /// The proven `entriesRoot`.
        expected: B256,
        /// [`entries_root`] of the witnessed entries.
        got: B256,
    },
    /// `VP_UNIT` is zero, so voting power is undefined.
    #[error("vp_unit must be > 0")]
    ZeroVpUnit,
    /// `HEARTBEAT_WINDOW` is zero, so the heartbeat windows of a filtered epoch are undefined.
    #[error("heartbeat window must be >= 1")]
    ZeroHeartbeatWindow,
    /// The target epoch has no MEM-08 `k = targetEpoch − e_0 + 1` in `u64`, or its heartbeat
    /// evaluation block `L1_first(targetEpoch − LOOKAHEAD_EPOCHS)` overflows `u64`.
    #[error("target epoch {0} is out of range")]
    EpochOutOfRange(u64),
    /// No entry is eligible. At `H_e` this halts the chain for good (the snapshot is fixed by
    /// the committed parent's anchor) until a recovery generation restarts it.
    #[error("no eligible registry entry")]
    Empty,
    /// A member's voting power `effStake / VP_UNIT` does not fit `u64`.
    #[error("voting power of {pubkey} does not fit u64")]
    PowerOverflow {
        /// The member's consensus public key.
        pubkey: B256,
    },
    /// The committee's total voting power exceeds [`MAX_TOTAL_POWER`].
    #[error("total voting power {total} exceeds {MAX_TOTAL_POWER}")]
    TotalPowerTooLarge {
        /// The total voting power (saturating at `u128::MAX`).
        total: u128,
    },
    /// The committee's total effective stake overflows `uint256`.
    #[error("total stake overflows uint256")]
    TotalStakeOverflow,
    /// The record the witness claims differs from the one derived from the snapshot.
    #[error("claimed committee record {claimed:?} differs from the derived {derived:?}")]
    RecordMismatch {
        /// The record carried by the witness.
        claimed: Box<CommitteeRecord>,
        /// The record derived from the proven snapshot.
        derived: Box<CommitteeRecord>,
    },
}

/// A verified registry snapshot: one checkpoint and all of its entries.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Snapshot {
    /// Index `i` of the checkpoint in `checkpoints[]`.
    pub checkpoint_index: u64,
    /// The checkpoint's `l1Block`: the L1 block whose entry changes it captures.
    pub l1_block: u64,
    /// The checkpoint's entries, in index (`bondId`) order.
    pub entries: Vec<RegistryEntry>,
}

/// The registry `entriesRoot` over `entries`.
///
/// Leaf `i` = `keccak256(abi.encode(bytes32("ETNA_REG_ENTRY"), uint256(i), bytes32 pubkey,
/// uint256 effStake, uint64 activeFromL1, uint64 exitEffectiveL1, uint64 lastHeartbeatAt,
/// uint64 lastHeartbeatSeq))`;
/// the leaves are padded with `bytes32(0)` to the next power of two and hashed pairwise
/// (`keccak256(left ‖ right)`). One entry gives its leaf; no entries give `bytes32(0)`.
pub fn entries_root(entries: &[RegistryEntry]) -> B256 {
    if entries.is_empty() {
        return B256::ZERO;
    }
    let mut level: Vec<B256> = entries.iter().enumerate().map(|(i, e)| entry_leaf(i, e)).collect();
    level.resize(level.len().next_power_of_two(), B256::ZERO);
    while level.len() > 1 {
        level = level.chunks_exact(2).map(|pair| keccak256([pair[0], pair[1]].concat())).collect();
    }
    level[0]
}

/// The MEM-08 sort key of `pubkey`:
/// `keccak256(abi.encode(bytes32("ETNA_SET_KEY"), uint256 chainId, bytes32 pubkey))`.
///
/// `l2_chain_id` is the L2 EVM chain id, which unlike the CometBFT `chain_id` does not change
/// with the recovery generation.
pub fn mem08_key(l2_chain_id: u64, pubkey: B256) -> B256 {
    keccak256([SET_KEY_TAG, word(l2_chain_id), pubkey].concat())
}

/// The MEM-08 set root over `members` (#22262), with `chainId` = the L2 EVM chain id.
///
/// `members` must already be sorted by [`mem08_key`] ascending (checked in debug builds). Leaf
/// `index` = `keccak256(abi.encode(bytes32("ETNA_SET_LEAF"), uint256 chainId, uint256 k,
/// uint256 index, bytes32 pubkey, uint256 effStake))`; inner node =
/// `keccak256(abi.encode(bytes32("ETNA_SET_NODE"), uint256 chainId, uint256 k, bytes32 left,
/// bytes32 right))`. Each level pairs nodes left to right and promotes an odd last node
/// unchanged. One member gives its leaf; no members give `bytes32(0)` (never a valid committee).
pub fn mem08_root(l2_chain_id: u64, k: u64, members: &[Member]) -> B256 {
    debug_assert!(
        members
            .windows(2)
            .all(|w| mem08_key(l2_chain_id, w[0].pubkey) < mem08_key(l2_chain_id, w[1].pubkey)),
        "members must be sorted by MEM-08 key without duplicates"
    );
    if members.is_empty() {
        return B256::ZERO;
    }
    let mut level: Vec<B256> =
        members.iter().enumerate().map(|(i, m)| set_leaf(l2_chain_id, k, i, m)).collect();
    while level.len() > 1 {
        level = level
            .chunks(2)
            .map(|chunk| match chunk {
                [left, right] => set_node(l2_chain_id, k, *left, *right),
                [odd] => *odd,
                _ => unreachable!("chunks(2) yields one or two nodes"),
            })
            .collect();
    }
    level[0]
}

/// The committee record hash stored at `committee[targetEpoch]` on L1:
/// `keccak256(abi.encode(bytes32("ETNA_COMMITTEE_V1"), uint256 l2ChainId, uint64 targetEpoch,
/// uint64 cutoffL1Block, uint64 checkpointIndex, bytes32 setRoot, uint256 totalStake,
/// uint64 totalPower, uint8 encodingVersion))`.
pub fn record_hash(l2_chain_id: u64, r: &CommitteeRecord) -> B256 {
    keccak256(
        [
            RECORD_TAG,
            word(l2_chain_id),
            word(r.target_epoch),
            word(r.cutoff_l1_block),
            word(r.checkpoint_index),
            r.set_root,
            word(r.total_stake),
            word(r.total_power),
            word(r.encoding_version),
        ]
        .concat(),
    )
}

/// The snapshot cutoff `C = grid · floor((parent_anchor − lag) / grid)`.
///
/// `parent_anchor` is the parent block's anchor L1 block number `n_p`. Rejects `grid == 0` and
/// `parent_anchor < lag`.
pub fn cutoff(parent_anchor: u64, grid: u64, lag: u64) -> Result<u64, CommitteeError> {
    if grid == 0 {
        return Err(CommitteeError::ZeroCutoffGrid);
    }
    let lagged = parent_anchor
        .checked_sub(lag)
        .ok_or(CommitteeError::AnchorBelowLag { parent_anchor, lag })?;
    Ok(lagged / grid * grid)
}

/// The snapshot cutoff of a committee for a target epoch after `e_0`, derived at a height whose
/// parent anchors at `parent_anchor`: `max(cutoff(parent_anchor), schedule.genesis_cutoff)`, with
/// `params`' grid and lag ([`cutoff`]). A parent anchor below the lag has no lagged cutoff, so the
/// floor alone stands: `schedule.genesis_cutoff`. Rejects only `grid == 0`.
///
/// The floor keeps every later snapshot at or after the genesis committee's: `e_0 + 1` is derived
/// at `H_0` from the genesis anchor `L1_0`, whose lagged cutoff may precede `genesisCutoff`, so
/// without it entries active at `genesisCutoff` could be missing from `e_0 + 1`. Every parent
/// anchor is at or after `L1_0 > genesisCutoff`, so the snapshot is always provable at it. `e_0`
/// itself is derived at `genesisCutoff` exactly ([`verify_committee_witness_at_cutoff`]).
pub fn snapshot_cutoff(
    parent_anchor: u64,
    schedule: &Schedule,
    params: &ChainParams,
) -> Result<u64, CommitteeError> {
    match cutoff(parent_anchor, params.cutoff_grid, params.cutoff_lag) {
        Ok(lagged) => Ok(lagged.max(schedule.genesis_cutoff)),
        Err(CommitteeError::AnchorBelowLag { .. }) => Ok(schedule.genesis_cutoff),
        Err(err) => Err(err),
    }
}

/// The registry slots a committee witness for checkpoint `i` proves, in this order:
/// `[checkpoints.length, checkpoints[i] word 0, checkpoints[i] word 1]`, followed by
/// `checkpoints[i + 1]` word 0 when `has_next`.
///
/// The next checkpoint's slot is computed as `checkpoints[i]` word 1 plus one in `U256`, so
/// `i = u64::MAX` does not overflow.
pub fn snapshot_slots(i: u64, has_next: bool) -> Vec<B256> {
    let [head, root] = registry::checkpoint_slots(i);
    let mut slots = vec![registry::length_slot(), head, root];
    if has_next {
        // checkpoint_slots(i + 1)[0] = data + 2(i + 1) = checkpoint_slots(i)[1] + 1.
        slots.push(B256::from(U256::from_be_bytes(root.0).wrapping_add(U256::from(1))));
    }
    slots
}

/// Verifies the registry snapshot carried by `w` against the L1 `state_root`.
///
/// The claimed checkpoint is `i = w.record.checkpoint_index`; the witness proves the next
/// checkpoint iff it carries four storage proofs. Checks, in order: the witness proves the
/// account at `registry`; its proofs verify for [`snapshot_slots`]`(i, has_next)`;
/// `i < length`; the next-checkpoint proof is present iff `i + 1 < length`;
/// `checkpoints[i].l1Block <= cutoff`; `checkpoints[i + 1].l1Block > cutoff` when present; the
/// witness carries exactly `count` entries; and they hash to `entriesRoot`. Does not look at the
/// rest of `w.record`.
pub fn verify_snapshot(
    state_root: B256,
    registry: Address,
    w: &CommitteeWitness,
    cutoff: u64,
) -> Result<Snapshot, CommitteeError> {
    if w.registry.address != registry {
        return Err(CommitteeError::WrongContract { expected: registry, got: w.registry.address });
    }
    let index = w.record.checkpoint_index;
    let has_next = w.registry.storage.len() == 4;
    let slots = snapshot_slots(index, has_next);
    let storage = verify_account_witness(state_root, &w.registry, &slots)?;
    // `verify_account_witness` succeeds only if the witness proves exactly `slots`.
    let value = |slot: B256| storage.get(slot).expect("slot belongs to the verified slot set");

    let length = value(slots[0]);
    let position = U256::from(index);
    if position >= length {
        return Err(CommitteeError::CheckpointOutOfRange { index, length });
    }
    if has_next != (position + U256::from(1) < length) {
        return Err(CommitteeError::NextCheckpointMismatch { index, length, proven: has_next });
    }

    let head = value(slots[1]);
    let l1_block = word_u64(head, 0);
    let count = word_u32(head, 64);
    if l1_block > cutoff {
        return Err(CommitteeError::CheckpointAfterCutoff { l1_block, cutoff });
    }
    if has_next {
        let next = word_u64(value(slots[3]), 0);
        if next <= cutoff {
            return Err(CommitteeError::NextCheckpointNotAfterCutoff { l1_block: next, cutoff });
        }
    }

    if w.entries.len() != count as usize {
        return Err(CommitteeError::EntryCountMismatch { expected: count, got: w.entries.len() });
    }
    let expected = B256::from(value(slots[2]));
    let got = entries_root(&w.entries);
    if got != expected {
        return Err(CommitteeError::EntriesRootMismatch { expected, got });
    }
    Ok(Snapshot { checkpoint_index: index, l1_block, entries: w.entries.clone() })
}

/// The heartbeat requirement of `target_epoch`'s committee derived at `cutoff` (MEM-13(3) of
/// #22262): `None` when the epoch's roster is not filtered by heartbeats, else the floor `f`. An
/// entry of a filtered epoch is eligible only with a heartbeat (`lastHeartbeatSeq > 0`) and
/// `lastHeartbeatAt >= f`.
///
/// With `W = HEARTBEAT_WINDOW`, the evaluation instant is
/// `I*(e) = floor(L1_first(e − LOOKAHEAD_EPOCHS) / W) · W`, the start of the window holding the
/// first L1 block of the L1-side epoch `e − 2`, and `f = I*(e) − W`: the last heartbeat must
/// name that window, the one before it or a later one, so an entry that attests once per window
/// is always eligible. The instant follows from the activation schedule and the target epoch
/// alone; the cutoff, which the parent block's proposer moves by choosing its anchor, does not
/// set it.
///
/// Two adaptations to in-consensus derivation, where the parent's anchor fixes the snapshot and a
/// derivation that leaves no entry eligible halts the chain for good:
/// - Epochs up to `e_0 + LOOKAHEAD_EPOCHS` are not filtered: `e_0` by CONS-14, and the launch
///   epochs `e_0 + 1` and `e_0 + 2`. The spec shifts their instant two windows past `L1_0` and
///   forbids appending their sets before then, but here `e_0 + 1` is derived at `H_0` from the
///   registry snapshot at the floored cutoff of `L1_0` ([`snapshot_cutoff`], before `L1_0`), proven
///   at the activation block `L1_0` (the genesis anchor), so the shifted instant could never be
///   met, and any filter on it would need the pre-activation heartbeats CONS-14 does not rely on.
/// - The instant is capped at the start of the window holding the cutoff, as the snapshot holds no
///   later heartbeat. Every block of epoch `e − 2`, the parent of the height deriving `e` included,
///   anchors at or after `L1_first(e − 2)`, so the cap binds only when the cutoff's lag and grid
///   put it before `I*(e)`, and it only lowers the floor.
///
/// Errors: [`CommitteeError::ZeroHeartbeatWindow`] for a filtered epoch with `W = 0`;
/// [`CommitteeError::EpochOutOfRange`] when `L1_first(e − 2)` overflows `u64`.
pub fn heartbeat_floor(
    schedule: &Schedule,
    heartbeat_window: u64,
    target_epoch: u64,
    cutoff: u64,
) -> Result<Option<u64>, CommitteeError> {
    let Some(instant_epoch) =
        target_epoch.checked_sub(LOOKAHEAD_EPOCHS).filter(|e| *e > Schedule::E0)
    else {
        return Ok(None);
    };
    if heartbeat_window == 0 {
        return Err(CommitteeError::ZeroHeartbeatWindow);
    }
    let l1_first = schedule
        .checked_l1_first(instant_epoch)
        .ok_or(CommitteeError::EpochOutOfRange(target_epoch))?;
    let window_start = |n: u64| n - n % heartbeat_window;
    let instant = window_start(l1_first).min(window_start(cutoff));
    Ok(Some(instant.saturating_sub(heartbeat_window)))
}

/// Derives the committee for `target_epoch` from a verified `snapshot` at `cutoff` and returns its
/// record and members (sorted by [`mem08_key`]).
///
/// An entry is eligible iff `active_from_l1 <= cutoff < exit_effective_l1`,
/// `eff_stake >= max(s_min, vp_unit)` and, when [`heartbeat_floor`] filters the epoch,
/// `last_heartbeat_seq > 0` and `last_heartbeat_at >=` the floor. Among eligible entries that
/// share a pubkey only the one with the lowest `bondId` (index in the snapshot, i.e. the earliest
/// registration) is kept: a later entry copying a sitting validator's key changes nothing
/// (defence in depth; the registry must refuse such a registration, see the module docs). If
/// more than `n_max` remain, the first `n_max` by (`eff_stake` descending, MEM-08 key ascending)
/// are kept. Each member's power is `eff_stake / vp_unit`; the total must not exceed
/// [`MAX_TOTAL_POWER`]. No eligible entry is [`CommitteeError::Empty`].
pub fn derive(
    snapshot: &Snapshot,
    cutoff: u64,
    target_epoch: u64,
    schedule: &Schedule,
    params: &ChainParams,
) -> Result<(CommitteeRecord, Vec<Member>), CommitteeError> {
    if params.vp_unit.is_zero() {
        return Err(CommitteeError::ZeroVpUnit);
    }
    let k = target_epoch
        .checked_sub(Schedule::E0)
        .and_then(|d| d.checked_add(1))
        .ok_or(CommitteeError::EpochOutOfRange(target_epoch))?;
    let min_stake = params.s_min.max(params.vp_unit);
    let floor = heartbeat_floor(schedule, params.heartbeat_window, target_epoch, cutoff)?;

    // `(MEM-08 key, bondId, entry)`; `bondId` is the entry's index in the snapshot.
    let mut eligible: Vec<(B256, usize, &RegistryEntry)> = snapshot
        .entries
        .iter()
        .enumerate()
        .filter(|(_, e)| is_eligible(e, cutoff, min_stake, floor))
        .map(|(bond_id, e)| (mem08_key(params.l2_chain_id, e.pubkey), bond_id, e))
        .collect();
    // Equal pubkeys have equal keys, so after the sort the entries of one pubkey are adjacent,
    // lowest bondId first, and `dedup_by_key` keeps exactly that one.
    eligible.sort_by_key(|(key, bond_id, _)| (*key, *bond_id));
    eligible.dedup_by_key(|(key, _, _)| *key);
    let mut eligible: Vec<(B256, &RegistryEntry)> =
        eligible.into_iter().map(|(key, _, e)| (key, e)).collect();
    if eligible.len() > params.n_max {
        eligible.sort_by(|a, b| b.1.eff_stake.cmp(&a.1.eff_stake).then(a.0.cmp(&b.0)));
        eligible.truncate(params.n_max);
        eligible.sort_by_key(|(key, _)| *key);
    }
    if eligible.is_empty() {
        return Err(CommitteeError::Empty);
    }

    let members = eligible
        .iter()
        .map(|(_, e)| {
            let power = u64::try_from(e.eff_stake / params.vp_unit)
                .map_err(|_| CommitteeError::PowerOverflow { pubkey: e.pubkey })?;
            Ok(Member { pubkey: e.pubkey, eff_stake: e.eff_stake, power })
        })
        .collect::<Result<Vec<_>, CommitteeError>>()?;

    let total = members.iter().fold(0u128, |acc, m| acc.saturating_add(u128::from(m.power)));
    let total_power = u64::try_from(total)
        .ok()
        .filter(|t| *t <= MAX_TOTAL_POWER)
        .ok_or(CommitteeError::TotalPowerTooLarge { total })?;
    let total_stake = members
        .iter()
        .try_fold(U256::ZERO, |acc, m| acc.checked_add(m.eff_stake))
        .ok_or(CommitteeError::TotalStakeOverflow)?;

    let record = CommitteeRecord {
        target_epoch,
        cutoff_l1_block: cutoff,
        checkpoint_index: snapshot.checkpoint_index,
        set_root: mem08_root(params.l2_chain_id, k, &members),
        total_stake,
        total_power,
        encoding_version: ENCODING_VERSION,
    };
    Ok((record, members))
}

/// Verifies a committee witness for a target epoch after `e_0` end to end against the parent's
/// anchor and returns the committee it proves.
///
/// The anchor binds the two facts the witness depends on: the cutoff comes from its L1 block
/// number with `params`' grid and lag, floored at `schedule.genesis_cutoff`
/// ([`snapshot_cutoff`]), and the snapshot proofs verify against its state root. The rest is
/// [`verify_committee_witness_at_cutoff`].
pub fn verify_committee_witness(
    parent_anchor: &AnchorState,
    schedule: &Schedule,
    params: &ChainParams,
    w: &CommitteeWitness,
    target_epoch: u64,
) -> Result<(CommitteeRecord, Vec<Member>), CommitteeError> {
    let c = snapshot_cutoff(parent_anchor.number, schedule, params)?;
    verify_committee_witness_at_cutoff(
        parent_anchor.state_root,
        c,
        schedule,
        params,
        w,
        target_epoch,
    )
}

/// Verifies a committee witness whose snapshot is taken at the given `cutoff`, with its proofs
/// against the L1 `state_root`, and returns the committee it proves.
///
/// The snapshot proofs verify against `state_root` and `params.registry` ([`verify_snapshot`]
/// with `cutoff` as is: no lag, no grid). Then derives the committee for `target_epoch` under
/// `schedule` at `cutoff` ([`derive`], so the record's `cutoff_l1_block` is `cutoff`) and
/// requires the derived record to equal `w.record` ([`CommitteeError::RecordMismatch`]
/// otherwise).
///
/// Precondition: `cutoff` is at or before the L1 block whose `state_root` the proofs verify
/// against (the proving block). Only then is the snapshot final: a checkpoint written after the
/// proving block but at or before `cutoff` would change it, and the proofs cannot show it.
///
/// Every epoch after `e_0` goes through [`verify_committee_witness`], which takes the cutoff from
/// the parent's anchor ([`snapshot_cutoff`]). The genesis committee `e_0` is verified here
/// directly, with the Inbox's `genesisCutoff` against the `L1_0` header's state root: the
/// activation names that cutoff explicitly, as `L1_0` is unknown when the DAO proposal that
/// activates Etna is written.
pub fn verify_committee_witness_at_cutoff(
    state_root: B256,
    cutoff: u64,
    schedule: &Schedule,
    params: &ChainParams,
    w: &CommitteeWitness,
    target_epoch: u64,
) -> Result<(CommitteeRecord, Vec<Member>), CommitteeError> {
    let snapshot = verify_snapshot(state_root, params.registry, w, cutoff)?;
    let (record, members) = derive(&snapshot, cutoff, target_epoch, schedule, params)?;
    if record != w.record {
        return Err(CommitteeError::RecordMismatch {
            claimed: Box::new(w.record.clone()),
            derived: Box::new(record),
        });
    }
    Ok((record, members))
}

/// The CometBFT validator updates that switch from committee `old` to committee `new`.
///
/// Every pubkey of `old` absent from `new` gets power 0 and every member of `new` gets its
/// power (unchanged members are restated). The result is sorted by pubkey without duplicates.
pub fn validator_updates(old: &[Member], new: &[Member]) -> Vec<(B256, u64)> {
    let mut updates: BTreeMap<B256, u64> = old.iter().map(|m| (m.pubkey, 0)).collect();
    updates.extend(new.iter().map(|m| (m.pubkey, m.power)));
    updates.into_iter().collect()
}

/// Whether `e` is eligible at `cutoff`: active, staked at least `min_stake` and, when the epoch is
/// filtered (`floor` from [`heartbeat_floor`]), with a heartbeat at or after the floor.
fn is_eligible(e: &RegistryEntry, cutoff: u64, min_stake: U256, floor: Option<u64>) -> bool {
    e.active_from_l1 <= cutoff &&
        cutoff < e.exit_effective_l1 &&
        e.eff_stake >= min_stake &&
        floor.is_none_or(|floor| e.last_heartbeat_seq > 0 && e.last_heartbeat_at >= floor)
}

/// The registry leaf of entry `index` (see [`entries_root`]).
fn entry_leaf(index: usize, e: &RegistryEntry) -> B256 {
    keccak256(
        [
            REG_ENTRY_TAG,
            word(index),
            e.pubkey,
            word(e.eff_stake),
            word(e.active_from_l1),
            word(e.exit_effective_l1),
            word(e.last_heartbeat_at),
            word(e.last_heartbeat_seq),
        ]
        .concat(),
    )
}

/// The MEM-08 leaf of the member at sorted position `index` (see [`mem08_root`]).
fn set_leaf(l2_chain_id: u64, k: u64, index: usize, m: &Member) -> B256 {
    keccak256(
        [SET_LEAF_TAG, word(l2_chain_id), word(k), word(index), m.pubkey, word(m.eff_stake)]
            .concat(),
    )
}

/// A MEM-08 inner node over `left` and `right` (see [`mem08_root`]).
fn set_node(l2_chain_id: u64, k: u64, left: B256, right: B256) -> B256 {
    keccak256([SET_NODE_TAG, word(l2_chain_id), word(k), left, right].concat())
}

/// One `abi.encode` word: the unsigned integer `value` left-padded to 32 bytes, big-endian.
fn word<T>(value: T) -> B256
where
    U256: UintTryFrom<T>,
{
    B256::from(U256::from(value))
}

/// A `bytes32` domain tag: the ASCII `name`, right-padded with zero bytes (at most 32 bytes).
const fn tag(name: &[u8]) -> B256 {
    let mut out = [0u8; 32];
    let mut i = 0;
    while i < name.len() {
        out[i] = name[i];
        i += 1;
    }
    B256::new(out)
}

#[cfg(test)]
mod tests;

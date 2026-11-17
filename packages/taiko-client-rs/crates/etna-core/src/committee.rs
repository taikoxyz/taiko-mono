//! Direct committee derivation from a complete authenticated registry snapshot.
//!
//! V1 uses compressed secp256k1eth keys, stake eligibility and deterministic top-N selection.
//! Snapshot cutoff and proving root are separate: runtime switches use D(t)'s committed anchor
//! as cutoff and S(t)'s own anchor root for the proof. No heartbeat or payout metadata
//! participates.

use crate::{
    key::ConsensusKey,
    params::ChainParams,
    registry::{self, word_u48},
    schedule::Schedule,
    types::{CommitteeRecord, Member, RegistryEntry},
};
use alloc::{boxed::Box, collections::BTreeMap, vec, vec::Vec};
use alloy_primitives::{Address, B256, U256, keccak256, ruint::UintTryFrom};
use core::convert::Infallible;

/// Upper bound on a committee's total voting power: CometBFT's `MaxTotalVotingPower`,
/// `(2^63 − 1) / 8`.
pub const MAX_TOTAL_POWER: u64 = (i64::MAX as u64) / 8;

/// `bytes32("ETNA_REG_ENTRY_V1")`: domain tag of registry entry leaves.
const REG_ENTRY_TAG: B256 = tag(b"ETNA_REG_ENTRY_V1");
/// `bytes32("ETNA_SET_KEY_V1")`: domain tag of the member sort key ([`set_key`]).
const SET_KEY_TAG: B256 = tag(b"ETNA_SET_KEY_V1");
/// `bytes32("ETNA_SET_LEAF_V1")`: domain tag of set-root leaves.
const SET_LEAF_TAG: B256 = tag(b"ETNA_SET_LEAF_V1");
/// `bytes32("ETNA_SET_NODE")`: domain tag of set-root inner nodes.
const SET_NODE_TAG: B256 = tag(b"ETNA_SET_NODE");
/// `bytes32("ETNA_COMMITTEE_V1")`: domain tag of the committee record hash.
const RECORD_TAG: B256 = tag(b"ETNA_COMMITTEE_V1");

/// Why a committee witness, snapshot or derivation was rejected.
#[derive(Clone, Debug, thiserror::Error, PartialEq, Eq)]
pub enum CommitteeError<E = Infallible> {
    /// An eligible entry carries an invalid consensus key.
    #[error(transparent)]
    Key(#[from] crate::key::KeyError),
    /// Multiple eligible entries carry the same consensus identity.
    #[error("duplicate eligible consensus key")]
    DuplicateKey,
    /// The proving anchor is too early to authenticate the explicit historical snapshot.
    #[error("snapshot cutoff {cutoff} is after proving anchor {anchor}")]
    CutoffAfterAnchor {
        /// Required explicit L1 snapshot cutoff.
        cutoff: u64,
        /// Proving L1 block number.
        anchor: u64,
    },
    /// The witness proves an account other than the configured staking registry.
    #[error("witness proves {got}, expected the registry at {expected}")]
    WrongContract {
        /// The configured registry address (chain constant).
        expected: Address,
        /// The address the witness proves.
        got: Address,
    },
    /// Backend authentication failed; legacy spelling preserves native error matching.
    #[error(transparent)]
    Mpt(E),
    /// Adapter returned a different word count than the exact requested slot list.
    #[error("authenticated storage returned {got} words, expected {expected}")]
    AuthenticatedWordCountMismatch {
        /// Number of canonical slots requested.
        expected: usize,
        /// Number of authenticated words returned.
        got: usize,
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
        expected: u64,
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
    /// The target epoch has no set version `k = targetEpoch − e_0 + 1` in `u64`.
    #[error("target epoch {0} is out of range")]
    EpochOutOfRange(u64),
    /// No entry is eligible at the immutable snapshot. Activation cannot advance its cutoff or
    /// silently reuse an old committee; recovery requires a new generation.
    #[error("no eligible registry entry")]
    Empty,
    /// A saved member's stake is below the configured eligibility floor.
    #[error("stake of {pubkey} is below the eligibility floor")]
    IneligibleStake {
        /// The member's consensus public key.
        pubkey: ConsensusKey,
    },
    /// A member's voting power `effStake / VP_UNIT` does not fit `u64`.
    #[error("voting power of {pubkey} does not fit u64")]
    PowerOverflow {
        /// The member's consensus public key.
        pubkey: ConsensusKey,
    },
    /// The committee's total voting power exceeds [`MAX_TOTAL_POWER`].
    #[error("total voting power {total} exceeds {MAX_TOTAL_POWER}")]
    TotalPowerTooLarge {
        /// The total voting power (saturating at `u128::MAX` on arithmetic overflow).
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
    /// A host-cached verified witness was offered for a root, cutoff or target epoch other than the
    /// one it was verified for; it is refused, never verified again there.
    #[error(
        "witness was not verified under root {root} at cutoff {cutoff} for epoch {target_epoch}"
    )]
    NotVerifiedUnder {
        /// The L1 state root the witness was required under.
        root: B256,
        /// The snapshot cutoff it was required at.
        cutoff: u64,
        /// The target epoch it was required for.
        target_epoch: u64,
    },
}

impl CommitteeError {
    /// Lifts a pure consensus failure into a verifier's backend-specific error channel.
    pub fn with_backend_error<E>(self) -> CommitteeError<E> {
        match self {
            CommitteeError::Mpt(never) => match never {},
            CommitteeError::Key(value) => CommitteeError::Key(value),
            CommitteeError::DuplicateKey => CommitteeError::DuplicateKey,
            CommitteeError::CutoffAfterAnchor { cutoff, anchor } => {
                CommitteeError::CutoffAfterAnchor { cutoff, anchor }
            }
            CommitteeError::WrongContract { expected, got } => {
                CommitteeError::WrongContract { expected, got }
            }
            CommitteeError::AuthenticatedWordCountMismatch { expected, got } => {
                CommitteeError::AuthenticatedWordCountMismatch { expected, got }
            }
            CommitteeError::CheckpointOutOfRange { index, length } => {
                CommitteeError::CheckpointOutOfRange { index, length }
            }
            CommitteeError::NextCheckpointMismatch { index, length, proven } => {
                CommitteeError::NextCheckpointMismatch { index, length, proven }
            }
            CommitteeError::CheckpointAfterCutoff { l1_block, cutoff } => {
                CommitteeError::CheckpointAfterCutoff { l1_block, cutoff }
            }
            CommitteeError::NextCheckpointNotAfterCutoff { l1_block, cutoff } => {
                CommitteeError::NextCheckpointNotAfterCutoff { l1_block, cutoff }
            }
            CommitteeError::EntryCountMismatch { expected, got } => {
                CommitteeError::EntryCountMismatch { expected, got }
            }
            CommitteeError::EntriesRootMismatch { expected, got } => {
                CommitteeError::EntriesRootMismatch { expected, got }
            }
            CommitteeError::ZeroVpUnit => CommitteeError::ZeroVpUnit,
            CommitteeError::EpochOutOfRange(value) => CommitteeError::EpochOutOfRange(value),
            CommitteeError::Empty => CommitteeError::Empty,
            CommitteeError::IneligibleStake { pubkey } => {
                CommitteeError::IneligibleStake { pubkey }
            }
            CommitteeError::PowerOverflow { pubkey } => CommitteeError::PowerOverflow { pubkey },
            CommitteeError::TotalPowerTooLarge { total } => {
                CommitteeError::TotalPowerTooLarge { total }
            }
            CommitteeError::TotalStakeOverflow => CommitteeError::TotalStakeOverflow,
            CommitteeError::RecordMismatch { claimed, derived } => {
                CommitteeError::RecordMismatch { claimed, derived }
            }
            CommitteeError::NotVerifiedUnder { root, cutoff, target_epoch } => {
                CommitteeError::NotVerifiedUnder { root, cutoff, target_epoch }
            }
        }
    }
}

/// Authenticates exact registry storage reads under the requested L1 state root.
/// Implementations bind the actual account address and its storage root to `state_root`,
/// authenticate every requested slot in order, and fail on unavailable or malformed evidence.
/// Zero denotes proven absence only; missing witness data must fail. No snapshot selection,
/// entry validation or committee derivation belongs in the backend.
pub trait RegistryProof {
    /// Native authentication failure, retained intact by the committee verifier.
    type Error;
    /// Account address carried by the actual supplied evidence, not configured expectations.
    fn address(&self) -> Address;
    /// Actual storage-proof count; the verifier checks the successor hint against proven length.
    fn storage_proof_count(&self) -> usize;
    /// Authenticates all `expected_slots` and returns exactly one word per slot in that order.
    fn authenticate_storage(
        &self,
        state_root: B256,
        expected_slots: &[B256],
    ) -> Result<Vec<U256>, Self::Error>;
}

/// Snapshot data; authentication is established only by the high-level verifier.
/// Discovery may construct this data before authentication; `derive` alone authenticates nothing.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Snapshot {
    /// Index `i` of the checkpoint in `checkpoints[]`.
    pub checkpoint_index: u64,
    /// The checkpoint's `l1Block`: the L1 block whose entry changes it captures.
    pub l1_block: u64,
    /// The checkpoint's entries, in index (`slot`) order.
    pub entries: Vec<RegistryEntry>,
}

/// V1 registry Merkle root: ABI leaves bind index, compressed-key prefix/x, stake and
/// activation/exit uint48 fields. Pad to a power of two with zero leaves; an empty list hashes to
/// zero.
pub fn entries_root(entries: &[RegistryEntry]) -> B256 {
    if entries.is_empty() {
        return B256::ZERO;
    }
    let mut level: Vec<B256> = entries.iter().enumerate().map(|(i, e)| entry_leaf(i, e)).collect();
    level.resize(level.len().next_power_of_two(), B256::ZERO);
    while level.len() > 1 {
        level = level
            .as_chunks::<2>()
            .0
            .iter()
            .map(|pair| keccak256([pair[0], pair[1]].concat()))
            .collect();
    }
    level[0]
}

/// V1 ordering key: keccak256 of ABI words (ETNA_SET_KEY_V1, L2 chain id, prefix, x).
pub fn set_key(l2_chain_id: u64, pubkey: ConsensusKey) -> B256 {
    keccak256([SET_KEY_TAG, word(l2_chain_id), word(pubkey.prefix()), pubkey.x()].concat())
}

/// V1 committee Merkle root over members already sorted by set key. Leaves bind chain id,
/// set version, index, prefix, x, effective stake and power. Tagged inner nodes bind chain id
/// and version; an odd last node is promoted without padding.
pub fn set_root(l2_chain_id: u64, k: u64, members: &[Member]) -> B256 {
    debug_assert!(
        members
            .windows(2)
            .all(|w| set_key(l2_chain_id, w[0].pubkey) < set_key(l2_chain_id, w[1].pubkey)),
        "members must be sorted by set key without duplicates"
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

/// V1 record hash over the tag, L2 chain id and the five canonical CommitteeRecord fields.
pub fn record_hash(l2_chain_id: u64, r: &CommitteeRecord) -> B256 {
    keccak256(
        [
            RECORD_TAG,
            word(l2_chain_id),
            word(r.target_epoch),
            word(r.cutoff_l1_block),
            word(r.checkpoint_index),
            r.set_root,
            word(r.total_power),
        ]
        .concat(),
    )
}

/// Authenticates seven ABI words: V1 parent-anchor tag, L2 chain id, registry address,
/// voting-power unit, minimum stake, maximum committee size and direct unsettled limit U.
pub fn committee_config_hash(params: &ChainParams) -> B256 {
    keccak256(
        [
            tag(b"ETNA_PARENT_ANCHOR_V1"),
            word(params.l2_chain_id),
            B256::from(U256::from_be_slice(params.registry.as_slice())),
            word(params.vp_unit),
            word(params.s_min),
            word(params.n_max),
            word(params.unsettled_limit),
        ]
        .concat(),
    )
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

/// Authenticates the latest registry checkpoint at `cutoff` and every captured entry.
/// Contract address is checked first, followed by exact slots, adapter word count, checkpoint
/// bounds, successor/cutoff inequalities, entry count and complete entry root, in that order.
pub fn verify_snapshot<P: RegistryProof>(
    state_root: B256,
    registry: Address,
    index: u64,
    entries: &[RegistryEntry],
    proof: &P,
    cutoff: u64,
) -> Result<Snapshot, CommitteeError<P::Error>> {
    if proof.address() != registry {
        return Err(CommitteeError::WrongContract { expected: registry, got: proof.address() });
    }
    let has_next = proof.storage_proof_count() == 4;
    let slots = snapshot_slots(index, has_next);
    let storage = proof.authenticate_storage(state_root, &slots).map_err(CommitteeError::Mpt)?;
    if storage.len() != slots.len() {
        return Err(CommitteeError::AuthenticatedWordCountMismatch {
            expected: slots.len(),
            got: storage.len(),
        });
    }
    let length = storage[0];
    let position = U256::from(index);
    if position >= length {
        return Err(CommitteeError::CheckpointOutOfRange { index, length });
    }
    if has_next != (position + U256::from(1) < length) {
        return Err(CommitteeError::NextCheckpointMismatch { index, length, proven: has_next });
    }

    let head = storage[1];
    let l1_block = word_u48(head, 0);
    let count = word_u48(head, 48);
    if l1_block > cutoff {
        return Err(CommitteeError::CheckpointAfterCutoff { l1_block, cutoff });
    }
    if has_next {
        let next = word_u48(storage[3], 0);
        if next <= cutoff {
            return Err(CommitteeError::NextCheckpointNotAfterCutoff { l1_block: next, cutoff });
        }
    }

    // A uint48 count can exceed RV32 usize; never truncate authenticated metadata.
    if usize::try_from(count) != Ok(entries.len()) {
        return Err(CommitteeError::EntryCountMismatch { expected: count, got: entries.len() });
    }
    let expected = B256::from(storage[2]);
    let got = entries_root(entries);
    if got != expected {
        return Err(CommitteeError::EntriesRootMismatch { expected, got });
    }
    Ok(Snapshot { checkpoint_index: index, l1_block, entries: entries.to_vec() })
}

/// Derives a committee from entries active at cutoff with stake >= max(s_min, vp_unit).
/// Rejects duplicate eligible keys, ranks descending stake then ascending set key, and keeps
/// at most n_max members. Output is encoded in set-key order with floor(stake/vp_unit) powers.
/// Empty sets, invalid keys and arithmetic/power overflows fail closed.
pub fn derive(
    snapshot: &Snapshot,
    cutoff: u64,
    target_epoch: u64,
    params: &ChainParams,
) -> Result<(CommitteeRecord, Vec<Member>), CommitteeError> {
    let Selection { k, members, total_power, .. } =
        select(&snapshot.entries, cutoff, target_epoch, params)?;
    let record = CommitteeRecord {
        target_epoch,
        cutoff_l1_block: cutoff,
        checkpoint_index: snapshot.checkpoint_index,
        set_root: set_root(params.l2_chain_id, k, &members),
        total_power,
    };
    Ok((record, members))
}

/// Authenticates the historical snapshot at cutoff under the proving root, derives the
/// committee and checks the entire claimed record. Caller enforces cutoff <= proving block.
pub fn verify_committee_at_cutoff<P: RegistryProof>(
    state_root: B256,
    cutoff: u64,
    params: &ChainParams,
    claimed: &CommitteeRecord,
    entries: &[RegistryEntry],
    proof: &P,
    target_epoch: u64,
) -> Result<(CommitteeRecord, Vec<Member>), CommitteeError<P::Error>> {
    let snapshot = verify_snapshot(
        state_root,
        params.registry,
        claimed.checkpoint_index,
        entries,
        proof,
        cutoff,
    )?;
    let (record, members) = derive(&snapshot, cutoff, target_epoch, params)
        .map_err(CommitteeError::with_backend_error)?;
    if record != *claimed {
        return Err(CommitteeError::RecordMismatch {
            claimed: Box::new(claimed.clone()),
            derived: Box::new(record),
        });
    }
    Ok((record, members))
}

/// Produces native key/power updates, including zero-power removals, sorted by key.
/// Identical native sets emit no updates; authenticated stake changes alone need no Comet update.
pub fn validator_updates(old: &[Member], new: &[Member]) -> Vec<(ConsensusKey, u64)> {
    let native = |members: &[Member]| {
        members.iter().map(|m| (m.pubkey, m.power)).collect::<BTreeMap<_, _>>()
    };
    if native(old) == native(new) {
        return Vec::new();
    }
    let mut updates: BTreeMap<ConsensusKey, u64> = old.iter().map(|m| (m.pubkey, 0)).collect();
    updates.extend(new.iter().map(|m| (m.pubkey, m.power)));
    updates.into_iter().collect()
}

/// The committee [`derive()`] selects from a snapshot's entries, before its record.
struct Selection {
    /// Set version `k = targetEpoch − e_0 + 1`.
    k: u64,
    /// The members, sorted by set key.
    members: Vec<Member>,
    /// The members' total voting power, at most [`MAX_TOTAL_POWER`].
    total_power: u64,
}

/// Selects the committee for `target_epoch` at `cutoff` from `entries` (indexed by `slot`)
/// under every rule and check of [`derive()`], which only adds the record.
fn select(
    entries: &[RegistryEntry],
    cutoff: u64,
    target_epoch: u64,
    params: &ChainParams,
) -> Result<Selection, CommitteeError> {
    if params.vp_unit.is_zero() {
        return Err(CommitteeError::ZeroVpUnit);
    }
    let k = target_epoch
        .checked_sub(Schedule::E0)
        .and_then(|d| d.checked_add(1))
        .ok_or(CommitteeError::EpochOutOfRange(target_epoch))?;
    let min_stake = params.s_min.max(params.vp_unit);

    // `(set key, slot, entry)`; `slot` is the entry's index in the snapshot.
    let mut eligible: Vec<(B256, usize, &RegistryEntry)> = entries
        .iter()
        .enumerate()
        .filter(|(_, e)| is_base_eligible(e, cutoff, min_stake))
        .map(|(slot, e)| Ok((set_key(params.l2_chain_id, e.consensus_key()?), slot, e)))
        .collect::<Result<_, CommitteeError>>()?;
    // Adjacent equal set keys identify duplicate eligible consensus identities.
    eligible.sort_by_key(|(key, slot, _)| (*key, *slot));
    if eligible.windows(2).any(|pair| pair[0].0 == pair[1].0) {
        return Err(CommitteeError::DuplicateKey);
    }
    if eligible.len() > params.n_max {
        eligible.sort_by(|a, b| b.2.eff_stake.cmp(&a.2.eff_stake).then(a.0.cmp(&b.0)));
        eligible.truncate(params.n_max);
        eligible.sort_by_key(|(key, _, _)| *key);
    }
    if eligible.is_empty() {
        return Err(CommitteeError::Empty);
    }
    let selected: Vec<(usize, &RegistryEntry)> =
        eligible.into_iter().map(|(_, slot, e)| (slot, e)).collect();

    let members = selected
        .iter()
        .map(|(_, e)| {
            let pubkey = e.consensus_key()?;
            let power = member_power(pubkey, e.eff_stake, params)?;
            Ok(Member { pubkey, eff_stake: e.eff_stake, power })
        })
        .collect::<Result<Vec<_>, CommitteeError>>()?;

    let (total_power, _) = member_totals(&members)?;
    Ok(Selection { k, members, total_power })
}

/// Computes canonical positive voting power from eligible stake, with checked narrowing.
fn member_power(
    pubkey: ConsensusKey,
    eff_stake: U256,
    params: &ChainParams,
) -> Result<u64, CommitteeError> {
    if params.vp_unit.is_zero() {
        return Err(CommitteeError::ZeroVpUnit);
    }
    if eff_stake < params.s_min.max(params.vp_unit) {
        return Err(CommitteeError::IneligibleStake { pubkey });
    }
    u64::try_from(eff_stake / params.vp_unit).map_err(|_| CommitteeError::PowerOverflow { pubkey })
}

/// Sums member stake and power without overflow, enforcing CometBFT's total power cap.
pub fn member_totals(members: &[Member]) -> Result<(u64, U256), CommitteeError> {
    let total = members
        .iter()
        .try_fold(0u128, |acc, member| acc.checked_add(u128::from(member.power)))
        .ok_or(CommitteeError::TotalPowerTooLarge { total: u128::MAX })?;
    let total_power = u64::try_from(total)
        .ok()
        .filter(|total| *total <= MAX_TOTAL_POWER)
        .ok_or(CommitteeError::TotalPowerTooLarge { total })?;
    let total_stake = members
        .iter()
        .try_fold(U256::ZERO, |acc, member| acc.checked_add(member.eff_stake))
        .ok_or(CommitteeError::TotalStakeOverflow)?;
    Ok((total_power, total_stake))
}

/// Whether `e` can hold a seat at `cutoff`: active and staked at least `min_stake`.
/// Empty released slots fail stake and active-lifetime eligibility.
fn is_base_eligible(e: &RegistryEntry, cutoff: u64, min_stake: U256) -> bool {
    e.active_from_l1 <= cutoff && cutoff < e.exit_effective_l1 && e.eff_stake >= min_stake
}

/// The registry leaf of entry `index` (see [`entries_root`]).
fn entry_leaf(index: usize, e: &RegistryEntry) -> B256 {
    keccak256(
        [
            REG_ENTRY_TAG,
            word(index),
            word(e.ck_prefix),
            e.ck_x,
            word(e.eff_stake),
            word(e.active_from_l1),
            word(e.exit_effective_l1),
        ]
        .concat(),
    )
}

/// The set-root leaf of the member at sorted position `index` (see [`set_root`]).
fn set_leaf(l2_chain_id: u64, k: u64, index: usize, m: &Member) -> B256 {
    keccak256(
        [
            SET_LEAF_TAG,
            word(l2_chain_id),
            word(k),
            word(index),
            word(m.pubkey.prefix()),
            m.pubkey.x(),
            word(m.eff_stake),
            word(m.power),
        ]
        .concat(),
    )
}

/// A set-root inner node over `left` and `right` (see [`set_root`]).
fn set_node(l2_chain_id: u64, k: u64, left: B256, right: B256) -> B256 {
    keccak256([SET_NODE_TAG, word(l2_chain_id), word(k), left, right].concat())
}

/// One `abi.encode` word: the unsigned integer `value` left-padded to 32 bytes, big-endian.
pub fn word<T>(value: T) -> B256
where
    U256: UintTryFrom<T>,
{
    B256::from(U256::from(value))
}

/// A `bytes32` domain tag: the ASCII `name`, right-padded with zero bytes (at most 32 bytes).
pub const fn tag(name: &[u8]) -> B256 {
    let mut out = [0u8; 32];
    let mut i = 0;
    while i < name.len() {
        out[i] = name[i];
        i += 1;
    }
    B256::new(out)
}

#[cfg(test)]
#[path = "committee_tests.rs"]
mod tests;

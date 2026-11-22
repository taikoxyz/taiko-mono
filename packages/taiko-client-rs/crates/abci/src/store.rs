//! The persisted app state and its atomic file store.
//!
//! [`AppState`] is everything `FinalizeBlock` needs besides the envelope and the EL: the chain
//! identity, the genesis record, the committed parent, its anchor facts, the forced
//! inclusion cursor and CometBFT's validator state. `Commit` persists it
//! with [`Store::save`]: the JSON is written to `abci-state.json.tmp`, fsynced, renamed over
//! `abci-state.json` and the directory fsynced, so a crash leaves either the old or the new
//! state, never a torn file.
//!
//! The per-height records written before that state (the committed Comet block IDs, the
//! validator updates, the validator-state snapshots and the finalized execution blocks) live in
//! append-only segment logs of [`SEGMENT_HEIGHTS`] heights per file ([`SegmentLog`]), pruned
//! below the committed anchor's checkpoint, so the store holds a bounded number of files at any
//! unsettled limit.

use std::{
    collections::BTreeMap,
    fmt,
    fs::{self, File},
    io::{self, Write},
    path::{Path, PathBuf},
};

use alloy_primitives::{Address, B256};
use serde::{Deserialize, Serialize};

use crate::{
    committee::SignerSource,
    fallback::FallbackKeys,
    key::ConsensusKey,
    recovery::RecoveryOrigin,
    types::{AnchorState, GenesisRecord, ParentInfo},
    valstate::{ValEntry, ValState},
};

/// Checksummed execution payloads retained for local EL crash recovery.
mod execution;
/// Append-only per-kind segment logs of the per-height records.
mod segments;

pub(crate) use segments::{SEGMENT_HEIGHTS, SegmentLog};

/// File name of the persisted state inside the data directory.
pub const STATE_FILE: &str = "abci-state.json";

/// File name [`Store::save`] writes before renaming it to [`STATE_FILE`]; a leftover one is an
/// interrupted save and is discarded by [`Store::load`].
pub const TMP_FILE: &str = "abci-state.json.tmp";

/// The one [`AppState`] schema; a state file of any other schema is refused, never migrated.
pub const STATE_SCHEMA_VERSION: u32 = 22;

/// The app's committed state, persisted at every `Commit`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AppState {
    /// Always [`STATE_SCHEMA_VERSION`].
    pub schema_version: u32,
    /// Mandatory consensus format marker; old saved state has no implicit migration.
    pub app_version: u64,
    /// The 48-byte CometBFT deployment-domain chain ID.
    pub chain_id: String,
    /// Recovery generation authenticated in the deployment domain.
    pub generation: u64,
    /// The authenticated recovery boundary: `None` exactly at generation zero. Always written
    /// (`null` at generation zero) and required: `deserialize_with` stops serde from reading a
    /// missing key as `None`.
    #[serde(deserialize_with = "Option::deserialize")]
    pub recovery: Option<RecoveryOrigin>,
    /// The EL block a checkpoint import installed this store at (DATA-5.4-4): the landed
    /// checkpoint s and ELHash(s), whose header and state the own EL keeps serving
    /// (DATA-5.4-6); `None` for a store `InitChain` started at its generation's origin. The EL
    /// reconciliation at every CometBFT handshake, the first `Info` or `FinalizeBlock` on each
    /// new set of ABCI connections, checks it ([`App::new`](crate::App::new) checks only that it
    /// lies above the origin and at or below the committed head). Always written and required,
    /// like `recovery`.
    #[serde(deserialize_with = "Option::deserialize")]
    pub execution_floor: Option<ExecutionFloor>,
    /// Inbox account authenticated at genesis. Required so a restart cannot switch contracts;
    /// state files written without this binding are refused rather than migrated implicitly.
    pub inbox: Address,
    /// The Etna genesis record verified at `InitChain`.
    pub genesis: GenesisRecord,
    /// Logical EL boundary (== `parent.number`); the Etna start S or c before the first generation
    /// commit.
    pub last_height: u64,
    /// Exact new-generation Comet block ID; zero before the first generation commit.
    pub last_comet_hash: B256,
    /// Summary of the last committed L2 block, the parent of the next height.
    pub parent: ParentInfo,
    /// The L1 anchor of the last committed block and the Inbox facts proven at it.
    pub anchor: AnchorState,
    /// The forced inclusion cursor `c(last_height)`: how many queue entries the chain's blocks
    /// have consumed (0 at deployment, the retained landing cursor at recovery). The next block
    /// may consume only entry `forced_cursor`. A required field: a state file without it is
    /// refused (no migration).
    pub forced_cursor: u64,
    /// CometBFT's validator state after `last_height` (its `height` is `last_height`): the
    /// generation's genesis state, advanced by every committed height's validator updates. A
    /// required field: a state file without it is refused (no migration).
    pub val_state: ValState,
    /// The set that signs `last_height`, in CometBFT order: the validators the next block's
    /// LastCommit lists. `FinalizeBlock` sets it to the replica's current set before advancing
    /// [`AppState::val_state`]; it is empty at a generation's origin, whose first block has no
    /// LastCommit. A required field: a state file without it is refused (no migration).
    pub parent_signers: Vec<ValEntry>,
    /// Where the sets that sign `last_height + 1` and `last_height + 2` come from, in that
    /// order: [`AppState::val_state`]'s current and next sets. Both are
    /// [`SignerSource::Fallback`] at a generation's origin, whose fallback keys sign its first
    /// two blocks; `FinalizeBlock(H)` shifts the pair by one and records the source of the set it
    /// decided for H + 2. A required field: a state file without it is refused (no migration).
    pub signer_sources: [SignerSource; 2],
    /// The fallback key lists the node holds, keyed by their hash, each hashing to its key, so
    /// a list is obtained from the own L1 once. Every generation starts with its origin record's
    /// list. Each `FinalizeBlock` keeps only the list the block's anchor proves, when the node
    /// holds it, and a recovery origin record's, which [`App::new`](crate::App::new) requires:
    /// at most two. A node-local cache outside the app hash. A required field: a state file
    /// without it is refused (no migration).
    pub fallback_keys: BTreeMap<B256, FallbackKeys>,
}

/// The oldest EL block a checkpoint-imported store holds with its state: the landed checkpoint
/// s and its EL hash (DATA-5.4-4). The import's AppHash at s is appHash of that hash and the
/// validator state derived for s (CONS-3.1-8), not the bare EL hash.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ExecutionFloor {
    /// The checkpoint height s.
    pub number: u64,
    /// ELHash(s).
    pub hash: B256,
}

impl AppState {
    /// The fixed global L2 boundary preceding this generation's first block.
    pub fn origin_height(&self) -> u64 {
        self.recovery.as_ref().map_or(self.genesis.genesis_height, |origin| origin.height)
    }

    /// The lowest height whose committed Comet block ID checkpoint trust may still read: the
    /// committed anchor's checkpoint. Back-pressure keeps `last_height` within the unsettled
    /// cap of it, so the retained IDs stay bounded.
    pub fn comet_history_floor(&self) -> u64 {
        self.anchor.inbox.last_checkpoint_height
    }

    /// Whether this generation has actually committed a new Comet block after its origin.
    pub fn has_generation_commit(&self) -> bool {
        self.last_height > self.origin_height()
    }

    /// Earliest L1 anchor/snapshot allowed for a block in this generation.
    pub fn anchor_floor(&self) -> u64 {
        self.recovery.as_ref().map_or(self.genesis.l1_0, |origin| origin.l1_number)
    }
}

/// Why the state could not be loaded or saved.
#[derive(Debug, thiserror::Error)]
pub enum StoreError {
    /// A checkpoint import installs only a landed state with its execution floor at s, and
    /// never over a different installed state.
    #[error("checkpoint import refused: {0}")]
    Import(&'static str),
    /// A filesystem operation failed.
    #[error("cannot {op} {}: {source}", path.display())]
    Io {
        /// The operation, e.g. `"read"` or `"rename"`.
        op: &'static str,
        /// The file or directory it acted on.
        path: PathBuf,
        /// The underlying I/O error.
        #[source]
        source: io::Error,
    },
    /// The state file exists but is not a valid [`AppState`] JSON document.
    #[error("corrupt state file {}: {source}", path.display())]
    Corrupt {
        /// The state file.
        path: PathBuf,
        /// The JSON decoding error.
        #[source]
        source: serde_json::Error,
    },
    /// Replaying a committed height produced a different Comet block ID.
    #[error("conflicting durable Comet block hash at height {0}")]
    CometConflict(u64),
    /// A committed Comet block ID record fails its hash, holds no 32-byte hash or may lie in a
    /// damaged region of its segment. Unlike the records a node recomputes, it is never read as
    /// absence.
    #[error("corrupt durable Comet block hash at height {height}: {reason}")]
    CometCorrupt {
        /// The height of the record.
        height: u64,
        /// Why it does not load.
        reason: String,
    },
    /// Replaying a finalized height produced a different execution block.
    #[error("conflicting durable execution block at height {0}")]
    ExecutionConflict(u64),
    /// Replaying the origin or a committed height produced a different validator state.
    #[error("conflicting durable validator state at height {0}")]
    ValStateConflict(u64),
    /// Replaying a committed height produced different validator updates.
    #[error("conflicting durable validator updates at height {0}")]
    ValUpdatesConflict(u64),
    /// An immutable recovery bootstrap already exists with different evidence.
    #[error("conflicting immutable recovery bootstrap")]
    BootstrapConflict,
    /// The state could not be serialized to JSON.
    #[error("cannot serialize the app state: {0}")]
    Encode(#[source] serde_json::Error),
}

/// A per-height record as the store finds it on disk.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum Record<T> {
    /// No record exists at that height.
    Missing,
    /// A record exists but fails its checksum, decoding or height check, or a value derived from
    /// records lacks one of them; the text names why. It is missing data to recompute, never a
    /// contradiction.
    Corrupt(String),
    /// A well-formed record of that height.
    Valid(T),
}

impl Record<Vec<u8>> {
    /// The record with its body decoded by `decode`; a failure is [`Record::Corrupt`] naming it.
    fn decode<T, E: fmt::Display>(self, decode: impl FnOnce(&[u8]) -> Result<T, E>) -> Record<T> {
        match self {
            Record::Valid(body) => match decode(&body) {
                Ok(value) => Record::Valid(value),
                Err(error) => Record::Corrupt(error.to_string()),
            },
            Record::Missing => Record::Missing,
            Record::Corrupt(reason) => Record::Corrupt(reason),
        }
    }
}

/// Decode one exact durable image of the single [`AppState`] schema, with no migration.
pub(crate) fn decode_journal(bytes: &[u8], path: &Path) -> Result<AppState, StoreError> {
    serde_json::from_slice(bytes)
        .map_err(|source| StoreError::Corrupt { path: path.to_owned(), source })
}

/// Atomic JSON file store for [`AppState`] in one data directory.
#[derive(Clone, Debug)]
pub struct Store {
    /// The data directory holding [`STATE_FILE`]; created on the first save.
    dir: PathBuf,
    /// Whether saves fsync the file and its directory. Only [`Store::volatile`] clears it.
    durable: bool,
    /// Optional independent archive of every committed height's immutable validator-state
    /// preimage.
    archive: Option<PathBuf>,
}

impl Store {
    /// A store over `dir`. Touches nothing on disk.
    pub fn new(dir: PathBuf) -> Self {
        Self { dir, durable: true, archive: None }
    }

    /// Retain the validator-state preimage of every height committed from now on, the
    /// generation's origin included, in a separate operator-managed directory: an import package
    /// at any landed s carries s − 1's (DATA-5.4-8). The namespace includes the
    /// generation-qualified chain ID and never prunes or overwrites.
    pub fn with_val_archive(mut self, archive: Option<PathBuf>) -> Self {
        self.archive = archive;
        self
    }

    /// A store that saves the same files without fsyncing them, for unit tests that commit many
    /// blocks without testing durability. This module's own tests keep [`Store::new`].
    #[cfg(test)]
    pub(crate) fn volatile(dir: PathBuf) -> Self {
        Self { dir, durable: false, archive: None }
    }

    /// Directory for node-local sidecars and private checkpoint control.
    pub fn directory(&self) -> &Path {
        &self.dir
    }

    /// Loads the persisted state, or `Ok(None)` when none was ever saved (no state file, or no
    /// data directory).
    ///
    /// A leftover [`TMP_FILE`] from an interrupted save is ignored and removed first. Fails with
    /// [`StoreError::Corrupt`] when the state file does not decode as the current canonical
    /// schema and with [`StoreError::Io`] on any other filesystem error. No legacy aliases or
    /// redundant schedules are migrated.
    pub fn load(&self) -> Result<Option<AppState>, StoreError> {
        let tmp = self.dir.join(TMP_FILE);
        match fs::remove_file(&tmp) {
            Ok(()) => {}
            Err(e) if e.kind() == io::ErrorKind::NotFound => {}
            Err(source) => return Err(StoreError::Io { op: "remove", path: tmp, source }),
        }

        let path = self.dir.join(STATE_FILE);
        let bytes = match fs::read(&path) {
            Ok(bytes) => bytes,
            Err(e) if e.kind() == io::ErrorKind::NotFound => return Ok(None),
            Err(source) => return Err(StoreError::Io { op: "read", path, source }),
        };
        let state = decode_journal(&bytes, &path)?;
        Ok(Some(state))
    }

    /// The segment log of the committed Comet block IDs: `comet-hash-<f>.log`.
    pub(crate) fn comet_hashes(&self) -> SegmentLog {
        self.log("comet-hash", StoreError::CometConflict)
    }

    /// The segment log of the validator-state snapshots: `val-state-<f>.log`.
    pub(crate) fn val_states(&self) -> SegmentLog {
        self.log("val-state", StoreError::ValStateConflict)
    }

    /// The segment log of every committed height's validator updates: `val-updates-<f>.log`.
    pub(crate) fn val_updates(&self) -> SegmentLog {
        self.log("val-updates", StoreError::ValUpdatesConflict)
    }

    /// The segment log of `kind` in the data directory, whose appends meet another body at a
    /// height with `conflict`.
    fn log(&self, kind: &'static str, conflict: fn(u64) -> StoreError) -> SegmentLog {
        SegmentLog::new(self.dir.clone(), kind, self.durable, conflict)
    }

    /// Reads committed Comet history. Absence keeps checkpoint trust closed until restored.
    /// Entries above the committed AppState height are never evidence of a commit. A record that
    /// fails its hash or holds no 32-byte hash, and a height whose segment holds a damaged
    /// region but no valid record of it, are [`StoreError::CometCorrupt`], never absence.
    pub fn load_comet_hash(&self, height: u64) -> Result<Option<B256>, StoreError> {
        let corrupt = |reason| StoreError::CometCorrupt { height, reason };
        match self.comet_hashes().read(height)? {
            Record::Missing => Ok(None),
            Record::Valid(body) => B256::try_from(body.as_slice())
                .map(Some)
                .map_err(|_| corrupt(format!("it holds {} bytes", body.len()))),
            Record::Corrupt(reason) => Err(corrupt(reason)),
        }
    }

    /// Durably records one immutable Comet block ID before publishing its committed AppState:
    /// an equal record succeeds unchanged, another is [`StoreError::CometConflict`].
    pub fn save_comet_hash(&self, height: u64, hash: B256) -> Result<(), StoreError> {
        self.comet_hashes().append(height, hash.as_slice())
    }

    /// Deletes the Comet block ID segments wholly below `floor` and returns how many files it
    /// removed ([`SegmentLog::prune_below`]).
    pub fn prune_comet_hashes(&self, floor: u64) -> Result<usize, StoreError> {
        self.comet_hashes().prune_below(floor)
    }

    /// The validator state after the committed height `height`, recomputed from the
    /// newest snapshot at or below it with CometBFT v0.40.0's per-height arithmetic
    /// ([`ValState::advance`]): one advance per height above the snapshot, by the validator
    /// updates recorded at that height (every height records them, an empty list included).
    ///
    /// The snapshots are the full states recorded at the generation's origin, at a checkpoint
    /// import's s − 1 and s, and at every committed height divisible by [`SEGMENT_HEIGHTS`]; a
    /// snapshot that fails its checksum, does not decode ([`ValState::decode`]) or holds another
    /// height is skipped for an older one. No snapshot at or below `height` in intact segments
    /// is [`Record::Missing`]; a corrupt snapshot or a damaged segment with no valid snapshot
    /// below it, a missing or corrupt update record between the snapshot and `height`, or
    /// updates the arithmetic refuses are [`Record::Corrupt`] naming the cause: missing data, never
    /// evidence against a landing. Each generation starts in an empty data directory, so every
    /// snapshot is this generation's. Filesystem errors are [`StoreError::Io`].
    pub fn load_val_state(&self, height: u64) -> Result<Record<ValState>, StoreError> {
        let mut base = None;
        let mut corrupt = None;
        for recorded in self.val_states().heights()?.into_iter().rev().filter(|&h| h <= height) {
            match self.val_snapshot(recorded)? {
                Record::Valid(state) => {
                    base = Some(state);
                    break;
                }
                Record::Corrupt(reason) => {
                    corrupt.get_or_insert(format!(
                        "the validator-state snapshot of height {recorded} is corrupt: {reason}"
                    ));
                }
                Record::Missing => {}
            }
        }
        let Some(mut state) = base else {
            if let Some(reason) = corrupt {
                return Ok(Record::Corrupt(reason));
            }
            return Ok(match self.val_states().damaged_at_or_below(height)? {
                Some((first, offset)) => Record::Corrupt(format!(
                    "the validator-state segment of {first} is damaged at byte {offset}"
                )),
                None => Record::Missing,
            });
        };
        while state.height < height {
            let next = state.height + 1;
            let updates = match self.load_val_updates(next)? {
                Record::Valid(updates) => updates,
                Record::Missing => {
                    let reason = format!("the validator-update record of height {next} is missing");
                    return Ok(Record::Corrupt(reason));
                }
                Record::Corrupt(reason) => {
                    let reason = format!(
                        "the validator-update record of height {next} is corrupt: {reason}"
                    );
                    return Ok(Record::Corrupt(reason));
                }
            };
            state = match state.advance(&updates) {
                Ok(state) => state,
                Err(error) => {
                    let reason = format!("cannot advance the validator state to {next}: {error}");
                    return Ok(Record::Corrupt(reason));
                }
            };
        }
        Ok(Record::Valid(state))
    }

    /// The validator-state snapshot recorded at exactly `height`: its body is the appendix A
    /// preimage ([`ValState::encode`]), decoded with [`ValState::decode`] (which checks every key
    /// and the set order) and required to hold `height`.
    fn val_snapshot(&self, height: u64) -> Result<Record<ValState>, StoreError> {
        Ok(self.val_states().read(height)?.decode(|preimage| {
            let state = ValState::decode(preimage).map_err(|error| error.to_string())?;
            if state.height == height {
                Ok(state)
            } else {
                Err(format!("it holds height {}", state.height))
            }
        }))
    }

    /// Durably records `state` as the immutable validator-state snapshot of its height
    /// (`state.height`): at InitChain the generation's origin state, at a checkpoint import the
    /// states after s − 1 and s, and at Commit the state of every height divisible by
    /// [`SEGMENT_HEIGHTS`], before the AppState of that height is published.
    ///
    /// An equal snapshot succeeds unchanged (a replay after a crash before the AppState was
    /// saved); a valid snapshot of another state is [`StoreError::ValStateConflict`] and is kept.
    /// A corrupt one is superseded.
    pub fn save_val_state(&self, state: &ValState) -> Result<(), StoreError> {
        self.val_states().append(state.height, &state.encode())
    }

    /// Reads the validator updates recorded for the committed height `height`: the
    /// `(key, power)` changes its `FinalizeBlock` returned, possibly none, as a JSON array of
    /// `[key, power]` pairs. A record that fails its checksum or does not decode (a key
    /// included) is [`Record::Corrupt`]: missing data to recompute. Filesystem errors
    /// are [`StoreError::Io`].
    pub fn load_val_updates(
        &self,
        height: u64,
    ) -> Result<Record<Vec<(ConsensusKey, u64)>>, StoreError> {
        Ok(self.val_updates().read(height)?.decode(|body| serde_json::from_slice(body)))
    }

    /// Durably records `updates` as the immutable validator updates of the height `height`
    /// before the AppState of that height is published. Every height has one, an empty list
    /// included, so a lost record is missing data, never "no change".
    ///
    /// An equal record succeeds unchanged; a valid record of other updates is
    /// [`StoreError::ValUpdatesConflict`] and is kept. A corrupt one is superseded.
    pub fn save_val_updates(
        &self,
        height: u64,
        updates: &[(ConsensusKey, u64)],
    ) -> Result<(), StoreError> {
        let body = serde_json::to_vec(updates).map_err(StoreError::Encode)?;
        self.val_updates().append(height, &body)
    }

    /// Retires the validator records below the Comet history `floor`, the committed anchor's
    /// checkpoint s, and returns how many files it removed (SYNC-9-5c).
    ///
    /// The base is the newest validator-state snapshot below `floor` that loads valid: a state
    /// the node holds exactly, from which it recomputes the state at s − 1, the preimage an
    /// import package at s carries (5.4), and at every later height, with the
    /// update records above it. The snapshot segments wholly below the base and the update
    /// segments wholly at or below it (the base already includes them) are deleted; everything
    /// else is kept. Without a valid snapshot below `floor` nothing is deleted.
    pub fn prune_val_records(&self, floor: u64) -> Result<usize, StoreError> {
        let snapshots = self.val_states();
        let mut base = None;
        for height in snapshots.heights()?.into_iter().rev().filter(|&h| h < floor) {
            if let Record::Valid(_) = self.val_snapshot(height)? {
                base = Some(height);
                break;
            }
        }
        let Some(base) = base else { return Ok(0) };
        // `base < floor`, so `base + 1` cannot overflow.
        Ok(snapshots.prune_below(base)? + self.val_updates().prune_below(base + 1)?)
    }

    /// Reads sticky fatal evidence. Its presence requires explicit operator repair before restart.
    pub(crate) fn fatal_evidence(&self) -> Result<Option<String>, StoreError> {
        let path = self.dir.join("fatal-evidence.txt");
        match fs::read(&path) {
            Ok(bytes) => Ok(Some(String::from_utf8_lossy(&bytes).into_owned())),
            Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(None),
            Err(source) => Err(StoreError::Io { op: "read", path, source }),
        }
    }

    /// Durably retains the first fatal observation without rewriting earlier evidence.
    pub(crate) fn record_fatal(&self, reason: &str) -> Result<(), StoreError> {
        if self.fatal_evidence()?.is_none() {
            self.save_bytes(reason.as_bytes(), "fatal-evidence.txt", "fatal-evidence.tmp")?;
        }
        Ok(())
    }

    /// Loads immutable bootstrap evidence; absence is never permission to reconstruct a saved
    /// recovery.
    pub(crate) fn load_recovery_bootstrap(
        &self,
    ) -> Result<Option<crate::recovery::RecoveryBootstrap>, StoreError> {
        let path = self.dir.join("recovery-bootstrap.json");
        match fs::read(&path) {
            Ok(bytes) => serde_json::from_slice(&bytes)
                .map(Some)
                .map_err(|source| StoreError::Corrupt { path, source }),
            Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(None),
            Err(source) => Err(StoreError::Io { op: "read", path, source }),
        }
    }

    /// Saves authenticated bootstrap evidence before AppState, refusing conflicting retries.
    pub fn save_recovery_bootstrap(
        &self,
        bootstrap: &crate::recovery::RecoveryBootstrap,
    ) -> Result<(), StoreError> {
        if let Some(existing) = self.load_recovery_bootstrap()? {
            return if existing == *bootstrap { Ok(()) } else { Err(StoreError::BootstrapConflict) };
        }
        let bytes = serde_json::to_vec(bootstrap).map_err(StoreError::Encode)?;
        self.save_bytes(&bytes, "recovery-bootstrap.json", "recovery-bootstrap.json.tmp")
    }

    /// Installs the app store of a checkpoint import landed at `s = state.last_height`
    /// (DATA-5.4-3, DATA-5.4-4) as `Commit` would have left it at s: the recovery `bootstrap`
    /// when there is one, the Comet block ID of s (`state.last_comet_hash`), the validator-state
    /// record of s, which after an import is the state DATA-5.4-3 derives for s from the
    /// authenticated preimage for s - 1 (SYNC-9-5c), and last the AppState.
    ///
    /// Each write is durable (the file and the directory fsynced) before the next starts, and
    /// [`Store::load`] finds no state until the last one: a crash leaves a store that is not
    /// installed, never a state without its records. The records are immutable, so a rerun over
    /// such a prefix completes the install, and a conflicting record fails it before the
    /// AppState. Creating the directory itself is not made durable here: the caller syncs the
    /// tree it publishes.
    ///
    /// Only a state landed above its origin is installed: its execution floor must be s and its
    /// hash ELHash(s). An origin import (s = o) has no floor and installs no AppState, since
    /// InitChain builds it (DATA-5.4-1). An already installed AppState is never replaced by a
    /// different one; reinstalling the same state is a no-op rerun.
    pub fn install_import(
        &self,
        state: &AppState,
        bootstrap: Option<&crate::recovery::RecoveryBootstrap>,
    ) -> Result<(), StoreError> {
        if state
            .execution_floor
            .is_none_or(|f| f.number != state.last_height || f.hash != state.parent.hash)
        {
            return Err(StoreError::Import("the state has no execution floor at its own height"));
        }
        if self.load()?.is_some_and(|installed| installed != *state) {
            return Err(StoreError::Import("a different app state is already installed"));
        }
        if let Some(bootstrap) = bootstrap {
            self.save_recovery_bootstrap(bootstrap)?;
        }
        self.save_comet_hash(state.last_height, state.last_comet_hash)?;
        self.save_val_state(&state.val_state)?;
        self.save(state)
    }

    /// Persists `s` atomically, replacing any previous state.
    ///
    /// Creates the data directory if needed, writes [`TMP_FILE`], fsyncs it, renames it to
    /// [`STATE_FILE`] and fsyncs the directory so the rename is durable.
    pub fn save(&self, s: &AppState) -> Result<(), StoreError> {
        if let Some(archive) = &self.archive {
            archive_preimage(archive, s)?;
        }
        let json = serde_json::to_vec_pretty(s).map_err(StoreError::Encode)?;
        self.save_bytes(&json, STATE_FILE, TMP_FILE)
    }

    /// Fsyncs and atomically replaces one bounded file in the data directory.
    fn save_bytes(&self, bytes: &[u8], name: &str, temporary_name: &str) -> Result<(), StoreError> {
        fs::create_dir_all(&self.dir).map_err(|source| io_err("create", &self.dir, source))?;

        let tmp = self.dir.join(temporary_name);
        let mut file = File::create(&tmp).map_err(|source| io_err("create", &tmp, source))?;
        file.write_all(bytes).map_err(|source| io_err("write", &tmp, source))?;
        if self.durable {
            file.sync_all().map_err(|source| io_err("fsync", &tmp, source))?;
        }
        drop(file);

        let path = self.dir.join(name);
        fs::rename(&tmp, &path).map_err(|source| io_err("rename", &tmp, source))?;
        if self.durable { sync_dir(&self.dir) } else { Ok(()) }
    }
}

/// Publish the immutable validator-state preimage of `s`'s height in the archive filesystem
/// before its corresponding live journal commit. Equal retries are safe; a conflicting copy is
/// never replaced.
fn archive_preimage(archive: &Path, s: &AppState) -> Result<(), StoreError> {
    let domain = alloy_primitives::keccak256(s.chain_id.as_bytes());
    let path = archive.join(format!("{domain}-{}.bin", s.last_height));
    let bytes = s.val_state.encode();
    let mut tmp = tempfile::NamedTempFile::new_in(archive)
        .map_err(|e| io_err("create archive", archive, e))?;
    tmp.write_all(&bytes)
        .and_then(|()| tmp.as_file().sync_all())
        .map_err(|e| io_err("sync archive", archive, e))?;
    match tmp.persist_noclobber(&path) {
        Ok(_) => {}
        Err(e) if e.error.kind() == io::ErrorKind::AlreadyExists => {
            let m = path.symlink_metadata().map_err(|e| io_err("archive metadata", &path, e))?;
            if !m.is_file() ||
                m.len() != bytes.len() as u64 ||
                fs::read(&path).map_err(|e| io_err("read archive", &path, e))? != bytes
            {
                return Err(StoreError::ValStateConflict(s.last_height))
            }
        }
        Err(e) => return Err(io_err("publish archive", &path, e.error)),
    }
    sync_dir(archive)
}

/// Builds a [`StoreError::Io`].
fn io_err(op: &'static str, path: &Path, source: io::Error) -> StoreError {
    StoreError::Io { op, path: path.to_path_buf(), source }
}

/// Fsyncs `dir` so a rename inside it survives a crash.
fn sync_dir(dir: &Path) -> Result<(), StoreError> {
    File::open(dir).and_then(|d| d.sync_all()).map_err(|source| io_err("fsync", dir, source))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{config::ChainParamsExt, types::InboxFacts};
    use alloy_primitives::{B256, U256};
    use std::fs;

    fn state() -> AppState {
        let genesis = GenesisRecord {
            config_hash: crate::config::ChainParams::builtin(
                protocol::shasta::constants::TAIKO_DEVNET_CHAIN_ID,
            )
            .unwrap()
            .config_hash(),
            genesis_height: 0,
            l1_0: 1_000,
            genesis_hash: B256::repeat_byte(0x66),
            genesis_state_root: B256::repeat_byte(0x77),
            forced_inclusion_delay: 3_600,
            max_anchor_age: 7_200,
        };
        AppState {
            schema_version: STATE_SCHEMA_VERSION,
            recovery: None,
            app_version: crate::app::APP_VERSION,
            chain_id: "taiko-etna-167001-g0".to_string(),
            generation: 0,
            inbox: alloy_primitives::address!("00000000000000000000000000000000E7A10001"),
            genesis,
            last_height: 105,
            last_comet_hash: B256::repeat_byte(5),
            parent: ParentInfo {
                number: 105,
                hash: B256::repeat_byte(0xbb),
                timestamp: 1_791_526_500,
                gas_limit: 45_000_000,
                gas_used: 21_000,
                base_fee: 25_000_000,
                difficulty: U256::from(243_000u64),
                grandparent_timestamp: 1_791_526_499,
            },
            anchor: AnchorState {
                number: 1_004,
                hash: B256::repeat_byte(0xa1),
                state_root: B256::repeat_byte(0x5a),
                timestamp: 1_791_526_400,
                inbox: InboxFacts {
                    rules_schedule: alloy_primitives::U256::ZERO,
                    recovery_generation: 0,
                    last_checkpoint_height: 101,
                    last_checkpoint_hash: B256::repeat_byte(0x33),
                    forced_inclusion_head: 2,
                    forced_inclusion_tail: 5,
                    fallback_keys_hash: B256::repeat_byte(0x44),
                    min_total_stake: U256::MAX,
                },
            },
            forced_cursor: 3,
            val_state: ValState::genesis(
                105,
                &crate::test_utils::fallback_list(&[1, 2, 3]).validator_set(),
            )
            .unwrap(),
            parent_signers: crate::valstate::comet_order(
                &crate::test_utils::fallback_list(&[1, 2, 3]).validator_set(),
            )
            .unwrap(),
            signer_sources: [SignerSource::Fallback, SignerSource::Candidate],
            fallback_keys: [crate::test_utils::fallback_list(&[1, 2])]
                .into_iter()
                .map(|keys| (keys.hash(), keys))
                .collect(),
            execution_floor: None,
        }
    }

    /// The archive holds the preimage of every committed height, the origin's and those that
    /// are not snapshot heights included, since a package at any landed s needs s − 1's
    /// (DATA-5.4-8), and keeps it once retention has deleted the record.
    #[test]
    fn archived_preimage_survives_pruning() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path().canonicalize().unwrap();
        let dir = root.join("app");
        let archive = root.join("archive");
        fs::create_dir(&archive).unwrap();
        let store = Store::new(dir.clone()).with_val_archive(Some(archive.clone()));
        let archived = |height: u64| {
            let domain = alloy_primitives::keccak256(state().chain_id.as_bytes());
            archive.join(format!("{domain}-{height}.bin"))
        };
        let at = |height: u64| {
            let mut s = state();
            s.last_height = height;
            s.parent.number = height;
            s.val_state.height = height;
            s
        };
        let origin = at(0);
        assert_eq!(origin.origin_height(), 0);
        store.save(&origin).unwrap();
        assert_eq!(fs::read(archived(0)).unwrap(), origin.val_state.encode());
        let s = at(SEGMENT_HEIGHTS + 76);
        store.save_val_state(&s.val_state).unwrap();
        store.save(&s).unwrap();
        assert_eq!(store.load().unwrap(), Some(s.clone()));
        // The snapshot of s is the base below the floor until the next segment's replaces it.
        let floor = 2 * SEGMENT_HEIGHTS + 1;
        assert_eq!(store.prune_val_records(floor).unwrap(), 0);
        store.save_val_state(&at(2 * SEGMENT_HEIGHTS).val_state).unwrap();
        assert_eq!(store.prune_val_records(floor).unwrap(), 1);
        assert_eq!(store.load_val_state(s.last_height).unwrap(), Record::Missing);
        assert_eq!(fs::read(archived(s.last_height)).unwrap(), s.val_state.encode());
        store.save(&s).unwrap();
        fs::write(archived(s.last_height), b"conflict").unwrap();
        assert!(store.save(&s).is_err());
    }

    /// A snapshot record's body is the appendix A preimage, so its body hash is the record's own
    /// `valStateHash`, and its header check covers the height, length and body hash. A body hash
    /// failure, a body that does not decode and a well-formed state of another height are
    /// corrupt, which the next save supersedes; only a valid record of the same height holding
    /// another state conflicts.
    #[test]
    fn val_state_snapshots_are_checksummed_and_corruption_is_not_conflict() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        let mut s = state();
        s.val_state.height = 108;
        let pre = s.val_state.encode();
        store.save_val_state(&s.val_state).unwrap();
        let path = dir.path().join("val-state-00000000000000000000.log");
        let framed = fs::read(&path).unwrap();
        let len = u32::try_from(pre.len()).unwrap().to_be_bytes();
        let header =
            [&108u64.to_be_bytes()[..], &len, alloy_primitives::keccak256(&pre).as_slice()]
                .concat();
        assert_eq!(framed[..header.len()], header);
        assert_eq!(framed[header.len() + 8..], pre);
        assert_eq!(store.load_val_state(108).unwrap(), Record::Valid(s.val_state.clone()));

        let snapshots = store.val_states();
        snapshots.corrupt(108);
        assert!(matches!(store.load_val_state(108).unwrap(), Record::Corrupt(_)));
        snapshots.replace(108, &pre[..40]);
        assert!(matches!(store.load_val_state(108).unwrap(), Record::Corrupt(_)));
        let mut later = s.val_state.clone();
        later.height = 114;
        snapshots.replace(108, &later.encode());
        let Record::Corrupt(reason) = store.load_val_state(108).unwrap() else { panic!() };
        assert!(reason.contains("holds height 114"), "{reason}");

        // Saving over a corrupt snapshot supersedes it.
        snapshots.corrupt(108);
        store.save_val_state(&s.val_state).unwrap();
        assert_eq!(store.load_val_state(108).unwrap(), Record::Valid(s.val_state.clone()));

        // A well-formed snapshot with another priority at 108 is a conflict, never replaced.
        let saved = fs::read(&path).unwrap();
        let mut other = s.val_state.clone();
        other.current.entries[0].priority += 1;
        assert!(matches!(store.save_val_state(&other), Err(StoreError::ValStateConflict(108))));
        assert_eq!(fs::read(&path).unwrap(), saved);
    }

    /// A checkpoint import installs an ordinary store (DATA-5.4-4, DATA-5.4-6): the Comet block
    /// ID and the validator-state record of s, then the AppState, which `App::new` opens like
    /// any other, with the execution floor in its status. The record at s is the installed
    /// preimage (SYNC-9-5c). Every prefix a crash can leave loads no state, a rerun over one
    /// completes the install, and a conflicting record fails it before the AppState.
    #[test]
    fn install_import_writes_an_ordinary_store_that_app_new_loads() {
        let fx = crate::test_utils::Fixture::genesis(1);
        let (state, _) = fx.imported_state(12, 12);
        let preimage = state.val_state.encode();
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        let installed = |dir: &Path| Store::new(dir.into()).load().unwrap();

        store.save_comet_hash(12, state.last_comet_hash).unwrap();
        assert_eq!(installed(dir.path()), None);
        store.save_val_state(&state.val_state).unwrap();
        fs::write(dir.path().join(TMP_FILE), b"{\"half-written").unwrap();
        assert_eq!(installed(dir.path()), None);

        store.install_import(&state, None).unwrap();
        let reopened = Store::new(dir.path().into());
        assert_eq!(reopened.load().unwrap(), Some(state.clone()));
        assert_eq!(reopened.load_comet_hash(12).unwrap(), Some(state.last_comet_hash));
        assert_eq!(reopened.val_states().read(12).unwrap(), Record::Valid(preimage.clone()));
        assert_eq!(reopened.val_states().heights().unwrap(), [12]);
        assert_eq!(reopened.load_val_state(12).unwrap(), Record::Valid(state.val_state.clone()));
        let app = crate::App::new(
            fx.l1(),
            fx.engine(),
            fx.params.clone(),
            reopened,
            crate::AppOptions::default(),
        )
        .expect("an installed import is an ordinary store");
        assert_eq!(app.state(), Some(&state));
        assert_eq!(app.status().unwrap().execution_floor, Some(12));
        assert_eq!(app.val_state_preimage(12), Ok(preimage));

        let mut other = state.val_state.clone();
        other.current.entries[0].priority += 1;
        for comet in [true, false] {
            let dir = tempfile::tempdir().unwrap();
            let store = Store::new(dir.path().into());
            if comet {
                store.save_comet_hash(12, B256::repeat_byte(0xee)).unwrap();
            } else {
                store.save_val_state(&other).unwrap();
            }
            let error = store.install_import(&state, None).expect_err("a conflicting record");
            assert!(
                matches!(error, StoreError::CometConflict(12) | StoreError::ValStateConflict(12)),
                "{error:?}"
            );
            assert_eq!(installed(dir.path()), None);
        }
    }

    /// Only a state landed above its origin is installed (DATA-5.4-1: an origin import has no
    /// floor, and InitChain builds its state), and a rerun never replaces a different installed
    /// AppState. Refusals write nothing.
    #[test]
    fn install_import_refuses_an_origin_state_and_a_different_installed_state() {
        let fx = crate::test_utils::Fixture::genesis(1);
        let (state, _) = fx.imported_state(12, 12);
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        let floor = |number, hash| {
            let mut refused = state.clone();
            refused.execution_floor = Some(ExecutionFloor { number, hash });
            refused
        };
        let mut origin = state.clone();
        origin.execution_floor = None;
        for refused in [origin, floor(11, state.parent.hash), floor(12, B256::repeat_byte(1))] {
            let error = store.install_import(&refused, None).expect_err("not a landed import");
            assert!(matches!(error, StoreError::Import(_)), "{error:?}");
            assert_eq!(fs::read_dir(dir.path()).unwrap().count(), 0);
        }
        store.install_import(&state, None).unwrap();
        store.install_import(&state, None).expect("a rerun of the same install");
        let mut other = state.clone();
        other.forced_cursor += 1;
        let error = store.install_import(&other, None).expect_err("a different installed state");
        assert!(matches!(error, StoreError::Import(_)), "{error:?}");
        assert_eq!(store.load().unwrap(), Some(state));
    }

    #[test]
    fn save_then_load_round_trips() {
        let dir = tempfile::tempdir().expect("tempdir");
        let store = Store::new(dir.path().to_path_buf());
        let s = state();
        store.save(&s).expect("saves");
        assert!(dir.path().join(STATE_FILE).is_file());
        assert!(!dir.path().join(TMP_FILE).exists(), "save leaves no temp file");
        assert_eq!(store.load().expect("loads"), Some(s));
    }

    /// The fallback key lists are a JSON object keyed by their hashes, each list the array of its
    /// keys.
    #[test]
    fn fallback_key_lists_are_saved_by_their_hash() {
        let s = state();
        let json = serde_json::to_value(&s).unwrap();
        let (hash, keys) = s.fallback_keys.first_key_value().unwrap();
        assert_eq!(json["fallback_keys"][hash.to_string()], serde_json::to_value(keys).unwrap());
        assert_eq!(serde_json::from_value::<AppState>(json).unwrap(), s);
    }

    /// The two signer sources are saved by name, the set signing `last_height + 1` first; any
    /// other name or count does not load.
    #[test]
    fn signer_sources_are_saved_by_name() {
        let s = state();
        let json = serde_json::to_value(&s).unwrap();
        assert_eq!(json["signer_sources"], serde_json::json!(["fallback", "candidate"]));
        for refused in [serde_json::json!(["fallback"]), serde_json::json!(["fallback", "staked"])]
        {
            let mut json = json.clone();
            json["signer_sources"] = refused;
            assert!(serde_json::from_value::<AppState>(json).is_err());
        }
    }

    #[test]
    fn load_rejects_a_state_missing_a_required_field() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        let current = serde_json::to_value(state()).unwrap();
        for (object, field) in [
            ("", "app_version"),
            ("", "schema_version"),
            ("", "recovery"),
            ("", "execution_floor"),
            ("", "inbox"),
            ("", "last_comet_hash"),
            ("/val_state/current/entries/0", "key"),
            ("", "forced_cursor"),
            ("", "val_state"),
            ("", "parent_signers"),
            ("", "signer_sources"),
            ("", "fallback_keys"),
            ("/genesis", "forced_inclusion_delay"),
            ("/genesis", "max_anchor_age"),
            ("/anchor/inbox", "forced_inclusion_head"),
            ("/anchor/inbox", "forced_inclusion_tail"),
            ("/anchor/inbox", "rules_schedule"),
        ] {
            let mut json = current.clone();
            json.pointer_mut(object)
                .and_then(|value| value.as_object_mut())
                .and_then(|value| value.remove(field))
                .unwrap_or_else(|| panic!("{object}/{field} is saved"));
            fs::write(dir.path().join(STATE_FILE), serde_json::to_vec(&json).unwrap()).unwrap();
            let err = store.load().expect_err("a state without the field must not load");
            assert!(matches!(err, StoreError::Corrupt { .. }), "{field}: {err:?}");
        }
    }

    #[test]
    fn save_replaces_the_previous_state() {
        let dir = tempfile::tempdir().expect("tempdir");
        let store = Store::new(dir.path().to_path_buf());
        let mut s = state();
        store.save(&s).expect("first save");
        s.last_height += 1;
        s.parent.number += 1;
        s.forced_cursor += 1;
        store.save(&s).expect("second save");
        assert_eq!(store.load().expect("loads"), Some(s));
    }

    #[test]
    fn save_creates_a_missing_directory() {
        let dir = tempfile::tempdir().expect("tempdir");
        let store = Store::new(dir.path().join("nested").join("data"));
        store.save(&state()).expect("saves");
        assert_eq!(store.load().expect("loads"), Some(state()));
    }

    #[test]
    fn missing_state_file_loads_as_none() {
        let dir = tempfile::tempdir().expect("tempdir");
        assert_eq!(Store::new(dir.path().to_path_buf()).load().expect("loads"), None);
        assert_eq!(Store::new(dir.path().join("absent")).load().expect("loads"), None);
    }

    #[test]
    fn leftover_temp_file_is_ignored_and_removed() {
        let dir = tempfile::tempdir().expect("tempdir");
        let store = Store::new(dir.path().to_path_buf());
        let tmp = dir.path().join(TMP_FILE);

        fs::write(&tmp, b"{\"half-written").expect("writes tmp");
        assert_eq!(store.load().expect("loads"), None);
        assert!(!tmp.exists(), "load removes the leftover temp file");

        store.save(&state()).expect("saves");
        fs::write(&tmp, b"garbage").expect("writes tmp");
        assert_eq!(store.load().expect("loads"), Some(state()));
        assert!(!tmp.exists(), "load removes the leftover temp file");
    }

    #[test]
    fn corrupt_state_file_is_an_error() {
        let dir = tempfile::tempdir().expect("tempdir");
        let store = Store::new(dir.path().to_path_buf());
        for bad in [&b"{not json"[..], b"", b"{\"chain_id\":\"x\"}"] {
            fs::write(dir.path().join(STATE_FILE), bad).expect("writes state");
            let err = store.load().expect_err("corrupt file must not load");
            assert!(matches!(err, StoreError::Corrupt { .. }), "{err:?}");
        }
    }
}

#[cfg(test)]
mod record_tests {
    use super::*;
    use crate::{envelope::ExecutionBlock, test_utils::test_key};

    #[test]
    fn durable_comet_hashes_are_immutable_and_corruption_is_not_absence() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        assert_eq!(store.load_comet_hash(6).unwrap(), None);
        let hash = B256::repeat_byte(6);
        store.save_comet_hash(6, hash).unwrap();
        let reopened = Store::new(dir.path().into());
        assert_eq!(reopened.load_comet_hash(6).unwrap(), Some(hash));
        reopened.save_comet_hash(6, hash).unwrap();
        assert!(matches!(
            reopened.save_comet_hash(6, B256::repeat_byte(7)),
            Err(StoreError::CometConflict(6))
        ));
        reopened.comet_hashes().corrupt(6);
        assert!(matches!(
            reopened.load_comet_hash(6),
            Err(StoreError::CometCorrupt { height: 6, .. })
        ));
        reopened.comet_hashes().replace(6, b"short");
        assert!(matches!(
            reopened.load_comet_hash(6),
            Err(StoreError::CometCorrupt { height: 6, .. })
        ));
        // A record whose body fails its hash is superseded by the height's next save.
        reopened.comet_hashes().corrupt(6);
        reopened.save_comet_hash(6, hash).unwrap();
        assert_eq!(reopened.load_comet_hash(6).unwrap(), Some(hash));
    }

    /// The header check covers a record's height: a record whose header height byte flipped is
    /// corruption at its own height, never the value of the height it now names, and a height
    /// its damaged segment may hold is never read as absent. The records after it stay readable,
    /// and later saves keep the damaged bytes.
    #[test]
    fn flipped_header_height_is_corruption_not_another_heights_value() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        let comet = dir.path().join("comet-hash-00000000000000000000.log");
        let updates_log = dir.path().join("val-updates-00000000000000000000.log");
        let flip_seven = |path: &Path, at: usize| {
            let mut bytes = fs::read(path).unwrap();
            assert_eq!(bytes[at + 7], 7);
            bytes[at + 7] = 6;
            fs::write(path, bytes).unwrap();
        };

        store.save_comet_hash(6, B256::repeat_byte(6)).unwrap();
        let at = fs::read(&comet).unwrap().len();
        store.save_comet_hash(7, B256::repeat_byte(7)).unwrap();
        store.save_comet_hash(8, B256::repeat_byte(8)).unwrap();
        store.save_val_updates(6, &updates(6)).unwrap();
        let updates_at = fs::read(&updates_log).unwrap().len();
        store.save_val_updates(7, &updates(7)).unwrap();
        store.save_val_updates(8, &updates(8)).unwrap();
        flip_seven(&comet, at);
        flip_seven(&updates_log, updates_at);

        assert_eq!(store.load_comet_hash(6).unwrap(), Some(B256::repeat_byte(6)));
        let error = store.load_comet_hash(7).unwrap_err();
        assert!(matches!(error, StoreError::CometCorrupt { height: 7, .. }), "{error:?}");
        assert_eq!(store.load_comet_hash(8).unwrap(), Some(B256::repeat_byte(8)));
        let error = store.load_comet_hash(9).unwrap_err();
        assert!(matches!(error, StoreError::CometCorrupt { height: 9, .. }), "{error:?}");
        assert_eq!(store.load_val_updates(6).unwrap(), Record::Valid(updates(6)));
        assert!(matches!(store.load_val_updates(7).unwrap(), Record::Corrupt(_)));
        assert_eq!(store.load_val_updates(8).unwrap(), Record::Valid(updates(8)));

        let damaged = fs::read(&comet).unwrap();
        store.save_comet_hash(9, B256::repeat_byte(9)).unwrap();
        assert!(fs::read(&comet).unwrap().starts_with(&damaged), "nothing is truncated");
        assert_eq!(store.load_comet_hash(9).unwrap(), Some(B256::repeat_byte(9)));
        assert_eq!(store.load_comet_hash(8).unwrap(), Some(B256::repeat_byte(8)));
    }

    /// Pruning deletes the Comet block ID segments wholly below the floor; the segment holding
    /// the floor keeps every record in it.
    #[test]
    fn pruning_removes_only_comet_hash_segments_below_the_floor() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::volatile(dir.path().into());
        let heights = [5, SEGMENT_HEIGHTS - 1, SEGMENT_HEIGHTS, SEGMENT_HEIGHTS + 7];
        for height in heights {
            store.save_comet_hash(height, B256::repeat_byte(height as u8)).unwrap();
        }
        let unrelated = [STATE_FILE, "comet-hash-5.json", "comet-hash-0.log", "comet-hash-x.log"];
        for name in unrelated {
            std::fs::write(dir.path().join(name), b"kept").unwrap();
        }

        assert_eq!(store.prune_comet_hashes(SEGMENT_HEIGHTS + 3).unwrap(), 1);

        for height in [5, SEGMENT_HEIGHTS - 1] {
            assert_eq!(store.load_comet_hash(height).unwrap(), None, "height {height}");
        }
        for height in [SEGMENT_HEIGHTS, SEGMENT_HEIGHTS + 7] {
            let hash = Some(B256::repeat_byte(height as u8));
            assert_eq!(store.load_comet_hash(height).unwrap(), hash, "height {height}");
        }
        for name in unrelated {
            assert!(dir.path().join(name).exists(), "{name} is not committed Comet history");
        }
        let again = store.prune_comet_hashes(SEGMENT_HEIGHTS + 3).unwrap();
        assert_eq!(again, 0, "pruning again finds nothing");
    }

    /// CometBFT's genesis validator state at `height` of two validators, the first with
    /// `power`.
    fn val_state(height: u64, power: u64) -> ValState {
        ValState::genesis(height, &[(test_key(1), power), (test_key(2), 1)]).unwrap()
    }

    #[test]
    fn durable_val_states_are_immutable() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        assert_eq!(store.load_val_state(6).unwrap(), Record::Missing);
        let recorded = val_state(6, 1);
        store.save_val_state(&recorded).unwrap();
        let reopened = Store::new(dir.path().into());
        assert_eq!(reopened.load_val_state(6).unwrap(), Record::Valid(recorded.clone()));
        reopened.save_val_state(&recorded).unwrap();
        assert!(matches!(
            reopened.save_val_state(&val_state(6, 2)),
            Err(StoreError::ValStateConflict(6))
        ));
        assert_eq!(reopened.load_val_state(6).unwrap(), Record::Valid(recorded));
    }

    /// Sample validator updates of `height`: power `height` for key 1 and the removal of key 3,
    /// so the records of different heights differ.
    fn updates(height: u64) -> Vec<(ConsensusKey, u64)> {
        vec![(test_key(1), height), (test_key(3), 0)]
    }

    /// An update record's body is the JSON array of its `[key, power]` pairs. Like a snapshot it
    /// is immutable once valid, and a checksum or decoding failure is a corrupt record (missing
    /// data) that the next save supersedes; only a valid record of other updates
    /// conflicts.
    #[test]
    fn val_update_records_are_immutable_and_checksummed() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        assert_eq!(store.load_val_updates(7).unwrap(), Record::Missing);

        // Round trip, the empty list of a height that changes nothing included.
        store.save_val_updates(3, &[]).unwrap();
        assert_eq!(store.load_val_updates(3).unwrap(), Record::Valid(vec![]));
        store.save_val_updates(7, &updates(7)).unwrap();
        let reopened = Store::new(dir.path().into());
        assert_eq!(reopened.load_val_updates(7).unwrap(), Record::Valid(updates(7)));
        let Record::Valid(body) = reopened.val_updates().read(7).unwrap() else { panic!() };
        let json = serde_json::json!(updates(7));
        assert_eq!(serde_json::from_slice::<serde_json::Value>(&body).unwrap(), json);
        let path = dir.path().join("val-updates-00000000000000000000.log");
        let framed = std::fs::read(&path).unwrap();

        // An equal re-save succeeds unchanged; other updates conflict and are not written.
        reopened.save_val_updates(7, &updates(7)).unwrap();
        assert!(matches!(
            reopened.save_val_updates(7, &updates(8)),
            Err(StoreError::ValUpdatesConflict(7))
        ));
        assert!(matches!(
            reopened.save_val_updates(3, &updates(3)),
            Err(StoreError::ValUpdatesConflict(3))
        ));
        assert_eq!(std::fs::read(&path).unwrap(), framed);

        // A failed checksum; a body that is not an update list or holds a bad key.
        reopened.val_updates().corrupt(7);
        assert!(matches!(reopened.load_val_updates(7).unwrap(), Record::Corrupt(_)));
        let unknown = serde_json::json!({ "height": 3, "updates": [] });
        let bad_key = serde_json::json!([[format!("0x{}", "00".repeat(33)), 1]]);
        for body in [unknown, bad_key] {
            let body = serde_json::to_vec(&body).unwrap();
            reopened.val_updates().replace(3, &body);
            let record = reopened.load_val_updates(3).unwrap();
            assert!(matches!(record, Record::Corrupt(_)), "{}", String::from_utf8_lossy(&body));
        }

        // Saving over the corrupt 7 supersedes it.
        reopened.save_val_updates(7, &updates(7)).unwrap();
        assert_eq!(reopened.load_val_updates(7).unwrap(), Record::Valid(updates(7)));
    }

    /// Retention keeps the newest snapshot below the floor that loads valid as the base the
    /// states above it are recomputed from: it deletes the snapshot segments wholly
    /// below the base and the update segments wholly at or below it. Without a valid base below
    /// the floor nothing is deleted.
    #[test]
    fn pruning_keeps_the_newest_valid_snapshot_below_the_floor() {
        let k = SEGMENT_HEIGHTS;
        let snapshots = |store: &Store| store.val_states().heights().unwrap();
        let recorded = |store: &Store| store.val_updates().heights().unwrap();
        let setup = |corrupt: &[u64]| {
            let dir = tempfile::tempdir().unwrap();
            let store = Store::volatile(dir.path().into());
            for height in [0, k, 2 * k, 3 * k] {
                store.save_val_state(&val_state(height, 1)).unwrap();
                store.save_comet_hash(height, B256::repeat_byte(height as u8)).unwrap();
            }
            for height in [5, k + 6, 2 * k + 2, 2 * k + 12, 3 * k + 8] {
                store.save_val_updates(height, &updates(height)).unwrap();
            }
            for &height in corrupt {
                store.val_states().corrupt(height);
            }
            (dir, store)
        };

        // Base 2k: the snapshot segments of 0 and k and the update segments up to 2k go.
        let (_dir, store) = setup(&[]);
        assert_eq!(store.prune_val_records(2 * k + 1).unwrap(), 4);
        assert_eq!(snapshots(&store), [2 * k, 3 * k]);
        assert_eq!(recorded(&store), [2 * k + 2, 2 * k + 12, 3 * k + 8]);
        assert_eq!(store.load_val_state(2 * k).unwrap(), Record::Valid(val_state(2 * k, 1)));
        assert_eq!(store.load_val_updates(2 * k + 2).unwrap(), Record::Valid(updates(2 * k + 2)));
        for height in [0, k, 2 * k, 3 * k] {
            assert!(store.load_comet_hash(height).unwrap().is_some(), "comet hash {height}");
        }
        assert_eq!(store.prune_val_records(2 * k + 1).unwrap(), 0, "pruning again finds nothing");

        // A corrupt 2k is no base: base k keeps the corrupt 2k for its recompute.
        let (_dir, store) = setup(&[2 * k]);
        assert_eq!(store.prune_val_records(2 * k + 1).unwrap(), 2);
        assert_eq!(snapshots(&store), [k, 2 * k, 3 * k]);
        assert!(matches!(store.val_states().read(2 * k).unwrap(), Record::Corrupt(_)));
        assert_eq!(recorded(&store), [k + 6, 2 * k + 2, 2 * k + 12, 3 * k + 8]);

        // A floor at a snapshot height keeps that snapshot; the base is the one below it.
        let (_dir, store) = setup(&[]);
        assert_eq!(store.prune_val_records(2 * k).unwrap(), 2);
        assert_eq!(snapshots(&store), [k, 2 * k, 3 * k]);
        assert_eq!(recorded(&store), [k + 6, 2 * k + 2, 2 * k + 12, 3 * k + 8]);

        // No valid snapshot below the floor: nothing is deleted.
        let (_dir, store) = setup(&[0, k, 2 * k]);
        assert_eq!(store.prune_val_records(2 * k + 1).unwrap(), 0);
        assert_eq!(snapshots(&store), [0, k, 2 * k, 3 * k]);
        let (_dir, store) = setup(&[]);
        assert_eq!(store.prune_val_records(0).unwrap(), 0);
        assert_eq!(recorded(&store).len(), 5);
        assert_eq!(
            store.prune_comet_hashes(2 * k + 1).unwrap(),
            2,
            "Comet history is pruned alone"
        );
        assert_eq!(snapshots(&store), [0, k, 2 * k, 3 * k]);
    }

    /// The finalized execution block of `height`, a bare header.
    fn execution_block(height: u64) -> ExecutionBlock {
        let header = alloy_consensus::Header { number: height, ..Default::default() };
        ExecutionBlock { header, transactions: vec![] }
    }

    /// 5,000 committed heights, each with its Comet block ID, validator updates and execution
    /// block, and a validator-state snapshot at the origin and every snapshot height, leave at
    /// most `5,000 / SEGMENT_HEIGHTS + 2` files of each kind, all of them readable back.
    #[test]
    fn files_stay_bounded() {
        const HEIGHTS: u64 = 5_000;
        let dir = tempfile::tempdir().unwrap();
        let store = Store::volatile(dir.path().into());
        let origin = SEGMENT_HEIGHTS - 24;
        let mut state = val_state(origin, 1);
        store.save_val_state(&state).unwrap();
        for height in origin + 1..=origin + HEIGHTS {
            store.save_comet_hash(height, B256::with_last_byte(height as u8)).unwrap();
            store.save_val_updates(height, &[]).unwrap();
            store.save_execution_block(&execution_block(height)).unwrap();
            state = state.advance(&[]).unwrap();
            if height % SEGMENT_HEIGHTS == 0 {
                store.save_val_state(&state).unwrap();
            }
        }
        let names = std::fs::read_dir(dir.path())
            .unwrap()
            .map(|entry| entry.unwrap().file_name().into_string().unwrap())
            .collect::<Vec<_>>();
        let bound = (HEIGHTS / SEGMENT_HEIGHTS + 2) as usize;
        for kind in ["comet-hash-", "val-updates-", "val-state-", "execution-block-"] {
            let files = names.iter().filter(|name| name.starts_with(kind)).count();
            assert!((1..=bound).contains(&files), "{kind}: {files} files, bound {bound}");
        }
        assert!(names.len() <= 4 * bound, "{names:?}");
        let head = origin + HEIGHTS;
        for height in [origin + 1, SEGMENT_HEIGHTS, 3_333, head] {
            let hash = B256::with_last_byte(height as u8);
            assert_eq!(store.load_comet_hash(height).unwrap(), Some(hash), "{height}");
            assert_eq!(store.load_val_updates(height).unwrap(), Record::Valid(vec![]), "{height}");
            let block = store.load_execution_block(height).unwrap();
            assert_eq!(block, Record::Valid(execution_block(height)), "{height}");
        }
        assert_eq!(store.load_val_state(head).unwrap(), Record::Valid(state));
    }

    /// Between snapshots the validator state is recomputed from the newest valid snapshot at or
    /// below the height and the update records above it, a non-empty update list included; a
    /// corrupt snapshot falls back to an older one, and a lost update record on the way is
    /// missing data naming its height.
    #[test]
    fn val_state_between_snapshots_is_recomputed() {
        let k = SEGMENT_HEIGHTS;
        let dir = tempfile::tempdir().unwrap();
        let store = Store::volatile(dir.path().into());
        let origin = k - 24;
        let members = [(test_key(1), 10), (test_key(2), 20), (test_key(3), 30)];
        let mut state = ValState::genesis(origin, &members).unwrap();
        store.save_val_state(&state).unwrap();
        let mut states = BTreeMap::from([(origin, state.clone())]);
        for height in origin + 1..=3 * k + 5 {
            let updates = match height {
                1_500 => vec![(test_key(1), 0), (test_key(4), 40)],
                2_100 => vec![(test_key(4), 7)],
                _ => vec![],
            };
            store.save_val_updates(height, &updates).unwrap();
            state = state.advance(&updates).unwrap();
            if height % k == 0 {
                store.save_val_state(&state).unwrap();
            }
            states.insert(height, state.clone());
        }
        assert_eq!(store.val_states().heights().unwrap(), [origin, k, 2 * k, 3 * k]);
        let load = |height: u64| store.load_val_state(height).unwrap();
        let sample =
            [origin, origin + 1, k - 1, k, k + 1, 1_499, 1_500, 2 * k - 1, 2_100, 3 * k + 5];
        for height in sample {
            assert_eq!(load(height), Record::Valid(states[&height].clone()), "{height}");
        }
        let next = states[&2_100].next.entries.iter().map(|e| e.key).collect::<Vec<_>>();
        assert!(next.contains(&test_key(4)) && !next.contains(&test_key(1)), "{next:?}");
        assert_eq!(load(origin - 1), Record::Missing, "no snapshot at or below it");

        // A corrupt snapshot is skipped for the newest valid one below it.
        store.val_states().corrupt(2 * k);
        assert_eq!(load(2_500), Record::Valid(states[&2_500].clone()));
        // A lost update record between that snapshot and the height is missing data.
        store.val_updates().remove(1_600);
        let Record::Corrupt(reason) = load(2_500) else { panic!("an update record is lost") };
        assert!(reason.contains("record of height 1600 is missing"), "{reason}");
        assert_eq!(load(1_599), Record::Valid(states[&1_599].clone()));
        assert_eq!(load(3 * k + 1), Record::Valid(states[&(3 * k + 1)].clone()));
        // With every snapshot at or below the height corrupt, there is no base.
        store.val_states().corrupt(k);
        store.val_states().corrupt(origin);
        let Record::Corrupt(reason) = load(1_500) else { panic!("no valid snapshot") };
        assert!(reason.contains(&format!("snapshot of height {k} is corrupt")), "{reason}");
    }

    /// After a checkpoint import at s the node holds the authenticated preimage for s − 1 and the
    /// state at s as snapshots. While the committed anchor's checkpoint is s, s − 1's preimage
    /// is the base retention keeps, the state an import package at s carries,
    /// whether or not s − 1 and s share a segment; once the checkpoint passes the next snapshot
    /// height, that snapshot is the base.
    #[test]
    fn prune_keeps_the_import_preimage_base() {
        let k = SEGMENT_HEIGHTS;
        let fx = crate::test_utils::Fixture::genesis(1);
        for s in [2 * k + 2, 2 * k] {
            let dir = tempfile::tempdir().unwrap();
            let store = Store::volatile(dir.path().into());
            let (before, _) = fx.imported_state(s - 1, s - 1);
            let (state, _) = fx.imported_state(s, s);
            store.save_val_state(&before.val_state).unwrap();
            store.install_import(&state, None).unwrap();
            let mut head = state.val_state.clone();
            let next = 3 * k;
            for height in s + 1..=next + 10 {
                store.save_val_updates(height, &[]).unwrap();
                head = head.advance(&[]).unwrap();
                if height % k == 0 {
                    store.save_val_state(&head).unwrap();
                }
            }
            assert_eq!(store.prune_val_records(s).unwrap(), 0, "s = {s}");
            assert_eq!(store.load_val_state(s - 1).unwrap(), Record::Valid(before.val_state));
            assert_eq!(store.load_val_state(s).unwrap(), Record::Valid(state.val_state.clone()));
            let mut expected = state.val_state.clone();
            for _ in s..s + 40 {
                expected = expected.advance(&[]).unwrap();
            }
            assert_eq!(store.load_val_state(s + 40).unwrap(), Record::Valid(expected));

            assert!(store.prune_val_records(next + 1).unwrap() > 0, "s = {s}");
            assert_eq!(store.val_states().heights().unwrap(), [next]);
            assert_eq!(store.load_val_state(s - 1).unwrap(), Record::Missing);
            assert_eq!(store.load_val_state(next + 10).unwrap(), Record::Valid(head));
        }
    }
}

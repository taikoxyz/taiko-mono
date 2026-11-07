//! The persisted app state and its atomic file store.
//!
//! [`AppState`] is everything `FinalizeBlock` needs besides the envelope and the EL: the chain
//! identity, the genesis record and schedule, the committed parent, its anchor facts, the forced
//! inclusion cursor, the known committees and CometBFT's validator state. `Commit` persists it
//! with [`Store::save`]: the JSON is written to `abci-state.json.tmp`, fsynced, renamed over
//! `abci-state.json` and the directory fsynced, so a crash leaves either the old or the new
//! state, never a torn file.

use std::{
    borrow::Cow,
    collections::BTreeMap,
    fmt,
    fs::{self, File},
    io::{self, Write},
    path::{Path, PathBuf},
};

use alloy_primitives::{Address, B256, keccak256};
use serde::{Deserialize, Serialize};

use crate::{
    key::ConsensusKey,
    recovery::RecoveryOrigin,
    schedule::Schedule,
    types::{AnchorState, CommitteeRecord, GenesisRecord, Member, ParentInfo},
    valstate::ValState,
};

/// File name of the persisted state inside the data directory.
pub const STATE_FILE: &str = "abci-state.json";

/// File name [`Store::save`] writes before renaming it to [`STATE_FILE`]; a leftover one is an
/// interrupted save and is discarded by [`Store::load`].
pub const TMP_FILE: &str = "abci-state.json.tmp";

/// Bounded sidecar of the last fully verified runtime committee witness.
pub const COMMITTEE_WITNESS_FILE: &str = "abci-committee-witness.json";

/// Interrupted atomic save of the committee sidecar; removed before loading.
pub const COMMITTEE_WITNESS_TMP_FILE: &str = "abci-committee-witness.json.tmp";

/// One epoch's committee: its record (as deterministically derived from a fixed L1 snapshot) and
/// members.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct CommitteeState {
    /// The committee record of the epoch.
    pub record: CommitteeRecord,
    /// The members, in set-key order; their powers are the CometBFT validator set.
    pub members: Vec<Member>,
}

/// The app's committed state, persisted at every `Commit`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AppState {
    /// Journal schema: 17 for generation zero, 18 exclusively for fresh recovery state.
    pub schema_version: u32,
    /// Mandatory consensus format marker; old saved state has no implicit migration.
    pub app_version: u64,
    /// The 48-byte CometBFT deployment-domain chain ID.
    pub chain_id: String,
    /// Recovery generation authenticated in the deployment domain.
    pub generation: u64,
    /// Fixed authenticated boundary for fresh recovery schema 18; absent in schema 17.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub recovery: Option<RecoveryOrigin>,
    /// Inbox account authenticated at genesis. Required so a restart cannot switch contracts;
    /// state files written without this binding are refused rather than migrated implicitly.
    pub inbox: Address,
    /// The Etna genesis record verified at `InitChain`.
    pub genesis: GenesisRecord,
    /// Logical EL boundary (== `parent.number`); B* or c before the first generation commit.
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
    /// Authenticated active and pending committee records, keyed by their actual target epochs.
    pub committees: BTreeMap<u64, CommitteeState>,
    /// CometBFT's validator state after `last_height` (its `height` is `last_height`): the
    /// generation's genesis state, advanced by every committed height's validator updates. A
    /// required field: a state file without it is refused (no migration).
    pub val_state: ValState,
}

impl AppState {
    /// Derives the epoch schedule from the canonical genesis record.
    pub fn schedule(&self) -> Schedule {
        Schedule::from_genesis(&self.genesis)
    }

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

    /// Target epoch of the authenticated initial committee, on the unchanged global schedule.
    pub fn initial_committee_epoch(&self) -> u64 {
        self.origin_height() / self.genesis.epoch_len
    }

    /// The actually active authenticated set; missing in-generation rotations never fall back.
    pub fn committee_at(&self, height: u64) -> Option<&CommitteeState> {
        self.committees.get(&self.schedule().active_committee_epoch(height, self.origin_height())?)
    }

    /// Drops obsolete records while retaining the set still active at `keep_from_epoch`.
    /// A discarded pre-recovery switch does not make the initial R set obsolete.
    pub fn prune_committees(&mut self, keep_from_epoch: u64) {
        let keep = self
            .schedule()
            .checked_h_first(keep_from_epoch)
            .and_then(|height| self.schedule().active_committee_epoch(height, self.origin_height()))
            .unwrap_or(keep_from_epoch);
        self.committees = self.committees.split_off(&keep);
    }
}

/// Why the state could not be loaded or saved.
#[derive(Debug, thiserror::Error)]
pub enum StoreError {
    /// A checkpoint journal was moved or restored beside another installation.
    #[error("checkpoint import state identity mismatch")]
    ImportIdentity,
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
    /// Replaying the origin or a committed grid height produced a different validator state.
    #[error("conflicting durable validator state at height {0}")]
    ValStateConflict(u64),
    /// Replaying a committed switch height produced different validator updates.
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
    /// A file exists but fails its checksum, decoding or height check; the text names why.
    /// It is missing data to recompute (SYNC-9-7), never a contradiction.
    Corrupt(String),
    /// A well-formed record of that height.
    Valid(T),
}

/// Explicit imported journal container; ordinary stores reject this structural format.
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ImportedState {
    /// Local journal envelope version.
    pub schema: u32,
    /// Immutable operation identity checked against the ready components.
    pub installation_id: B256,
    /// Unmodified application state using its original deployment/recovery schema.
    pub state: AppState,
}

/// Decode a single exact durable image using the caller's verified distinction between
/// ordinary and imported storage. No general state migration or automatic tag adoption.
pub(crate) fn decode_journal(
    bytes: &[u8],
    installation: Option<B256>,
    path: &Path,
) -> Result<AppState, StoreError> {
    let corrupt = |source| StoreError::Corrupt { path: path.to_owned(), source };
    if let Some(id) = installation {
        let tagged: ImportedState = serde_json::from_slice(bytes).map_err(corrupt)?;
        if tagged.schema != 1 || tagged.installation_id != id {
            return Err(StoreError::ImportIdentity)
        }
        Ok(tagged.state)
    } else {
        serde_json::from_slice(bytes).map_err(corrupt)
    }
}

/// Atomic JSON file store for [`AppState`] in one data directory.
#[derive(Clone, Debug)]
pub struct Store {
    /// The data directory holding [`STATE_FILE`]; created on the first save.
    dir: PathBuf,
    /// Whether saves fsync the file and its directory. Only [`Store::volatile`] clears it.
    durable: bool,
    /// Install identity for imported journals; ordinary legacy state is never rewritten.
    import: Option<(B256, u64)>,
    /// Optional independent archive of immutable landed-candidate grid preimages.
    archive: Option<PathBuf>,
}

impl Store {
    /// A store over `dir`. Touches nothing on disk.
    pub fn new(dir: PathBuf) -> Self {
        Self { dir, durable: true, import: None, archive: None }
    }

    /// Open an imported journal only after the caller checked the complete publication
    /// and component identities. This selects a local format, never admission or signing.
    pub fn imported(dir: PathBuf, id: B256, floor: u64) -> Self {
        Self { import: Some((id, floor)), ..Self::new(dir) }
    }

    /// Oldest independently installed execution state; ordinary fully replayed stores have no
    /// import floor.
    pub fn execution_floor(&self) -> Option<u64> {
        self.import.map(|(_, height)| height)
    }

    /// Retain every future grid preimage in a separate operator-managed directory. The
    /// namespace includes the generation-qualified chain ID and never prunes or overwrites.
    pub fn with_val_archive(mut self, archive: Option<PathBuf>) -> Self {
        self.archive = archive;
        self
    }

    /// A store that saves the same files without fsyncing them, for unit tests that commit many
    /// blocks without testing durability. This module's own tests keep [`Store::new`].
    #[cfg(test)]
    pub(crate) fn volatile(dir: PathBuf) -> Self {
        Self { dir, durable: false, import: None, archive: None }
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
        let state = decode_journal(&bytes, self.import.map(|(id, _)| id), &path)?;
        Ok(Some(state))
    }

    /// Reads committed Comet history. Absence keeps checkpoint trust closed until restored.
    /// Entries above the committed AppState height are never evidence of a commit.
    pub fn load_comet_hash(&self, height: u64) -> Result<Option<B256>, StoreError> {
        let path = self.dir.join(COMET_HASH_FILE.name(height));
        match fs::read(&path) {
            Ok(bytes) => serde_json::from_slice(&bytes)
                .map(Some)
                .map_err(|source| StoreError::Corrupt { path, source }),
            Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(None),
            Err(source) => Err(StoreError::Io { op: "read", path, source }),
        }
    }

    /// Durably records one immutable Comet block ID before publishing its committed AppState.
    pub fn save_comet_hash(&self, height: u64, hash: B256) -> Result<(), StoreError> {
        if let Some(previous) = self.load_comet_hash(height)? {
            return if previous == hash { Ok(()) } else { Err(StoreError::CometConflict(height)) };
        }
        let json = serde_json::to_vec(&hash).map_err(StoreError::Encode)?;
        self.save_bytes(&json, &COMET_HASH_FILE.name(height), "comet-hash.tmp")
    }

    /// Deletes the recorded Comet block IDs below `floor` and returns how many it removed. Only
    /// canonical `comet-hash-{height}.json` names are touched. A deletion lost to a crash leaves
    /// a correct immutable record behind, so the directory is not fsynced.
    pub fn prune_comet_hashes(&self, floor: u64) -> Result<usize, StoreError> {
        self.prune_below(floor, COMET_HASH_FILE)
    }

    /// Reads the validator state recorded for the committed height `height` (SYNC-9-5c).
    ///
    /// The record `val-state-{height}.bin` is framed: `keccak256(preimage) ‖ preimage`,
    /// the preimage being [`ValState::encode`]. A file that fails the checksum, does not decode
    /// ([`ValState::decode`], which checks every key and the set order) or holds another height
    /// is [`Record::Corrupt`]: missing data to recompute (SYNC-9-7), never evidence against a
    /// landing. Filesystem errors other than absence are [`StoreError::Io`].
    pub fn load_val_state(&self, height: u64) -> Result<Record<ValState>, StoreError> {
        self.load_framed(VAL_STATE_FILE, height, |preimage| {
            ValState::decode(preimage).map(|state| (state.height, state))
        })
    }

    /// Durably records `state` as the immutable validator state of its height (`state.height`):
    /// at InitChain the generation's origin state, at Commit a grid height's, before the
    /// AppState of that height is published.
    ///
    /// An equal valid record succeeds unchanged (a replay after a crash before the AppState was
    /// saved); a valid record of another state is [`StoreError::ValStateConflict`] and is kept.
    /// A corrupt record is renamed to `val-state-{height}.bin.corrupt`, replacing an earlier
    /// one set aside at that height, and the record is then written.
    pub fn save_val_state(&self, state: &ValState) -> Result<(), StoreError> {
        let found = self.load_val_state(state.height)?;
        self.save_framed(VAL_STATE_RECORD, state.height, found, state, || Ok(state.encode()))
    }

    /// Reads the validator updates recorded for the committed switch height `height`: the
    /// `(key, power)` changes its `FinalizeBlock` returned, possibly none (SYNC-9-5c).
    ///
    /// The record `val-updates-{height}.bin` is framed like a validator-state record,
    /// `keccak256(body) ‖ body`, the body the JSON object of its `height` and `updates` (no
    /// other field). A file that fails the checksum, does not decode (a key included) or holds
    /// another height is [`Record::Corrupt`]: missing data to recompute (SYNC-9-7).
    /// Filesystem errors other than absence are [`StoreError::Io`].
    pub fn load_val_updates(
        &self,
        height: u64,
    ) -> Result<Record<Vec<(ConsensusKey, u64)>>, StoreError> {
        self.load_framed(VAL_UPDATES_FILE, height, |body| {
            serde_json::from_slice::<ValUpdates<'_>>(body)
                .map(|record| (record.height, record.updates.into_owned()))
        })
    }

    /// Durably records `updates` as the immutable validator updates of the switch height
    /// `height` before the AppState of that height is published. Every switch height has one,
    /// an empty list included, so a lost record is missing data, never "no change".
    ///
    /// An equal valid record succeeds unchanged; a valid record of other updates is
    /// [`StoreError::ValUpdatesConflict`] and is kept. A corrupt record is renamed to
    /// `val-updates-{height}.bin.corrupt`, replacing an earlier one set aside at that height,
    /// and the record is then written.
    pub fn save_val_updates(
        &self,
        height: u64,
        updates: &[(ConsensusKey, u64)],
    ) -> Result<(), StoreError> {
        let found = self.load_val_updates(height)?;
        self.save_framed(VAL_UPDATES_RECORD, height, found, updates, || {
            serde_json::to_vec(&ValUpdates { height, updates: Cow::Borrowed(updates) })
                .map_err(StoreError::Encode)
        })
    }

    /// The heights of the canonical `val-state-{height}.bin` records, in ascending order,
    /// whether they load valid or not.
    pub fn val_state_heights(&self) -> Result<Vec<u64>, StoreError> {
        self.heights(VAL_STATE_FILE)
    }

    /// Retires the validator records below the Comet history `floor` and returns how many
    /// files it removed (SYNC-9-5c).
    ///
    /// The base is the newest validator state below `floor` that loads valid: a state the
    /// node holds exactly, from which it recomputes the state at any retained height with the
    /// update records above it. The validator states below the base, the update records at or
    /// below it (the base already includes them) and the corrupt records set aside below
    /// `floor` are deleted; everything else is kept. Without a valid state below `floor`
    /// nothing is deleted. Only canonical names are touched, and as for
    /// [`Store::prune_comet_hashes`] the directory is not fsynced: a deletion lost to a crash
    /// leaves an immutable record behind, which the next pruning removes.
    pub fn prune_val_records(&self, floor: u64) -> Result<usize, StoreError> {
        let mut base = None;
        for height in self.val_state_heights()?.into_iter().rev().filter(|&h| h < floor) {
            if let Record::Valid(_) = self.load_val_state(height)? {
                base = Some(height);
                break;
            }
        }
        let Some(base) = base else { return Ok(0) };
        // `base < floor`, so `base + 1` cannot overflow.
        Ok(self.prune_below(base, VAL_STATE_FILE)? +
            self.prune_below(base + 1, VAL_UPDATES_FILE)? +
            self.prune_below(floor, VAL_STATE_SET_ASIDE)? +
            self.prune_below(floor, VAL_UPDATES_SET_ASIDE)?)
    }

    /// Reads the [`frame`]d record of `kind` at `height` and decodes its body with `decode`
    /// into the height it records and its value; a failed checksum, a failed decoding or
    /// another height is [`Record::Corrupt`].
    fn load_framed<T, E: fmt::Display>(
        &self,
        kind: HeightFile,
        height: u64,
        decode: impl FnOnce(&[u8]) -> Result<(u64, T), E>,
    ) -> Result<Record<T>, StoreError> {
        let path = self.dir.join(kind.name(height));
        let bytes = match fs::read(&path) {
            Ok(bytes) => bytes,
            Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(Record::Missing),
            Err(source) => return Err(StoreError::Io { op: "read", path, source }),
        };
        let Some(body) = unframe(&bytes) else {
            return Ok(Record::Corrupt("the checksum does not match".into()));
        };
        Ok(match decode(body) {
            Err(error) => Record::Corrupt(error.to_string()),
            Ok((recorded, _)) if recorded != height => {
                Record::Corrupt(format!("it holds height {recorded}"))
            }
            Ok((_, value)) => Record::Valid(value),
        })
    }

    /// Durably writes the [`frame`]d `body` as the immutable record of `kind` at `height`,
    /// given the record `found` there: an equal valid one is kept and succeeds, another valid
    /// one is `kind`'s conflict, and a corrupt one is set aside first.
    fn save_framed<T: PartialEq<V>, V: ?Sized>(
        &self,
        kind: FramedRecord,
        height: u64,
        found: Record<T>,
        value: &V,
        body: impl FnOnce() -> Result<Vec<u8>, StoreError>,
    ) -> Result<(), StoreError> {
        let name = kind.file.name(height);
        match found {
            Record::Valid(previous) => {
                return if previous == *value { Ok(()) } else { Err((kind.conflict)(height)) };
            }
            Record::Corrupt(reason) => {
                let path = self.dir.join(&name);
                let aside = self.dir.join(kind.set_aside.name(height));
                tracing::warn!(height, file = %name, %reason, "setting a corrupt record aside");
                // The directory fsync of the save below also makes this rename durable.
                fs::rename(&path, &aside).map_err(|source| io_err("rename", &path, source))?;
            }
            Record::Missing => {}
        }
        self.save_bytes(&frame(&body()?), &name, kind.temporary)
    }

    /// The heights of the canonical names of `kind` in the directory, in ascending order.
    fn heights(&self, kind: HeightFile) -> Result<Vec<u64>, StoreError> {
        let entries = match fs::read_dir(&self.dir) {
            Ok(entries) => entries,
            Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(vec![]),
            Err(source) => return Err(io_err("list", &self.dir, source)),
        };
        let mut heights = vec![];
        for entry in entries {
            let entry = entry.map_err(|source| io_err("list", &self.dir, source))?;
            heights.extend(entry.file_name().to_str().and_then(|name| kind.height(name)));
        }
        heights.sort_unstable();
        Ok(heights)
    }

    /// Deletes the per-height records named by `kind` below `floor` and returns how many it
    /// removed; other names are never touched.
    fn prune_below(&self, floor: u64, kind: HeightFile) -> Result<usize, StoreError> {
        let mut removed = 0;
        for height in self.heights(kind)?.into_iter().take_while(|&height| height < floor) {
            let path = self.dir.join(kind.name(height));
            match fs::remove_file(&path) {
                Ok(()) => removed += 1,
                Err(error) if error.kind() == io::ErrorKind::NotFound => {}
                Err(source) => return Err(io_err("remove", &path, source)),
            }
        }
        Ok(removed)
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

    /// Retain typed supersession only when no previous fatal cause exists. A crash after the
    /// fatal write but before this sidecar intentionally requires manual investigation.
    pub(crate) fn record_supersession(
        &self,
        state: &AppState,
        current: u64,
        reason: &str,
    ) -> Result<(), StoreError> {
        use crate::recovery::supersession::{SUPERSESSION_FILE, SupersessionEvidence};
        if self.fatal_evidence()?.is_some() {
            return Ok(());
        }
        if fs::symlink_metadata(self.dir.join(SUPERSESSION_FILE)).is_ok() {
            return Err(StoreError::BootstrapConflict);
        }
        let path = self.dir.join(STATE_FILE);
        let bytes = fs::read(&path).map_err(|source| StoreError::Io {
            op: "read superseded state",
            path,
            source,
        })?;
        let persisted =
            decode_journal(&bytes, self.import.map(|(id, _)| id), &self.dir.join(STATE_FILE))?;
        if &persisted != state || current <= state.generation {
            return Err(StoreError::BootstrapConflict);
        }
        self.record_fatal(reason)?;
        let evidence = SupersessionEvidence::new(state, current, &bytes, reason.as_bytes());
        self.save_bytes(
            &serde_json::to_vec(&evidence).map_err(StoreError::Encode)?,
            SUPERSESSION_FILE,
            "generation-superseded.pending",
        )
    }

    /// Loads the untrusted committee sidecar bytes and discards an interrupted temporary save.
    /// The app independently authenticates its identity and proof before reuse.
    pub(crate) fn load_committee_witness(&self) -> Result<Option<Vec<u8>>, StoreError> {
        let tmp = self.dir.join(COMMITTEE_WITNESS_TMP_FILE);
        match fs::remove_file(&tmp) {
            Ok(()) => {}
            Err(error) if error.kind() == io::ErrorKind::NotFound => {}
            Err(source) => return Err(StoreError::Io { op: "remove", path: tmp, source }),
        }
        let path = self.dir.join(COMMITTEE_WITNESS_FILE);
        match fs::read(&path) {
            Ok(bytes) => Ok(Some(bytes)),
            Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(None),
            Err(source) => Err(StoreError::Io { op: "read", path, source }),
        }
    }

    /// Atomically saves the complete verified committee sidecar before proposal signing.
    pub(crate) fn save_committee_witness(&self, bytes: &[u8]) -> Result<(), StoreError> {
        self.save_bytes(bytes, COMMITTEE_WITNESS_FILE, COMMITTEE_WITNESS_TMP_FILE)
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

    /// Persists `s` atomically, replacing any previous state.
    ///
    /// Creates the data directory if needed, writes [`TMP_FILE`], fsyncs it, renames it to
    /// [`STATE_FILE`] and (on unix) fsyncs the directory so the rename is durable.
    pub fn save(&self, s: &AppState) -> Result<(), StoreError> {
        if let Some(archive) = &self.archive &&
            s.has_generation_commit() &&
            s.last_height.is_multiple_of(crate::GRID_INTERVAL)
        {
            archive_preimage(archive, s)?;
        }
        let json = match self.import {
            Some((id, _)) => serde_json::to_vec_pretty(&ImportedState {
                schema: 1,
                installation_id: id,
                state: s.clone(),
            }),
            None => serde_json::to_vec_pretty(s),
        }
        .map_err(StoreError::Encode)?;
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

/// Publish an immutable grid preimage in the archive filesystem before its corresponding
/// live journal commit. Equal retries are safe; a conflicting copy is never replaced.
fn archive_preimage(archive: &Path, s: &AppState) -> Result<(), StoreError> {
    use std::os::unix::fs::MetadataExt;
    let metadata = archive.symlink_metadata().map_err(|e| io_err("stat archive", archive, e))?;
    if archive.canonicalize().ok().as_deref() != Some(archive) ||
        !metadata.is_dir() ||
        metadata.mode() & 0o022 != 0
    {
        return Err(StoreError::ImportIdentity)
    }
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

/// The `{prefix}{height}{suffix}` file names of one kind of per-height record.
#[derive(Clone, Copy, Debug)]
struct HeightFile {
    /// The name before the decimal height.
    prefix: &'static str,
    /// The name after the decimal height.
    suffix: &'static str,
}

/// The committed Comet block IDs: `comet-hash-{height}.json`.
const COMET_HASH_FILE: HeightFile = HeightFile { prefix: "comet-hash-", suffix: ".json" };

/// The grid heights' [`frame`]d validator-state records: `val-state-{height}.bin`.
const VAL_STATE_FILE: HeightFile = HeightFile { prefix: "val-state-", suffix: ".bin" };

/// Corrupt validator-state records set aside by [`Store::save_val_state`]:
/// `val-state-{height}.bin.corrupt`.
const VAL_STATE_SET_ASIDE: HeightFile = HeightFile { prefix: "val-state-", suffix: ".bin.corrupt" };

/// The switch heights' [`frame`]d validator-update records: `val-updates-{height}.bin`.
const VAL_UPDATES_FILE: HeightFile = HeightFile { prefix: "val-updates-", suffix: ".bin" };

/// Corrupt validator-update records set aside by [`Store::save_val_updates`]:
/// `val-updates-{height}.bin.corrupt`.
const VAL_UPDATES_SET_ASIDE: HeightFile =
    HeightFile { prefix: "val-updates-", suffix: ".bin.corrupt" };

/// One kind of immutable [`frame`]d per-height record, as [`Store::save_framed`] writes it.
#[derive(Clone, Copy, Debug)]
struct FramedRecord {
    /// Its canonical names.
    file: HeightFile,
    /// The names a corrupt record is set aside under.
    set_aside: HeightFile,
    /// The name a save writes before renaming it.
    temporary: &'static str,
    /// The error of a save meeting a valid record that holds something else.
    conflict: fn(u64) -> StoreError,
}

/// The validator-state records.
const VAL_STATE_RECORD: FramedRecord = FramedRecord {
    file: VAL_STATE_FILE,
    set_aside: VAL_STATE_SET_ASIDE,
    temporary: "val-state.tmp",
    conflict: StoreError::ValStateConflict,
};

/// The validator-update records.
const VAL_UPDATES_RECORD: FramedRecord = FramedRecord {
    file: VAL_UPDATES_FILE,
    set_aside: VAL_UPDATES_SET_ASIDE,
    temporary: "val-updates.tmp",
    conflict: StoreError::ValUpdatesConflict,
};

/// The body of a validator-update record: the switch height and the `(key, power)` updates
/// its `FinalizeBlock` returned, in response order.
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct ValUpdates<'a> {
    /// The switch height.
    height: u64,
    /// The validator updates.
    updates: Cow<'a, [(ConsensusKey, u64)]>,
}

/// A per-height record file: `keccak256(body) ‖ body`. For a validator-state record the body
/// is the ENC-A-29a preimage, so the prefix is the record's own `valStateHash`; for an update
/// record it is the JSON of [`ValUpdates`].
fn frame(body: &[u8]) -> Vec<u8> {
    [keccak256(body).as_slice(), body].concat()
}

/// The body of a [`frame`]d record, or `None` when it is shorter than the checksum or its
/// checksum does not match.
fn unframe(bytes: &[u8]) -> Option<&[u8]> {
    let (checksum, body) = bytes.split_first_chunk::<32>()?;
    (keccak256(body).0 == *checksum).then_some(body)
}

impl HeightFile {
    /// The canonical file name of `height`.
    fn name(self, height: u64) -> String {
        format!("{}{height}{}", self.prefix, self.suffix)
    }

    /// The height a canonical file name of this kind records.
    fn height(self, name: &str) -> Option<u64> {
        let digits = name.strip_prefix(self.prefix)?.strip_suffix(self.suffix)?;
        let height = digits.parse::<u64>().ok()?;
        (height.to_string() == digits).then_some(height)
    }
}

/// Builds a [`StoreError::Io`].
fn io_err(op: &'static str, path: &Path, source: io::Error) -> StoreError {
    StoreError::Io { op, path: path.to_path_buf(), source }
}

/// Fsyncs `dir` so a rename inside it survives a crash (unix only; a no-op elsewhere).
fn sync_dir(dir: &Path) -> Result<(), StoreError> {
    #[cfg(unix)]
    File::open(dir).and_then(|d| d.sync_all()).map_err(|source| io_err("fsync", dir, source))?;
    #[cfg(not(unix))]
    let _ = dir;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::types::InboxFacts;
    use alloy_primitives::{B256, U256};
    use std::fs;

    fn record(epoch: u64) -> CommitteeRecord {
        CommitteeRecord {
            target_epoch: epoch,
            cutoff_l1_block: 100 + epoch,
            checkpoint_index: epoch,
            set_root: B256::repeat_byte(epoch as u8 + 1),
            total_power: 3_000_000_000,
        }
    }

    fn committee(epoch: u64) -> CommitteeState {
        CommitteeState {
            record: record(epoch),
            members: (1..=3u8)
                .map(|i| Member {
                    pubkey: crate::test_utils::key_from_seed(B256::repeat_byte(i)),
                    eff_stake: U256::from(1_000_000_000_000_000_000u128),
                    power: 1_000_000_000,
                })
                .collect(),
        }
    }

    fn state() -> AppState {
        let genesis = GenesisRecord {
            committee_config_hash: crate::committee::committee_config_hash(
                &crate::config::ChainParams::builtin(
                    protocol::shasta::constants::TAIKO_DEVNET_CHAIN_ID,
                )
                .unwrap(),
            ),
            genesis_height: 0,
            l1_0: 1_000,
            epoch_len: 20,
            genesis_hash: B256::repeat_byte(0x66),
            genesis_state_root: B256::repeat_byte(0x77),
            genesis_cutoff: 990,
            forced_inclusion_delay: 3_600,
            max_anchor_age: 7_200,
        };
        AppState {
            schema_version: 17,
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
                },
            },
            forced_cursor: 3,
            committees: (0..4).map(|e| (e, committee(e))).collect(),
            val_state: ValState::genesis(105, &crate::test_utils::powers(&committee(0).members))
                .unwrap(),
        }
    }

    #[test]
    fn detached_import_is_not_legacy_state_and_archived_preimage_survives_pruning() {
        let tmp = tempfile::tempdir().unwrap();
        let root = tmp.path().canonicalize().unwrap();
        let dir = root.join("app");
        let archive = root.join("archive");
        fs::create_dir(&archive).unwrap();
        let id = B256::repeat_byte(9);
        let store = Store::imported(dir.clone(), id, 108).with_val_archive(Some(archive.clone()));
        let mut s = state();
        s.last_height = 108;
        s.parent.number = 108;
        s.val_state.height = 108;
        store.save_val_state(&s.val_state).unwrap();
        store.save(&s).unwrap();
        assert_eq!(store.load().unwrap(), Some(s.clone()));
        assert!(Store::new(dir.clone()).load().is_err());
        assert!(Store::imported(dir.clone(), B256::ZERO, 108).load().is_err());
        // 108 is the base below floor 115 until 114 replaces it.
        assert_eq!(store.prune_val_records(115).unwrap(), 0);
        let mut later = s.val_state.clone();
        later.height = 114;
        store.save_val_state(&later).unwrap();
        assert_eq!(store.prune_val_records(115).unwrap(), 1);
        assert_eq!(store.load_val_state(108).unwrap(), Record::Missing);
        let saved =
            archive.join(format!("{}-108.bin", alloy_primitives::keccak256(s.chain_id.as_bytes())));
        assert_eq!(fs::read(&saved).unwrap(), s.val_state.encode());
        store.save(&s).unwrap();
        fs::write(&saved, b"conflict").unwrap();
        assert!(store.save(&s).is_err());
    }

    /// A sidecar is `keccak256(preimage) ‖ preimage` (the record's own `valStateHash`, then the
    /// ENC-A-29a preimage). A checksum, decoding or height failure is a corrupt record, which
    /// the next save sets aside and replaces; only a well-formed record of the same height
    /// holding another state conflicts (SYNC-9-5b/5c, SYNC-9-7).
    #[test]
    fn val_state_records_are_checksummed_and_corruption_is_not_conflict() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        let mut s = state();
        s.val_state.height = 108;
        let pre = s.val_state.encode();
        store.save_val_state(&s.val_state).unwrap();
        let path = dir.path().join("val-state-108.bin");
        let framed = fs::read(&path).unwrap();
        assert_eq!(framed, [alloy_primitives::keccak256(&pre).0.as_slice(), &pre].concat());
        assert_eq!(store.load_val_state(108).unwrap(), Record::Valid(s.val_state.clone()));

        // The last byte of the first entry's priority word (preimage word 10): the edited body
        // is still a canonical preimage of height 108, so only the checksum catches it.
        let mut flipped = framed.clone();
        flipped[32 + 32 * 10 + 31] ^= 1;
        assert!(ValState::decode(&flipped[32..]).is_ok_and(|v| v.height == 108));
        fs::write(&path, &flipped).unwrap();
        assert!(matches!(store.load_val_state(108).unwrap(), Record::Corrupt(_)));
        fs::write(&path, &framed[..40]).unwrap();
        assert!(matches!(store.load_val_state(108).unwrap(), Record::Corrupt(_)));
        // A valid record of 108 under the name of 114 holds the wrong height.
        fs::write(dir.path().join("val-state-114.bin"), &framed).unwrap();
        assert!(matches!(store.load_val_state(114).unwrap(), Record::Corrupt(_)));

        // Saving over the corrupt 108 sets it aside and writes the record.
        store.save_val_state(&s.val_state).unwrap();
        assert_eq!(fs::read(dir.path().join("val-state-108.bin.corrupt")).unwrap(), &framed[..40]);
        assert_eq!(store.load_val_state(108).unwrap(), Record::Valid(s.val_state.clone()));

        // A well-formed record with another priority at 108 is a conflict, never replaced.
        let mut other = s.val_state.clone();
        other.current.entries[0].priority += 1;
        assert!(matches!(store.save_val_state(&other), Err(StoreError::ValStateConflict(108))));
        assert_eq!(fs::read(&path).unwrap(), framed);
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

    #[test]
    fn load_rejects_state_without_authenticated_inbox() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        store.save(&state()).unwrap();
        let path = dir.path().join(STATE_FILE);
        let mut json: serde_json::Value =
            serde_json::from_slice(&fs::read(&path).unwrap()).unwrap();
        json.as_object_mut().unwrap().remove("inbox");
        fs::write(path, serde_json::to_vec(&json).unwrap()).unwrap();
        assert!(matches!(store.load(), Err(StoreError::Corrupt { .. })));
    }

    /// Newly written state has one canonical source for the epoch schedule.
    #[test]
    fn save_omits_the_redundant_schedule() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        store.save(&state()).unwrap();
        let json: serde_json::Value =
            serde_json::from_slice(&fs::read(dir.path().join(STATE_FILE)).unwrap()).unwrap();
        assert!(json.get("schedule").is_none());
        assert_eq!(store.load().unwrap(), Some(state()));
    }

    /// Newly saved state identifies the initialized genesis record explicitly.
    #[test]
    fn save_uses_genesis_terminology() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        store.save(&state()).unwrap();
        let json: serde_json::Value =
            serde_json::from_slice(&fs::read(dir.path().join(STATE_FILE)).unwrap()).unwrap();
        assert!(json.get("genesis").is_some());
        assert!(json.get("activation").is_none());
        assert!(json["anchor"]["inbox"].get("status").is_none());
        assert!(json["anchor"]["inbox"].get("migration_state").is_none());
        assert_eq!(store.load().unwrap(), Some(state()));
    }

    #[test]
    fn load_rejects_the_legacy_genesis_alias() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        let mut json = serde_json::to_value(state()).unwrap();
        let genesis = json.as_object_mut().unwrap().remove("genesis").unwrap();
        json["activation"] = genesis;
        fs::write(dir.path().join(STATE_FILE), serde_json::to_vec(&json).unwrap()).unwrap();
        assert!(matches!(store.load(), Err(StoreError::Corrupt { .. })));
    }

    #[test]
    fn load_rejects_the_legacy_inbox_status_alias() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        let mut json = serde_json::to_value(state()).unwrap();
        let facts = json["anchor"]["inbox"].as_object_mut().unwrap();
        let status = serde_json::json!(3);
        facts.insert("migration_state".into(), status);
        fs::write(dir.path().join(STATE_FILE), serde_json::to_vec(&json).unwrap()).unwrap();
        assert!(matches!(store.load(), Err(StoreError::Corrupt { .. })));
    }

    #[test]
    fn load_rejects_a_redundant_legacy_schedule() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        let s = state();
        let mut json = serde_json::to_value(&s).unwrap();
        json["schedule"] = serde_json::json!({
            "genesis_height": s.genesis.genesis_height,
            "l1_0": s.genesis.l1_0,
            "epoch_len": s.genesis.epoch_len,
            "genesis_cutoff": s.genesis.genesis_cutoff,
        });
        fs::write(dir.path().join(STATE_FILE), serde_json::to_vec(&json).unwrap()).unwrap();
        assert!(matches!(store.load(), Err(StoreError::Corrupt { .. })));
    }

    /// A state saved while the genesis record still carried the L1 epoch length is refused
    /// rather than loaded without it.
    #[test]
    fn load_rejects_a_state_with_an_l1_epoch_length() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        let mut json = serde_json::to_value(state()).unwrap();
        json["genesis"]["epoch_len_l1"] = 4.into();
        fs::write(dir.path().join(STATE_FILE), serde_json::to_vec(&json).unwrap()).unwrap();
        let err = store.load().expect_err("a state with the removed field must not load");
        assert!(matches!(err, StoreError::Corrupt { .. }), "{err:?}");
    }

    /// A state written before forced inclusion or the validator state lacks its genesis-record,
    /// anchor, cursor or validator-state fields and is refused rather than defaulted (prelaunch:
    /// no migration).
    #[test]
    fn load_rejects_a_state_without_forced_inclusion_fields() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        let current = serde_json::to_value(state()).unwrap();
        for (object, field) in [
            ("", "app_version"),
            ("", "schema_version"),
            ("", "last_comet_hash"),
            ("/committees/0/members/0", "pubkey"),
            ("", "forced_cursor"),
            ("", "val_state"),
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
        s.committees.remove(&0);
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
    fn interrupted_committee_sidecar_save_preserves_the_previous_complete_witness() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().to_path_buf());
        store.save_committee_witness(b"complete verified witness").unwrap();
        fs::write(dir.path().join(COMMITTEE_WITNESS_TMP_FILE), b"partial").unwrap();
        assert_eq!(
            store.load_committee_witness().unwrap(),
            Some(b"complete verified witness".to_vec())
        );
        assert!(!dir.path().join(COMMITTEE_WITNESS_TMP_FILE).exists());
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

    #[test]
    fn prune_committees_drops_epochs_below_the_bound() {
        let mut s = state();
        s.prune_committees(0);
        assert_eq!(s.committees.keys().copied().collect::<Vec<_>>(), [0, 1, 2, 3]);
        s.prune_committees(2);
        assert_eq!(s.committees.keys().copied().collect::<Vec<_>>(), [2, 3]);
        assert_eq!(s.committees[&2], committee(2));
        s.prune_committees(10);
        assert!(s.committees.is_empty());
    }
}

#[cfg(test)]
mod comet_history_tests {
    use super::*;
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
        std::fs::write(dir.path().join("comet-hash-6.json"), b"invalid").unwrap();
        assert!(matches!(reopened.load_comet_hash(6), Err(StoreError::Corrupt { .. })));
    }

    #[test]
    fn pruning_removes_only_comet_hashes_below_the_floor() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::volatile(dir.path().into());
        for height in 1..=5 {
            store.save_comet_hash(height, B256::repeat_byte(height as u8)).unwrap();
        }
        let unrelated = [STATE_FILE, "comet-hash.tmp", "comet-hash-01.json", "comet-hash-x.json"];
        for name in unrelated {
            std::fs::write(dir.path().join(name), b"kept").unwrap();
        }

        assert_eq!(store.prune_comet_hashes(3).unwrap(), 2);

        for height in 1..=2 {
            assert_eq!(store.load_comet_hash(height).unwrap(), None, "height {height}");
        }
        for height in 3..=5 {
            assert_eq!(
                store.load_comet_hash(height).unwrap(),
                Some(B256::repeat_byte(height as u8)),
                "height {height}"
            );
        }
        for name in unrelated {
            assert!(dir.path().join(name).exists(), "{name} is not committed Comet history");
        }
        assert_eq!(store.prune_comet_hashes(3).unwrap(), 0, "pruning again finds nothing");
    }

    /// CometBFT's genesis validator state at `height` of two validators, the first with
    /// `power`.
    fn val_state(height: u64, power: u64) -> ValState {
        use crate::test_utils::test_key;
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
        use crate::test_utils::test_key;
        vec![(test_key(1), height), (test_key(3), 0)]
    }

    /// An update record is `keccak256(body) ‖ body`, the body the JSON of its height and
    /// updates. Like a validator-state record it is immutable once valid, and a checksum,
    /// decoding or height failure is a corrupt record (missing data, SYNC-9-7) that the next save
    /// sets aside; only a valid record of other updates conflicts (SYNC-9-5c).
    #[test]
    fn val_update_records_are_immutable_and_checksummed() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        assert_eq!(store.load_val_updates(7).unwrap(), Record::Missing);

        // Round trip, the empty list of a switch that changes nothing included.
        store.save_val_updates(3, &[]).unwrap();
        assert_eq!(store.load_val_updates(3).unwrap(), Record::Valid(vec![]));
        store.save_val_updates(7, &updates(7)).unwrap();
        let reopened = Store::new(dir.path().into());
        assert_eq!(reopened.load_val_updates(7).unwrap(), Record::Valid(updates(7)));
        let path = dir.path().join("val-updates-7.bin");
        let framed = std::fs::read(&path).unwrap();
        let body = serde_json::json!({ "height": 7, "updates": updates(7) });
        assert_eq!(serde_json::from_slice::<serde_json::Value>(&framed[32..]).unwrap(), body);
        assert_eq!(framed[..32], keccak256(&framed[32..]).0);

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

        // A flipped body byte fails the checksum; a well-formed record of 7 under the name of
        // 8 holds the wrong height; an unknown field or a bad key fails decoding.
        let mut flipped = framed.clone();
        *flipped.last_mut().unwrap() ^= 1;
        std::fs::write(&path, &flipped).unwrap();
        assert!(matches!(reopened.load_val_updates(7).unwrap(), Record::Corrupt(_)));
        std::fs::write(dir.path().join("val-updates-8.bin"), &framed).unwrap();
        assert!(matches!(reopened.load_val_updates(8).unwrap(), Record::Corrupt(_)));
        let unknown = serde_json::json!({ "height": 9, "updates": [], "extra": 1 });
        let bad_key =
            serde_json::json!({ "height": 9, "updates": [[format!("0x{}", "00".repeat(33)), 1]] });
        for body in [unknown, bad_key] {
            let body = serde_json::to_vec(&body).unwrap();
            std::fs::write(dir.path().join("val-updates-9.bin"), frame(&body)).unwrap();
            let record = reopened.load_val_updates(9).unwrap();
            assert!(matches!(record, Record::Corrupt(_)), "{}", String::from_utf8_lossy(&body));
        }

        // Saving over the corrupt 7 sets it aside and writes the record.
        reopened.save_val_updates(7, &updates(7)).unwrap();
        assert_eq!(std::fs::read(dir.path().join("val-updates-7.bin.corrupt")).unwrap(), flipped);
        assert_eq!(std::fs::read(&path).unwrap(), framed);
        assert_eq!(reopened.load_val_updates(7).unwrap(), Record::Valid(updates(7)));
    }

    /// Retention keeps the newest sidecar below the floor that loads valid as the base the
    /// states above it are recomputed from (SYNC-9-5c): it deletes the sidecars below the base,
    /// the update records at or below it (the base already includes them) and the set-aside
    /// corrupt records below the floor. Without a valid base below the floor nothing is deleted.
    #[test]
    fn pruning_keeps_the_newest_valid_record_below_the_floor() {
        let sidecars = |store: &Store| store.val_state_heights().unwrap();
        let records = |dir: &Path| {
            (0..=24)
                .filter(|h| dir.join(format!("val-updates-{h}.bin")).exists())
                .collect::<Vec<u64>>()
        };
        let unrelated = [
            STATE_FILE,
            "val-state.tmp",
            "val-updates.tmp",
            "val-state-06.bin",
            "val-state-x.bin",
            "val-state-6.json",
            "val-updates-06.bin",
            "val-updates-2.json",
        ];
        let setup = |corrupt: &[u64]| {
            let dir = tempfile::tempdir().unwrap();
            let store = Store::volatile(dir.path().into());
            for height in [0, 6, 12, 18] {
                store.save_val_state(&val_state(height, 1)).unwrap();
                store.save_comet_hash(height, B256::repeat_byte(height as u8)).unwrap();
            }
            for height in [2, 6, 10, 14, 20] {
                store.save_val_updates(height, &updates(height)).unwrap();
            }
            for name in unrelated
                .into_iter()
                .chain(["val-state-4.bin.corrupt", "val-updates-8.bin.corrupt"])
                .chain(["val-state-14.bin.corrupt", "val-updates-13.bin.corrupt"])
            {
                std::fs::write(dir.path().join(name), b"kept").unwrap();
            }
            for height in corrupt {
                std::fs::write(dir.path().join(format!("val-state-{height}.bin")), b"bad").unwrap();
            }
            (dir, store)
        };

        // Base 12: sidecars 0 and 6, records 2, 6 and 10 and the set-aside 4 and 8 go.
        let (dir, store) = setup(&[]);
        assert_eq!(store.prune_val_records(13).unwrap(), 7);
        assert_eq!(sidecars(&store), [12, 18]);
        assert_eq!(records(dir.path()), [14, 20]);
        assert_eq!(store.load_val_state(12).unwrap(), Record::Valid(val_state(12, 1)));
        assert_eq!(store.load_val_updates(14).unwrap(), Record::Valid(updates(14)));
        assert!(!dir.path().join("val-state-4.bin.corrupt").exists());
        assert!(!dir.path().join("val-updates-8.bin.corrupt").exists());
        for name in unrelated.into_iter().chain(["val-state-14.bin.corrupt"]) {
            assert!(dir.path().join(name).exists(), "{name} is kept");
        }
        assert!(dir.path().join("val-updates-13.bin.corrupt").exists(), "13 is not below 13");
        for height in [0, 6, 12, 18] {
            assert!(store.load_comet_hash(height).unwrap().is_some(), "comet hash {height}");
        }
        assert_eq!(store.prune_val_records(13).unwrap(), 0, "pruning again finds nothing");

        // A corrupt 12 is no base: base 6 keeps the corrupt 12 for its recompute.
        let (dir, store) = setup(&[12]);
        assert_eq!(store.prune_val_records(13).unwrap(), 5);
        assert_eq!(sidecars(&store), [6, 12, 18]);
        assert!(matches!(store.load_val_state(12).unwrap(), Record::Corrupt(_)));
        assert_eq!(records(dir.path()), [10, 14, 20]);

        // No valid sidecar below the floor: nothing is deleted.
        let (dir, store) = setup(&[0, 6, 12]);
        assert_eq!(store.prune_val_records(13).unwrap(), 0);
        assert_eq!(sidecars(&store), [0, 6, 12, 18]);
        assert_eq!(records(dir.path()), [2, 6, 10, 14, 20]);
        assert!(dir.path().join("val-state-4.bin.corrupt").exists());
        let (dir, store) = setup(&[]);
        assert_eq!(store.prune_val_records(0).unwrap(), 0);
        assert_eq!(records(dir.path()), [2, 6, 10, 14, 20]);
        assert_eq!(store.prune_comet_hashes(13).unwrap(), 3, "Comet history is pruned alone");
        assert_eq!(sidecars(&store), [0, 6, 12, 18]);
    }

    /// Only canonical `val-state-{height}.bin` names count, in ascending height order.
    #[test]
    fn val_state_heights_lists_canonical_sidecars() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::volatile(dir.path().join("absent"));
        assert_eq!(store.val_state_heights().unwrap(), Vec::<u64>::new());
        let store = Store::volatile(dir.path().into());
        for height in [18, 0, 120, 6] {
            store.save_val_state(&val_state(height, 1)).unwrap();
        }
        for name in ["val-state-06.bin", "val-state-7.bin.corrupt", "val-updates-12.bin"] {
            std::fs::write(dir.path().join(name), b"other").unwrap();
        }
        std::fs::write(dir.path().join("val-state-24.bin"), b"corrupt").unwrap();
        assert_eq!(store.val_state_heights().unwrap(), [0, 6, 18, 24, 120]);
    }
}

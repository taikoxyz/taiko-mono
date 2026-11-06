//! The persisted app state and its atomic file store.
//!
//! [`AppState`] is everything `FinalizeBlock` needs besides the envelope and the EL: the chain
//! identity, the genesis record and schedule, the committed parent, its anchor facts, the forced
//! inclusion cursor, the known committees and CometBFT's validator state. `Commit` persists it
//! with [`Store::save`]: the JSON is written to `abci-state.json.tmp`, fsynced, renamed over
//! `abci-state.json` and the directory fsynced, so a crash leaves either the old or the new
//! state, never a torn file.

use std::{
    collections::BTreeMap,
    fs::{self, File},
    io::{self, Write},
    path::{Path, PathBuf},
};

use alloy_primitives::{Address, B256};
use serde::{Deserialize, Serialize};

use crate::{
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
    /// Replaying a committed grid height produced a different validator-state preimage.
    #[error("conflicting durable validator state at height {0}")]
    ValStateConflict(u64),
    /// An immutable recovery bootstrap already exists with different evidence.
    #[error("conflicting immutable recovery bootstrap")]
    BootstrapConflict,
    /// The state could not be serialized to JSON.
    #[error("cannot serialize the app state: {0}")]
    Encode(#[source] serde_json::Error),
}

/// Atomic JSON file store for [`AppState`] in one data directory.
#[derive(Clone, Debug)]
pub struct Store {
    /// The data directory holding [`STATE_FILE`]; created on the first save.
    dir: PathBuf,
    /// Whether saves fsync the file and its directory. Only [`Store::volatile`] clears it.
    durable: bool,
}

impl Store {
    /// A store over `dir`. Touches nothing on disk.
    pub fn new(dir: PathBuf) -> Self {
        Self { dir, durable: true }
    }

    /// A store that saves the same files without fsyncing them, for unit tests that commit many
    /// blocks without testing durability. This module's own tests keep [`Store::new`].
    #[cfg(test)]
    pub(crate) fn volatile(dir: PathBuf) -> Self {
        Self { dir, durable: false }
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
        let state: AppState = serde_json::from_slice(&bytes)
            .map_err(|source| StoreError::Corrupt { path, source })?;
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

    /// Reads the validator-state preimage ([`ValState::encode`]) recorded for the committed grid
    /// height `height`. The bytes are returned as stored; the caller decodes them.
    pub fn load_val_state(&self, height: u64) -> Result<Option<Vec<u8>>, StoreError> {
        let path = self.dir.join(VAL_STATE_FILE.name(height));
        match fs::read(&path) {
            Ok(bytes) => Ok(Some(bytes)),
            Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(None),
            Err(source) => Err(StoreError::Io { op: "read", path, source }),
        }
    }

    /// Durably records the immutable validator-state preimage of the committed grid height
    /// `height` before publishing its committed AppState. Saving the recorded bytes again
    /// succeeds; other bytes are [`StoreError::ValStateConflict`].
    pub fn save_val_state(&self, height: u64, preimage: &[u8]) -> Result<(), StoreError> {
        if let Some(previous) = self.load_val_state(height)? {
            return if previous == preimage {
                Ok(())
            } else {
                Err(StoreError::ValStateConflict(height))
            };
        }
        self.save_bytes(preimage, &VAL_STATE_FILE.name(height), "val-state.tmp")
    }

    /// Deletes the recorded validator-state preimages below `floor` and returns how many it
    /// removed, as [`Store::prune_comet_hashes`] does for `val-state-{height}.bin` names.
    pub fn prune_val_states(&self, floor: u64) -> Result<usize, StoreError> {
        self.prune_below(floor, VAL_STATE_FILE)
    }

    /// Deletes the per-height records named by `kind` below `floor` and returns how many it
    /// removed; other names are never touched.
    fn prune_below(&self, floor: u64, kind: HeightFile) -> Result<usize, StoreError> {
        let entries = match fs::read_dir(&self.dir) {
            Ok(entries) => entries,
            Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(0),
            Err(source) => return Err(io_err("list", &self.dir, source)),
        };
        let mut removed = 0;
        for entry in entries {
            let entry = entry.map_err(|source| io_err("list", &self.dir, source))?;
            let name = entry.file_name();
            let Some(height) = name.to_str().and_then(|name| kind.height(name)) else { continue };
            if height >= floor {
                continue;
            }
            let path = entry.path();
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
        let persisted: AppState = serde_json::from_slice(&bytes)
            .map_err(|source| StoreError::Corrupt { path: self.dir.join(STATE_FILE), source })?;
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

/// The grid heights' validator-state preimages: `val-state-{height}.bin`.
const VAL_STATE_FILE: HeightFile = HeightFile { prefix: "val-state-", suffix: ".bin" };

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

    #[test]
    fn durable_val_states_are_immutable() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        assert_eq!(store.load_val_state(6).unwrap(), None);
        store.save_val_state(6, b"preimage").unwrap();
        let reopened = Store::new(dir.path().into());
        assert_eq!(reopened.load_val_state(6).unwrap(), Some(b"preimage".to_vec()));
        reopened.save_val_state(6, b"preimage").unwrap();
        assert!(matches!(
            reopened.save_val_state(6, b"other"),
            Err(StoreError::ValStateConflict(6))
        ));
        assert_eq!(reopened.load_val_state(6).unwrap(), Some(b"preimage".to_vec()));
    }

    #[test]
    fn pruning_removes_only_val_states_below_the_floor() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::volatile(dir.path().into());
        for height in [6, 12, 18] {
            store.save_val_state(height, &[height as u8]).unwrap();
            store.save_comet_hash(height, B256::repeat_byte(height as u8)).unwrap();
        }
        let unrelated =
            ["val-state.tmp", "val-state-06.bin", "val-state-x.bin", "val-state-6.json"];
        for name in unrelated {
            std::fs::write(dir.path().join(name), b"kept").unwrap();
        }

        assert_eq!(store.prune_val_states(13).unwrap(), 2);

        for height in [6, 12] {
            assert_eq!(store.load_val_state(height).unwrap(), None, "height {height}");
        }
        assert_eq!(store.load_val_state(18).unwrap(), Some(vec![18]));
        for height in [6, 12, 18] {
            assert!(store.load_comet_hash(height).unwrap().is_some(), "comet hash {height}");
        }
        for name in unrelated {
            assert!(dir.path().join(name).exists(), "{name} is not a validator-state sidecar");
        }
        assert_eq!(store.prune_val_states(13).unwrap(), 0, "pruning again finds nothing");
        assert_eq!(store.prune_comet_hashes(13).unwrap(), 2, "and leaves Comet history alone");
        assert_eq!(store.load_val_state(18).unwrap(), Some(vec![18]));
    }
}

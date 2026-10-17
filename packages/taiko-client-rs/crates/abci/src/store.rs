//! The persisted app state and its atomic file store.
//!
//! [`AppState`] is everything `FinalizeBlock` needs besides the envelope and the EL: the chain
//! identity, the genesis record and schedule, the committed parent, its anchor facts, the forced
//! inclusion cursor and the known committees. `Commit` persists it with [`Store::save`]: the JSON
//! is written to `abci-state.json.tmp`, fsynced, renamed over `abci-state.json` and the directory
//! fsynced, so a crash leaves either the old or the new state, never a torn file.

use std::{
    collections::BTreeMap,
    fs::{self, File},
    io::{self, Write},
    path::{Path, PathBuf},
};

use alloy_primitives::Address;
use serde::{Deserialize, Serialize};

use crate::{
    schedule::Schedule,
    types::{AnchorState, CommitteeRecord, GenesisRecord, Member, ParentInfo},
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
    /// Mandatory consensus format marker; old saved state has no implicit migration.
    pub app_version: u64,
    /// CometBFT `chain_id` (`taiko-etna-<l2ChainId>-g<generation>`).
    pub chain_id: String,
    /// Recovery generation of the running chain (the `chain_id` suffix).
    pub generation: u64,
    /// Inbox account authenticated at genesis. Required so a restart cannot switch contracts;
    /// state files written without this binding are refused rather than migrated implicitly.
    pub inbox: Address,
    /// The Etna genesis record verified at `InitChain`.
    pub genesis: GenesisRecord,
    /// Last committed CometBFT height (== `parent.number`); `B*` right after `InitChain`.
    pub last_height: u64,
    /// Summary of the last committed L2 block, the parent of the next height.
    pub parent: ParentInfo,
    /// The L1 anchor of the last committed block and the Inbox facts proven at it.
    pub anchor: AnchorState,
    /// The forced inclusion cursor `c(last_height)`: how many queue entries the chain's blocks
    /// have consumed (0 at `InitChain`). The next block may consume only entry
    /// `forced_cursor`. A required field: a state file without it is refused (no migration).
    pub forced_cursor: u64,
    /// Known committees by epoch: the running epoch's and, once derived, the next one's.
    pub committees: BTreeMap<u64, CommitteeState>,
}

impl AppState {
    /// Derives the epoch schedule from the canonical genesis record.
    pub fn schedule(&self) -> Schedule {
        Schedule::from_genesis(&self.genesis)
    }

    /// Drops every committee of an epoch below `keep_from_epoch`.
    pub fn prune_committees(&mut self, keep_from_epoch: u64) {
        self.committees = self.committees.split_off(&keep_from_epoch);
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
            total_stake: U256::from(3_000_000_000_000_000_000u128),
            total_power: 3_000_000_000,
            encoding_version: 1,
        }
    }

    fn committee(epoch: u64) -> CommitteeState {
        CommitteeState {
            record: record(epoch),
            members: (1..=3u8)
                .map(|i| Member {
                    reward_recipient: alloy_primitives::Address::repeat_byte(0x77),
                    pubkey: B256::repeat_byte(i),
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
            epoch_len_l1: 4,
            genesis_hash: B256::repeat_byte(0x66),
            genesis_state_root: B256::repeat_byte(0x77),
            genesis_cutoff: 990,
            forced_inclusion_delay: 3_600,
            max_anchor_age: 7_200,
        };
        AppState {
            app_version: crate::app::APP_VERSION,
            chain_id: "taiko-etna-167001-g0".to_string(),
            generation: 0,
            inbox: alloy_primitives::address!("00000000000000000000000000000000E7A10001"),
            genesis,
            last_height: 105,
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
                    status: 3,
                    recovery_generation: 0,
                    last_checkpoint_height: 101,
                    last_checkpoint_hash: B256::repeat_byte(0x33),
                    forced_inclusion_head: 2,
                    forced_inclusion_tail: 5,
                },
            },
            forced_cursor: 3,
            committees: (0..4).map(|e| (e, committee(e))).collect(),
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
        assert!(json["anchor"]["inbox"].get("status").is_some());
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
        let status = facts.remove("status").unwrap();
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
            "epoch_len_l1": s.genesis.epoch_len_l1,
            "genesis_cutoff": s.genesis.genesis_cutoff,
        });
        fs::write(dir.path().join(STATE_FILE), serde_json::to_vec(&json).unwrap()).unwrap();
        assert!(matches!(store.load(), Err(StoreError::Corrupt { .. })));
    }

    /// A state written before forced inclusion lacks its genesis-record, anchor and cursor fields
    /// and is refused rather than defaulted (prelaunch: no migration).
    #[test]
    fn load_rejects_a_state_without_forced_inclusion_fields() {
        let dir = tempfile::tempdir().unwrap();
        let store = Store::new(dir.path().into());
        let current = serde_json::to_value(state()).unwrap();
        for (object, field) in [
            ("", "app_version"),
            ("/committees/0/members/0", "reward_recipient"),
            ("", "forced_cursor"),
            ("/genesis", "forced_inclusion_delay"),
            ("/genesis", "max_anchor_age"),
            ("/anchor/inbox", "forced_inclusion_head"),
            ("/anchor/inbox", "forced_inclusion_tail"),
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

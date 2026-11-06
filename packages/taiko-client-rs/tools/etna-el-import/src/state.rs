//! Recompute the leaf root without reading downloaded trie or historical indexes.

use std::{fmt::Display, path::Path};

use alloy_primitives::{B256, KECCAK256_EMPTY, keccak256};
use reth_db::{
    DatabaseEnv,
    mdbx::{DatabaseArguments, DatabaseFlags, TransactionKind, ffi::MDBX_dbi, tx::Tx},
};
use reth_db_api::{
    Database,
    cursor::DbCursorRO,
    models::{SNAP_ATTEMPT_VERSION, SnapAttempt, StorageSettings},
    table::{DupSort, Table},
    tables::{self, RawDupSort, RawTable, RawValue},
    transaction::{DbTx, DbTxMut},
};
use reth_primitives_traits::{
    Account, Bytecode, StorageEntry,
    account::{AccountFlags, compact_ids::*},
};
use reth_trie::{StateRoot, trie_cursor::noop::NoopTrieCursorFactory};
use reth_trie_db::DatabaseHashedCursorFactory;
use serde::Serialize;

/// Maximum leaf writes retained in one scratch MDBX transaction.
const SCRATCH_BATCH: u64 = 10_000;

/// An invalid/incomplete dataset or a failed offline storage operation.
#[derive(Debug, thiserror::Error)]
pub enum ImportError {
    /// A filesystem operation failed before publication.
    #[error("EL import filesystem: {0}")]
    Io(#[from] std::io::Error),
    /// Metadata was not encoded in the pinned supported format.
    #[error("EL import metadata: {0}")]
    Json(#[from] serde_json::Error),
    /// A pinned storage API refused the dataset.
    #[error("EL import database: {0}")]
    Database(String),
    /// Required source material or a local invariant is absent.
    #[error("invalid EL import: {0}")]
    Invalid(&'static str),
    /// Actual state leaves disagree with the authenticated terminal header.
    #[error("EL leaf root {computed} differs from authenticated root {expected}")]
    StateRoot {
        /// Root committed by the authenticated execution header.
        expected: B256,
        /// Root recomputed from all canonical state leaves.
        computed: B256,
    },
}

/// Result of complete local leaf/code verification; this alone does not publish an import.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct StateReport {
    /// Independently recomputed Ethereum state root.
    pub state_root: B256,
    /// Number of canonical account leaves examined.
    pub accounts: u64,
    /// Number of nonzero canonical storage leaves examined.
    pub storage_slots: u64,
    /// Number of stored bytecode rows whose original bytes were hashed.
    pub bytecodes: u64,
    /// Whether hashed state is authoritative under the pinned v2 layout.
    pub storage_v2: bool,
}

/// Preserve lower-level storage failures without treating an error as proof of pruning.
fn db_error(error: impl Display) -> ImportError {
    ImportError::Database(error.to_string())
}

/// Reject path aliases before opening the dataset; callers must pass canonical absolute paths.
pub(crate) fn existing_directory(path: &Path) -> Result<(), ImportError> {
    if !path.is_absolute() || !path.is_dir() || path.canonicalize()? != path {
        return Err(ImportError::Invalid("dataset path must be a canonical absolute directory"));
    }
    for ancestor in path.ancestors() {
        if ancestor.symlink_metadata()?.file_type().is_symlink() {
            return Err(ImportError::Invalid("aliased dataset ancestor"));
        }
    }
    for entry in std::fs::read_dir(path)? {
        let entry = entry?;
        if !entry.file_type()?.is_file() {
            return Err(ImportError::Invalid("nonregular database entry"));
        }
    }
    Ok(())
}

/// Read the same authoritative layout that the pinned runtime uses, rejecting unknown metadata.
fn layout<T: DbTx>(tx: &T) -> Result<StorageSettings, ImportError> {
    if let Some(bytes) = tx.get::<tables::Metadata>("snap_attempt".into()).map_err(db_error)? {
        let json: serde_json::Value = serde_json::from_slice(&bytes)?;
        if json.get("version").and_then(serde_json::Value::as_u64) !=
            Some(u64::from(SNAP_ATTEMPT_VERSION))
        {
            return Err(ImportError::Invalid("unsupported EL snap attempt format"));
        }
        let attempt: SnapAttempt = serde_json::from_value(json)?;
        if !attempt.is_verified() {
            return Err(ImportError::Invalid(
                "complete the EL's pending snap attempt before import",
            ));
        }
    }
    let Some(bytes) = tx.get::<tables::Metadata>("storage_settings".into()).map_err(db_error)?
    else {
        return Ok(StorageSettings::v1());
    };
    let json: serde_json::Value = serde_json::from_slice(&bytes)?;
    if json.as_object().is_none_or(|object| {
        object.len() != 1 || !object.get("storage_v2").is_some_and(serde_json::Value::is_boolean)
    }) {
        return Err(ImportError::Invalid("unsupported storage settings"));
    }
    Ok(serde_json::from_value(json)?)
}

/// The pinned Alethia CLI's TaikoTables adds these ordinary MDBX tables to Reth Tables::ALL
/// (alethia-reth 6ac93d4, crates/cli/src/tables.rs and crates/db/src/model.rs). We inspect
/// only their native names/flags and never interpret or retain publisher origin records.
const ALETHIA_TABLES: [&str; 3] =
    ["StoredL1OriginTable", "StoredL1HeadOriginTable", "BatchToLastBlock"];

/// Check every DBI and physical comparator in a complete pinned Reth or Alethia catalog.
/// Return the checked handles so sanitization clears every table except authenticated leaves.
pub(crate) fn checked_tables<K: TransactionKind>(
    tx: &Tx<K>,
) -> Result<Vec<(&'static str, MDBX_dbi)>, ImportError> {
    let native = tx.inner();
    let catalog = native.open_db(None).map_err(db_error)?;
    let count = native.db_stat_with_dbi(catalog.dbi()).map_err(db_error)?.entries();
    let extensions: &[&str] = if count == tables::Tables::COUNT {
        &[]
    } else if count == tables::Tables::COUNT + ALETHIA_TABLES.len() {
        &ALETHIA_TABLES
    } else {
        return Err(ImportError::Invalid("unexpected physical database schema"));
    };
    tables::Tables::ALL
        .iter()
        .map(|table| (table.name(), table.is_dupsort()))
        .chain(extensions.iter().map(|&name| (name, false)))
        .map(|(name, dupsort)| {
            let dbi = tx.get_dbi_raw(name).map_err(db_error)?;
            let flags = native.db_flags(dbi).map_err(db_error)?;
            let required = if dupsort { DatabaseFlags::DUP_SORT } else { DatabaseFlags::empty() };
            if flags.bits() != required.bits() {
                return Err(ImportError::Invalid("unexpected physical database table flags"));
            }
            Ok((name, dbi))
        })
        .collect()
}

/// Read the pinned compact envelope without constructing an analyzed object from foreign metadata.
/// Legacy raw rows have no derived fields; current analyzed/7702 rows must equal a fresh encoding.
fn check_bytecode(hash: B256, row: &[u8]) -> Result<(), ImportError> {
    const INVALID: ImportError = ImportError::Invalid("invalid compact bytecode");
    let (size, rest) = row.split_first_chunk::<4>().ok_or(INVALID)?;
    let (payload, meta) =
        rest.split_at_checked(u32::from_be_bytes(*size) as usize).ok_or(INVALID)?;
    let (&kind, meta) = meta.split_first().ok_or(INVALID)?;
    let original = match kind {
        LEGACY_RAW_BYTECODE_ID | EIP7702_BYTECODE_ID if meta.is_empty() => payload,
        LEGACY_ANALYZED_BYTECODE_ID => {
            let (length, _) = meta.split_first_chunk::<8>().ok_or(INVALID)?;
            payload
                .get(..usize::try_from(u64::from_be_bytes(*length)).map_err(|_| INVALID)?)
                .ok_or(INVALID)?
        }
        _ => return Err(INVALID),
    };
    if keccak256(original) != hash {
        return Err(ImportError::Invalid("bytecode content does not match its hash"));
    }
    let code = Bytecode::new_raw_checked(original.to_vec().into()).map_err(|_| INVALID)?;
    if kind != LEGACY_RAW_BYTECODE_ID && RawValue::new(code).raw_value() != row {
        return Err(INVALID);
    }
    Ok(())
}

/// Authenticate original bytes and every persisted analysis field before a typed code lookup.
fn verify_bytecodes<T: DbTx>(tx: &T) -> Result<u64, ImportError> {
    let mut cursor = tx.cursor_read::<RawTable<tables::Bytecodes>>().map_err(db_error)?;
    let mut count = 0;
    let mut previous = None;
    for item in cursor.walk(None).map_err(db_error)? {
        let (key, value) = item.map_err(db_error)?;
        let key: [u8; 32] = key
            .raw_key()
            .as_slice()
            .try_into()
            .map_err(|_| ImportError::Invalid("invalid code hash key"))?;
        if previous.replace(key).is_some_and(|last| last >= key) {
            return Err(ImportError::Invalid("noncanonical code hash order"));
        }
        check_bytecode(key.into(), value.raw_value())?;
        count += 1;
    }
    Ok(count)
}

/// Bound the pinned compact account fields before invoking its infallible internal decoder.
fn validate_leaf_encoding<A, S>(tx: &impl DbTx, key_len: usize) -> Result<(), ImportError>
where
    A: Table<Value = Account>,
    S: DupSort<Value = StorageEntry>,
{
    const INVALID: ImportError = ImportError::Invalid("invalid canonical state encoding");
    let mut previous = None;
    let mut accounts = tx.cursor_read::<RawTable<A>>().map_err(db_error)?;
    for row in accounts.walk(None).map_err(db_error)? {
        let (key, value) = row.map_err(db_error)?;
        let raw = value.raw_value();
        if key.raw_key().len() != key_len || raw.len() < Account::bitflag_encoded_bytes() {
            return Err(INVALID);
        }
        let key = key.into_key();
        if previous.as_ref().is_some_and(|last| last >= &key) {
            return Err(INVALID);
        }
        previous = Some(key);
        let (flags, body) = AccountFlags::from(raw);
        let nonce = usize::from(flags.nonce_len());
        let balance = usize::from(flags.balance_len());
        if nonce > 8 ||
            balance > 32 ||
            body.len() != nonce + balance + 32 * usize::from(flags.bytecode_hash_len()) ||
            RawValue::new(value.value().map_err(db_error)?).raw_value() != raw
        {
            return Err(INVALID);
        }
    }
    // DUP_SORT compares the entire encoded value. Two distinct values may share a storage slot.
    let mut previous = None;
    let mut storage = tx.cursor_read::<RawDupSort<S>>().map_err(db_error)?;
    for row in storage.walk(None).map_err(db_error)? {
        let (key, value) = row.map_err(db_error)?;
        let slot = value.raw_value().split_first_chunk::<32>().ok_or(INVALID)?;
        if key.raw_key().len() != key_len || slot.1.len() > 32 || slot.1.first() == Some(&0) {
            return Err(INVALID);
        }
        let pair = (key.into_key(), *slot.0);
        if previous.as_ref().is_some_and(|last| last >= &pair) {
            return Err(INVALID);
        }
        previous = Some(pair);
    }
    Ok(())
}

/// Every nonempty code hash referenced by an account must have a verified stored preimage.
fn check_code<T: DbTx>(tx: &T, account: &Account) -> Result<(), ImportError> {
    if let Some(hash) = account.bytecode_hash &&
        hash != KECCAK256_EMPTY &&
        tx.get::<RawTable<tables::Bytecodes>>(hash.into()).map_err(db_error)?.is_none()
    {
        return Err(ImportError::Invalid("missing referenced bytecode"));
    }
    Ok(())
}

/// Compute a root from complete hashed leaves, with no access to imported intermediate nodes.
fn leaf_root<T: DbTx>(tx: &T) -> Result<B256, ImportError> {
    StateRoot::new(NoopTrieCursorFactory::default(), DatabaseHashedCursorFactory::new(tx))
        .root()
        .map_err(db_error)
}

/// Rehash legacy plain leaves into a private scratch database in bounded write batches.
pub(crate) fn rehash_plain<T: DbTx>(
    source: &T,
    scratch: &DatabaseEnv,
) -> Result<(u64, u64), ImportError> {
    let mut accounts = 0;
    let mut storage_slots = 0;
    let mut write = scratch.tx_mut().map_err(db_error)?;
    let mut cursor = source.cursor_read::<tables::PlainAccountState>().map_err(db_error)?;
    for item in cursor.walk(None).map_err(db_error)? {
        let (address, account) = item.map_err(db_error)?;
        check_code(source, &account)?;
        write.put::<tables::HashedAccounts>(keccak256(address), account).map_err(db_error)?;
        accounts += 1;
        if accounts % SCRATCH_BATCH == 0 {
            write.commit().map_err(db_error)?;
            write = scratch.tx_mut().map_err(db_error)?;
        }
    }
    let mut cursor = source.cursor_read::<tables::PlainStorageState>().map_err(db_error)?;
    for item in cursor.walk(None).map_err(db_error)? {
        let (address, entry) = item.map_err(db_error)?;
        if entry.value.is_zero() ||
            source.get::<tables::PlainAccountState>(address).map_err(db_error)?.is_none()
        {
            return Err(ImportError::Invalid("zero or orphan storage row"));
        }
        write
            .put::<tables::HashedStorages>(
                keccak256(address),
                StorageEntry { key: keccak256(entry.key), value: entry.value },
            )
            .map_err(db_error)?;
        storage_slots += 1;
        if storage_slots % SCRATCH_BATCH == 0 {
            write.commit().map_err(db_error)?;
            write = scratch.tx_mut().map_err(db_error)?;
        }
    }
    write.commit().map_err(db_error)?;
    Ok((accounts, storage_slots))
}

/// Verify complete v2 hashed state leaves, which are canonical state rather than an index.
fn verify_hashed<T: DbTx>(tx: &T) -> Result<(u64, u64), ImportError> {
    let mut accounts = 0;
    let mut storage_slots = 0;
    let mut cursor = tx.cursor_read::<tables::HashedAccounts>().map_err(db_error)?;
    for item in cursor.walk(None).map_err(db_error)? {
        let (_, account) = item.map_err(db_error)?;
        check_code(tx, &account)?;
        accounts += 1;
    }
    let mut cursor = tx.cursor_read::<tables::HashedStorages>().map_err(db_error)?;
    for item in cursor.walk(None).map_err(db_error)? {
        let (address, entry) = item.map_err(db_error)?;
        if entry.value.is_zero() ||
            tx.get::<tables::HashedAccounts>(address).map_err(db_error)?.is_none()
        {
            return Err(ImportError::Invalid("zero or orphan hashed storage row"));
        }
        storage_slots += 1;
    }
    Ok((accounts, storage_slots))
}

/// Verify actual local state/code against a trusted header root without modifying its database.
///
/// Legacy hashed indexes and all imported trie nodes are ignored. V1 state is rehashed into a
/// private temporary database under `scratch_parent`; v2 state is read directly. The source
/// must be offline and its canonical database directory must already exist.
pub fn verify_state(
    database: &Path,
    expected_root: B256,
    scratch_parent: &Path,
) -> Result<StateReport, ImportError> {
    existing_directory(database)?;
    if scratch_parent.canonicalize()?.starts_with(database) {
        return Err(ImportError::Invalid("verification scratch overlaps the source database"));
    }
    let private = crate::offline::private_temp("etna-reader-", scratch_parent)?;
    for name in ["database.version", "mdbx.dat"] {
        crate::offline::sparse_copy(&database.join(name), &private.path().join(name))?;
    }
    verify_owned_state(&private.path().canonicalize()?, expected_root, scratch_parent)
}

/// An owned offline database may create its reader lock locally. Never open the operator's source.
pub(crate) fn verify_owned_state(
    database: &Path,
    expected_root: B256,
    scratch_parent: &Path,
) -> Result<StateReport, ImportError> {
    existing_directory(database)?;
    reth_db::version::check_db_version_file(database)
        .map_err(|_| ImportError::Invalid("unsupported database version"))?;
    let source =
        reth_db::open_db_read_only(database, DatabaseArguments::default()).map_err(db_error)?;
    let tx = crate::offline::scan(&source)?;
    checked_tables(&tx)?;
    let settings = layout(&tx)?;
    let bytecodes = verify_bytecodes(&tx)?;
    let (computed, accounts, storage_slots) = if settings.use_hashed_state() {
        validate_leaf_encoding::<tables::HashedAccounts, tables::HashedStorages>(&tx, 32)?;
        let (accounts, storage_slots) = verify_hashed(&tx)?;
        (leaf_root(&tx)?, accounts, storage_slots)
    } else {
        validate_leaf_encoding::<tables::PlainAccountState, tables::PlainStorageState>(&tx, 20)?;
        let temporary = crate::offline::private_temp("etna-state-", scratch_parent)?;
        let scratch = reth_db::init_db(temporary.path().join("db"), DatabaseArguments::default())
            .map_err(db_error)?;
        let (accounts, storage_slots) = rehash_plain(&tx, &scratch)?;
        let hashed = crate::offline::scan(&scratch)?;
        (leaf_root(&hashed)?, accounts, storage_slots)
    };
    if computed != expected_root {
        return Err(ImportError::StateRoot { expected: expected_root, computed });
    }
    Ok(StateReport {
        state_root: computed,
        accounts,
        storage_slots,
        bytecodes,
        storage_v2: settings.storage_v2,
    })
}

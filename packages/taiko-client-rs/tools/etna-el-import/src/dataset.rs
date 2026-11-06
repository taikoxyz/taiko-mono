//! Rebuild a private pruned baseline rather than trusting a publisher's historical indexes.

use std::{
    fmt::Display,
    fs::{File, OpenOptions},
    io::{Read, Write},
    os::unix::fs::{MetadataExt, OpenOptionsExt},
    path::{Path, PathBuf},
    sync::Arc,
};

use alethia_reth_chainspec::spec::{TaikoChainSpec, TaikoDevnetConfigExt};
use alethia_reth_primitives::engine::TaikoEngineTypes;
use alloy_consensus::Header;
use alloy_genesis::Genesis;
use alloy_primitives::B256;
use reth_chainspec::EthChainSpec;
use reth_db::{DatabaseEnv, mdbx::DatabaseArguments};
use reth_db_api::{
    Database,
    cursor::DbCursorRO,
    models::StorageSettings,
    tables,
    transaction::{DbTx, DbTxMut},
};
use reth_ethereum_primitives::EthPrimitives;
use reth_node_types::{AnyNodeTypes, NodeTypesWithDBAdapter};
use reth_provider::{
    EthStorage, HeaderProvider, ProviderFactory, PruneCheckpointWriter, StageCheckpointWriter,
    StaticFileProviderBuilder, StaticFileWriter, TrieWriter, providers::RocksDBProvider,
};
use reth_prune_types::{PruneCheckpoint, PruneMode, PruneSegment};
use reth_stages_types::{StageCheckpoint, StageId};
use reth_static_file_types::StaticFileSegment;
use reth_tasks::{RayonConfig, RuntimeBuilder, RuntimeConfig, TokioConfig};
use reth_trie::{StateRoot, StateRootProgress, trie_cursor::noop::NoopTrieCursorFactory};
use reth_trie_db::DatabaseHashedCursorFactory;
use serde::{Deserialize, Serialize};

use crate::{
    ElTrust, HeaderManifest, ImportError, StateReport, VerifiedHeaders, install_headers,
    verify_state,
};

/// Private lifecycle claim, issued only after creating a fresh unpublished component directory.
const STAGING_MARKER: &str = ".etna-el-import-staging.json";
/// A completed component is never rebuilt over subsequent runtime progress.
const COMPLETED_MARKER: &str = ".etna-el-import-completed.json";
/// Exclusive in-progress filename; a crash leaves uncertainty for the outer owner to discard.
const RUNNING_MARKER: &str = ".etna-el-import-running";
/// Pinned consensus-side EL library revision.
const ALETHIA_REVISION: &str = "6ac93d4b38e1cd72b993cef1ed1dc2cb0affa7b4";
/// Pinned backing database/static-file implementation revision.
const RETH_REVISION: &str = "d9bd9875fe88dcc0183d78b187ce2ceab0c93e93";
/// Bounded number of derived leaves/updates retained before releasing a write transaction.
const BATCH_ITEMS: u64 = 10_000;

/// Same chain/storage/payload types as the pinned runtime, without starting any service.
type ImportTypes = AnyNodeTypes<EthPrimitives, TaikoChainSpec, EthStorage, TaikoEngineTypes>;
/// Provider backed by the candidate's owned MDBX environment and fresh auxiliary stores.
type ImportFactory = ProviderFactory<NodeTypesWithDBAdapter<ImportTypes, Arc<DatabaseEnv>>>;

/// Strict private claim binding staging to one local plan and exact authenticated header input.
#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct StagingClaim {
    /// Supported local claim format.
    schema: u32,
    /// Opaque lifecycle installation identity, never signing authority.
    installation_id: B256,
    /// Deterministic digest of the helper's typed header manifest.
    manifest_hash: B256,
}

/// Receipt of offline work; even installed=true grants no application trust or signing right.
#[derive(Clone, Debug, Serialize)]
pub struct DatasetReport {
    /// Supported local receipt schema.
    pub schema: u32,
    /// Opaque local operation binding.
    pub installation_id: B256,
    /// Exact helper package version.
    pub helper_version: &'static str,
    /// Actual pinned EL source dependency.
    pub alethia_revision: &'static str,
    /// Actual pinned database/static-file source dependency.
    pub reth_revision: &'static str,
    /// Digest of the typed header context used for this operation.
    pub manifest_hash: B256,
    /// Runtime L2 chain identifier checked against the local chainspec.
    pub chain_id: u64,
    /// Authenticated original EL genesis hash.
    pub genesis_hash: B256,
    /// Selected landed state height s.
    pub height: u64,
    /// Exact selected EL hash.
    pub block_hash: B256,
    /// Independently verified state root.
    pub state_root: B256,
    /// Exact inherited checkpoint height retained by the EL finality fence.
    pub finalized_height: u64,
    /// Exact inherited checkpoint hash, not substituted with s or zero.
    pub finalized_hash: B256,
    /// First retained contiguous context header, excluding a separate genesis singleton.
    pub first_header: u64,
    /// Last retained context header.
    pub last_header: u64,
    /// Number of authenticated context headers installed or requested.
    pub header_count: usize,
    /// Lowest independently available post-state after installation; absent for read-only verify.
    pub state_floor: Option<u64>,
    /// Whether all local baseline writes and normal provider checks completed.
    pub installed: bool,
    /// Actual account/storage/code enumeration and leaf-root measurements.
    pub state: StateReport,
}

/// Preserve the pinned storage error without guessing that it proves history pruning.
fn db_error(error: impl Display) -> ImportError {
    ImportError::Database(error.to_string())
}

/// Derive the original header from the operator's runtime chainspec and compare trusted identities.
fn chain(genesis: &Genesis, trust: &ElTrust) -> Result<(TaikoChainSpec, Header), ImportError> {
    if genesis.config.chain_id != trust.chain_id {
        return Err(ImportError::Invalid("runtime genesis uses another chain id"));
    }
    let spec = runtime_spec(genesis);
    let header = spec.genesis_header().clone();
    if header.hash_slow() != trust.genesis_hash {
        return Err(ImportError::Invalid("runtime original genesis hash differs"));
    }
    Ok((spec, header))
}

/// Apply the pinned native CLI's validated canonical-devnet fork-table repair.
///
/// Generic Genesis conversion omits Taiko's complete Ethereum fork table. The native helper
/// restores it only when every field outside alloc matches the canonical devnet definition;
/// a matching genesis hash alone never authorizes changing a custom runtime configuration.
fn runtime_spec(genesis: &Genesis) -> TaikoChainSpec {
    let parsed = TaikoChainSpec::from(genesis.clone());
    parsed.clone_with_devnet_etna_timestamp(0).unwrap_or(parsed)
}

/// Construct an immutable receipt only from verified local results and trusted expectations.
fn report(
    state: StateReport,
    headers: &VerifiedHeaders<'_>,
    trust: &ElTrust,
    installed: bool,
) -> Result<DatasetReport, ImportError> {
    Ok(DatasetReport {
        schema: 1,
        installation_id: headers.installation_id(),
        helper_version: env!("CARGO_PKG_VERSION"),
        alethia_revision: ALETHIA_REVISION,
        reth_revision: RETH_REVISION,
        manifest_hash: headers.manifest_hash()?,
        chain_id: trust.chain_id,
        genesis_hash: trust.genesis_hash,
        height: headers.terminal().number,
        block_hash: trust.terminal_hash,
        state_root: trust.state_root,
        finalized_height: headers.finalized().number,
        finalized_hash: headers.finalized().hash_slow(),
        first_header: headers.headers()[0].number,
        last_header: headers.terminal().number,
        header_count: headers.headers().len(),
        state_floor: installed.then_some(headers.terminal().number),
        installed,
        state,
    })
}

/// Verify complete local state/code read-only; this does not validate or publish foreign histories.
pub fn verify_dataset(
    data_dir: &Path,
    genesis: &Genesis,
    manifest: &HeaderManifest,
    trust: &ElTrust,
) -> Result<DatasetReport, ImportError> {
    verify_dataset_with_scratch(data_dir, genesis, manifest, trust, &std::env::temp_dir())
}

/// Verify an offline source without writing to it, keeping reader locks and hashed leaves below
/// an independent scratch parent owned by the calling lifecycle.
pub fn verify_dataset_with_scratch(
    data_dir: &Path,
    genesis: &Genesis,
    manifest: &HeaderManifest,
    trust: &ElTrust,
    scratch_parent: &Path,
) -> Result<DatasetReport, ImportError> {
    external_scratch(data_dir, scratch_parent)?;
    let headers = manifest.verify(trust)?;
    chain(genesis, trust)?;
    let state = verify_state(&data_dir.join("db"), trust.state_root, scratch_parent)?;
    report(state, &headers, trust, false)
}

/// The caller may own the dataset's parent, but scratch may not be created in the source itself.
fn external_scratch(data_dir: &Path, scratch_parent: &Path) -> Result<(), ImportError> {
    if scratch_parent.canonicalize()?.starts_with(data_dir.canonicalize()?) {
        return Err(ImportError::Invalid("scratch parent overlaps the EL dataset"));
    }
    Ok(())
}

/// Refuse aliases/special files before deleting or rebuilding a component-owned directory.
fn check_tree(path: &Path) -> Result<(), ImportError> {
    let meta = path.symlink_metadata()?;
    if meta.file_type().is_symlink() ||
        (!meta.is_file() && !meta.is_dir()) ||
        (meta.is_file() && meta.nlink() != 1)
    {
        return Err(ImportError::Invalid("aliased or special dataset artifact"));
    }
    if meta.is_dir() {
        for entry in std::fs::read_dir(path)? {
            check_tree(&entry?.path())?;
        }
    }
    Ok(())
}

/// Read a protected local claim without following a substituted final inode.
fn check_claim(data_dir: &Path, headers: &VerifiedHeaders<'_>) -> Result<(), ImportError> {
    let meta = data_dir.symlink_metadata()?;
    // SAFETY: geteuid has no preconditions or side effects.
    let uid = unsafe { libc::geteuid() };
    if !data_dir.is_absolute() ||
        data_dir.canonicalize()? != data_dir ||
        !meta.is_dir() ||
        meta.mode() & 0o077 != 0 ||
        meta.uid() != uid
    {
        return Err(ImportError::Invalid("EL install requires private canonical owned staging"));
    }
    if data_dir.join(COMPLETED_MARKER).symlink_metadata().is_ok() {
        return Err(ImportError::Invalid("EL component is already installed"));
    }
    for entry in std::fs::read_dir(data_dir)? {
        let entry = entry?;
        let name = entry.file_name();
        if !["db", "static_files", "rocksdb", STAGING_MARKER].iter().any(|allowed| name == *allowed)
        {
            return Err(ImportError::Invalid("unexpected artifact in fresh EL staging"));
        }
        check_tree(&entry.path())?;
    }
    let mut file = OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC)
        .open(data_dir.join(STAGING_MARKER))?;
    let meta = file.metadata()?;
    if !meta.is_file() ||
        meta.mode() & 0o077 != 0 ||
        meta.uid() != uid ||
        meta.nlink() != 1 ||
        meta.len() > 4096
    {
        return Err(ImportError::Invalid("unprotected EL staging claim"));
    }
    let mut bytes = Vec::new();
    file.read_to_end(&mut bytes)?;
    let claim: StagingClaim = serde_json::from_slice(&bytes)?;
    if claim.schema != 1 ||
        claim.installation_id != headers.installation_id() ||
        claim.manifest_hash != headers.manifest_hash()?
    {
        return Err(ImportError::Invalid("EL staging claim belongs to another input"));
    }
    Ok(())
}

/// Remove only copied, alias-free, unpublished auxiliary data and create a fresh component.
fn reset_directory(path: &Path) -> Result<(), ImportError> {
    if path.symlink_metadata().is_ok() {
        check_tree(path)?;
        std::fs::remove_dir_all(path)?;
    }
    std::fs::create_dir(path)?;
    Ok(())
}

/// Establish empty active auxiliary tables while retaining only canonical state/code leaves.
fn sanitize_mdbx(database: &Path, storage_v2: bool) -> Result<(), ImportError> {
    let db = reth_db::open_db(database, DatabaseArguments::default()).map_err(db_error)?;
    let tx = db.tx_mut().map_err(db_error)?;
    let (accounts, storage) = if storage_v2 {
        (tables::Tables::HashedAccounts, tables::Tables::HashedStorages)
    } else {
        (tables::Tables::PlainAccountState, tables::Tables::PlainStorageState)
    };
    let retained = [accounts.name(), storage.name(), tables::Tables::Bytecodes.name()];
    for (name, dbi) in crate::state::checked_tables(&tx)? {
        if !retained.contains(&name) {
            tx.inner().clear_db(dbi).map_err(db_error)?;
        }
    }
    tx.put::<tables::Metadata>(
        "storage_settings".into(),
        serde_json::to_vec(&StorageSettings { storage_v2 })?,
    )
    .map_err(db_error)?;
    tx.commit().map_err(db_error)?;
    Ok(())
}

/// Open the normal pinned provider without healing incomplete frontiers during construction.
pub(crate) fn open_factory(
    data_dir: &Path,
    genesis: &Genesis,
) -> Result<ImportFactory, ImportError> {
    let db = Arc::new(
        reth_db::open_db(data_dir.join("db"), DatabaseArguments::default()).map_err(db_error)?,
    );
    let static_files = StaticFileProviderBuilder::read_write(data_dir.join("static_files"))
        .build::<EthPrimitives>()
        .map_err(db_error)?;
    let rocksdb = RocksDBProvider::builder(data_dir.join("rocksdb"))
        .with_default_tables()
        .build()
        .map_err(db_error)?;
    let pools = RayonConfig {
        cpu_threads: Some(2),
        rpc_threads: Some(2),
        storage_threads: Some(2),
        proof_storage_worker_threads: Some(2),
        proof_account_worker_threads: Some(2),
        prewarming_threads: Some(2),
        bal_streaming_threads: Some(2),
        state_trie_overlay_worker_threads: Some(2),
        ..Default::default()
    };
    let runtime = RuntimeBuilder::new(
        RuntimeConfig::default().with_tokio(TokioConfig::with_worker_threads(1)).with_rayon(pools),
    )
    .build()
    .map_err(db_error)?;
    ProviderFactory::new(db, Arc::new(runtime_spec(genesis)), static_files, rocksdb, runtime)
        .map_err(db_error)
}

/// Rebuild legacy hashed indexes without retaining all leaf bytes or overlapping source writes.
fn rebuild_legacy_hashes(factory: &ImportFactory, parent: &Path) -> Result<(), ImportError> {
    let temporary = crate::offline::private_temp(".etna-hashed-", parent)?;
    let scratch = reth_db::init_db(temporary.path().join("db"), DatabaseArguments::default())
        .map_err(db_error)?;
    {
        let source = crate::offline::scan(factory.db_ref())?;
        crate::state::rehash_plain(&source, &scratch)?;
    }
    let source = crate::offline::scan(&scratch)?;
    let mut target = factory.provider_rw().map_err(db_error)?;
    let mut count = 0u64;
    let mut cursor = source.cursor_read::<tables::HashedAccounts>().map_err(db_error)?;
    for item in cursor.walk(None).map_err(db_error)? {
        let (key, value) = item.map_err(db_error)?;
        target.tx_ref().put::<tables::HashedAccounts>(key, value).map_err(db_error)?;
        count += 1;
        if count.is_multiple_of(BATCH_ITEMS) {
            target.commit().map_err(db_error)?;
            target = factory.provider_rw().map_err(db_error)?;
        }
    }
    let mut cursor = source.cursor_read::<tables::HashedStorages>().map_err(db_error)?;
    for item in cursor.walk(None).map_err(db_error)? {
        let (key, value) = item.map_err(db_error)?;
        target.tx_ref().put::<tables::HashedStorages>(key, value).map_err(db_error)?;
        count += 1;
        if count.is_multiple_of(BATCH_ITEMS) {
            target.commit().map_err(db_error)?;
            target = factory.provider_rw().map_err(db_error)?;
        }
    }
    target.commit().map_err(db_error)?;
    Ok(())
}

/// Recompute and materialize compatible v1/v2 trie caches in bounded progress chunks.
fn rebuild_tries(factory: &ImportFactory, expected: B256) -> Result<(), ImportError> {
    let mut intermediate = None;
    loop {
        let provider = factory.provider_rw().map_err(db_error)?;
        let progress = StateRoot::new(
            NoopTrieCursorFactory::default(),
            DatabaseHashedCursorFactory::new(provider.tx_ref()),
        )
        .with_threshold(BATCH_ITEMS)
        .with_intermediate_state(intermediate.take())
        .root_with_progress()
        .map_err(db_error)?;
        match progress {
            StateRootProgress::Progress(next, _, updates) => {
                provider.write_trie_updates(updates).map_err(db_error)?;
                intermediate = Some(*next);
                provider.commit().map_err(db_error)?;
            }
            StateRootProgress::Complete(computed, _, updates) => {
                if computed != expected {
                    return Err(ImportError::StateRoot { expected, computed });
                }
                provider.write_trie_updates(updates).map_err(db_error)?;
                provider.commit().map_err(db_error)?;
                return Ok(());
            }
        }
    }
}

/// Seed only block-s empty payload/change markers; no row represents invented pre-s history.
fn seed_static_frontiers(data_dir: &Path, height: u64) -> Result<(), ImportError> {
    let files = StaticFileProviderBuilder::read_write(data_dir.join("static_files"))
        .with_blocks_per_file(1)
        .build::<EthPrimitives>()
        .map_err(db_error)?;
    for segment in [
        StaticFileSegment::Transactions,
        StaticFileSegment::Receipts,
        StaticFileSegment::TransactionSenders,
    ] {
        let mut writer = files.get_writer(height, segment).map_err(db_error)?;
        writer.increment_block(height).map_err(db_error)?;
        writer.commit().map_err(db_error)?;
    }
    for segment in [StaticFileSegment::AccountChangeSets, StaticFileSegment::StorageChangeSets] {
        let mut writer = files.get_writer(height, segment).map_err(db_error)?;
        if segment == StaticFileSegment::AccountChangeSets {
            writer.begin_account_changeset(height).map_err(db_error)?;
        } else {
            writer.begin_storage_changeset(height).map_err(db_error)?;
        }
        writer.commit().map_err(db_error)?;
    }
    files.commit().map_err(db_error)?;
    Ok(())
}

/// Record the exact available post-state floor and fresh coherent pipeline frontiers.
fn set_frontiers(factory: &ImportFactory, height: u64) -> Result<(), ImportError> {
    let provider = factory.provider_rw().map_err(db_error)?;
    for id in StageId::ALL {
        provider.save_stage_checkpoint(id, StageCheckpoint::new(height)).map_err(db_error)?;
    }
    for segment in [
        PruneSegment::AccountHistory,
        PruneSegment::StorageHistory,
        PruneSegment::Bodies,
        PruneSegment::Receipts,
        PruneSegment::ContractLogs,
        PruneSegment::SenderRecovery,
        PruneSegment::TransactionLookup,
    ] {
        provider
            .save_prune_checkpoint(
                segment,
                PruneCheckpoint {
                    block_number: Some(height),
                    tx_number: None,
                    prune_mode: PruneMode::Before(height + 1),
                },
            )
            .map_err(db_error)?;
    }
    provider.commit().map_err(db_error)?;
    Ok(())
}

/// Flush all owned native stores before publishing a component completion receipt.
fn sync_tree(path: &Path) -> Result<(), ImportError> {
    if path.is_dir() {
        for entry in std::fs::read_dir(path)? {
            sync_tree(&entry?.path())?;
        }
    }
    File::open(path)?.sync_all()?;
    Ok(())
}

/// Guard against simultaneous helper invocations; uncertain crash residue is not adopted.
struct RunningGuard {
    /// Only the newly created operation filename may be removed by this invocation.
    path: PathBuf,
    /// Retain the fresh private file until every native writer has closed.
    file: File,
}
impl RunningGuard {
    /// Acquire a new filename inside already authenticated private staging.
    fn acquire(data_dir: &Path) -> Result<Self, ImportError> {
        let path = data_dir.join(RUNNING_MARKER);
        let file = OpenOptions::new().write(true).create_new(true).mode(0o600).open(&path)?;
        file.sync_all()?;
        File::open(data_dir)?.sync_all()?;
        Ok(Self { path, file })
    }
    /// Remove our exact named inode after completion; failure keeps the outer operation closed.
    fn finish(self) -> Result<(), ImportError> {
        std::fs::remove_file(&self.path)?;
        File::open(self.path.parent().expect("private staging parent"))?.sync_all()?;
        Ok(())
    }
}
impl Drop for RunningGuard {
    /// Best-effort removal only of this invocation's inode; a failure leaves an unusable staging
    /// path.
    fn drop(&mut self) {
        if let (Ok(named), Ok(opened)) = (self.path.symlink_metadata(), self.file.metadata()) &&
            named.dev() == opened.dev() &&
            named.ino() == opened.ino()
        {
            let _ = std::fs::remove_file(&self.path);
        }
    }
}

/// Build a complete normal-provider-compatible baseline in fresh, offline, unpublished staging.
///
/// Caller owns the operation and preserves original sources and signing state elsewhere.
/// Every through-s body/transaction/receipt/history row is unavailable after this baseline;
/// future normal execution writes genuine post-s data. An interruption never publishes it.
pub fn install_dataset(
    data_dir: &Path,
    genesis: &Genesis,
    manifest: &HeaderManifest,
    trust: &ElTrust,
) -> Result<DatasetReport, ImportError> {
    install(data_dir, genesis, manifest, trust, data_dir)
}

/// Install into claimed private staging, allocating heavy transient state under owned scratch.
pub fn install_dataset_with_scratch(
    data_dir: &Path,
    genesis: &Genesis,
    manifest: &HeaderManifest,
    trust: &ElTrust,
    scratch_parent: &Path,
) -> Result<DatasetReport, ImportError> {
    external_scratch(data_dir, scratch_parent)?;
    install(data_dir, genesis, manifest, trust, scratch_parent)
}

/// Only a successfully checked local claim permits writes and an in-place MDBX reader lock.
fn install(
    data_dir: &Path,
    genesis: &Genesis,
    manifest: &HeaderManifest,
    trust: &ElTrust,
    scratch_parent: &Path,
) -> Result<DatasetReport, ImportError> {
    let headers = manifest.verify(trust)?;
    let (_, genesis_header) = chain(genesis, trust)?;
    check_claim(data_dir, &headers)?;
    let running = RunningGuard::acquire(data_dir)?;
    let state =
        crate::state::verify_owned_state(&data_dir.join("db"), trust.state_root, scratch_parent)?;
    reset_directory(&data_dir.join("static_files"))?;
    reset_directory(&data_dir.join("rocksdb"))?;
    sanitize_mdbx(&data_dir.join("db"), state.storage_v2)?;
    install_headers(
        &data_dir.join("db"),
        &data_dir.join("static_files"),
        &genesis_header,
        &headers,
    )?;
    seed_static_frontiers(data_dir, headers.terminal().number)?;
    let factory = open_factory(data_dir, genesis)?;
    if !state.storage_v2 {
        rebuild_legacy_hashes(&factory, scratch_parent)?;
    }
    rebuild_tries(&factory, trust.state_root)?;
    set_frontiers(&factory, headers.terminal().number)?;
    drop(factory);
    let factory = open_factory(data_dir, genesis)?.assert_consistent().map_err(db_error)?;
    let mut provider = factory.provider().map_err(db_error)?;
    provider.tx_mut().disable_long_read_transaction_safety();
    for header in headers.headers() {
        if provider.header(header.hash_slow()).map_err(db_error)?.as_ref() != Some(header) {
            return Err(ImportError::Invalid(
                "normal EL canonical hash lookup differs after reopen",
            ));
        }
    }
    drop(provider);
    drop(factory);
    sync_tree(&data_dir.join("db"))?;
    sync_tree(&data_dir.join("static_files"))?;
    sync_tree(&data_dir.join("rocksdb"))?;
    let receipt = report(state, &headers, trust, true)?;
    let mut completed = OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .open(data_dir.join(COMPLETED_MARKER))?;
    completed.write_all(&serde_json::to_vec(&receipt)?)?;
    completed.sync_all()?;
    File::open(data_dir)?.sync_all()?;
    running.finish()?;
    Ok(receipt)
}

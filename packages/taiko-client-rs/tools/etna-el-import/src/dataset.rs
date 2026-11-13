//! Rebuild a private pruned baseline rather than trusting a publisher's historical indexes.

use std::{
    fmt::Display,
    fs::{DirBuilder, File},
    os::unix::fs::DirBuilderExt,
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
use serde::Serialize;
use tempfile::TempDir;

use crate::{ElTrust, HeaderManifest, ImportError, StateCounts, VerifiedHeaders, install_headers};

/// Pinned consensus-side EL library revision.
const ALETHIA_REVISION: &str = "20a9282a24b14567ebad82c427f8ceeeaf40aab4";
/// Pinned backing database/static-file implementation revision.
const RETH_REVISION: &str = "3c5f2f11c4e5a5647e6e911cd131ccf1bada4f25";
/// Bounded number of derived leaves/updates retained before releasing a write transaction.
const BATCH_ITEMS: u64 = 10_000;

/// Same chain/storage/payload types as the pinned runtime, without starting any service.
type ImportTypes = AnyNodeTypes<EthPrimitives, TaikoChainSpec, EthStorage, TaikoEngineTypes>;
/// Provider backed by the candidate's owned MDBX environment and fresh auxiliary stores.
type ImportFactory = ProviderFactory<NodeTypesWithDBAdapter<ImportTypes, Arc<DatabaseEnv>>>;

/// Receipt of a completed install; it grants no application trust or signing right.
#[derive(Clone, Debug, Serialize)]
pub struct DatasetReport {
    /// Supported local receipt schema.
    pub schema: u32,
    /// Exact helper package version.
    pub helper_version: &'static str,
    /// Actual pinned EL source dependency.
    pub alethia_revision: &'static str,
    /// Actual pinned database/static-file source dependency.
    pub reth_revision: &'static str,
    /// Runtime L2 chain identifier checked against the local chainspec.
    pub chain_id: u64,
    /// Authenticated original EL genesis hash.
    pub genesis_hash: B256,
    /// Selected landed state height s.
    pub height: u64,
    /// Exact selected EL hash.
    pub block_hash: B256,
    /// Trusted state root, equal to the single root recomputed from the installed leaves.
    pub state_root: B256,
    /// Exact inherited checkpoint height retained by the EL finality fence.
    pub finalized_height: u64,
    /// Exact inherited checkpoint hash, not substituted with s or zero.
    pub finalized_hash: B256,
    /// First retained contiguous context header, excluding a separate genesis singleton.
    pub first_header: u64,
    /// Last retained context header.
    pub last_header: u64,
    /// Number of authenticated context headers installed.
    pub header_count: usize,
    /// Actual account/storage/code enumeration.
    pub state: StateCounts,
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
fn report(state: StateCounts, headers: &VerifiedHeaders<'_>, trust: &ElTrust) -> DatasetReport {
    DatasetReport {
        schema: 1,
        helper_version: env!("CARGO_PKG_VERSION"),
        alethia_revision: ALETHIA_REVISION,
        reth_revision: RETH_REVISION,
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
        state,
    }
}

/// Neither the fresh datadir nor scratch may sit inside the stopped source, which is never written.
fn outside_source(
    source: &Path,
    data_dir: &Path,
    scratch_parent: Option<&Path>,
) -> Result<(), ImportError> {
    let source = source.canonicalize()?;
    let parent = data_dir
        .parent()
        .filter(|_| data_dir.is_absolute())
        .ok_or(ImportError::Invalid("EL datadir must be an absolute path"))?;
    for path in std::iter::once(parent).chain(scratch_parent) {
        if path.canonicalize()?.starts_with(&source) {
            return Err(ImportError::Invalid("EL install target overlaps the stopped source"));
        }
    }
    Ok(())
}

/// Create the absent private datadir and copy only the source's MDBX data and version into it.
fn copy_source(source: &Path, data_dir: &Path) -> Result<PathBuf, ImportError> {
    DirBuilder::new().mode(0o700).create(data_dir).map_err(|e| match e.kind() {
        std::io::ErrorKind::AlreadyExists => ImportError::Invalid("EL datadir already exists"),
        _ => e.into(),
    })?;
    let data_dir = data_dir.canonicalize()?;
    std::fs::create_dir(data_dir.join("db"))?;
    for name in ["mdbx.dat", "database.version"] {
        crate::offline::sparse_copy(
            &source.join("db").join(name),
            &data_dir.join("db").join(name),
        )?;
    }
    Ok(data_dir)
}

/// Establish empty active auxiliary tables while retaining only canonical state/code leaves.
fn sanitize_mdbx(database: &Path, storage_v2: bool) -> Result<(), ImportError> {
    let db = reth_db::open_db(database, crate::offline::write_arguments()).map_err(db_error)?;
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
        reth_db::open_db(data_dir.join("db"), crate::offline::write_arguments())
            .map_err(db_error)?,
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

/// Rebuild legacy hashed indexes from the v1 leaves already rehashed and checked by
/// `verify_owned_state`; sanitizing kept the plain leaves and code they were derived from.
fn rebuild_legacy_hashes(factory: &ImportFactory, hashed: &TempDir) -> Result<(), ImportError> {
    let scratch =
        reth_db::open_db_read_only(hashed.path().join("db"), DatabaseArguments::default())
            .map_err(db_error)?;
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

/// The single state-root computation: recompute the root from the installed leaves only
/// (DATA-5.3-4), compare it to the trusted root and materialize v1/v2 trie caches in bounded
/// progress chunks.
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

/// Flush all owned native stores before returning the install receipt.
fn sync_tree(path: &Path) -> Result<(), ImportError> {
    if path.is_dir() {
        for entry in std::fs::read_dir(path)? {
            sync_tree(&entry?.path())?;
        }
    }
    File::open(path)?.sync_all()?;
    Ok(())
}

/// Build a complete normal-provider-compatible baseline in a fresh datadir from a stopped source.
///
/// The source is only read. The caller owns the operation and discards a failed or interrupted
/// datadir. Every through-s body/transaction/receipt/history row is unavailable after this
/// baseline; future normal execution writes genuine post-s data.
pub fn install_dataset(
    source: &Path,
    data_dir: &Path,
    genesis: &Genesis,
    manifest: &HeaderManifest,
    trust: &ElTrust,
) -> Result<DatasetReport, ImportError> {
    install(source, data_dir, genesis, manifest, trust, None)
}

/// Install as `install_dataset`, allocating heavy transient state under owned scratch.
pub fn install_dataset_with_scratch(
    source: &Path,
    data_dir: &Path,
    genesis: &Genesis,
    manifest: &HeaderManifest,
    trust: &ElTrust,
    scratch_parent: &Path,
) -> Result<DatasetReport, ImportError> {
    install(source, data_dir, genesis, manifest, trust, Some(scratch_parent))
}

/// Copy the stopped source into a fresh datadir, check it and install it once; scratch defaults
/// to the new datadir.
fn install(
    source: &Path,
    data_dir: &Path,
    genesis: &Genesis,
    manifest: &HeaderManifest,
    trust: &ElTrust,
    scratch_parent: Option<&Path>,
) -> Result<DatasetReport, ImportError> {
    let headers = manifest.verify(trust)?;
    let (_, genesis_header) = chain(genesis, trust)?;
    outside_source(source, data_dir, scratch_parent)?;
    let data_dir = &copy_source(source, data_dir)?;
    let scratch_parent = scratch_parent.unwrap_or(data_dir);
    let (state, hashed) = crate::state::verify_owned_state(&data_dir.join("db"), scratch_parent)?;
    std::fs::create_dir(data_dir.join("static_files"))?;
    std::fs::create_dir(data_dir.join("rocksdb"))?;
    sanitize_mdbx(&data_dir.join("db"), state.storage_v2)?;
    install_headers(
        &data_dir.join("db"),
        &data_dir.join("static_files"),
        &genesis_header,
        &headers,
    )?;
    seed_static_frontiers(data_dir, headers.terminal().number)?;
    let factory = open_factory(data_dir, genesis)?;
    if let Some(hashed) = hashed {
        rebuild_legacy_hashes(&factory, &hashed)?;
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
    sync_tree(data_dir)?;
    Ok(report(state, &headers, trust))
}

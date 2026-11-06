use super::{ImportError, StateReport, verify_state};
use alloy_primitives::{Address, B256, U256, keccak256};
use alloy_trie::{HashBuilder, Nibbles, TrieAccount};
use reth_db::{DatabaseEnv, mdbx::DatabaseArguments};
use reth_db_api::{
    Database, tables,
    transaction::{DbTx, DbTxMut},
};
use reth_primitives_traits::{Account, Bytecode, StorageEntry};

fn account_root(address: Address, account: Account) -> B256 {
    account_storage_root(address, account, alloy_trie::EMPTY_ROOT_HASH)
}

fn account_storage_root(address: Address, account: Account, storage_root: B256) -> B256 {
    let leaf = TrieAccount {
        nonce: account.nonce,
        balance: account.balance,
        storage_root,
        code_hash: account.bytecode_hash.unwrap_or(alloy_primitives::KECCAK256_EMPTY),
    };
    let mut trie = HashBuilder::default();
    trie.add_leaf(Nibbles::unpack(keccak256(address)), &alloy_rlp::encode(leaf));
    trie.root()
}

fn fixture(root: &std::path::Path) -> (DatabaseEnv, Address, Account, B256) {
    let db = reth_db::init_db(root, DatabaseArguments::test()).unwrap();
    let address = Address::repeat_byte(0x35);
    let account = Account { nonce: 7, balance: U256::from(19), bytecode_hash: None };
    let tx = db.tx_mut().unwrap();
    tx.put::<tables::PlainAccountState>(address, account).unwrap();
    tx.commit().unwrap();
    (db, address, account, account_root(address, account))
}

fn verify_fixture(dir: &tempfile::TempDir, expected: B256) -> Result<StateReport, ImportError> {
    verify_state(
        &dir.path().join("db").canonicalize().unwrap(),
        expected,
        &dir.path().canonicalize().unwrap(),
    )
}

#[test]
fn verifies_plain_accounts_independently_of_a_forged_hashed_index() {
    let dir = tempfile::tempdir().unwrap();
    let (db, address, account, expected) = fixture(&dir.path().join("db"));
    let tx = db.tx_mut().unwrap();
    tx.put::<tables::HashedAccounts>(keccak256(address), Account { balance: U256::MAX, ..account })
        .unwrap();
    tx.commit().unwrap();
    drop(db);
    let report = verify_fixture(&dir, expected).unwrap();
    assert_eq!(report.state_root, expected);
    assert_eq!(report.accounts, 1);
    assert!(!report.storage_v2);
}

#[test]
fn rejects_changed_plain_balance_despite_a_matching_claimed_root() {
    let dir = tempfile::tempdir().unwrap();
    let (db, address, account, expected) = fixture(&dir.path().join("db"));
    let tx = db.tx_mut().unwrap();
    tx.put::<tables::PlainAccountState>(address, Account { balance: U256::from(20), ..account })
        .unwrap();
    tx.commit().unwrap();
    drop(db);
    assert!(
        matches!(verify_fixture(&dir, expected), Err(ImportError::StateRoot { expected: root, .. }) if root == expected)
    );
}

#[test]
fn rejects_missing_referenced_bytecode_even_when_the_account_root_matches() {
    let dir = tempfile::tempdir().unwrap();
    let (db, address, account, _) = fixture(&dir.path().join("db"));
    let account = Account { bytecode_hash: Some(keccak256([0x60, 0x01])), ..account };
    let expected = account_root(address, account);
    let tx = db.tx_mut().unwrap();
    tx.put::<tables::PlainAccountState>(address, account).unwrap();
    tx.commit().unwrap();
    drop(db);
    assert!(matches!(
        verify_fixture(&dir, expected),
        Err(ImportError::Invalid("missing referenced bytecode"))
    ));
}

#[test]
fn refuses_an_unfinished_snap_attempt_in_a_legacy_layout() {
    let dir = tempfile::tempdir().unwrap();
    let (db, _, _, expected) = fixture(&dir.path().join("db"));
    let tx = db.tx_mut().unwrap();
    let attempt = reth_db_api::models::SnapAttempt::start(
        None,
        alloy_eips::BlockNumHash { number: 0, hash: B256::repeat_byte(0x84) },
        expected,
    );
    tx.put::<tables::Metadata>("snap_attempt".into(), serde_json::to_vec(&attempt).unwrap())
        .unwrap();
    tx.commit().unwrap();
    drop(db);
    assert!(matches!(
        verify_fixture(&dir, expected),
        Err(ImportError::Invalid("complete the EL's pending snap attempt before import"))
    ));
}

#[test]
fn v2_verifies_canonical_hashed_leaves_instead_of_obsolete_plain_state() {
    let dir = tempfile::tempdir().unwrap();
    let (db, address, account, expected) = fixture(&dir.path().join("db"));
    let tx = db.tx_mut().unwrap();
    tx.put::<tables::Metadata>("storage_settings".into(), br#"{"storage_v2":true}"#.to_vec())
        .unwrap();
    tx.put::<tables::HashedAccounts>(keccak256(address), account).unwrap();
    tx.put::<tables::PlainAccountState>(address, Account { balance: U256::MAX, ..account })
        .unwrap();
    tx.commit().unwrap();
    drop(db);
    let report = verify_fixture(&dir, expected).unwrap();
    assert!(report.storage_v2);
    assert_eq!(report.state_root, expected);
}

#[test]
fn accepts_a_verified_snap_record_after_independent_leaf_verification() {
    let dir = tempfile::tempdir().unwrap();
    let (db, address, account, expected) = fixture(&dir.path().join("db"));
    let tx = db.tx_mut().unwrap();
    tx.put::<tables::Metadata>("storage_settings".into(), br#"{"storage_v2":true}"#.to_vec())
        .unwrap();
    tx.put::<tables::HashedAccounts>(keccak256(address), account).unwrap();
    let mut attempt = reth_db_api::models::SnapAttempt::start(
        None,
        alloy_eips::BlockNumHash { number: 0, hash: B256::repeat_byte(0x84) },
        expected,
    );
    attempt.verify();
    tx.put::<tables::Metadata>("snap_attempt".into(), serde_json::to_vec(&attempt).unwrap())
        .unwrap();
    tx.commit().unwrap();
    drop(db);
    assert_eq!(verify_fixture(&dir, expected).unwrap().state_root, expected);
}

#[test]
fn verifies_referenced_code_and_rejects_changed_bytes_under_the_same_key() {
    let dir = tempfile::tempdir().unwrap();
    let (db, address, account, _) = fixture(&dir.path().join("db"));
    let code = alloy_primitives::Bytes::from_static(&[0x60, 0x01]);
    let code_hash = keccak256(&code);
    let account = Account { bytecode_hash: Some(code_hash), ..account };
    let expected = account_root(address, account);
    let tx = db.tx_mut().unwrap();
    tx.put::<tables::PlainAccountState>(address, account).unwrap();
    tx.put::<tables::Bytecodes>(code_hash, Bytecode::new_raw(code)).unwrap();
    tx.commit().unwrap();
    drop(db);
    assert_eq!(verify_fixture(&dir, expected).unwrap().bytecodes, 1);
    let db = reth_db::open_db(dir.path().join("db"), DatabaseArguments::test()).unwrap();
    let tx = db.tx_mut().unwrap();
    tx.put::<tables::Bytecodes>(
        code_hash,
        Bytecode::new_raw(alloy_primitives::Bytes::from_static(&[0x60, 0x02])),
    )
    .unwrap();
    tx.commit().unwrap();
    drop(db);
    assert!(matches!(
        verify_fixture(&dir, expected),
        Err(ImportError::Invalid("bytecode content does not match its hash"))
    ));
}

#[test]
fn authenticates_storage_values_and_rejects_orphan_storage() {
    let dir = tempfile::tempdir().unwrap();
    let (db, address, account, _) = fixture(&dir.path().join("db"));
    let slot = B256::repeat_byte(0x78);
    let value = U256::from(9);
    let mut trie = HashBuilder::default();
    trie.add_leaf(Nibbles::unpack(keccak256(slot)), &alloy_rlp::encode(value));
    let expected = account_storage_root(address, account, trie.root());
    let tx = db.tx_mut().unwrap();
    tx.put::<tables::PlainStorageState>(address, StorageEntry { key: slot, value }).unwrap();
    tx.commit().unwrap();
    drop(db);
    assert_eq!(verify_fixture(&dir, expected).unwrap().storage_slots, 1);
    let db = reth_db::open_db(dir.path().join("db"), DatabaseArguments::test()).unwrap();
    let tx = db.tx_mut().unwrap();
    tx.put::<tables::PlainStorageState>(
        Address::repeat_byte(0x79),
        StorageEntry { key: slot, value },
    )
    .unwrap();
    tx.commit().unwrap();
    drop(db);
    assert!(matches!(
        verify_fixture(&dir, expected),
        Err(ImportError::Invalid("zero or orphan storage row"))
    ));
}

#[test]
fn rejects_an_added_storage_value_when_the_authenticated_account_had_empty_storage() {
    let dir = tempfile::tempdir().unwrap();
    let (db, address, _, expected) = fixture(&dir.path().join("db"));
    let tx = db.tx_mut().unwrap();
    tx.put::<tables::PlainStorageState>(
        address,
        StorageEntry { key: B256::repeat_byte(0x81), value: U256::from(11) },
    )
    .unwrap();
    tx.commit().unwrap();
    drop(db);
    assert!(matches!(verify_fixture(&dir, expected), Err(ImportError::StateRoot { .. })));
}

fn header_manifest() -> (super::HeaderManifest, super::ElTrust) {
    let mut headers = Vec::new();
    for number in 600..=900 {
        let header = alloy_consensus::Header {
            number,
            timestamp: 1000 + number,
            parent_hash: headers
                .last()
                .map_or(B256::repeat_byte(0x12), alloy_consensus::Header::hash_slow),
            state_root: B256::repeat_byte(0x13),
            ..Default::default()
        };
        headers.push(header);
    }
    let trust = super::ElTrust {
        chain_id: 167001,
        genesis_hash: B256::repeat_byte(0x14),
        terminal_hash: headers.last().unwrap().hash_slow(),
        state_root: headers.last().unwrap().state_root,
    };
    let manifest = super::HeaderManifest {
        schema: 1,
        installation_id: B256::repeat_byte(0xa1),
        chain_id: trust.chain_id,
        origin: 600,
        unsettled_limit: 3600,
        finalized_height: 610,
        finalized_hash: headers[10].hash_slow(),
        headers,
    };
    (manifest, trust)
}

#[test]
fn retains_a_finalized_ancestor_more_than_255_headers_behind_the_import() {
    let (manifest, trust) = header_manifest();
    let verified = manifest.verify(&trust).unwrap();
    assert_eq!(verified.terminal().number, 900);
    assert_eq!(verified.finalized().number, 610);
    assert_eq!(verified.headers().first().unwrap().number, 600);
}

#[test]
fn refuses_a_255_only_header_window_and_a_rebound_finalized_hash() {
    let (manifest, trust) = header_manifest();
    let mut shortened = manifest.clone();
    shortened.headers.retain(|header| header.number >= 645);
    assert!(shortened.verify(&trust).is_err());
    let mut rebound = manifest;
    rebound.finalized_hash = trust.terminal_hash;
    assert!(rebound.verify(&trust).is_err());
}

#[test]
fn retains_the_inherited_fence_at_s_minus_u_until_the_next_anchor_advances() {
    let (mut manifest, trust) = header_manifest();
    manifest.origin = 0;
    manifest.unsettled_limit = 300;
    manifest.finalized_height = 600;
    manifest.finalized_hash = manifest.headers[0].hash_slow();
    let verified = manifest.verify(&trust).unwrap();
    assert_eq!(verified.finalized().number, 600);
    assert_eq!(verified.headers().first().unwrap().number, 600);
}

#[test]
fn reopens_sparse_static_headers_and_real_hash_number_indexes() {
    use reth_ethereum_primitives::EthPrimitives;
    use reth_provider::{HeaderProvider, StaticFileProviderBuilder, StaticFileWriter};
    use reth_static_file_types::StaticFileSegment;
    let dir = tempfile::tempdir().unwrap();
    let database = dir.path().join("db");
    let db = reth_db::init_db(&database, DatabaseArguments::test()).unwrap();
    let tx = db.tx_mut().unwrap();
    tx.put::<tables::HeaderNumbers>(B256::repeat_byte(0x90), 599).unwrap();
    tx.commit().unwrap();
    drop(db);
    let static_files = dir.path().join("static_files");
    std::fs::create_dir(&static_files).unwrap();
    let genesis = alloy_consensus::Header::default();
    let (manifest, mut trust) = header_manifest();
    trust.genesis_hash = genesis.hash_slow();
    let verified = manifest.verify(&trust).unwrap();
    super::install_headers(
        &database.canonicalize().unwrap(),
        &static_files.canonicalize().unwrap(),
        &genesis,
        &verified,
    )
    .unwrap();
    let provider =
        StaticFileProviderBuilder::read_only(&static_files).build::<EthPrimitives>().unwrap();
    assert_eq!(
        provider.header_by_number(610).unwrap().unwrap().hash_slow(),
        manifest.finalized_hash
    );
    assert!(provider.header_by_number(599).unwrap().is_none());
    assert_eq!(provider.header_by_number(0).unwrap().unwrap(), genesis);
    drop(provider);
    let successor = alloy_consensus::Header {
        number: 901,
        timestamp: 1901,
        parent_hash: trust.terminal_hash,
        ..Default::default()
    };
    let provider =
        StaticFileProviderBuilder::read_write(&static_files).build::<EthPrimitives>().unwrap();
    {
        let mut writer = provider.get_writer(901, StaticFileSegment::Headers).unwrap();
        writer.append_header(&successor, &successor.hash_slow()).unwrap();
        writer.commit().unwrap();
    }
    provider.commit().unwrap();
    drop(provider);
    let provider =
        StaticFileProviderBuilder::read_only(&static_files).build::<EthPrimitives>().unwrap();
    assert_eq!(provider.header_by_number(901).unwrap().unwrap(), successor);
    drop(provider);
    let db = reth_db::open_db_read_only(&database, DatabaseArguments::test()).unwrap();
    let tx = db.tx().unwrap();
    assert_eq!(tx.get::<tables::HeaderNumbers>(manifest.finalized_hash).unwrap(), Some(610));
    assert_eq!(tx.get::<tables::HeaderNumbers>(B256::repeat_byte(0x90)).unwrap(), None);
}

struct DatasetFixture {
    dir: tempfile::TempDir,
    genesis: alloy_genesis::Genesis,
    manifest: super::HeaderManifest,
    trust: super::ElTrust,
    address: Address,
    account: Account,
}

fn dataset_fixture(storage_v2: bool) -> DatasetFixture {
    use reth_chainspec::EthChainSpec;
    use std::os::unix::fs::PermissionsExt;
    let dir = tempfile::tempdir().unwrap();
    std::fs::set_permissions(dir.path(), std::fs::Permissions::from_mode(0o700)).unwrap();
    let (db, address, account, root) = fixture(&dir.path().join("db"));
    let tx = db.tx_mut().unwrap();
    if storage_v2 {
        tx.put::<tables::Metadata>("storage_settings".into(), br#"{"storage_v2":true}"#.to_vec())
            .unwrap();
        tx.put::<tables::HashedAccounts>(keccak256(address), account).unwrap();
    }
    tx.put::<tables::Metadata>("downloaded-control".into(), b"untrusted".to_vec()).unwrap();
    tx.put::<tables::TransactionHashNumbers>(B256::repeat_byte(0xf1), 123).unwrap();
    tx.commit().unwrap();
    drop(db);
    let genesis: alloy_genesis::Genesis = serde_json::from_value(serde_json::json!({
        "config":{"chainId":167001},"gasLimit":"0x2aea540","difficulty":"0x0",
        "timestamp":"0x0","extraData":"0x",
        "alloc":{(address.to_string()):{"balance":"0x13","nonce":"0x7"}}
    }))
    .unwrap();
    let spec = alethia_reth_chainspec::spec::TaikoChainSpec::from(genesis.clone());
    assert_eq!(spec.genesis_header().state_root, root);
    let (mut manifest, mut trust) = header_manifest();
    let mut parent = manifest.headers[0].parent_hash;
    for header in &mut manifest.headers {
        header.state_root = root;
        header.parent_hash = parent;
        parent = header.hash_slow();
    }
    trust.genesis_hash = spec.genesis_header().hash_slow();
    trust.terminal_hash = parent;
    trust.state_root = root;
    manifest.finalized_hash = manifest.headers[10].hash_slow();
    let verified = manifest.verify(&trust).unwrap();
    let marker = serde_json::json!({"schema":1,"installation_id":manifest.installation_id,
        "manifest_hash":verified.manifest_hash().unwrap()});
    std::fs::write(
        dir.path().join(".etna-el-import-staging.json"),
        serde_json::to_vec(&marker).unwrap(),
    )
    .unwrap();
    std::fs::set_permissions(
        dir.path().join(".etna-el-import-staging.json"),
        std::fs::Permissions::from_mode(0o600),
    )
    .unwrap();
    DatasetFixture { dir, genesis, manifest, trust, address, account }
}

#[test]
fn installs_a_pruned_baseline_and_rejects_pre_checkpoint_state_in_both_layouts() {
    use reth_provider::StateProviderFactory;
    for storage_v2 in [false, true] {
        let f = dataset_fixture(storage_v2);
        let data_dir = f.dir.path().canonicalize().unwrap();
        let report = super::install_dataset(&data_dir, &f.genesis, &f.manifest, &f.trust).unwrap();
        assert!(report.installed);
        assert_eq!(report.state_floor, Some(900));
        assert_eq!(report.state.state_root, f.trust.state_root);
        let factory = super::dataset::open_factory(&data_dir, &f.genesis)
            .unwrap()
            .assert_consistent()
            .unwrap();
        assert_eq!(factory.latest().unwrap().basic_account(&f.address).unwrap(), Some(f.account));
        let provider = reth_provider::providers::BlockchainProvider::new(factory).unwrap();
        if let Ok(old) = provider.history_by_block_number(899) {
            assert!(
                old.basic_account(&f.address).is_err(),
                "authenticated old headers cannot authorize downloaded old state"
            )
        }
        drop(provider);
        let db =
            reth_db::open_db_read_only(data_dir.join("db"), DatabaseArguments::test()).unwrap();
        let tx = db.tx().unwrap();
        assert_eq!(
            tx.get::<tables::TransactionHashNumbers>(B256::repeat_byte(0xf1)).unwrap(),
            None
        );
        assert_eq!(tx.get::<tables::Metadata>("downloaded-control".into()).unwrap(), None);
    }
}

#[test]
fn verifies_canonical_devnet_alloc_variants_with_the_runtime_fork_table() {
    use alethia_reth_chainspec::{TAIKO_DEVNET, spec::TaikoDevnetConfigExt};
    use reth_chainspec::EthChainSpec;
    let mut f = dataset_fixture(false);
    let mut canonical = TAIKO_DEVNET.genesis().clone();
    canonical.alloc = f.genesis.alloc.clone();
    let configured = alethia_reth_chainspec::spec::TaikoChainSpec::from(canonical.clone())
        .clone_with_devnet_etna_timestamp(0)
        .unwrap();
    f.trust.genesis_hash = configured.genesis_header().hash_slow();
    let report = super::verify_dataset(
        &f.dir.path().canonicalize().unwrap(),
        &canonical,
        &f.manifest,
        &f.trust,
    )
    .unwrap();
    assert_eq!(report.genesis_hash, f.trust.genesis_hash);
    assert_eq!(report.state_root, f.trust.state_root);
}

#[test]
fn review_rejects_foreign_bytecode_analysis_and_malformed_compact_data() {
    use reth_db_api::tables::{RawTable, RawValue};
    let dir = tempfile::tempdir().unwrap();
    let (db, _, _, expected) = fixture(&dir.path().join("db"));
    let code = Bytecode::new_raw(vec![0x60, 0x01, 0x5b].into());
    let hash = keccak256(code.original_byte_slice());
    let mut altered = RawValue::new(code).into_value();
    let mut padding = altered.clone();
    let last_payload = 3 + u32::from_be_bytes(padding[..4].try_into().unwrap()) as usize;
    assert!(last_payload >= 7);
    padding[last_payload] ^= 1;
    *altered.last_mut().unwrap() ^= 1;
    drop(db);
    for bad in [altered, padding, vec![0], vec![0, 0, 0, 0, 1]] {
        let db = reth_db::open_db(dir.path().join("db"), DatabaseArguments::test()).unwrap();
        let tx = db.tx_mut().unwrap();
        tx.put::<RawTable<tables::Bytecodes>>(hash.into(), RawValue::from_vec(bad)).unwrap();
        tx.commit().unwrap();
        drop(db);
        assert!(verify_fixture(&dir, expected).is_err(), "invalid compact bytecode accepted");
    }
}

#[test]
fn review_accepts_checked_native_eip7702_bytecode() {
    let dir = tempfile::tempdir().unwrap();
    let (db, _, _, expected) = fixture(&dir.path().join("db"));
    let code = Bytecode::new_raw([&[0xef, 0x01, 0x00][..], &[0x19; 20]].concat().into());
    assert!(code.is_eip7702());
    let tx = db.tx_mut().unwrap();
    tx.put::<tables::Bytecodes>(keccak256(code.original_byte_slice()), code).unwrap();
    tx.commit().unwrap();
    drop(db);
    assert_eq!(verify_fixture(&dir, expected).unwrap().bytecodes, 1);
}

#[test]
fn review_rejects_noncanonical_physical_table_schema() {
    use reth_db::mdbx::DatabaseFlags;
    let dir = tempfile::tempdir().unwrap();
    let (db, address, account, expected) = fixture(&dir.path().join("db"));
    drop(db);
    let db = reth_db::open_db(dir.path().join("db"), DatabaseArguments::test()).unwrap();
    let name = reth_db_api::Tables::PlainAccountState.name();
    db.drop_orphan_table(name).unwrap();
    let tx = db.tx_mut().unwrap();
    tx.inner().create_db(Some(name), DatabaseFlags::DUP_SORT).unwrap();
    tx.put::<tables::PlainAccountState>(address, account).unwrap();
    tx.commit().unwrap();
    drop(db);
    assert!(verify_fixture(&dir, expected).is_err(), "unexpected native DB flags accepted");
}

#[test]
fn review_full_scan_read_transaction_outlives_interactive_timeout() {
    use reth_db::mdbx::MaxReadTransactionDuration;
    use std::time::Duration;
    let dir = tempfile::tempdir().unwrap();
    let (db, address, account, _) = fixture(&dir.path().join("db"));
    drop(db);
    let db = reth_db::open_db_read_only(
        dir.path().join("db"),
        DatabaseArguments::test().with_max_read_transaction_duration(Some(
            MaxReadTransactionDuration::Set(Duration::from_millis(20)),
        )),
    )
    .unwrap();
    let bounded = db.tx().unwrap();
    let scan = crate::offline::scan(&db).unwrap();
    std::thread::sleep(Duration::from_millis(1200));
    assert!(bounded.get::<tables::PlainAccountState>(address).is_err());
    assert_eq!(scan.get::<tables::PlainAccountState>(address).unwrap(), Some(account));
}

fn install_multichunk_state(storage_v2: bool) {
    use std::collections::BTreeMap;
    const N: u64 = 75_011;
    let mut f = dataset_fixture(storage_v2);
    let data = f.dir.path().canonicalize().unwrap();
    let db = reth_db::open_db(data.join("db"), DatabaseArguments::test()).unwrap();
    let mut tx = db.tx_mut().unwrap();
    let mut accounts = BTreeMap::new();
    let mut slots = BTreeMap::new();
    let address = |i: u64| Address::from_word(B256::from(U256::from(i)));
    let slot = |i: u64| B256::from(U256::from(i));
    let account = |i: u64| Account { nonce: i, balance: U256::from(i + 1), bytecode_hash: None };
    for i in 1..=N {
        let (addr, key, value) = (address(i), slot(i), U256::from(i));
        let (ha, hk) = (keccak256(addr), keccak256(key));
        accounts.insert(ha, account(i).into_trie_account(alloy_trie::EMPTY_ROOT_HASH));
        slots.insert(hk, value);
        if storage_v2 {
            tx.put::<tables::HashedAccounts>(ha, account(i)).unwrap();
            tx.put::<tables::HashedStorages>(keccak256(f.address), StorageEntry { key: hk, value })
                .unwrap();
        } else {
            tx.put::<tables::PlainAccountState>(addr, account(i)).unwrap();
            tx.put::<tables::PlainStorageState>(f.address, StorageEntry { key, value }).unwrap();
        }
        if i.is_multiple_of(4096) {
            tx.commit().unwrap();
            tx = db.tx_mut().unwrap();
        }
    }
    tx.commit().unwrap();
    drop(db);
    let mut storage = HashBuilder::default();
    for (k, v) in slots {
        storage.add_leaf(Nibbles::unpack(k), &alloy_rlp::encode(v));
    }
    accounts.insert(keccak256(f.address), f.account.into_trie_account(storage.root()));
    let mut trie = HashBuilder::default();
    for (k, v) in accounts {
        trie.add_leaf(Nibbles::unpack(k), &alloy_rlp::encode(v));
    }
    let expected = trie.root();
    let last = f.manifest.headers.last_mut().unwrap();
    last.state_root = expected;
    f.trust.state_root = expected;
    f.trust.terminal_hash = last.hash_slow();
    let digest = f.manifest.verify(&f.trust).unwrap().manifest_hash().unwrap();
    std::fs::write(
        data.join(".etna-el-import-staging.json"),
        serde_json::to_vec(&serde_json::json!({
            "schema":1, "installation_id": f.manifest.installation_id, "manifest_hash": digest
        }))
        .unwrap(),
    )
    .unwrap();
    let report = super::install_dataset(&data, &f.genesis, &f.manifest, &f.trust).unwrap();
    assert_eq!((report.state.accounts, report.state.storage_slots), (N + 1, N));
    let factory =
        super::dataset::open_factory(&data, &f.genesis).unwrap().assert_consistent().unwrap();
    let provider = factory.provider().unwrap();
    let tx = provider.tx_ref();
    let cache_nodes = tx.entries::<tables::AccountsTrie>().unwrap() +
        tx.entries::<tables::StoragesTrie>().unwrap();
    assert!(cache_nodes > 10_000, "must exercise cache continuation: {cache_nodes} nodes");
    let state = factory.latest().unwrap();
    let keys = [slot(1), slot(10_000), slot(N), slot(N + 1)];
    for i in [1, 10_000, N] {
        assert_eq!(state.basic_account(&address(i)).unwrap(), Some(account(i)));
        assert_eq!(state.storage(f.address, slot(i)).unwrap(), Some(U256::from(i)));
        state.proof(Default::default(), address(i), &[]).unwrap().verify(expected).unwrap();
    }
    assert_eq!(state.basic_account(&address(N + 1)).unwrap(), None);
    let proof = state.proof(Default::default(), f.address, &keys).unwrap();
    assert_eq!(proof.storage_proofs.len(), keys.len());
    proof.verify(expected).unwrap();
}

#[test]
fn multichunk_v1_reopened_provider_state_and_proofs() {
    install_multichunk_state(false);
}
#[test]
fn multichunk_v2_reopened_provider_state_and_proofs() {
    install_multichunk_state(true);
}

#[test]
fn rejects_two_values_for_one_canonical_storage_slot_in_both_layouts() {
    for v2 in [false, true] {
        let f = dataset_fixture(v2);
        let db = reth_db::open_db(f.dir.path().join("db"), DatabaseArguments::test()).unwrap();
        let tx = db.tx_mut().unwrap();
        let key = B256::repeat_byte(5);
        for n in 1..=2 {
            let entry = StorageEntry { key, value: U256::from(n) };
            if v2 {
                tx.put::<tables::HashedStorages>(keccak256(f.address), entry).unwrap();
            } else {
                tx.put::<tables::PlainStorageState>(f.address, entry).unwrap();
            }
        }
        tx.commit().unwrap();
        drop(db);
        assert!(matches!(
            verify_fixture(&f.dir, f.trust.state_root),
            Err(ImportError::Invalid("invalid canonical state encoding"))
        ));
    }
}

#[test]
fn rejects_malformed_account_fields_before_pinned_compact_decode() {
    use reth_db_api::tables::{RawTable, RawValue};
    let dir = tempfile::tempdir().unwrap();
    let (db, address, _, expected) = fixture(&dir.path().join("db"));
    let tx = db.tx_mut().unwrap();
    tx.put::<RawTable<tables::PlainAccountState>>(
        address.into(),
        RawValue::from_vec(vec![0xff, 0xff]),
    )
    .unwrap();
    tx.commit().unwrap();
    drop(db);
    assert!(matches!(
        verify_fixture(&dir, expected),
        Err(ImportError::Invalid("invalid canonical state encoding"))
    ));
}

#[test]
fn private_reader_copy_preserves_sparse_data_and_trailing_holes() {
    use std::{
        fs::File,
        io::{Read, Seek, SeekFrom, Write},
        os::unix::fs::MetadataExt,
    };
    let dir = tempfile::tempdir().unwrap();
    let source = dir.path().join("source");
    let copy = dir.path().join("copy");
    let mut file = File::create(&source).unwrap();
    file.seek(SeekFrom::Start(3 * 1024 * 1024)).unwrap();
    file.write_all(&[1, 2, 3]).unwrap();
    file.set_len(16 * 1024 * 1024).unwrap();
    drop(file);
    crate::offline::sparse_copy(&source, &copy).unwrap();
    let original = std::fs::metadata(&source).unwrap();
    let mut copied = File::open(copy).unwrap();
    let meta = copied.metadata().unwrap();
    assert_ne!(meta.ino(), original.ino());
    assert_eq!(meta.len(), original.len());
    if original.blocks() * 512 < original.len() / 2 {
        assert!(meta.blocks() * 512 < meta.len() / 2);
    }
    copied.seek(SeekFrom::Start(3 * 1024 * 1024 - 1)).unwrap();
    let mut bytes = [0; 5];
    copied.read_exact(&mut bytes).unwrap();
    assert_eq!(bytes, [0, 1, 2, 3, 0]);
}

fn add_native_tables(db: &DatabaseEnv, names: &[&str], dup_sort: Option<&str>) {
    use reth_db::mdbx::{DatabaseFlags, WriteFlags};
    let tx = db.tx_mut().unwrap();
    for name in names {
        let flags =
            if Some(*name) == dup_sort { DatabaseFlags::DUP_SORT } else { DatabaseFlags::empty() };
        let table = tx.inner().create_db(Some(name), flags).unwrap();
        tx.inner().put(table.dbi(), 1u64.to_be_bytes(), [0x01], WriteFlags::UPSERT).unwrap();
    }
    tx.commit().unwrap();
}

#[test]
fn installed_native_version_history_accepts_the_actual_versioned_startup_path() {
    use reth_db::{
        ClientVersion,
        tables::{RawTable, RawValue},
    };
    let f = dataset_fixture(false);
    let data = f.dir.path().canonicalize().unwrap();
    let db = reth_db::open_db(data.join("db"), DatabaseArguments::test()).unwrap();
    let tx = db.tx_mut().unwrap();
    tx.put::<RawTable<tables::VersionHistory>>(1u64.into(), RawValue::from_vec(vec![0])).unwrap();
    tx.put::<RawTable<tables::HeaderTerminalDifficulties>>(
        11u64.into(),
        RawValue::from_vec(vec![5]),
    )
    .unwrap();
    tx.commit().unwrap();
    drop(db);
    super::install_dataset(&data, &f.genesis, &f.manifest, &f.trust).unwrap();
    let version = ClientVersion {
        version: "etna-test".into(),
        git_sha: "6ac93d4".into(),
        build_timestamp: "test".into(),
    };
    let db = reth_db::init_db(
        data.join("db"),
        DatabaseArguments::new(version.clone())
            .with_geometry_max_size(Some(64 << 20))
            .with_growth_step(Some(4 << 20)),
    )
    .unwrap();
    let tx = db.tx().unwrap();
    use reth_db_api::cursor::DbCursorRO;
    assert_eq!(
        tx.cursor_read::<tables::VersionHistory>().unwrap().last().unwrap().unwrap().1,
        version
    );
    assert_eq!(tx.entries::<tables::VersionHistory>().unwrap(), 1);
    assert!(tx.get::<RawTable<tables::VersionHistory>>(1u64.into()).unwrap().is_none());
    assert_eq!(tx.entries::<tables::HeaderTerminalDifficulties>().unwrap(), 0);
}

#[test]
fn installs_pinned_alethia_catalog_and_discards_foreign_origin_rows() {
    let names = ["StoredL1OriginTable", "StoredL1HeadOriginTable", "BatchToLastBlock"];
    for v2 in [false, true] {
        let f = dataset_fixture(v2);
        let data = f.dir.path().canonicalize().unwrap();
        let db = reth_db::open_db(data.join("db"), DatabaseArguments::test()).unwrap();
        add_native_tables(&db, &names, None);
        drop(db);
        super::install_dataset(&data, &f.genesis, &f.manifest, &f.trust).unwrap();
        let db = reth_db::open_db_read_only(data.join("db"), DatabaseArguments::test()).unwrap();
        let tx = db.tx().unwrap();
        for name in names {
            let dbi = tx.get_dbi_raw(name).unwrap();
            assert_eq!(tx.inner().db_stat_with_dbi(dbi).unwrap().entries(), 0);
        }
        drop(tx);
        drop(db);
        let factory = super::dataset::open_factory(&data, &f.genesis).unwrap();
        assert_eq!(factory.latest().unwrap().basic_account(&f.address).unwrap(), Some(f.account));
    }
}

#[test]
fn rejects_partial_substituted_or_wrong_flag_alethia_catalogs() {
    for (names, bad_flag) in [
        (vec!["StoredL1OriginTable"], None),
        (vec!["StoredL1OriginTable", "StoredL1HeadOriginTable", "Foreign"], None),
        (
            vec!["StoredL1OriginTable", "StoredL1HeadOriginTable", "BatchToLastBlock"],
            Some("BatchToLastBlock"),
        ),
    ] {
        let f = dataset_fixture(false);
        let db = reth_db::open_db(f.dir.path().join("db"), DatabaseArguments::test()).unwrap();
        add_native_tables(&db, &names, bad_flag);
        drop(db);
        assert!(verify_fixture(&f.dir, f.trust.state_root).is_err());
    }
}

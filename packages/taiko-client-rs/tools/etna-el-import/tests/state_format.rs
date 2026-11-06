use etna_el_import::{ImportError, verify_state};
use reth_db::mdbx::DatabaseArguments;

#[test]
fn rejects_an_unsupported_database_format_even_if_leaf_state_matches() {
    let dir = tempfile::tempdir().unwrap();
    let database = dir.path().join("db");
    let db = reth_db::init_db(&database, DatabaseArguments::default()).unwrap();
    drop(db);
    std::fs::write(database.join("database.version"), b"99999999").unwrap();
    assert!(matches!(
        verify_state(
            &database.canonicalize().unwrap(),
            alloy_trie::EMPTY_ROOT_HASH,
            &dir.path().canonicalize().unwrap()
        ),
        Err(ImportError::Invalid("unsupported database version"))
    ));
}

#[test]
fn verifies_a_fresh_copy_without_importing_the_sources_reader_lock() {
    let dir = tempfile::tempdir().unwrap();
    let source = dir.path().join("source");
    let db = reth_db::init_db(&source, DatabaseArguments::default()).unwrap();
    drop(db);
    let target = dir.path().join("db");
    std::fs::create_dir(&target).unwrap();
    for name in ["mdbx.dat", "database.version"] {
        std::fs::copy(source.join(name), target.join(name)).unwrap();
    }
    assert!(!target.join("mdbx.lck").exists());
    assert_eq!(
        verify_state(
            &target.canonicalize().unwrap(),
            alloy_trie::EMPTY_ROOT_HASH,
            &dir.path().canonicalize().unwrap()
        )
        .unwrap()
        .state_root,
        alloy_trie::EMPTY_ROOT_HASH
    );
}

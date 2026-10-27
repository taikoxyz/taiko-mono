//! Independently verify checked-in artifact bytes and pinned Solidity compilation provenance.

use anyhow::{Context, Result};
use sha2::{Digest, Sha256};

#[test]
fn lander_artifacts_match_pinned_compiler_and_recorded_hashes() -> Result<()> {
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/contracts");
    let manifest: serde_json::Value =
        serde_json::from_slice(&std::fs::read(root.join("manifest.json"))?)?;
    assert_eq!(manifest["protocolRevision"], crate::contracts::PROTOCOL_REVISION);
    assert!(manifest["artifacts"].get("L2FeeVault").is_none());
    assert!(!root.join("L2FeeVault.json").exists());
    for (name, entry) in manifest["artifacts"].as_object().context("artifact entries")? {
        assert_eq!(entry["compiler"]["version"], "0.8.30+commit.73712a01");
        assert_eq!(entry["settings"]["evmVersion"], "osaka");
        assert_eq!(entry["settings"]["optimizer"]["runs"], 200);
        let bytes = std::fs::read(root.join(format!("{name}.json")))?;
        assert_eq!(
            alloy_primitives::hex::encode(Sha256::digest(bytes)),
            entry["sha256"].as_str().context("artifact hash")?
        );
    }
    let interface = std::fs::read(
        std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("contracts/IEtnaInbox.sol"),
    )?;
    assert_eq!(
        alloy_primitives::hex::encode(Sha256::digest(interface)),
        manifest["interface"]["sha256"].as_str().context("interface hash")?
    );
    Ok(())
}

/// The shared Etna vectors (`testdata/etna_vectors`, which the abci and lander tests read) are
/// exactly the files the generator copied from the pinned protocol revision: no file is missing,
/// added or changed.
#[test]
fn shared_vectors_match_the_pinned_protocol_copy() -> Result<()> {
    use crate::test_utils::vectors::DIR;
    let manifest_dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
    let manifest: serde_json::Value = serde_json::from_slice(&std::fs::read(
        manifest_dir.join("tests/fixtures/contracts/manifest.json"),
    )?)?;
    assert_eq!(manifest["vectors"]["source"], DIR);
    let recorded = manifest["vectors"]["files"].as_object().context("vector file hashes")?;
    let dir = manifest_dir.join("../../../..").join(DIR);
    let mut names = std::fs::read_dir(&dir)?
        .filter_map(|entry| match entry {
            Ok(entry) if entry.path().is_file() => {
                Some(Ok(entry.file_name().into_string().expect("UTF-8 file name")))
            }
            Ok(_) => None,
            Err(e) => Some(Err(e.into())),
        })
        .collect::<Result<Vec<_>>>()?;
    // Untracked dotfiles (a desktop's folder metadata) are not part of the copy.
    names.retain(|name| !name.starts_with('.'));
    names.sort();
    assert_eq!(names, recorded.keys().cloned().collect::<Vec<_>>(), "vector files");
    assert!(names.iter().any(|name| name == "vectors.json"));
    for (name, digest) in recorded {
        let bytes = std::fs::read(dir.join(name))?;
        assert_eq!(
            alloy_primitives::hex::encode(Sha256::digest(bytes)),
            digest.as_str().context("vector file hash")?,
            "{name}"
        );
    }
    Ok(())
}

/// The binding contains the complete pinned ABI, without a legacy event projection.
#[test]
fn generated_binding_keeps_complete_current_abi() -> Result<()> {
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
    let original: serde_json::Value = serde_json::from_slice(&std::fs::read(
        root.join("tests/fixtures/contracts/EtnaInbox.json"),
    )?)?;
    let binding: serde_json::Value =
        serde_json::from_slice(&std::fs::read(root.join("contracts/EtnaInbox.json"))?)?;
    assert_eq!(original["abi"], binding["abi"]);
    assert!(
        !original["abi"].as_array().unwrap().iter().any(|item| item["name"] ==
            "BatchRewardRecorded" ||
            item["name"] == "hashLandStatement")
    );
    Ok(())
}

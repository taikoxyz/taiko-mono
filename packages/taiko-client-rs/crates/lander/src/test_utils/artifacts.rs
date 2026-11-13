//! Independently verify checked-in artifact bytes and pinned Solidity compilation provenance.

use anyhow::{Context, Result};
use sha2::{Digest, Sha256};

#[test]
fn lander_artifacts_match_pinned_compiler_and_recorded_hashes() -> Result<()> {
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/contracts");
    let manifest: serde_json::Value =
        serde_json::from_slice(&std::fs::read(root.join("manifest.json"))?)?;
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
    Ok(())
}

/// The generator's only protocol pin is the revision the checked-in manifest records, so a re-pin
/// without regeneration fails offline here, not only in `just check-lander-artifacts`.
#[test]
fn generator_pin_matches_the_manifest_revision() -> Result<()> {
    let manifest_dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
    let script =
        std::fs::read_to_string(manifest_dir.join("../../script/gen_lander_artifacts.sh"))?;
    let pinned = script
        .lines()
        .find_map(|line| line.strip_prefix("PINNED_REVISION="))
        .context("PINNED_REVISION line")?;
    let manifest: serde_json::Value = serde_json::from_slice(&std::fs::read(
        manifest_dir.join("tests/fixtures/contracts/manifest.json"),
    )?)?;
    assert_eq!(manifest["protocolRevision"], pinned);
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
    let mut names = Vec::new();
    let mut pending = vec![dir.clone()];
    while let Some(parent) = pending.pop() {
        for entry in std::fs::read_dir(parent)? {
            let entry = entry?;
            let name = entry.file_name();
            let name = name.to_str().context("UTF-8 vector file name")?;
            // Desktop metadata and Python bytecode are not generated source inputs.
            if name.starts_with('.') || name == "__pycache__" {
                continue;
            }
            let path = entry.path();
            if path.is_dir() {
                pending.push(path);
            } else if path.is_file() {
                names.push(
                    path.strip_prefix(&dir)?
                        .to_str()
                        .context("UTF-8 vector path")?
                        .replace(std::path::MAIN_SEPARATOR, "/"),
                );
            }
        }
    }
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

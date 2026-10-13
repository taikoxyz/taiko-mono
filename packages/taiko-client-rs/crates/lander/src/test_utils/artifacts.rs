//! Independently verify checked-in artifact bytes and pinned Solidity compilation provenance.

use anyhow::{Context, Result};
use sha2::{Digest, Sha256};

#[test]
fn lander_artifacts_match_pinned_compiler_and_recorded_hashes() -> Result<()> {
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/contracts");
    let manifest: serde_json::Value =
        serde_json::from_slice(&std::fs::read(root.join("manifest.json"))?)?;
    assert_eq!(manifest["protocolRevision"], crate::contracts::PROTOCOL_REVISION);
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

/// The pinned `EtnaInbox` declares the `ZeroFeeRecipient()` error the lander recognizes in a
/// rejected gas estimation, with the same selector.
#[test]
fn pinned_inbox_declares_the_zero_fee_recipient_error() -> Result<()> {
    use alloy::sol_types::SolError;
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/contracts");
    let artifact: serde_json::Value =
        serde_json::from_slice(&std::fs::read(root.join("EtnaInbox.json"))?)?;
    let abi = artifact["abi"].as_array().context("EtnaInbox ABI")?;
    assert!(abi.iter().any(|item| item["type"] == "error" &&
        item["name"] == "ZeroFeeRecipient" &&
        item["inputs"].as_array().is_some_and(Vec::is_empty)));
    assert_eq!(
        crate::contracts::ZeroFeeRecipient::SELECTOR,
        alloy_primitives::keccak256("ZeroFeeRecipient()")[..4]
    );
    Ok(())
}

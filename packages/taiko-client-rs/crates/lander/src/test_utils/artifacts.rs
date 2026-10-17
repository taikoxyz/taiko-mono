//! Independently verify checked-in artifact bytes and pinned Solidity compilation provenance.

use anyhow::{Context, Result};
use sha2::{Digest, Sha256};

#[test]
fn lander_artifacts_match_pinned_compiler_and_recorded_hashes() -> Result<()> {
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/contracts");
    let manifest: serde_json::Value =
        serde_json::from_slice(&std::fs::read(root.join("manifest.json"))?)?;
    assert_eq!(manifest["protocolRevision"], crate::contracts::PROTOCOL_REVISION);
    assert!(manifest["artifacts"]["L2FeeVault"].is_object());
    assert!(manifest["artifacts"].get("EtnaRewardPool").is_none());
    assert!(!root.join("EtnaRewardPool.json").exists());
    assert_eq!(
        manifest["artifacts"]["L2FeeVault"]["sourceArtifact"],
        "packages/protocol/out/layer2/L2FeeVault.sol/L2FeeVault.json"
    );
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
        .map(|entry| Ok(entry?.file_name().into_string().expect("UTF-8 file name")))
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

/// Only the oversized event is relocated; complete bytecode and ABI remain the source of truth.
#[test]
fn generated_bindings_relocate_only_the_typed_reward_event() -> Result<()> {
    use crate::contracts::BatchRewardRecorded;
    use alloy::sol_types::SolEvent;
    use alloy_primitives::{Address, B256, U256, keccak256};
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
    let original: serde_json::Value = serde_json::from_slice(&std::fs::read(
        root.join("tests/fixtures/contracts/EtnaInbox.json"),
    )?)?;
    let projection: serde_json::Value =
        serde_json::from_slice(&std::fs::read(root.join("contracts/EtnaInbox.json"))?)?;
    let abi = original["abi"].as_array().context("real Inbox ABI")?;
    let event = abi
        .iter()
        .find(|item| item["type"] == "event" && item["name"] == "BatchRewardRecorded")
        .context("reward event")?;
    let expected = abi.iter().filter(|item| *item != event).cloned().collect::<Vec<_>>();
    assert_eq!(projection["abi"], serde_json::json!(expected));
    assert!(projection.get("bytecode").is_none());
    let inputs = event["inputs"].as_array().context("event fields")?;
    let types = inputs
        .iter()
        .map(|field| field["type"].as_str().context("event type"))
        .collect::<Result<Vec<_>>>()?;
    assert_eq!(BatchRewardRecorded::SIGNATURE, format!("BatchRewardRecorded({})", types.join(",")));
    assert_eq!(
        inputs
            .iter()
            .filter(|field| field["indexed"] == true)
            .map(|field| field["name"].as_str().unwrap())
            .collect::<Vec<_>>(),
        ["batchId", "l2RewardRecipient"]
    );
    let event = BatchRewardRecorded {
        batchId: B256::repeat_byte(1),
        l2RewardRecipient: Address::repeat_byte(2),
        baseFeeAmount: U256::from(3),
        generation: 4,
        parentHeight: 5,
        parentHash: B256::repeat_byte(6),
        lastHeight: 7,
        lastBlockHash: B256::repeat_byte(8),
    };
    let log = event.encode_log_data();
    assert_eq!(log.topics().len(), 3);
    assert_eq!(log.topics()[0], keccak256(BatchRewardRecorded::SIGNATURE));
    assert_eq!(log.topics()[1], event.batchId);
    assert_eq!(log.topics()[2], B256::from(event.l2RewardRecipient.into_word()));
    assert_eq!(log.data.len(), 6 * 32);
    assert_eq!(&log.data[..32], event.baseFeeAmount.to_be_bytes::<32>().as_slice());
    let restored = BatchRewardRecorded::decode_log_data(&log)?;
    assert_eq!(restored, event);
    let manifest: serde_json::Value = serde_json::from_slice(&std::fs::read(
        root.join("tests/fixtures/contracts/manifest.json"),
    )?)?;
    assert_eq!(manifest["bindings"]["sourceArtifact"], "EtnaInbox.json");
    assert_eq!(manifest["bindings"]["omittedEvents"], serde_json::json!(["BatchRewardRecorded"]));
    for name in ["projection", "standaloneEvent"] {
        let record = &manifest["bindings"][name];
        let bytes = std::fs::read(root.join(record["path"].as_str().context("binding path")?))?;
        assert_eq!(alloy_primitives::hex::encode(Sha256::digest(bytes)), record["sha256"]);
    }
    Ok(())
}

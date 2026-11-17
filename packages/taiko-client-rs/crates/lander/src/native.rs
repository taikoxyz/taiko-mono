//! Host RPC adapters over the authoritative shared native Comet representations.
use self::evidence::Sum as RawEvidence;
use base64::{Engine as _, engine::general_purpose::STANDARD};
/// Canonical native wire and domain types shared with proving consumers.
pub use etna_core::comet::native::*;
use serde_json::Value;
use tendermint_proto::{
    google::protobuf::Timestamp,
    v0_38::types::{Header as RawHeader, Vote as RawVote},
};

/// Decodes stock block RPC JSON, preserving evidence, native keys and canonical timestamps.
pub fn decode_block(mut value: serde_json::Value) -> Result<RawBlock, String> {
    if let Some(evidence) = value.pointer_mut("/evidence/evidence").and_then(Value::as_array_mut) {
        for item in evidence {
            if item.get("type").and_then(Value::as_str) == Some("tendermint/DuplicateVoteEvidence")
            {
                for vote in ["vote_a", "vote_b"] {
                    if let Some(vote) = item.pointer_mut(&format!("/value/{vote}")) {
                        decode_vote_extensions(vote)?;
                    }
                }
                continue;
            }
            if item.get("type").and_then(Value::as_str) !=
                Some("tendermint/LightClientAttackEvidence")
            {
                continue;
            }
            if let Some(fields) = item.get_mut("value").and_then(Value::as_object_mut) {
                for (go, proto) in [
                    ("ConflictingBlock", "conflicting_block"),
                    ("CommonHeight", "common_height"),
                    ("ByzantineValidators", "byzantine_validators"),
                    ("TotalVotingPower", "total_voting_power"),
                    ("Timestamp", "timestamp"),
                ] {
                    if let Some(field) = fields.remove(go) &&
                        fields.insert(proto.into(), field).is_some()
                    {
                        return Err(format!("duplicate light-client evidence field {proto}"));
                    }
                }
            }
        }
    }
    check_block_timestamps(&value)?;
    let mut block: RawBlock = serde_json::from_value(value).map_err(|e| e.to_string())?;
    restore_block_times(&mut block);
    Ok(block)
}
/// Decodes a stock decision certificate without the SDK's 64-byte signature restriction.
pub fn decode_commit(value: serde_json::Value) -> Result<Commit, String> {
    serde_json::from_value(value).map_err(|e| e.to_string())
}

/// Rejects absent, null or malformed timestamp fields while their JSON presence is still known.
fn check_timestamp(value: &Value, field: &str) -> Result<(), String> {
    let timestamp = value.get(field).ok_or_else(|| format!("missing {field}"))?;
    if !timestamp.is_string() {
        return Err(format!("{field} must be an explicit RFC3339 timestamp"));
    }
    serde_json::from_value::<Timestamp>(timestamp.clone()).map(|_| ()).map_err(|e| e.to_string())
}

/// Checks each present raw certificate slot before SDK optional timestamp deserialization.
fn check_commit_timestamps(commit: &Value) -> Result<(), String> {
    if let Some(signatures) = commit.get("signatures").and_then(Value::as_array) {
        for signature in signatures {
            check_timestamp(signature, "timestamp")?;
        }
    }
    Ok(())
}

/// Checks every timestamp that the stock block RPC carries, including nested evidence.
/// Optional message nodes remain structural-validation inputs; every present node must supply time.
fn check_block_timestamps(block: &Value) -> Result<(), String> {
    if let Some(header) = block.get("header").filter(|v| !v.is_null()) {
        check_timestamp(header, "time")?;
    }
    if let Some(commit) = block.get("last_commit").filter(|v| !v.is_null()) {
        check_commit_timestamps(commit)?;
    }
    if let Some(evidence) = block.pointer("/evidence/evidence").and_then(Value::as_array) {
        for item in evidence {
            let Some(fields) = item.get("value") else { continue };
            match item.get("type").and_then(Value::as_str) {
                Some("tendermint/DuplicateVoteEvidence") => {
                    // The SDK accepts Go's exported name as well as protobuf-shaped JSON.
                    let field =
                        if fields.get("timestamp").is_some() { "timestamp" } else { "Timestamp" };
                    check_timestamp(fields, field)?;
                    for name in ["vote_a", "vote_b"] {
                        if let Some(vote) = fields.get(name).filter(|v| !v.is_null()) {
                            check_timestamp(vote, "timestamp")?;
                        }
                    }
                }
                Some("tendermint/LightClientAttackEvidence") => {
                    // Exported aliases have already been normalized by decode_block.
                    check_timestamp(fields, "timestamp")?;
                    if let Some(header) = fields
                        .pointer("/conflicting_block/signed_header/header")
                        .filter(|v| !v.is_null())
                    {
                        check_timestamp(header, "time")?;
                    }
                    if let Some(commit) = fields
                        .pointer("/conflicting_block/signed_header/commit")
                        .filter(|v| !v.is_null())
                    {
                        check_commit_timestamps(commit)?;
                    }
                }
                _ => {}
            }
        }
    }
    Ok(())
}

/// Restores the Unix-epoch times of `block`'s header, last commit and evidence votes and
/// light-client headers and commits ([`restore_header_time`]).
fn restore_block_times(block: &mut RawBlock) {
    if let Some(header) = &mut block.header {
        restore_header_time(header);
    }
    if let Some(commit) = &mut block.last_commit {
        restore_commit_times(commit);
    }
    for evidence in block.evidence.iter_mut().flat_map(|list| list.evidence.iter_mut()) {
        match evidence.sum.as_mut() {
            Some(RawEvidence::DuplicateVoteEvidence(duplicate)) => {
                for vote in [&mut duplicate.vote_a, &mut duplicate.vote_b].into_iter().flatten() {
                    restore_vote_time(vote);
                }
            }
            Some(RawEvidence::LightClientAttackEvidence(attack)) => {
                let signed = attack
                    .conflicting_block
                    .as_mut()
                    .and_then(|light| light.signed_header.as_mut());
                if let Some(signed) = signed {
                    if let Some(header) = &mut signed.header {
                        restore_header_time(header);
                    }
                    if let Some(commit) = &mut signed.commit {
                        restore_commit_times(commit);
                    }
                }
            }
            None => {}
        }
    }
}

/// Restores only the supplied Unix-epoch timestamp erased by SDK's optional JSON adapter.
/// `check_block_timestamps` first requires and parses every corresponding original JSON field,
/// so neither an explicit null nor an omitted timestamp can reach this restoration path.
fn restore_header_time(header: &mut RawHeader) {
    header.time.get_or_insert_with(Default::default);
}

/// [`restore_header_time`] for every signature of `commit`.
fn restore_commit_times(commit: &mut RawCommit) {
    for signature in &mut commit.signatures {
        signature.timestamp.get_or_insert_with(Default::default);
    }
}

/// [`restore_header_time`] for a vote.
fn restore_vote_time(vote: &mut RawVote) {
    vote.timestamp.get_or_insert_with(Default::default);
}

/// Replaces a vote's base64 `extension` and `extension_signature` strings with the byte arrays the
/// proto JSON adapter reads; `null` (no extension) and absent fields stay as they are.
fn decode_vote_extensions(vote: &mut Value) -> std::result::Result<(), String> {
    for field in ["extension", "extension_signature"] {
        let Some(slot) = vote.get_mut(field) else { continue };
        let Some(encoded) = slot.as_str() else { continue };
        let bytes = STANDARD
            .decode(encoded)
            .map_err(|e| format!("duplicate vote evidence {field} base64: {e}"))?;
        *slot = Value::from(bytes);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use prost::Message;
    use tendermint_proto::v0_38::types::{BlockId, Commit as RawCommit, CommitSig, PartSetHeader};

    #[test]
    fn native_certificate_preserves_all_65_signature_bytes() {
        let raw = RawCommit {
            height: 6,
            round: 0,
            block_id: Some(BlockId {
                hash: vec![1; 32],
                part_set_header: Some(PartSetHeader { total: 1, hash: vec![2; 32] }),
            }),
            signatures: vec![CommitSig {
                block_id_flag: 2,
                validator_address: vec![3; 20],
                timestamp: Some(tendermint_proto::google::protobuf::Timestamp {
                    seconds: 0,
                    nanos: 0,
                }),
                signature: vec![4; 65],
            }],
        };
        let bytes = raw.encode_to_vec();
        let commit = Commit::try_from(raw).expect("native 65-byte certificate is representable");
        assert_eq!(RawCommit::from(commit).encode_to_vec(), bytes);
    }
    fn unhex(value: &str) -> Vec<u8> {
        value
            .as_bytes()
            .as_chunks::<2>()
            .0
            .iter()
            .map(|pair| u8::from_str_radix(std::str::from_utf8(pair).unwrap(), 16).unwrap())
            .collect()
    }

    #[test]
    fn stock_native_block_protobuf_preserves_nested_evidence_keys() {
        for fixture in [
            include_str!("../../etna-core/testdata/cometbft-v0.40/vectors.json"),
            include_str!("../../etna-core/testdata/cometbft-v0.40/differential.json"),
        ] {
            let fixture: serde_json::Value = serde_json::from_str(fixture).unwrap();
            for vector in fixture["vectors"].as_array().unwrap() {
                let bytes = unhex(vector["block_proto"].as_str().unwrap());
                let raw = RawBlock::decode(bytes.as_slice()).unwrap();
                assert_eq!(
                    raw.encode_to_vec(),
                    bytes,
                    "{}: original evidence must survive",
                    vector["name"]
                );
                Block::try_from(raw).unwrap();
                if let Some(encoded) = vector["commit_proto"].as_str() {
                    let bytes = unhex(encoded);
                    let raw = RawCommit::decode(bytes.as_slice()).unwrap();
                    let commit = Commit::try_from(raw).unwrap();
                    assert_eq!(
                        RawCommit::from(commit).encode_to_vec(),
                        bytes,
                        "{}",
                        vector["name"]
                    );
                }
            }
        }
    }

    #[test]
    fn stock_native_rpc_preserves_original_protobufs() {
        for fixture in [
            include_str!("../../etna-core/testdata/cometbft-v0.40/vectors.json"),
            include_str!("../../etna-core/testdata/cometbft-v0.40/differential.json"),
        ] {
            let fixture: serde_json::Value = serde_json::from_str(fixture).unwrap();
            for vector in fixture["vectors"].as_array().unwrap() {
                let name = &vector["name"];
                let raw = decode_block(vector["block_rpc"]["block"].clone())
                    .unwrap_or_else(|e| panic!("{name}: {e}"));
                let bytes = unhex(vector["block_proto"].as_str().unwrap());
                assert!(raw.encode_to_vec() == bytes, "{name}: block RPC must retain exact bytes");
                let commit = decode_commit(vector["commit_rpc"]["signed_header"]["commit"].clone())
                    .unwrap_or_else(|e| panic!("{name}: {e}"));
                if let Some(encoded) = vector["commit_proto"].as_str() {
                    assert!(
                        RawCommit::from(commit).encode_to_vec() == unhex(encoded),
                        "{name}: commit RPC must retain exact bytes"
                    );
                }
            }
        }
    }

    #[test]
    fn direct_commit_json_keeps_unix_epoch_votes() {
        let fixture: serde_json::Value = serde_json::from_str(include_str!(
            "../../etna-core/testdata/cometbft-v0.40/differential.json"
        ))
        .unwrap();
        let vector = fixture["vectors"]
            .as_array()
            .unwrap()
            .iter()
            .find(|v| v["name"] == "own_commit_sig_at_unix_epoch")
            .unwrap();
        let commit: Commit =
            serde_json::from_value(vector["commit_rpc"]["signed_header"]["commit"].clone())
                .expect("all public serde entrypoints preserve the Unix epoch");
        assert_eq!(
            RawCommit::from(commit).encode_to_vec(),
            unhex(vector["commit_proto"].as_str().unwrap())
        );
    }

    #[test]
    fn foreign_evidence_keys_keep_all_stock_algorithm_tags() {
        for (tag, kind) in [
            (1u8, "tendermint/PubKeyEd25519"),
            (2, "tendermint/PubKeySecp256k1"),
            (3, "cometbft/PubKeyBls12_381"),
            (4, "cometbft/PubKeyMlDsa65"),
            (5, "tendermint/PubKeySecp256k1eth"),
        ] {
            // Opaque bytes test representation only; these are deliberately not committee keys.
            let encoded = vec![(tag << 3) | 2, 3, 0, 7, 0];
            let key = PublicKey::decode(encoded.as_slice()).unwrap();
            assert_eq!(key.encode_to_vec(), encoded, "stock key tag {tag} must not disappear");
            let json = serde_json::to_value(&key).unwrap();
            assert_eq!(json["type"], kind);
            assert_eq!(json["value"], "AAcA");
            let restored: PublicKey = serde_json::from_value(json).unwrap();
            assert_eq!(restored.encode_to_vec(), encoded);
        }
    }

    #[test]
    fn rejects_legacy_signature_widths_and_malformed_certificate_metadata() {
        let fixture: serde_json::Value = serde_json::from_str(include_str!(
            "../../etna-core/testdata/cometbft-v0.40/differential.json"
        ))
        .unwrap();
        let bytes = unhex(fixture["vectors"][0]["commit_proto"].as_str().unwrap());
        let valid = RawCommit::decode(bytes.as_slice()).unwrap();
        for width in [0, 32, 64, 66, 96] {
            let mut raw = valid.clone();
            raw.signatures[0].signature.resize(width, 0);
            assert!(Commit::try_from(raw).is_err(), "signature width {width}");
        }
        for mutation in 0..9 {
            let mut raw = valid.clone();
            match mutation {
                0 => raw.height = -1,
                1 => raw.round = -1,
                2 => raw.block_id = None,
                3 => raw.signatures[0].block_id_flag = 0,
                4 => {
                    raw.signatures[0].validator_address.pop();
                }
                5 => raw.signatures[0].timestamp = None,
                6 => raw.signatures[0].timestamp.as_mut().unwrap().nanos = 1_000_000_000,
                7 => raw.signatures[0].block_id_flag = 1,
                8 => {
                    raw.signatures[0] = super::CommitSig::BlockIdFlagAbsent.into();
                    raw.signatures[0].timestamp = Some(Timestamp { seconds: 0, nanos: 0 });
                }
                _ => unreachable!(),
            }
            assert!(Commit::try_from(raw).is_err(), "malformed certificate mutation {mutation}");
        }
        let raw = RawCommitSig::from(super::CommitSig::BlockIdFlagAbsent);
        assert!(matches!(
            super::CommitSig::try_from(raw).unwrap(),
            super::CommitSig::BlockIdFlagAbsent
        ));
    }

    #[test]
    fn rejects_ambiguous_light_client_json_field_aliases() {
        let fixture: serde_json::Value = serde_json::from_str(include_str!(
            "../../etna-core/testdata/cometbft-v0.40/vectors.json"
        ))
        .unwrap();
        let vector = fixture["vectors"]
            .as_array()
            .unwrap()
            .iter()
            .find(|v| v["name"] == "light_client_attack")
            .unwrap();
        let mut block = vector["block_rpc"]["block"].clone();
        let fields = block["evidence"]["evidence"][0]["value"].as_object_mut().unwrap();
        fields.insert("conflicting_block".into(), fields["ConflictingBlock"].clone());
        assert!(decode_block(block).is_err());
    }
    fn fixture_vector(file: &str, name: &str) -> Value {
        let fixture: Value = serde_json::from_str(match file {
            "evidence" => include_str!("../../etna-core/testdata/cometbft-v0.40/vectors.json"),
            "differential" => {
                include_str!("../../etna-core/testdata/cometbft-v0.40/differential.json")
            }
            _ => unreachable!(),
        })
        .unwrap();
        fixture["vectors"].as_array().unwrap().iter().find(|v| v["name"] == name).unwrap().clone()
    }

    fn omit_or_null(value: &mut Value, path: &str, omit: bool) {
        assert!(value.pointer(path).is_some(), "fixture field {path}");
        if omit {
            let (parent, field) = path.rsplit_once('/').unwrap();
            value.pointer_mut(parent).unwrap().as_object_mut().unwrap().remove(field);
        } else {
            *value.pointer_mut(path).unwrap() = Value::Null;
        }
    }

    #[test]
    fn commit_json_rejects_missing_or_null_signed_timestamps() {
        let mut accepted = Vec::new();
        for name in ["own_commit_sig_at_unix_epoch", "own_nil_sig_at_unix_epoch"] {
            let vector = fixture_vector("differential", name);
            let original = vector["commit_rpc"]["signed_header"]["commit"].clone();
            for index in 0..2 {
                for omit in [false, true] {
                    let mut json = original.clone();
                    omit_or_null(&mut json, &format!("/signatures/{index}/timestamp"), omit);
                    if decode_commit(json.clone()).is_ok() ||
                        serde_json::from_value::<Commit>(json.clone()).is_ok() ||
                        serde_json::from_str::<Commit>(&json.to_string()).is_ok()
                    {
                        accepted.push(format!("{name} slot {index} omit={omit}"));
                    }
                }
            }
        }
        assert!(accepted.is_empty(), "malformed commit timestamps accepted: {accepted:?}");
    }

    #[test]
    fn block_rpc_rejects_missing_or_null_nested_timestamps() {
        let mut accepted = Vec::new();
        for (file, name, path) in [
            ("differential", "header_at_unix_epoch", "/header/time"),
            (
                "differential",
                "last_commit_sig_at_unix_epoch",
                "/last_commit/signatures/1/timestamp",
            ),
            (
                "differential",
                "last_commit_nil_sig_at_unix_epoch",
                "/last_commit/signatures/1/timestamp",
            ),
            (
                "differential",
                "duplicate_votes_at_unix_epoch",
                "/evidence/evidence/0/value/vote_a/timestamp",
            ),
            (
                "differential",
                "duplicate_votes_at_unix_epoch",
                "/evidence/evidence/0/value/vote_b/timestamp",
            ),
            (
                "differential",
                "duplicate_votes_at_unix_epoch",
                "/evidence/evidence/0/value/Timestamp",
            ),
            (
                "evidence",
                "light_client_attack",
                "/evidence/evidence/0/value/ConflictingBlock/signed_header/header/time",
            ),
            (
                "evidence",
                "light_client_attack",
                "/evidence/evidence/0/value/ConflictingBlock/signed_header/commit/signatures/0/timestamp",
            ),
            ("evidence", "light_client_attack", "/evidence/evidence/0/value/Timestamp"),
        ] {
            let original = fixture_vector(file, name)["block_rpc"]["block"].clone();
            assert!(decode_block(original.clone()).is_ok());
            for omit in [false, true] {
                let mut json = original.clone();
                omit_or_null(&mut json, path, omit);
                if decode_block(json).is_ok() {
                    accepted.push(format!("{name} {path} omit={omit}"));
                }
            }
        }
        assert!(accepted.is_empty(), "malformed block timestamps accepted: {accepted:?}");
    }
}

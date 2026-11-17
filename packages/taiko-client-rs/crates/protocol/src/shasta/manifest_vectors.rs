//! Shared regression corpus for source decoding and execution-encoding compatibility.

use super::*;
use alethia_reth_primitives::payload::builder::decode_recovered_transactions;
use alloy::primitives::hex;
use serde::Deserialize;

#[derive(Deserialize)]
struct ManifestVector {
    name: String,
    family: String,
    payload_hex: String,
    offset: usize,
    expect_default: bool,
    expected_manifest_rlp_hex: String,
    engine_tx_list_hex: Option<String>,
    engine_decodable: Option<bool>,
}

fn load_manifest_vectors() -> Vec<ManifestVector> {
    #[derive(Deserialize)]
    struct Corpus {
        schema_version: u32,
        cases: Vec<ManifestVector>,
    }
    let corpus: Corpus = serde_json::from_str(include_str!(
        "../../../../../../testdata/derivation_vectors/manifest_cases.json"
    ))
    .unwrap();
    assert_eq!(corpus.schema_version, 1);
    assert!(!corpus.cases.is_empty());
    corpus.cases
}

#[test]
fn f9_manifest_vectors() {
    for v in
        load_manifest_vectors().into_iter().filter(|v| v.family == "f9" || v.family == "framing")
    {
        let payload = hex::decode(&v.payload_hex).unwrap();
        let got = DerivationSourceManifest::decompress_and_decode(&payload, v.offset).unwrap();
        let expected = hex::decode(&v.expected_manifest_rlp_hex).unwrap();
        assert_eq!(alloy_rlp::encode(&got), expected, "{}", v.name);
        if v.expect_default {
            assert_eq!(
                alloy_rlp::encode(&got),
                alloy_rlp::encode(DerivationSourceManifest::default()),
                "{}",
                v.name
            );
        }
    }
}

#[test]
fn f9_engine_encoding_oracle() {
    for v in load_manifest_vectors().into_iter().filter(|v| v.family == "f9") {
        let list = hex::decode(v.engine_tx_list_hex.as_ref().unwrap()).unwrap();
        assert_eq!(
            decode_recovered_transactions(&list).is_ok(),
            v.engine_decodable.expect("F9 vector needs an engine expectation"),
            "{}",
            v.name
        );
    }
}

#[test]
fn f8_manifest_vectors() {
    for v in load_manifest_vectors().into_iter().filter(|v| v.family == "f8") {
        let payload = hex::decode(&v.payload_hex).unwrap();
        let got = DerivationSourceManifest::decompress_and_decode(&payload, v.offset).unwrap();
        assert_eq!(
            alloy_rlp::encode(&got),
            hex::decode(&v.expected_manifest_rlp_hex).unwrap(),
            "{}",
            v.name
        );
    }
}

#[test]
fn f8_all_entry_points_are_strict() {
    for v in load_manifest_vectors().into_iter().filter(|v| v.family == "f8") {
        let payload = hex::decode(&v.payload_hex).unwrap();
        let got = DerivationSourceManifest::decompress_and_decode_with_max_blocks(
            &payload,
            v.offset,
            DERIVATION_SOURCE_MAX_BLOCKS,
        )
        .unwrap();
        assert_eq!(
            alloy_rlp::encode(&got),
            hex::decode(&v.expected_manifest_rlp_hex).unwrap(),
            "{}",
            v.name
        );
    }
}

#[test]
fn f8_large_stream_drains_output() {
    let v = load_manifest_vectors().into_iter().find(|v| v.name == "large_output").unwrap();
    let expected = hex::decode(&v.expected_manifest_rlp_hex).unwrap();
    assert!(expected.len() > 2 * 8192);
    let got =
        DerivationSourceManifest::decompress_and_decode(&hex::decode(v.payload_hex).unwrap(), 0)
            .unwrap();
    assert_eq!(alloy_rlp::encode(&got), expected);
}

#[test]
fn zlib_drains_small_output_chunks() {
    for v in load_manifest_vectors()
        .into_iter()
        .filter(|v| matches!(v.name.as_str(), "large_output" | "dictionary_id_1"))
    {
        let payload = hex::decode(v.payload_hex).unwrap();
        let expected = hex::decode(v.expected_manifest_rlp_hex).unwrap();
        for chunk_size in [1, 7, 8192] {
            assert_eq!(
                decompress_manifest_zlib(&payload[64..], &mut vec![0; chunk_size]).unwrap(),
                expected,
                "{} chunk size {chunk_size}",
                v.name
            );
        }
    }
}

#[test]
fn zlib_rejects_invalid_distances_and_incomplete_trees() {
    // These streams are rejected by Go and C zlib but accepted by miniz_oxide.
    // Test decompression itself: a later RLP error must not mask backend drift.
    for encoded in [
        "789c03020000030001",
        "789c04a0810800000000e46f7d00c012939201024d0127",
        "789c0d80014100000082b602ff3f68d8010608140250",
    ] {
        assert!(decompress_manifest_zlib(&hex::decode(encoded).unwrap(), &mut [0; 8192]).is_err());
    }
}

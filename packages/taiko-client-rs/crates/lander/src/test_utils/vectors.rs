//! The Etna vectors shared with the contracts: `testdata/etna_vectors/vectors.json` at the
//! repository root (see its README), the byte-identical copy of the protocol package's file that
//! `script/gen_lander_artifacts.sh` takes from the pinned protocol revision and the artifact
//! manifest hashes.
//!
//! Paths are JSON pointers (`/land_statement/hash`); integers are decimal strings, so every
//! value survives parsing exactly.

use std::sync::OnceLock;

use alloy_primitives::{Address, B256, Bytes, U256};
use serde_json::Value;

/// The repository-relative directory of the shared vectors.
pub(crate) const DIR: &str = "testdata/etna_vectors";

/// The vectors document, parsed once.
pub(crate) fn vectors() -> &'static Value {
    static VECTORS: OnceLock<Value> = OnceLock::new();
    VECTORS.get_or_init(|| {
        serde_json::from_str(include_str!("../../../../../../testdata/etna_vectors/vectors.json"))
            .expect("the shared Etna vectors are valid JSON")
    })
}

/// The string at the JSON `pointer`.
pub(crate) fn str_at(pointer: &str) -> &'static str {
    vectors()
        .pointer(pointer)
        .and_then(Value::as_str)
        .unwrap_or_else(|| panic!("no Etna vector string at {pointer}"))
}

/// The decimal integer at `pointer`.
pub(crate) fn u64_at(pointer: &str) -> u64 {
    str_at(pointer).parse().unwrap_or_else(|e| panic!("Etna vector {pointer}: {e}"))
}

/// The decimal integer at `pointer`.
pub(crate) fn u256_at(pointer: &str) -> U256 {
    U256::from_str_radix(str_at(pointer), 10)
        .unwrap_or_else(|e| panic!("Etna vector {pointer}: {e}"))
}

/// The 32-byte hex word at `pointer`.
pub(crate) fn b256_at(pointer: &str) -> B256 {
    str_at(pointer).parse().unwrap_or_else(|e| panic!("Etna vector {pointer}: {e}"))
}

/// The address at `pointer`.
pub(crate) fn address_at(pointer: &str) -> Address {
    str_at(pointer).parse().unwrap_or_else(|e| panic!("Etna vector {pointer}: {e}"))
}

/// The hex byte string at `pointer`.
pub(crate) fn bytes_at(pointer: &str) -> Bytes {
    str_at(pointer).parse().unwrap_or_else(|e| panic!("Etna vector {pointer}: {e}"))
}

/// The length of the array at `pointer`.
pub(crate) fn len_at(pointer: &str) -> usize {
    vectors()
        .pointer(pointer)
        .and_then(Value::as_array)
        .unwrap_or_else(|| panic!("no Etna vector array at {pointer}"))
        .len()
}

/// The 32-byte words of the array at `pointer`.
pub(crate) fn b256s_at(pointer: &str) -> Vec<B256> {
    (0..len_at(pointer)).map(|i| b256_at(&format!("{pointer}/{i}"))).collect()
}

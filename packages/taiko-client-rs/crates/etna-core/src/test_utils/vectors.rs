//! The Etna vectors shared with the contracts: `testdata/etna_vectors/vectors.json` at the
//! repository root (see its README), the byte-identical copy of the protocol package's file that
//! the lander fixtures pin (`script/gen_lander_artifacts.sh`).
//!
//! Paths are JSON pointers (`/layout/inbox/slots/status`); integers are decimal strings, so
//! every value survives parsing exactly.

use std::sync::OnceLock;

use alloy_primitives::B256;
use serde_json::Value;

/// The vectors document, parsed once.
pub(crate) fn vectors() -> &'static Value {
    static VECTORS: OnceLock<Value> = OnceLock::new();
    VECTORS.get_or_init(|| {
        serde_json::from_str(include_str!("../../../../../../testdata/etna_vectors/vectors.json"))
            .expect("the shared Etna vectors are valid JSON")
    })
}

/// The vector at `pointer`.
pub(crate) fn at(pointer: &str) -> &'static Value {
    vectors().pointer(pointer).unwrap_or_else(|| panic!("no Etna vector at {pointer}"))
}

/// The string at `pointer`.
pub(crate) fn str_at(pointer: &str) -> &'static str {
    at(pointer).as_str().unwrap_or_else(|| panic!("Etna vector {pointer} is not a string"))
}

/// The number of elements of the array at `pointer`.
pub(crate) fn len_at(pointer: &str) -> usize {
    at(pointer).as_array().unwrap_or_else(|| panic!("Etna vector {pointer} is not an array")).len()
}

/// The decimal integer at `pointer`.
pub(crate) fn u64_at(pointer: &str) -> u64 {
    str_at(pointer).parse().unwrap_or_else(|e| panic!("Etna vector {pointer}: {e}"))
}

/// The decimal integer at `pointer`.
pub(crate) fn usize_at(pointer: &str) -> usize {
    str_at(pointer).parse().unwrap_or_else(|e| panic!("Etna vector {pointer}: {e}"))
}

/// The 32-byte hex word at `pointer`.
pub(crate) fn b256_at(pointer: &str) -> B256 {
    str_at(pointer).parse().unwrap_or_else(|e| panic!("Etna vector {pointer}: {e}"))
}

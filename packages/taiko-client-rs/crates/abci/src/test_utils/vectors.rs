//! The Etna vectors shared with the contracts: `testdata/etna_vectors/vectors.json` at the
//! repository root (see its README), the byte-identical copy of the protocol package's file that
//! the lander fixtures pin (`script/gen_lander_artifacts.sh`).
//!
//! Paths are JSON pointers (`/layout/inbox/slots/status`); integers are decimal strings, so
//! every value survives parsing exactly.

use std::sync::OnceLock;

use alloy_primitives::{B256, U256};
use serde_json::Value;

use crate::types::RegistryEntry;

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

/// The decimal integer at `pointer`.
pub(crate) fn u256_at(pointer: &str) -> U256 {
    U256::from_str_radix(str_at(pointer), 10)
        .unwrap_or_else(|e| panic!("Etna vector {pointer}: {e}"))
}

/// The 32-byte hex word at `pointer`.
pub(crate) fn b256_at(pointer: &str) -> B256 {
    str_at(pointer).parse().unwrap_or_else(|e| panic!("Etna vector {pointer}: {e}"))
}

/// The 32-byte words of the array at `pointer`.
pub(crate) fn b256s_at(pointer: &str) -> Vec<B256> {
    (0..len_at(pointer)).map(|i| b256_at(&format!("{pointer}/{i}"))).collect()
}

/// The decimal integers of the array at `pointer`.
pub(crate) fn u64s_at(pointer: &str) -> Vec<u64> {
    (0..len_at(pointer)).map(|i| u64_at(&format!("{pointer}/{i}"))).collect()
}

/// Entry `index` of `registry_entries`.
pub(crate) fn registry_entry(index: usize) -> RegistryEntry {
    let field = |name: &str| format!("/registry_entries/entries/{index}/{name}");
    RegistryEntry {
        ck_prefix: u64_at(&field("ck_prefix")) as u8,
        ck_x: b256_at(&field("ck_x")),
        eff_stake: u256_at(&field("eff_stake")),
        active_from_l1: u64_at(&field("active_from_l1")),
        exit_effective_l1: u64_at(&field("exit_effective_l1")),
    }
}

/// Every entry of `registry_entries`.
pub(crate) fn registry_entries() -> Vec<RegistryEntry> {
    (0..len_at("/registry_entries/entries")).map(registry_entry).collect()
}

/// The storage word holding `fields` (name, value) at their offsets in the packing table at
/// `packing` (e.g. `/layout/inbox/packing/activation_packed`), zero elsewhere. Panics if a
/// value does not fit its field.
pub(crate) fn pack(packing: &str, fields: &[(&str, U256)]) -> U256 {
    fields.iter().fold(U256::ZERO, |word, (name, value)| {
        let (offset, bits) = (
            usize_at(&format!("{packing}/{name}/offset")),
            usize_at(&format!("{packing}/{name}/bits")),
        );
        assert!(value.bit_len() <= bits, "{packing}/{name}: {value} exceeds {bits} bits");
        word | (*value << offset)
    })
}

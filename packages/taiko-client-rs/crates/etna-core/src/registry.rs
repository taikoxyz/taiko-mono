//! Registry ERC-7201 storage layout and packed-word reads.

use alloy_primitives::{B256, U256, keccak256};

/// The ERC-7201 namespace identifier of the registry's storage.
pub const NAMESPACE: &str = "taiko.etna.registry";

/// The ERC-7201 base slot `R`:
/// `keccak256(abi.encode(uint256(keccak256(NAMESPACE)) - 1)) & ~bytes32(uint256(0xff))`.
pub fn base() -> B256 {
    let namespace = U256::from_be_bytes(keccak256(NAMESPACE).0);
    let mut base = keccak256(B256::from(namespace.wrapping_sub(U256::from(1))));
    base.0[31] = 0;
    base
}

/// The slot holding `checkpoints.length` (the array's own slot, `R`).
pub fn length_slot() -> B256 {
    base()
}

/// The two slots of `checkpoints[i]`, as Solidity lays out dynamic-array elements:
/// `[keccak256(R) + 2i, keccak256(R) + 2i + 1]` (wrapping in U256).
///
/// The first word packs `l1Block` (`uint48`, bits 0–47) and `count` (`uint48`, bits 48–95);
/// the second is `entriesRoot`.
pub fn checkpoint_slots(i: u64) -> [B256; 2] {
    let data = U256::from_be_bytes(keccak256(base()).0);
    let first = data.wrapping_add(U256::from(i) * U256::from(2));
    [B256::from(first), B256::from(first.wrapping_add(U256::from(1)))]
}

/// The slot holding `entries.length` (the `entries` array's own slot, `R + 1`).
pub fn entries_length_slot() -> B256 {
    B256::from(U256::from_be_bytes(base().0).wrapping_add(U256::from(1)))
}

/// The three words of `entries[j]`, at `keccak256(R + 1) + 3j` (wrapping in U256).
/// Words zero and one hold the key x coordinate and effective stake. Word two packs
/// key prefix (bits 0–7), activation (8–55) and exit (56–103).
pub fn entry_slots(j: u64) -> [B256; 3] {
    let data = U256::from_be_bytes(keccak256(entries_length_slot()).0);
    let first = data.wrapping_add(U256::from(j) * U256::from(3));
    [
        B256::from(first),
        B256::from(first.wrapping_add(U256::from(1))),
        B256::from(first.wrapping_add(U256::from(2))),
    ]
}
/// The `uint64` packed at `bit_offset` (low-order-first) in a storage word.
///
/// Bits beyond the word's end read as zero.
pub fn word_u64(word: U256, bit_offset: usize) -> u64 {
    (word >> bit_offset).wrapping_to::<u64>()
}

/// The `uint48` packed at `bit_offset` (low-order-first) in a storage word, widened to `u64`.
///
/// Bits beyond the word's end read as zero.
pub fn word_u48(word: U256, bit_offset: usize) -> u64 {
    word_u64(word, bit_offset) & ((1 << 48) - 1)
}

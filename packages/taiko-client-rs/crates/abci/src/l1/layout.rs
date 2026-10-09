//! L1 storage layout of the Etna Inbox and staking registry (spec §6.2). No I/O.
//!
//! This module is normative for contract authors: every slot the node proves with EIP-1186
//! witnesses is derived here. Values are 32-byte storage words; packed fields follow Solidity's
//! low-order-first packing and are extracted with [`word_u64`], [`word_u32`] and [`word_u8`].

use alloy_primitives::U256;

/// Inbox storage slots (contract address = chain constant `ETNA_INBOX`).
pub mod inbox {
    use alloy_primitives::{B256, U256, keccak256};

    /// `migrationState` (spec-pinned): `uint8`, bits 0–7.
    pub const MIGRATION_STATE: u64 = 258;
    /// `recoveryGeneration` (spec-pinned): `uint64`, bits 0–63.
    pub const RECOVERY_GENERATION: u64 = 268;
    /// `lastCheckpoint.height`: `uint64`, bits 0–63.
    pub const LAST_CHECKPOINT_HEIGHT: u64 = 270;
    /// `lastCheckpoint.blockHash`: `bytes32`.
    pub const LAST_CHECKPOINT_HASH: u64 = 271;
    /// Activation record, packed: `genesisHeight` (B*, bits 0–63), `l1Block` (L1_0, bits 64–127),
    /// `epochLenL2` (L, bits 128–191), `epochLenL1` (bits 192–255).
    pub const ACTIVATION_PACKED: u64 = 272;
    /// Activation record: `genesisBlockHash` (H*), `bytes32`.
    pub const ACTIVATION_GENESIS_HASH: u64 = 273;
    /// Activation record: `genesisStateRoot` (S*), `bytes32`.
    pub const ACTIVATION_GENESIS_STATE_ROOT: u64 = 274;
    /// Base slot of `committee`: `mapping(uint64 epoch => bytes32 recordHash)`.
    pub const COMMITTEE_MAPPING: u64 = 276;
    /// `migrationState` value once Etna PoS is live.
    pub const ETNA_ACTIVE: u8 = 3;

    /// The 32-byte storage slot for the plain slot number `n`.
    pub fn slot(n: u64) -> B256 {
        B256::from(U256::from(n))
    }

    /// The storage slot of `committee[epoch]`:
    /// `keccak256(abi.encode(uint256(epoch), uint256(COMMITTEE_MAPPING)))`.
    pub fn committee_slot(epoch: u64) -> B256 {
        keccak256([slot(epoch), slot(COMMITTEE_MAPPING)].concat())
    }

    /// The slots a per-block anchor witness proves, in this order:
    /// `[258, 268, 270, 271]`, followed by `committee[epoch]` when `committee_epoch` is set
    /// (switch heights, D19).
    pub fn anchor_slots(committee_epoch: Option<u64>) -> Vec<B256> {
        let mut slots = vec![
            slot(MIGRATION_STATE),
            slot(RECOVERY_GENERATION),
            slot(LAST_CHECKPOINT_HEIGHT),
            slot(LAST_CHECKPOINT_HASH),
        ];
        slots.extend(committee_epoch.map(committee_slot));
        slots
    }

    /// The slots the genesis witness proves, in this order:
    /// `[258, 268, 272, 273, 274, committee[e0]]`.
    pub fn genesis_slots(e0: u64) -> Vec<B256> {
        vec![
            slot(MIGRATION_STATE),
            slot(RECOVERY_GENERATION),
            slot(ACTIVATION_PACKED),
            slot(ACTIVATION_GENESIS_HASH),
            slot(ACTIVATION_GENESIS_STATE_ROOT),
            committee_slot(e0),
        ]
    }
}

/// Staking-registry storage slots (contract address = chain constant `ETNA_REGISTRY`).
///
/// The registry keeps its state in an ERC-7201 namespace `taiko.etna.registry` whose first field
/// is `checkpoints`, a dynamic array of two-word structs `{ uint64 l1Block; uint32 count; }` and
/// `bytes32 entriesRoot`. The second field (amendment A1) is `entries`, a dynamic array of
/// three-word structs `{ bytes32 pubkey; uint256 effStake; uint64 activeFromL1;
/// uint64 exitEffectiveL1; uint64 lastHeartbeatAt; }` indexed by `bondId`.
///
/// The contract appends a checkpoint in every L1 block that changes any entry, so the entries
/// read at block `checkpoints[i].l1Block` (or any later block before `checkpoints[i + 1].l1Block`)
/// are checkpoint `i`'s snapshot. Entry reads are discovery only: a committee witness carries the
/// entries and `committee::verify_snapshot` checks them against the proven `entriesRoot`.
pub mod registry {
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
    /// The first word packs `l1Block` (`uint64`, bits 0–63) and `count` (`uint32`, bits 64–95);
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

    /// The three slots of `entries[j]`, as Solidity lays out dynamic-array elements:
    /// `[keccak256(R + 1) + 3j, keccak256(R + 1) + 3j + 1, keccak256(R + 1) + 3j + 2]` (wrapping
    /// in U256).
    ///
    /// The words are `pubkey` (`bytes32`), `effStake` (`uint256`), and the packed
    /// `activeFromL1` (`uint64`, bits 0–63), `exitEffectiveL1` (bits 64–127) and
    /// `lastHeartbeatAt` (bits 128–191).
    pub fn entry_slots(j: u64) -> [B256; 3] {
        let data = U256::from_be_bytes(keccak256(entries_length_slot()).0);
        let first = data.wrapping_add(U256::from(j) * U256::from(3));
        [
            B256::from(first),
            B256::from(first.wrapping_add(U256::from(1))),
            B256::from(first.wrapping_add(U256::from(2))),
        ]
    }
}

/// The `uint64` packed at `bit_offset` (low-order-first) in a storage word.
///
/// Bits beyond the word's end read as zero.
pub fn word_u64(word: U256, bit_offset: usize) -> u64 {
    (word >> bit_offset).wrapping_to::<u64>()
}

/// The `uint32` packed at `bit_offset` (low-order-first) in a storage word.
///
/// Bits beyond the word's end read as zero.
pub fn word_u32(word: U256, bit_offset: usize) -> u32 {
    (word >> bit_offset).wrapping_to::<u32>()
}

/// The `uint8` packed at `bit_offset` (low-order-first) in a storage word.
///
/// Bits beyond the word's end read as zero.
pub fn word_u8(word: U256, bit_offset: usize) -> u8 {
    (word >> bit_offset).wrapping_to::<u8>()
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_primitives::{B256, b256, keccak256};

    /// Builds `abi.encode(uint256(a), uint256(b))` byte by byte.
    fn abi_encode_two_u64(a: u64, b: u64) -> [u8; 64] {
        let mut out = [0u8; 64];
        out[24..32].copy_from_slice(&a.to_be_bytes());
        out[56..64].copy_from_slice(&b.to_be_bytes());
        out
    }

    #[test]
    fn inbox_plain_slots_are_big_endian_numbers() {
        assert_eq!(
            inbox::slot(inbox::MIGRATION_STATE),
            b256!("0000000000000000000000000000000000000000000000000000000000000102")
        );
        assert_eq!(
            inbox::slot(inbox::COMMITTEE_MAPPING),
            b256!("0000000000000000000000000000000000000000000000000000000000000114")
        );
        assert_eq!(inbox::slot(0), B256::ZERO);
        assert_eq!(inbox::slot(u64::MAX), B256::from(U256::from(u64::MAX)));
    }

    #[test]
    fn committee_slot_is_pinned() {
        assert_eq!(
            inbox::committee_slot(0),
            b256!("2787162cb5efc0991778decb6064e0d16695115fa7a391c7834a23d0f07e0d55")
        );
        assert_eq!(
            inbox::committee_slot(1),
            b256!("231d1e3aab20212e2b1c4bfd35b30ad741110c0b6bc7e655cd2209414a3b58fb")
        );
        assert_eq!(
            inbox::committee_slot(u64::MAX),
            b256!("84d66c6015411bc5482c4c3241ff6a96073d9595f88bfe6d47fa1e53a96585b9")
        );
    }

    #[test]
    fn committee_slot_matches_manual_abi_encoding() {
        for epoch in [0, 1, 2, 1_000, u64::MAX] {
            assert_eq!(inbox::committee_slot(epoch), keccak256(abi_encode_two_u64(epoch, 276)));
        }
    }

    #[test]
    fn anchor_slots_are_ordered_and_optionally_extended() {
        let expected = [258u64, 268, 270, 271].map(inbox::slot).to_vec();
        assert_eq!(inbox::anchor_slots(None), expected);

        let mut with_committee = expected;
        with_committee.push(inbox::committee_slot(7));
        assert_eq!(inbox::anchor_slots(Some(7)), with_committee);
    }

    #[test]
    fn genesis_slots_are_ordered() {
        let mut expected = [258u64, 268, 272, 273, 274].map(inbox::slot).to_vec();
        expected.push(inbox::committee_slot(0));
        assert_eq!(inbox::genesis_slots(0), expected);
        assert_eq!(inbox::genesis_slots(3)[5], inbox::committee_slot(3));
    }

    #[test]
    fn registry_base_is_pinned() {
        assert_eq!(
            registry::base(),
            b256!("46e4e2fea4a7d0ac18aca03baa3a1f64e1be04ec23c1ca0c7b901af7b59b8000")
        );
        assert_eq!(registry::length_slot(), registry::base());
    }

    #[test]
    fn registry_base_matches_manual_erc7201_derivation() {
        let namespace_hash = keccak256(b"taiko.etna.registry");
        // uint256(namespace_hash) - 1, big-endian, by hand: borrow through trailing zero bytes.
        let mut preimage = namespace_hash.0;
        for byte in preimage.iter_mut().rev() {
            let (next, borrow) = byte.overflowing_sub(1);
            *byte = next;
            if !borrow {
                break;
            }
        }
        let mut expected = keccak256(preimage).0;
        expected[31] = 0;
        assert_eq!(registry::base(), B256::from(expected));
    }

    #[test]
    fn registry_checkpoint_slots_are_pinned() {
        assert_eq!(
            registry::checkpoint_slots(0),
            [
                b256!("d9a608a417f242366fbd54f054137bf7eb45998d56e782c42e929a940d78cebf"),
                b256!("d9a608a417f242366fbd54f054137bf7eb45998d56e782c42e929a940d78cec0"),
            ]
        );
        assert_eq!(
            registry::checkpoint_slots(1),
            [
                b256!("d9a608a417f242366fbd54f054137bf7eb45998d56e782c42e929a940d78cec1"),
                b256!("d9a608a417f242366fbd54f054137bf7eb45998d56e782c42e929a940d78cec2"),
            ]
        );
        assert_eq!(
            registry::checkpoint_slots(5),
            [
                b256!("d9a608a417f242366fbd54f054137bf7eb45998d56e782c42e929a940d78cec9"),
                b256!("d9a608a417f242366fbd54f054137bf7eb45998d56e782c42e929a940d78ceca"),
            ]
        );
        assert_eq!(
            registry::checkpoint_slots(u64::MAX),
            [
                b256!("d9a608a417f242366fbd54f054137bf7eb45998d56e782c62e929a940d78cebd"),
                b256!("d9a608a417f242366fbd54f054137bf7eb45998d56e782c62e929a940d78cebe"),
            ]
        );
    }

    #[test]
    fn registry_checkpoint_data_starts_at_keccak_of_base() {
        assert_eq!(registry::checkpoint_slots(0)[0], keccak256(registry::base()));
    }

    #[test]
    fn registry_entries_length_slot_is_base_plus_one() {
        assert_eq!(
            registry::entries_length_slot(),
            b256!("46e4e2fea4a7d0ac18aca03baa3a1f64e1be04ec23c1ca0c7b901af7b59b8001")
        );
        let base = U256::from_be_bytes(registry::base().0);
        assert_eq!(registry::entries_length_slot(), B256::from(base + U256::from(1)));
    }

    #[test]
    fn registry_entry_slots_are_pinned() {
        assert_eq!(
            registry::entry_slots(0),
            [
                b256!("4d419ea4bc25ad27df001f0b7723b9f336aaf0c5d43f32d8ebc7877436afbcba"),
                b256!("4d419ea4bc25ad27df001f0b7723b9f336aaf0c5d43f32d8ebc7877436afbcbb"),
                b256!("4d419ea4bc25ad27df001f0b7723b9f336aaf0c5d43f32d8ebc7877436afbcbc"),
            ]
        );
        assert_eq!(
            registry::entry_slots(1),
            [
                b256!("4d419ea4bc25ad27df001f0b7723b9f336aaf0c5d43f32d8ebc7877436afbcbd"),
                b256!("4d419ea4bc25ad27df001f0b7723b9f336aaf0c5d43f32d8ebc7877436afbcbe"),
                b256!("4d419ea4bc25ad27df001f0b7723b9f336aaf0c5d43f32d8ebc7877436afbcbf"),
            ]
        );
        assert_eq!(
            registry::entry_slots(2),
            [
                b256!("4d419ea4bc25ad27df001f0b7723b9f336aaf0c5d43f32d8ebc7877436afbcc0"),
                b256!("4d419ea4bc25ad27df001f0b7723b9f336aaf0c5d43f32d8ebc7877436afbcc1"),
                b256!("4d419ea4bc25ad27df001f0b7723b9f336aaf0c5d43f32d8ebc7877436afbcc2"),
            ]
        );
        assert_eq!(
            registry::entry_slots(u64::MAX),
            [
                b256!("4d419ea4bc25ad27df001f0b7723b9f336aaf0c5d43f32dbebc7877436afbcb7"),
                b256!("4d419ea4bc25ad27df001f0b7723b9f336aaf0c5d43f32dbebc7877436afbcb8"),
                b256!("4d419ea4bc25ad27df001f0b7723b9f336aaf0c5d43f32dbebc7877436afbcb9"),
            ]
        );
    }

    #[test]
    fn registry_entry_data_starts_at_keccak_of_the_entries_slot() {
        assert_eq!(registry::entry_slots(0)[0], keccak256(registry::entries_length_slot()));
        // The entries array does not overlap the checkpoints array near index 0.
        assert_ne!(registry::entry_slots(0)[0], registry::checkpoint_slots(0)[0]);
    }

    #[test]
    fn packed_fields_are_read_low_order_first() {
        // Activation-style word: four uint64 fields at bits 0 / 64 / 128 / 192.
        let word = U256::from_limbs([
            0x0000_0000_0000_0007,
            0x0000_0000_0000_1234,
            0x0000_0000_0000_0014,
            0xffff_ffff_ffff_fffe,
        ]);
        assert_eq!(word_u64(word, 0), 7);
        assert_eq!(word_u64(word, 64), 0x1234);
        assert_eq!(word_u64(word, 128), 20);
        assert_eq!(word_u64(word, 192), 0xffff_ffff_ffff_fffe);

        // Checkpoint-style word: uint64 l1Block at bit 0, uint32 count at bit 64, junk above.
        let word = U256::from_limbs([0xdead_beef_0000_0042, 0xaaaa_aaaa_0000_0009, u64::MAX, 0]);
        assert_eq!(word_u64(word, 0), 0xdead_beef_0000_0042);
        assert_eq!(word_u32(word, 64), 9);
        assert_eq!(word_u32(word, 96), 0xaaaa_aaaa);

        // uint8 at bit 0 ignores higher bits; a field straddling the top reads zeros past bit 255.
        let word = U256::from(0x1_03u64);
        assert_eq!(word_u8(word, 0), 3);
        assert_eq!(word_u8(word, 8), 1);
        assert_eq!(word_u8(U256::MAX, 252), 0x0f);
        assert_eq!(word_u64(U256::MAX, 256), 0);
    }
}

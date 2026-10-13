//! Normative L1 Inbox and staking-registry storage slots. No I/O.
//!
//! Inbox activation authenticates status, generation, schedule, genesis cutoff, configuration
//! hash, the single genesis committee hash and the forced inclusion delay and maximum anchor
//! age. Runtime anchors prove only status, generation, checkpoint height/hash and the forced
//! inclusion queue's head/tail; no future committee mapping exists.
//!
//! Registry checkpoints must be strictly increasing and complete, with a checkpoint in every
//! changing L1 block. Discovery reads historical entries before the next checkpoint and then
//! verifies their authenticated root. Heartbeat sequence zero means no heartbeat; registration
//! must protect unique non-exited public keys. Earliest-bond deduplication is defense in depth.
//! Packed Solidity fields are decoded low-order-first.

use alloy_primitives::U256;

/// Inbox storage slots (contract address = chain constant `ETNA_INBOX`).
pub mod inbox {
    use alloy_primitives::{B256, U256, keccak256};

    /// Inbox initialization status: `uint8`, bits 0–7. Slot 258 remains compatible with
    /// the contract's `migrationState()` getter.
    pub const STATUS: u64 = 258;
    /// `recoveryGeneration` (slot pinned by #22262): `uint64`, bits 0–63.
    pub const RECOVERY_GENERATION: u64 = 268;
    /// `lastCheckpoint.height`: `uint64`, bits 0–63.
    pub const LAST_CHECKPOINT_HEIGHT: u64 = 270;
    /// `lastCheckpoint.blockHash`: `bytes32`.
    pub const LAST_CHECKPOINT_HASH: u64 = 271;
    /// Activation record, packed: `genesisHeight` (B*, bits 0–63), `l1Block` (L1_0, bits 64–127),
    /// `epochLenL2` (L, bits 128–191), `epochLenL1` (bits 192–255).
    pub const GENESIS_PACKED: u64 = 272;
    /// Activation record: `genesisBlockHash` (H*), `bytes32`.
    pub const GENESIS_BLOCK_HASH: u64 = 273;
    /// Activation record: `genesisStateRoot` (S*), `bytes32`.
    pub const GENESIS_STATE_ROOT: u64 = 274;
    /// Authenticated parent-anchor derivation configuration hash.
    pub const COMMITTEE_CONFIG_HASH: u64 = 269;
    /// The single bootstrap committee record hash; future committees are never published.
    pub const GENESIS_COMMITTEE_HASH: u64 = 278;
    /// `genesisCutoff`: `uint64`, bits 0–63. The snapshot cutoff (an L1 block before `L1_0`) of
    /// the genesis committee, set once by the genesis.
    pub const GENESIS_CUTOFF: u64 = 279;
    /// The forced inclusion `queue` mapping (`LibForcedInclusion.Storage.queue`), keyed by entry
    /// index; see [`forced_inclusion_entry_slots`].
    pub const FORCED_INCLUSION_QUEUE: u64 = 280;
    /// The forced inclusion queue's `head` (`uint48`, bits 0–47: the next entry not yet settled
    /// on L1) and `tail` (`uint48`, bits 48–95: the next free index).
    pub const FORCED_INCLUSION_HEAD_TAIL: u64 = 281;
    /// Genesis forced inclusion configuration: `forcedInclusionDelay` (`uint64` seconds, bits
    /// 0–63) and `maxAnchorAge` (`uint64` seconds, bits 64–127).
    pub const FORCED_INCLUSION_CONFIG: u64 = 282;
    /// Inbox status after genesis initialization.
    pub const ETNA_ACTIVE: u8 = 3;

    /// The 32-byte storage slot for the plain slot number `n`.
    pub fn slot(n: u64) -> B256 {
        B256::from(U256::from(n))
    }

    /// The fixed slots authenticated by every per-block anchor witness: status, generation,
    /// last checkpoint height and hash, and the forced inclusion queue's head/tail.
    pub fn anchor_slots() -> Vec<B256> {
        [
            STATUS,
            RECOVERY_GENERATION,
            LAST_CHECKPOINT_HEIGHT,
            LAST_CHECKPOINT_HASH,
            FORCED_INCLUSION_HEAD_TAIL,
        ]
        .map(slot)
        .to_vec()
    }

    /// Genesis status, generation, schedule, cutoff, bootstrap committee, configuration, and
    /// forced inclusion configuration.
    pub fn genesis_slots() -> Vec<B256> {
        [
            STATUS,
            RECOVERY_GENERATION,
            GENESIS_PACKED,
            GENESIS_BLOCK_HASH,
            GENESIS_STATE_ROOT,
            GENESIS_CUTOFF,
            GENESIS_COMMITTEE_HASH,
            COMMITTEE_CONFIG_HASH,
            FORCED_INCLUSION_CONFIG,
        ]
        .map(slot)
        .to_vec()
    }

    /// The four slots of forced inclusion entry `index`, as Solidity lays out
    /// `queue[index]` (a `ForcedInclusion { uint64 feeInGwei; BlobSlice blobSlice; }` with
    /// `BlobSlice { bytes32[] blobHashes; uint24 offset; uint48 timestamp; }`) at
    /// `base = keccak256(abi.encode(index, 280))`:
    ///
    /// 1. `base`: `feeInGwei` (bits 0–63);
    /// 2. `base + 1`: `blobHashes.length`;
    /// 3. `base + 2`: `offset` (bits 0–23) and `timestamp` (bits 24–71);
    /// 4. `keccak256(base + 1)`: `blobHashes[0]`.
    ///
    /// Additions wrap in U256.
    pub fn forced_inclusion_entry_slots(index: u64) -> [B256; 4] {
        let mut preimage = [0u8; 64];
        preimage[..32].copy_from_slice(&U256::from(index).to_be_bytes::<32>());
        preimage[32..].copy_from_slice(&U256::from(FORCED_INCLUSION_QUEUE).to_be_bytes::<32>());
        let base = U256::from_be_bytes(keccak256(preimage).0);
        let length = B256::from(base.wrapping_add(U256::from(1)));
        [B256::from(base), length, B256::from(base.wrapping_add(U256::from(2))), keccak256(length)]
    }
}

/// Staking-registry storage slots (contract address = chain constant `ETNA_REGISTRY`).
///
/// The registry keeps its state in an ERC-7201 namespace `taiko.etna.registry` whose first field
/// is `checkpoints`, a dynamic array of two-word structs
/// `{ uint64 l1Block; uint32 count; bytes32 entriesRoot; }`. The second field is `entries`, the
/// live entry array the checkpoints snapshot: a dynamic array of three-word structs
/// `{ bytes32 pubkey; uint256 effStake; uint64 activeFromL1; uint64 exitEffectiveL1;
/// uint64 lastHeartbeatAt; uint64 lastHeartbeatSeq; }` indexed by `bondId`.
///
/// As the contract appends a checkpoint in every L1 block that changes any entry (see the
/// contract obligations in the module docs), the entries read at block `checkpoints[i].l1Block`
/// (or any later block before `checkpoints[i + 1].l1Block`) are checkpoint `i`'s snapshot. Entry
/// reads are discovery only: a committee witness carries the entries and
/// `committee::verify_snapshot` checks them against the proven `entriesRoot`.
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
    /// `activeFromL1` (`uint64`, bits 0–63), `exitEffectiveL1` (bits 64–127),
    /// `lastHeartbeatAt` (bits 128–191) and `lastHeartbeatSeq` (bits 192–255).
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

/// The `uint48` packed at `bit_offset` (low-order-first) in a storage word, widened to `u64`.
///
/// Bits beyond the word's end read as zero.
pub fn word_u48(word: U256, bit_offset: usize) -> u64 {
    word_u64(word, bit_offset) & ((1 << 48) - 1)
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

    #[test]
    fn inbox_plain_slots_are_big_endian_numbers() {
        assert_eq!(
            inbox::slot(inbox::STATUS),
            b256!("0000000000000000000000000000000000000000000000000000000000000102")
        );
        assert_eq!(
            inbox::slot(inbox::GENESIS_COMMITTEE_HASH),
            b256!("0000000000000000000000000000000000000000000000000000000000000116")
        );
        assert_eq!(
            inbox::slot(inbox::GENESIS_CUTOFF),
            b256!("0000000000000000000000000000000000000000000000000000000000000117")
        );
        assert_eq!(inbox::slot(0), B256::ZERO);
        assert_eq!(inbox::slot(u64::MAX), B256::from(U256::from(u64::MAX)));
    }

    #[test]
    fn anchor_slots_are_fixed() {
        assert_eq!(inbox::anchor_slots(), [258u64, 268, 270, 271, 281].map(inbox::slot).to_vec());
    }
    #[test]
    fn genesis_slots_are_ordered() {
        assert_eq!(
            inbox::genesis_slots(),
            [258u64, 268, 272, 273, 274, 279, 278, 269, 282].map(inbox::slot).to_vec()
        );
    }

    /// Entry `i` of the `queue` mapping at slot 280 is a `ForcedInclusion` struct at
    /// `keccak256(abi.encode(i, 280))`: `feeInGwei`, then the `BlobSlice` (its `blobHashes`
    /// length, then `offset | timestamp`), and `blobHashes[0]` at `keccak256` of the length slot.
    #[test]
    fn forced_inclusion_entry_slots_follow_solidity_layout() {
        let slots = inbox::forced_inclusion_entry_slots(7);

        let mut preimage = [0u8; 64];
        preimage[..32].copy_from_slice(&U256::from(7u64).to_be_bytes::<32>());
        preimage[32..].copy_from_slice(&U256::from(280u64).to_be_bytes::<32>());
        let base = U256::from_be_bytes(keccak256(preimage).0);
        assert_eq!(slots[0], B256::from(base));
        assert_eq!(slots[1], B256::from(base + U256::from(1)));
        assert_eq!(slots[2], B256::from(base + U256::from(2)));
        assert_eq!(slots[3], keccak256(slots[1]));

        // Pinned with `cast index uint256 7 280` and `cast keccak`.
        assert_eq!(
            slots,
            [
                b256!("fe59ba1b996c9452f7b7815b262d72cb08473c9b1ad66a36420423a2c51d1f32"),
                b256!("fe59ba1b996c9452f7b7815b262d72cb08473c9b1ad66a36420423a2c51d1f33"),
                b256!("fe59ba1b996c9452f7b7815b262d72cb08473c9b1ad66a36420423a2c51d1f34"),
                b256!("61e848bf49344b279049a8d9175c784c35bb8aea653f992d2fdbba7fc2fb23d4"),
            ]
        );
        assert_ne!(inbox::forced_inclusion_entry_slots(8)[0], slots[0]);
    }

    /// Slot 281 packs `head` (`uint48`, bits 0–47) and `tail` (`uint48`, bits 48–95).
    #[test]
    fn uint48_fields_are_read_low_order_first() {
        let max = (1u64 << 48) - 1;
        let word = U256::from(3u64) | (U256::from(9u64) << 48) | (U256::MAX << 96);
        assert_eq!(word_u48(word, 0), 3);
        assert_eq!(word_u48(word, 48), 9);
        assert_eq!(word_u48(U256::MAX, 0), max);
        assert_eq!(word_u48(U256::MAX, 48), max);
        assert_eq!(word_u48(U256::MAX, 232), 0x00ff_ffff);
        assert_eq!(word_u48(U256::MAX, 256), 0);
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

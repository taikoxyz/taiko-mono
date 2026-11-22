//! Normative L1 Inbox and staking-registry storage slots. No I/O.
//!
//! Inbox activation authenticates status, generation, schedule, genesis cutoff, configuration
//! hash, the single genesis committee hash and the forced inclusion delay and maximum anchor
//! age. Runtime anchors prove generation, checkpoint height/hash, the fallback keys hash, the
//! minimum total stake, the forced inclusion queue's head/tail and the rules schedule; no
//! future committee mapping exists.
//!
//! Registry checkpoints must be strictly increasing and complete, with a checkpoint in every
//! changing L1 block. Discovery reads historical entries before the next checkpoint and then
//! verifies their authenticated root. Eligible consensus keys must be unique.
//! Packed Solidity fields are decoded low-order-first.

use alloy_primitives::U256;

/// Inbox storage slots (contract address = chain constant `ETNA_INBOX`).
pub mod inbox {
    use alloy_primitives::{B256, U256};

    /// Inbox initialization status: `uint8`, bits 0–7. Slot 258 remains compatible with
    /// the contract's `migrationState()` getter.
    pub const STATUS: u64 = 258;
    /// `recoveryGeneration` (slot pinned by #22262): `uint48`, bits 0–47.
    pub const RECOVERY_GENERATION: u64 = 268;
    /// `lastCheckpoint.height`: `uint48`, bits 0–47.
    pub const LAST_CHECKPOINT_HEIGHT: u64 = 270;
    /// `lastCheckpoint.blockHash`: `bytes32`.
    pub const LAST_CHECKPOINT_HASH: u64 = 271;
    /// Activation record, packed: `genesisHeight` (the Etna start S, bits 0–47), `l1Block` (L1_0,
    /// bits 48–95), `epochLenL2` (L, bits 96–143); higher bits are reserved.
    pub const GENESIS_PACKED: u64 = 272;
    /// Etna start record: Solidity `startBlockHash`, the start hash (the Etna start block's hash),
    /// `bytes32`.
    pub const START_BLOCK_HASH: u64 = 273;
    /// Etna start record: Solidity `startStateRoot`, the start state root (the Etna start block's
    /// state root), `bytes32`.
    pub const START_STATE_ROOT: u64 = 274;
    /// Authenticated parent-anchor derivation configuration hash.
    pub const COMMITTEE_CONFIG_HASH: u64 = 269;
    /// `fallbackKeysHash`, a whole `bytes32`: the hash of the DAO's fallback key list, set at
    /// initialization and replaced only by `setFallbackKeys`. Every anchor witness proves it.
    pub const FALLBACK_KEYS_HASH: u64 = 278;
    /// `minTotalStake`, a whole `uint256` read without masking: the least `snapshotTotalStake` of
    /// a usable candidate, set at initialization and replaced only by `setMinTotalStake`. Every
    /// anchor witness proves it; 2^256 − 1 makes no candidate usable.
    pub const MIN_TOTAL_STAKE: u64 = 279;
    /// Slot [`FALLBACK_KEYS_HASH`] as the genesis witness still reads it: the single bootstrap
    /// committee record hash.
    pub const GENESIS_COMMITTEE_HASH: u64 = FALLBACK_KEYS_HASH;
    /// Slot [`MIN_TOTAL_STAKE`] as the genesis witness still reads it: `genesisCutoff`,
    /// `uint48`, bits 0–47, the snapshot cutoff (an L1 block before `L1_0`) of the genesis
    /// committee.
    pub const GENESIS_CUTOFF: u64 = MIN_TOTAL_STAKE;
    /// The forced inclusion `queue` mapping (`LibForcedInclusion.Storage.queue`), keyed by entry
    /// index; see [`forced_inclusion_entry_slots`].
    pub const FORCED_INCLUSION_QUEUE: u64 = 280;
    /// The forced inclusion queue's `head` (`uint48`, bits 0–47: the next entry not yet settled
    /// on L1) and `tail` (`uint48`, bits 48–95: the next free index).
    pub const FORCED_INCLUSION_HEAD_TAIL: u64 = 281;
    /// Genesis forced inclusion configuration: `forcedInclusionDelay` (`uint48` seconds, bits
    /// 0–47) and `maxAnchorAge` (`uint48` seconds, bits 48–95).
    pub const FORCED_INCLUSION_CONFIG: u64 = 282;
    /// Proof-bound active committee snapshot: `uint64` L1 block number, bits 0–63.
    #[cfg(test)]
    pub const ACTIVE_COMMITTEE_SNAPSHOT: u64 = 284;
    /// Checkpoint landing records, keyed by endpoint height, three words each (STOR-B-9); see
    /// [`landing_record_slots`] and [`LandingRecord`].
    pub const LANDINGS: u64 = 285;
    /// Immutable generation origins, keyed by generation, three words each.
    pub const ORIGINS: u64 = 290;
    /// Four packed uint48 fields: active rules, next rules, rules time and stop time
    /// (STOR-B-15a); see [`RulesSchedule`].
    pub const RULES_SCHEDULE: u64 = 293;

    /// Returns the `N` consecutive words at a Solidity mapping element: `base =
    /// keccak256(abi.encode(uint256(key), uint256(mapping)))` and the words after it, with
    /// addition wrapping in 256 bits as in Solidity.
    fn mapping_words<const N: usize>(mapping: u64, key: u64) -> [B256; N] {
        let base = U256::from_be_bytes(
            alloy_primitives::keccak256([slot(key).as_slice(), slot(mapping).as_slice()].concat())
                .0,
        );
        std::array::from_fn(|offset| B256::from(base.wrapping_add(U256::from(offset))))
    }

    /// The three words of the slot 285 record of the landed endpoint `height` (STOR-B-9,
    /// ENC-A-3): packed parent/generation/head, EL hash and Comet hash. [`LandingRecord`]
    /// decodes them.
    pub fn landing_record_slots(height: u64) -> [B256; 3] {
        mapping_words(LANDINGS, height)
    }

    /// One decoded slot 285 record (STOR-B-9, ENC-A-3). Word 1 packs, from bit 0, the
    /// actual parent height, the generation that wrote the record and the forced inclusion
    /// head, 48 bits each, and its bits from 144 up are zero (STOR-B-23, STOR-B-24); words 2
    /// and 3 are the EL and Comet hashes. The start write records parent S, generation 0,
    /// head 0 and Comet hash 0.
    #[derive(Clone, Copy, Debug, PartialEq, Eq)]
    pub struct LandingRecord {
        /// The actual parent checkpoint height c the landing settled from.
        pub parent_height: u64,
        /// The recovery generation that wrote the record.
        pub generation: u64,
        /// The forced inclusion queue head after the landed height.
        pub forced_head: u64,
        /// The landed height's EL block hash.
        pub el_hash: B256,
        /// The landed height's Comet block ID hash.
        pub comet_hash: B256,
    }

    impl LandingRecord {
        /// The lowest reserved bit of word 1.
        pub const RESERVED_BIT: usize = 144;

        /// Decodes the words at [`landing_record_slots`], in order, or `None` when word 1 sets
        /// a reserved bit.
        pub fn decode([packed, el_hash, comet_hash]: [U256; 3]) -> Option<Self> {
            (packed >> Self::RESERVED_BIT == U256::ZERO).then(|| Self {
                parent_height: super::word_u48(packed, 0),
                generation: super::word_u48(packed, 48),
                forced_head: super::word_u48(packed, 96),
                el_hash: el_hash.into(),
                comet_hash: comet_hash.into(),
            })
        }
    }

    /// Decoded slot 293, the rules schedule (START-10.1-3e, STOR-B-15a): `activeRules`,
    /// `nextRules`, `rulesTime` and `stopTime`, 48 bits each from bit 0 (STOR-B-23). Bits from
    /// [`RulesSchedule::RESERVED_BIT`] up are zero (STOR-B-24).
    #[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
    pub struct RulesSchedule {
        /// The ruleset a block runs under before `rules_time`.
        pub active_rules: u64,
        /// The ruleset a block runs under from `rules_time` on.
        pub next_rules: u64,
        /// The block timestamp, in Unix seconds, from which `next_rules` applies.
        pub rules_time: u64,
        /// The planned stop time in Unix seconds; 0 means no stop (START-10.1-14d).
        pub stop_time: u64,
    }

    impl RulesSchedule {
        /// The lowest reserved bit of slot 293. Anchor witness verification rejects a word that
        /// sets it or any bit above it.
        pub const RESERVED_BIT: usize = 192;

        /// Decodes the four fields of slot 293's `word`. It reads no bit from
        /// [`Self::RESERVED_BIT`] up; checking those is the L1 witness verifier's job.
        pub fn decode(word: U256) -> Self {
            Self {
                active_rules: super::word_u48(word, 0),
                next_rules: super::word_u48(word, 48),
                rules_time: super::word_u48(word, 96),
                stop_time: super::word_u48(word, 144),
            }
        }

        /// The ruleset of a block whose timestamp is `timestamp`, in Unix seconds:
        /// `next_rules` from `rules_time` on, `active_rules` before (START-10.1-3f).
        pub fn rules_at(&self, timestamp: u64) -> u64 {
            if timestamp >= self.rules_time { self.next_rules } else { self.active_rules }
        }
    }

    /// Fixed start height, L1 block number and L1 timestamp for a generation.
    pub fn origin_slots(generation: u64) -> [B256; 3] {
        mapping_words(ORIGINS, generation)
    }

    /// Exact slot order for a recovery observation, including immutable deployment facts,
    /// current checkpoint/queue observations, fixed generation origin and retained landing.
    pub fn recovery_slots(generation: u64, height: u64) -> Vec<B256> {
        let mut slots = genesis_slots();
        slots.extend([
            slot(LAST_CHECKPOINT_HEIGHT),
            slot(LAST_CHECKPOINT_HASH),
            slot(FORCED_INCLUSION_HEAD_TAIL),
            slot(RULES_SCHEDULE),
        ]);
        slots.extend(origin_slots(generation));
        slots.extend(landing_record_slots(height));
        slots
    }

    /// Inbox status after genesis initialization.
    pub const ETNA_ACTIVE: u8 = 3;

    /// The 32-byte storage slot for the plain slot number `n`.
    pub fn slot(n: u64) -> B256 {
        B256::from(U256::from(n))
    }

    /// The fixed slots every per-block anchor witness proves, in this order: generation, last
    /// checkpoint height and hash, fallback keys hash, minimum total stake, the forced inclusion
    /// queue's head/tail and the rules schedule.
    pub fn anchor_slots() -> Vec<B256> {
        [
            RECOVERY_GENERATION,
            LAST_CHECKPOINT_HEIGHT,
            LAST_CHECKPOINT_HASH,
            FALLBACK_KEYS_HASH,
            MIN_TOTAL_STAKE,
            FORCED_INCLUSION_HEAD_TAIL,
            RULES_SCHEDULE,
        ]
        .map(slot)
        .to_vec()
    }

    /// Genesis status, generation, schedule, cutoff, bootstrap committee, configuration, and
    /// forced inclusion configuration.
    pub fn genesis_slots() -> Vec<B256> {
        let mut slots = [
            STATUS,
            RECOVERY_GENERATION,
            GENESIS_PACKED,
            START_BLOCK_HASH,
            START_STATE_ROOT,
            GENESIS_CUTOFF,
            GENESIS_COMMITTEE_HASH,
            COMMITTEE_CONFIG_HASH,
            FORCED_INCLUSION_CONFIG,
        ]
        .map(slot)
        .to_vec();
        slots.extend(origin_slots(0));
        slots
    }

    /// The two slots of forced inclusion `queue[index]`: the transaction hash, then the packed
    /// uint48 timestamp/L1 block.
    pub fn forced_inclusion_entry_slots(index: u64) -> [B256; 2] {
        mapping_words(FORCED_INCLUSION_QUEUE, index)
    }
}

/// Staking-registry storage slots (contract address = chain constant `ETNA_REGISTRY`).
///
/// The registry keeps its state in an ERC-7201 namespace `taiko.etna.registry` whose first field
/// is `checkpoints`, a dynamic array of two-word structs
/// `{ uint48 l1Block; uint48 count; bytes32 entriesRoot; }`. The second field is `entries`,
/// a dynamic array of three-word structs with a compressed key, uint256 stake and packed
/// uint8 key prefix / uint48 activation / uint48 exit heights, indexed by slot number.
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
#[cfg(test)]
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
    use crate::test_utils::vectors;
    use alloy_primitives::{B256, b256, keccak256};

    #[test]
    fn inbox_plain_slots_are_big_endian_numbers() {
        assert_eq!(
            inbox::slot(inbox::STATUS),
            b256!("0000000000000000000000000000000000000000000000000000000000000102")
        );
        assert_eq!(
            inbox::slot(inbox::FALLBACK_KEYS_HASH),
            b256!("0000000000000000000000000000000000000000000000000000000000000116")
        );
        assert_eq!(
            inbox::slot(inbox::MIN_TOTAL_STAKE),
            b256!("0000000000000000000000000000000000000000000000000000000000000117")
        );
        assert_eq!(inbox::slot(0), B256::ZERO);
        assert_eq!(inbox::slot(u64::MAX), B256::from(U256::from(u64::MAX)));
    }

    /// Every plain Inbox slot, the active status and the origin and landing slots match the
    /// shared layout vectors (`testdata/etna_vectors`), which the contracts check against a
    /// deployed Inbox. The anchor slot list is checked against the specification's own list
    /// (`anchor_slots_are_in_the_fixed_order` in the witness tests): the shared vectors still list
    /// the five slots of the anchor witness before it proved slots 278 and 279.
    #[test]
    fn inbox_slots_match_the_shared_vectors() {
        let slots = vectors::at("/layout/inbox/slots").as_object().expect("named slots");
        assert_eq!(slots.len(), 18);
        for name in slots.keys() {
            let constant = match name.as_str() {
                "initialization_status" => inbox::STATUS,
                "recovery_generation" => inbox::RECOVERY_GENERATION,
                "committee_config_hash" => inbox::COMMITTEE_CONFIG_HASH,
                "last_checkpoint_height" => inbox::LAST_CHECKPOINT_HEIGHT,
                "last_checkpoint_hash" => inbox::LAST_CHECKPOINT_HASH,
                "genesis_packed" => inbox::GENESIS_PACKED,
                "genesis_block_hash" => inbox::START_BLOCK_HASH,
                "genesis_state_root" => inbox::START_STATE_ROOT,
                "genesis_committee_record_hash" => inbox::GENESIS_COMMITTEE_HASH,
                "genesis_cutoff" => inbox::GENESIS_CUTOFF,
                "forced_inclusion_queue" => inbox::FORCED_INCLUSION_QUEUE,
                "forced_inclusion_head_tail" => inbox::FORCED_INCLUSION_HEAD_TAIL,
                "forced_inclusion_config" => inbox::FORCED_INCLUSION_CONFIG,
                "landings" => inbox::LANDINGS,
                "origins" => inbox::ORIGINS,
                "active_committee_snapshot" => inbox::ACTIVE_COMMITTEE_SNAPSHOT,
                // Governance authorization state is deliberately absent from node witnesses.
                "recovery_nonce" => 292,
                "rules_schedule" => inbox::RULES_SCHEDULE,
                other => panic!("the node reads no Inbox slot named {other}"),
            };
            assert_eq!(constant, vectors::u64_at(&format!("/layout/inbox/slots/{name}")), "{name}");
        }
        assert_eq!(
            u64::from(inbox::ETNA_ACTIVE),
            vectors::u64_at("/layout/inbox/initialized_status")
        );
        assert!(!inbox::anchor_slots().contains(&inbox::slot(292)));
        let origin_slots: fn(u64) -> Vec<B256> =
            |generation| inbox::origin_slots(generation).into();
        let landing_slots: fn(u64) -> Vec<B256> =
            |height| inbox::landing_record_slots(height).into();
        for (table, key, slots_fn) in [
            ("origin_slots", "generation", origin_slots),
            ("landing_slots", "height", landing_slots),
        ] {
            for case in vectors::at(&format!("/layout/inbox/{table}")).as_array().unwrap() {
                let index = case[key].as_str().unwrap().parse().unwrap();
                let expected: Vec<B256> = case["slots"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .map(|v| v.as_str().unwrap().parse().unwrap())
                    .collect();
                assert_eq!(slots_fn(index), expected, "{table} {index}");
            }
        }
    }

    /// STOR-B-9, STOR-B-23/24: slot 285's record is three words; word 1 packs parent height,
    /// generation and forced inclusion head, 48 bits each from bit 0, and its bits from 144 up
    /// are reserved. Words after the third are not part of the record.
    #[test]
    fn landing_record_decodes_three_words_and_rejects_reserved_bits() {
        let max48 = (1u64 << 48) - 1;
        let packed = U256::from(max48) | (U256::from(max48 - 1) << 48) | (U256::from(7) << 96);
        let el = U256::from_be_bytes([0xe1; 32]);
        let comet = U256::from_be_bytes([0xc1; 32]);
        assert_eq!(
            inbox::LandingRecord::decode([packed, el, comet]),
            Some(inbox::LandingRecord {
                parent_height: max48,
                generation: max48 - 1,
                forced_head: 7,
                el_hash: B256::repeat_byte(0xe1),
                comet_hash: B256::repeat_byte(0xc1),
            })
        );
        assert_eq!(
            inbox::LandingRecord::decode([U256::from(max48) << 96, el, comet])
                .map(|record| record.forced_head),
            Some(max48)
        );
        for bit in [144, 200, 255] {
            assert_eq!(inbox::LandingRecord::decode([U256::from(1) << bit, el, comet]), None);
        }
        let [first, second, third] = inbox::landing_record_slots(12);
        assert_eq!(
            U256::from_be_bytes(second.0),
            U256::from_be_bytes(first.0).wrapping_add(U256::from(1))
        );
        assert_eq!(
            U256::from_be_bytes(third.0),
            U256::from_be_bytes(first.0).wrapping_add(U256::from(2))
        );
    }

    /// STOR-B-15a, START-10.1-3f: slot 293 packs `activeRules`, `nextRules`, `rulesTime` and
    /// `stopTime`, 48 bits each from bit 0; a block's ruleset is `nextRules` from `rulesTime` on.
    #[test]
    fn rules_schedule_decodes_four_fields() {
        let max48 = (1u64 << 48) - 1;
        let word = U256::from(2) |
            (U256::from(3) << 48) |
            (U256::from(100) << 96) |
            (U256::from(max48) << 144) |
            (U256::from(9) << inbox::RulesSchedule::RESERVED_BIT);
        let schedule = inbox::RulesSchedule::decode(word);
        assert_eq!(
            schedule,
            inbox::RulesSchedule {
                active_rules: 2,
                next_rules: 3,
                rules_time: 100,
                stop_time: max48
            }
        );
        assert_eq!((schedule.rules_at(99), schedule.rules_at(100)), (2, 3));
        assert_eq!(inbox::RulesSchedule::RESERVED_BIT, 192);
        assert_eq!(inbox::RulesSchedule::decode(U256::ZERO), inbox::RulesSchedule::default());
        assert_eq!(inbox::RulesSchedule::default().rules_at(0), 0);
        // The shared packing table names the same offsets for the four fields.
        for (name, offset) in
            [("active_rules", 0), ("next_rules", 48), ("rules_time", 96), ("stop_time", 144)]
        {
            let field = format!("/layout/inbox/packing/rules_schedule/{name}");
            assert_eq!(vectors::u64_at(&format!("{field}/offset")), offset, "{name}");
            assert_eq!(vectors::u64_at(&format!("{field}/bits")), 48, "{name}");
        }
    }

    /// Entry `i` of the `queue` mapping at slot 280 is a `ForcedInclusion` struct at
    /// `keccak256(abi.encode(i, 280))`: `txHash`, then `timestamp | l1Block << 48` (two
    /// `uint48`s) in the next slot.
    #[test]
    fn forced_inclusion_entry_slots_follow_solidity_layout() {
        let slots = inbox::forced_inclusion_entry_slots(7);

        let mut preimage = [0u8; 64];
        preimage[..32].copy_from_slice(&U256::from(7u64).to_be_bytes::<32>());
        preimage[32..].copy_from_slice(&U256::from(280u64).to_be_bytes::<32>());
        let base = U256::from_be_bytes(keccak256(preimage).0);
        assert_eq!(slots[0], B256::from(base));
        assert_eq!(slots[1], B256::from(base + U256::from(1)));
        assert_ne!(inbox::forced_inclusion_entry_slots(8)[0], slots[0]);

        // The shared vectors (`cast index uint256 <i> 280`), which the contracts check against
        // a deployed Inbox's queue.
        for k in 0..vectors::len_at("/layout/inbox/forced_inclusion_entry_slots") {
            let p = format!("/layout/inbox/forced_inclusion_entry_slots/{k}");
            let index = vectors::u64_at(&format!("{p}/index"));
            assert_eq!(
                inbox::forced_inclusion_entry_slots(index).to_vec(),
                vectors::b256s_at(&format!("{p}/slots")),
                "entry {index}"
            );
        }
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

    /// The registry namespace, base, entries length slot and the checkpoint and entry slots
    /// (including the last `u64` index) match the shared layout vectors, which the contracts
    /// check against a deployed registry.
    #[test]
    fn registry_slots_match_the_shared_vectors() {
        assert_eq!(registry::NAMESPACE, vectors::str_at("/layout/registry/namespace"));
        assert_eq!(registry::base(), vectors::b256_at("/layout/registry/base"));
        assert_eq!(registry::length_slot(), registry::base());
        assert_eq!(
            registry::entries_length_slot(),
            vectors::b256_at("/layout/registry/entries_slot")
        );
        for k in 0..vectors::len_at("/layout/registry/checkpoint_slots") {
            let p = format!("/layout/registry/checkpoint_slots/{k}");
            let i = vectors::u64_at(&format!("{p}/index"));
            let expected = vectors::b256s_at(&format!("{p}/slots"));
            assert_eq!(registry::checkpoint_slots(i).to_vec(), expected, "checkpoint {i}");
        }
        for k in 0..vectors::len_at("/layout/registry/entry_slots") {
            let p = format!("/layout/registry/entry_slots/{k}");
            let j = vectors::u64_at(&format!("{p}/index"));
            let expected = vectors::b256s_at(&format!("{p}/slots"));
            assert_eq!(registry::entry_slots(j).to_vec(), expected, "entry {j}");
        }
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
    fn registry_checkpoint_data_starts_at_keccak_of_base() {
        assert_eq!(registry::checkpoint_slots(0)[0], keccak256(registry::base()));
        // Element `i` is two words past element `i - 1`, wrapping in U256 at the last index.
        let data = U256::from_be_bytes(keccak256(registry::base()).0);
        let last = data.wrapping_add(U256::from(u64::MAX) * U256::from(2));
        assert_eq!(registry::checkpoint_slots(u64::MAX)[0], B256::from(last));
    }

    #[test]
    fn registry_entries_length_slot_is_base_plus_one() {
        let base = U256::from_be_bytes(registry::base().0);
        assert_eq!(registry::entries_length_slot(), B256::from(base + U256::from(1)));
    }

    #[test]
    fn registry_entries_reject_the_obsolete_four_word_stride() {
        let base = U256::from_be_bytes(keccak256(registry::entries_length_slot()).0);
        assert_ne!(registry::entry_slots(1)[0], B256::from(base + U256::from(4)));
        assert_eq!(registry::entry_slots(1)[0], B256::from(base + U256::from(3)));
        assert_eq!(registry::entry_slots(0).len(), 3);
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

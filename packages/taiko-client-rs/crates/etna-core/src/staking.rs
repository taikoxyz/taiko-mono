//! `EtnaStaking` ERC-7201 storage layout: the candidate snapshot and key-to-seat words that nodes
//! and guests read (Appendix B of the Etna specification).
//!
//! Slot arithmetic wraps in 256 bits, as Solidity storage offsets do. Words are returned whole:
//! callers compare `snapshotHeight` with a block number in all 256 bits and check the unused bits
//! of each record's second word themselves.

use alloy_primitives::{Address, B256, U256, b256, keccak256};

/// The ERC-7201 namespace identifier of the staking contract's storage.
pub const NAMESPACE: &str = "taiko.etna.staking";

/// The ERC-7201 base slot `T` of [`NAMESPACE`], as [`erc7201_base`] computes it.
pub const BASE: B256 = b256!("5cfa9ae4fa3ccb6db5189dbaff84335bb566ebd2f7442638272a1d81ccb19e00");

/// The number of snapshot seat records, one per seat number whatever the contract's seat limit
/// is; seat numbers are below this count.
pub const RECORD_COUNT: usize = 128;

/// The number of words one candidate snapshot read takes: `snapshotHeight`,
/// `snapshotTotalStake` and two words per seat record.
pub const SNAPSHOT_SLOT_COUNT: usize = 2 + 2 * RECORD_COUNT;

/// The ERC-7201 base slot of `namespace`:
/// `keccak256(abi.encode(uint256(keccak256(namespace)) - 1)) & ~bytes32(uint256(0xff))`.
pub fn erc7201_base(namespace: &str) -> B256 {
    let id = U256::from_be_bytes(keccak256(namespace).0);
    let mut base = keccak256(B256::from(id.wrapping_sub(U256::from(1))));
    base.0[31] = 0;
    base
}

/// The slot `T + offset`, wrapping in 256 bits.
fn base_plus(offset: u64) -> B256 {
    B256::from(U256::from_be_bytes(BASE.0).wrapping_add(U256::from(offset)))
}

/// The slot of `snapshotHeight` (`T`): the block number whose `onBlockStart` stored the snapshot.
pub fn snapshot_height_slot() -> B256 {
    BASE
}

/// The slot of `snapshotTotalStake` (`T + 1`).
pub fn snapshot_total_stake_slot() -> B256 {
    base_plus(1)
}

/// The slot of the live key-to-seat value of consensus key address `ck_addr`:
/// `keccak256(abi.encode(ck_addr, T + 2))`. Its word decodes with [`decode_seat`].
pub fn key_to_seat_slot(ck_addr: Address) -> B256 {
    let mut preimage = [0u8; 64];
    preimage[..32].copy_from_slice(ck_addr.into_word().as_slice());
    preimage[32..].copy_from_slice(base_plus(2).as_slice());
    keccak256(preimage)
}

/// The two slots of snapshot seat record `seat`, `[T + 3 + 2 * seat, T + 4 + 2 * seat]`.
///
/// Word one is `ckX`; word two packs `ckPrefix` (bits 0–7) and power (bits 8–71) with every other
/// bit zero. A record whose two words are both zero is an empty seat.
///
/// # Panics
///
/// If `seat` is not below [`RECORD_COUNT`]: those slots hold no seat record.
pub fn record_slots(seat: u8) -> [B256; 2] {
    assert!(usize::from(seat) < RECORD_COUNT, "seat {seat} has no snapshot record");
    let first = 3 + 2 * u64::from(seat);
    [base_plus(first), base_plus(first + 1)]
}

/// Every slot of one candidate snapshot read, in read order: `snapshotHeight`,
/// `snapshotTotalStake`, then word one and word two of each record from seat 0 to seat 127.
pub fn snapshot_slots() -> [B256; SNAPSHOT_SLOT_COUNT] {
    let mut slots = [B256::ZERO; SNAPSHOT_SLOT_COUNT];
    slots[0] = snapshot_height_slot();
    slots[1] = snapshot_total_stake_slot();
    for (seat, pair) in slots[2..].as_chunks_mut::<2>().0.iter_mut().enumerate() {
        // `seat` is below RECORD_COUNT, which fits in a u8.
        *pair = record_slots(seat as u8);
    }
    slots
}

/// The seat a live key-to-seat word names, or `None` when the key holds no seat or the word is
/// malformed.
///
/// The word packs `holdsSeat` (bits 0–7) and the seat number (bits 8–15) with every bit from 16 up
/// zero. It is well formed and names a seat only when `holdsSeat` is 1, the seat number is below
/// [`RECORD_COUNT`] and the high bits are zero; a key holding no seat maps to the zero word.
pub fn decode_seat(word: U256) -> Option<u8> {
    let holds_seat = word.byte(0);
    let seat = word.byte(1);
    (holds_seat == 1 && usize::from(seat) < RECORD_COUNT && (word >> 16usize).is_zero())
        .then_some(seat)
}

/// The words of one candidate snapshot, whole and unmasked.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct StakingWords {
    /// The word at `T`, `snapshotHeight`, in all 256 bits.
    pub snapshot_height: U256,
    /// The word at `T + 1`, `snapshotTotalStake`.
    pub total_stake: U256,
    /// Each seat record's two words, indexed by seat number: `[ckX, packed ckPrefix and power]`.
    pub records: [[U256; 2]; RECORD_COUNT],
}

impl StakingWords {
    /// The snapshot from `values` read at [`snapshot_slots`], in that order; `None` unless there
    /// are exactly [`SNAPSHOT_SLOT_COUNT`] values.
    pub fn from_snapshot_values(values: &[U256]) -> Option<Self> {
        if values.len() != SNAPSHOT_SLOT_COUNT {
            return None;
        }
        let mut records = [[U256::ZERO; 2]; RECORD_COUNT];
        // The length check leaves exactly two words for each record after the header.
        records.copy_from_slice(values[2..].as_chunks::<2>().0);
        Some(Self { snapshot_height: values[0], total_stake: values[1], records })
    }

    /// A snapshot with the given header words and every seat record empty (all zero).
    pub fn header_only(snapshot_height: U256, total_stake: U256) -> Self {
        Self { snapshot_height, total_stake, records: [[U256::ZERO; 2]; RECORD_COUNT] }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::vectors::{at as vector, b256_at, len_at, str_at, u64_at};

    fn at(offset: u64) -> B256 {
        B256::from(U256::from_be_bytes(BASE.0) + U256::from(offset))
    }

    /// The word at `pointer`, a 32-byte hex string.
    fn word_at(pointer: &str) -> U256 {
        U256::from_be_bytes(b256_at(pointer).0)
    }

    #[test]
    fn base_is_the_erc7201_slot_of_the_namespace() {
        let expected = b256_at("/staking_layout/base");
        assert_eq!(NAMESPACE, str_at("/staking_layout/namespace"));
        assert_eq!(BASE, expected);
        assert_eq!(erc7201_base(NAMESPACE), expected);
        assert_eq!(snapshot_height_slot(), BASE);
        assert_eq!(snapshot_height_slot(), b256_at("/staking_layout/snapshot_height_slot"));
        assert_eq!(snapshot_total_stake_slot(), at(1));
        assert_eq!(
            snapshot_total_stake_slot(),
            b256_at("/staking_layout/snapshot_total_stake_slot")
        );
        // The key-to-seat mapping's base slot, T + 2.
        assert_eq!(at(2), b256_at("/staking_layout/key_seat_slot"));
    }

    #[test]
    fn record_slots_follow_the_base() {
        assert_eq!(record_slots(0), [at(3), at(4)]);
        assert_eq!(record_slots(5), [at(13), at(14)]);
        assert_eq!(record_slots(127)[1], at(258));
        for index in 0..len_at("/staking_layout/record_slots") {
            let path = |field: &str| format!("/staking_layout/record_slots/{index}/{field}");
            let seat = u8::try_from(u64_at(&path("seat"))).unwrap();
            assert_eq!(
                record_slots(seat),
                [b256_at(&path("word1")), b256_at(&path("word2"))],
                "seat {seat}"
            );
        }
    }

    #[test]
    #[should_panic(expected = "seat 128 has no snapshot record")]
    fn record_slots_refuse_a_seat_past_the_last_record() {
        record_slots(128);
    }

    /// The key-to-seat slot of each shared vector address, the first the key of secret one.
    #[test]
    fn key_to_seat_slot_of_the_key_of_secret_one() {
        assert_eq!(
            str_at("/staking_layout/key_seat_slots/0/ck_addr").parse::<Address>().unwrap(),
            crate::test_utils::test_key(0).address()
        );
        for index in 0..len_at("/staking_layout/key_seat_slots") {
            let path = |field: &str| format!("/staking_layout/key_seat_slots/{index}/{field}");
            let address: Address = str_at(&path("ck_addr")).parse().unwrap();
            assert_eq!(key_to_seat_slot(address), b256_at(&path("slot")), "{address}");
        }
    }

    #[test]
    fn decode_seat_accepts_only_well_formed_words() {
        for (word, seat) in [(0x0501, 5), (0x0301, 3), (0x7f01, 127), (0x6401, 100), (0x0001, 0)] {
            assert_eq!(decode_seat(U256::from(word)), Some(seat), "word {word:#x}");
        }
        // Not holding a seat, a holdsSeat flag other than one, a seat at or above the record
        // count, a nonzero bit from bit 16 up, and a released seat that kept its number.
        for word in [0, 0x0302, 0x8001, 0x10301, 0x0500] {
            assert_eq!(decode_seat(U256::from(word)), None, "word {word:#x}");
        }
        assert_eq!(decode_seat(U256::MAX), None);
        assert_eq!(decode_seat((U256::from(1) << 255) | U256::from(0x0501)), None);
        // The shared key-to-seat words, each with its seat or none.
        for index in 0..len_at("/staking_layout/key_seat_words") {
            let path = format!("/staking_layout/key_seat_words/{index}");
            let seat =
                vector(&format!("{path}/seat")).as_str().map(|seat| seat.parse::<u8>().unwrap());
            assert_eq!(decode_seat(word_at(&format!("{path}/word"))), seat, "{path}");
        }
        // The packed holdsSeat flag and seat number.
        for index in 0..len_at("/packed_words/staking_key_seat") {
            let path = |field: &str| format!("/packed_words/staking_key_seat/{index}/{field}");
            assert_eq!(u64_at(&path("holds_seat")), 1);
            let seat = u8::try_from(u64_at(&path("seat"))).unwrap();
            assert_eq!(decode_seat(word_at(&path("word"))), Some(seat), "seat {seat}");
        }
    }

    #[test]
    fn snapshot_slots_are_258_in_read_order() {
        let slots = snapshot_slots();
        assert_eq!(slots.len(), SNAPSHOT_SLOT_COUNT);
        assert_eq!(SNAPSHOT_SLOT_COUNT, 258);
        assert_eq!(slots[0], BASE);
        assert_eq!(slots[1], at(1));
        assert_eq!(slots[2], at(3));
        assert_eq!(slots[257], at(258));
        for seat in 0..RECORD_COUNT as u8 {
            let index = 2 + 2 * usize::from(seat);
            assert_eq!([slots[index], slots[index + 1]], record_slots(seat), "seat {seat}");
        }
    }

    #[test]
    fn from_snapshot_values_requires_all_258() {
        let values: Vec<U256> = (0..SNAPSHOT_SLOT_COUNT as u64).map(U256::from).collect();
        assert_eq!(StakingWords::from_snapshot_values(&values[..257]), None);
        let mut longer = values.clone();
        longer.push(U256::ZERO);
        assert_eq!(StakingWords::from_snapshot_values(&longer), None);

        let words = StakingWords::from_snapshot_values(&values).expect("all 258 words");
        assert_eq!(words.snapshot_height, U256::from(0));
        assert_eq!(words.total_stake, U256::from(1));
        assert_eq!(words.records[0], [U256::from(2), U256::from(3)]);
        assert_eq!(words.records[127], [U256::from(256), U256::from(257)]);

        let mut header = vec![U256::ZERO; SNAPSHOT_SLOT_COUNT];
        header[0] = U256::from(7);
        header[1] = U256::from(9);
        assert_eq!(
            StakingWords::from_snapshot_values(&header),
            Some(StakingWords::header_only(U256::from(7), U256::from(9)))
        );
    }
}

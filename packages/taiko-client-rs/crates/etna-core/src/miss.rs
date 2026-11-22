//! The `missBitmap` a block's `extraData` carries: which seats the validators missing from its
//! LastCommit hold.
//!
//! The validators considered are the set that signs the parent, in CometBFT order, whether they
//! are candidate members or fallback keys. One is missing when its LastCommit entry is not a
//! commit for the parent block (an absent or nil vote). Each missing validator's live key-to-seat
//! word, read from the parent's post-state, gives its seat through
//! [`decode_seat`](crate::staking::decode_seat); a word naming no seat, malformed ones included,
//! sets no bit. A generation's first block has no LastCommit and its `missBitmap` is 0.

use crate::staking::decode_seat;
use alloc::vec::Vec;
use alloy_primitives::{Address, U256};

/// The validators of `signers` whose LastCommit entry is not a commit: `committed[i]` says whether
/// the i-th entry, which belongs to `signers[i]` as in stock CometBFT, has the commit flag. `None`
/// when the two lengths differ, as a LastCommit that does not list exactly the parent's signers.
pub fn missing_addresses(signers: &[Address], committed: &[bool]) -> Option<Vec<Address>> {
    (signers.len() == committed.len()).then(|| {
        signers
            .iter()
            .zip(committed)
            .filter_map(|(address, &committed)| (!committed).then_some(*address))
            .collect()
    })
}

/// The `missBitmap` of the `missing` validators: bit `s` is set exactly when `seat_word` gives
/// some missing validator's address a key-to-seat word naming seat `s`, so a seat that two
/// addresses map to is set when either is missing. `seat_word` is called only for the addresses
/// in `missing`.
pub fn miss_bitmap(missing: &[Address], mut seat_word: impl FnMut(Address) -> U256) -> u128 {
    missing
        .iter()
        .filter_map(|&address| decode_seat(seat_word(address)))
        // `decode_seat` names only seats below 128, each a bit of the u128.
        .fold(0, |bitmap, seat| bitmap | (1u128 << seat))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::BTreeMap;

    fn addr(n: u8) -> Address {
        Address::with_last_byte(n)
    }

    /// The `missBitmap` of a LastCommit whose i-th entry, for `signers[i]`, has `committed[i]`,
    /// with the key-to-seat word of each address in `words` and the zero word for every other.
    fn bitmap(signers: &[Address], committed: &[bool], words: &[(Address, u64)]) -> u128 {
        let words: BTreeMap<_, _> = words.iter().copied().collect();
        let missing = missing_addresses(signers, committed).expect("one flag per signer");
        miss_bitmap(&missing, |address| U256::from(words.get(&address).copied().unwrap_or(0)))
    }

    #[test]
    fn all_committed_gives_zero() {
        let signers = [addr(1), addr(2), addr(3)];
        let committed = [true; 3];
        assert_eq!(missing_addresses(&signers, &committed), Some(vec![]));
        let missing = missing_addresses(&signers, &committed).unwrap();
        assert_eq!(miss_bitmap(&missing, |address| panic!("read the seat of {address}")), 0);
    }

    #[test]
    fn absent_or_nil_with_seat_3_gives_8() {
        // An absent vote and a nil vote both leave the entry's flag other than commit.
        let signers = [addr(1), addr(2), addr(3)];
        let committed = [true, false, true];
        assert_eq!(missing_addresses(&signers, &committed), Some(vec![addr(2)]));
        assert_eq!(bitmap(&signers, &committed, &[(addr(1), 0x0101), (addr(2), 0x0301)]), 8);
    }

    #[test]
    fn two_missing_give_9() {
        let signers = [addr(1), addr(2), addr(3)];
        let committed = [false, true, false];
        assert_eq!(missing_addresses(&signers, &committed), Some(vec![addr(1), addr(3)]));
        assert_eq!(bitmap(&signers, &committed, &[(addr(1), 0x0001), (addr(3), 0x0301)]), 9);
    }

    #[test]
    fn unseated_fallback_key_sets_no_bit() {
        assert_eq!(bitmap(&[addr(1)], &[false], &[(addr(1), 0)]), 0);
    }

    #[test]
    fn fallback_key_with_a_seated_bond_sets_its_seat() {
        let signers = [addr(1), addr(2)];
        assert_eq!(bitmap(&signers, &[false, true], &[(addr(1), 0x0701)]), 1 << 7);
    }

    #[test]
    fn malformed_words_set_no_bit() {
        // A holdsSeat flag of 2, a seat of 128, a nonzero bit from bit 16 up, and a seat number
        // without the holdsSeat flag.
        for word in [0x0302, 0x8001, 0x10301, 0x0500] {
            assert_eq!(bitmap(&[addr(1)], &[false], &[(addr(1), word)]), 0, "word {word:#x}");
        }
        let signers = [addr(1), addr(2), addr(3), addr(4)];
        let words = [(addr(1), 0x0302), (addr(2), 0x8001), (addr(3), 0x10301), (addr(4), 0x0500)];
        assert_eq!(bitmap(&signers, &[false; 4], &words), 0);
        assert_eq!(miss_bitmap(&[addr(1)], |_| U256::MAX), 0);
    }

    #[test]
    fn shared_seat_is_set_once() {
        let signers = [addr(1), addr(2)];
        let words = [(addr(1), 0x0601), (addr(2), 0x0601)];
        assert_eq!(bitmap(&signers, &[false, true], &words), 1 << 6);
        assert_eq!(bitmap(&signers, &[true, false], &words), 1 << 6);
        assert_eq!(bitmap(&signers, &[false, false], &words), 1 << 6);
        assert_eq!(bitmap(&signers, &[true, true], &words), 0);
    }

    #[test]
    fn seat_100_sets_bit_100() {
        assert_eq!(bitmap(&[addr(1)], &[false], &[(addr(1), 0x6401)]), 1 << 100);
    }

    #[test]
    fn empty_commit_gives_zero() {
        assert_eq!(missing_addresses(&[], &[]), Some(vec![]));
        assert_eq!(miss_bitmap(&[], |address| panic!("read the seat of {address}")), 0);
    }

    #[test]
    fn length_mismatch_is_none() {
        let signers = [addr(1), addr(2)];
        assert_eq!(missing_addresses(&signers, &[false]), None);
        assert_eq!(missing_addresses(&signers, &[false, true, true]), None);
        assert_eq!(missing_addresses(&[], &[false]), None);
        assert_eq!(missing_addresses(&signers, &[]), None);
    }
}

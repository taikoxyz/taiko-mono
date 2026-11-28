//! Hash-pinned reads of the `EtnaStaking` words a node decides with, from its own EL.
//!
//! The candidate snapshot that decides the set signing H + 2 is read from H's post-state, and the
//! live key-to-seat values that set a block's miss bitmap from its parent's post-state. Every read
//! names the exact block hash whose post-state it reads ([`Engine::storage_at`]), never the EL's
//! head, so a replay reads the same words wherever the head has moved since. Words are returned
//! whole; callers compare and decode them with etna-core's rules ([`needs_records`],
//! [`decode_seat`](etna_core::staking::decode_seat)).

use std::collections::{BTreeMap, BTreeSet};

use alloy_primitives::{Address, B256, U256};
use etna_core::staking::{StakingWords, key_to_seat_slot, snapshot_slots};

use super::{Engine, EngineError};
use crate::committee::needs_records;

/// The candidate snapshot that block `hash`'s block-start call stored in the staking contract
/// `staking`, read from that block's post-state; `height` is the block's number and
/// `min_total_stake` the minimum total stake its anchor proves.
///
/// `snapshotHeight` and `snapshotTotalStake` are read first. When they rule the candidate out at
/// `height` ([`needs_records`]), the 256 record words are not read and come back as empty seats,
/// which decides the same set; otherwise all 128 records are read at the same hash. Every word
/// is whole. An error of the engine is returned as it is, and an answer with another number of
/// words than slots asked for is [`EngineError::BadReply`].
pub async fn staking_words<E: Engine + ?Sized>(
    engine: &E,
    staking: Address,
    hash: B256,
    height: u64,
    min_total_stake: U256,
) -> Result<StakingWords, EngineError> {
    let slots = snapshot_slots();
    let (header, records) = slots.split_at(2);
    let mut words = read(engine, staking, header, hash).await?;
    if !needs_records(height, words[0], words[1], min_total_stake) {
        return Ok(StakingWords::header_only(words[0], words[1]));
    }
    words.extend(read(engine, staking, records, hash).await?);
    StakingWords::from_snapshot_values(&words)
        .ok_or_else(|| EngineError::BadReply(format!("incomplete staking snapshot at {hash}")))
}

/// The live key-to-seat word of each address in `addrs` in the staking contract `staking`, read
/// whole from the post-state of block `hash`, each address once; a key that holds no seat reads
/// zero. Decode the words with [`decode_seat`](etna_core::staking::decode_seat). No address
/// reads nothing. Errors as [`staking_words`].
pub async fn seat_words<E: Engine + ?Sized>(
    engine: &E,
    staking: Address,
    hash: B256,
    addrs: &[Address],
) -> Result<BTreeMap<Address, U256>, EngineError> {
    if addrs.is_empty() {
        return Ok(BTreeMap::new());
    }
    let addrs = addrs.iter().copied().collect::<BTreeSet<_>>();
    let slots: Vec<B256> = addrs.iter().map(|addr| key_to_seat_slot(*addr)).collect();
    let words = read(engine, staking, &slots, hash).await?;
    Ok(addrs.into_iter().zip(words).collect())
}

/// [`Engine::storage_at`], checked to answer one word per slot.
async fn read<E: Engine + ?Sized>(
    engine: &E,
    address: Address,
    slots: &[B256],
    hash: B256,
) -> Result<Vec<U256>, EngineError> {
    let words = engine.storage_at(address, slots, hash).await?;
    if words.len() != slots.len() {
        return Err(EngineError::BadReply(format!(
            "storage read of {address} at {hash} answered {} words for {} slots",
            words.len(),
            slots.len()
        )));
    }
    Ok(words)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::{EngineCall, MockEngine};
    use alloy_consensus::Header;
    use etna_core::staking::{
        RECORD_COUNT, SNAPSHOT_SLOT_COUNT, snapshot_height_slot, snapshot_total_stake_slot,
    };

    const STAKING: Address = Address::repeat_byte(0x5a);
    const H: u64 = 40;

    fn min_stake() -> U256 {
        U256::from(1_000)
    }

    /// Each storage read `engine` was asked for: the account, the block hash and the slots.
    fn reads(engine: &MockEngine) -> Vec<(Address, B256, Vec<B256>)> {
        engine
            .calls()
            .into_iter()
            .filter_map(|call| match call {
                EngineCall::StorageAt { address, slots, hash } => Some((address, hash, slots)),
                _ => None,
            })
            .collect()
    }

    /// How many slots `engine` was asked to read, over every read.
    fn slots_read(engine: &MockEngine) -> usize {
        reads(engine).iter().map(|(_, _, slots)| slots.len()).sum()
    }

    /// Stores at `hash` a snapshot with the given header words whose record words all differ,
    /// derived from `salt`, and returns it.
    fn store_snapshot(
        engine: &MockEngine,
        hash: B256,
        snapshot_height: U256,
        total_stake: U256,
        salt: u64,
    ) -> StakingWords {
        let mut words = StakingWords::header_only(snapshot_height, total_stake);
        for (seat, record) in words.records.iter_mut().enumerate() {
            let seat = seat as u64;
            // Full-width words: bit 255 set, so a reader that masks them is caught.
            *record = [
                U256::MAX - U256::from(salt * 1_000 + 2 * seat),
                U256::MAX - U256::from(salt * 1_000 + 2 * seat + 1),
            ];
        }
        let values = [snapshot_height, total_stake]
            .into_iter()
            .chain(words.records.iter().flatten().copied());
        for (slot, value) in snapshot_slots().into_iter().zip(values) {
            engine.set_storage(hash, STAKING, slot, value);
        }
        words
    }

    /// A block at `number` on `parent`, distinct per `salt`.
    fn header(number: u64, parent: B256, salt: u64) -> Header {
        Header { number, parent_hash: parent, timestamp: salt, ..Header::default() }
    }

    /// Both readers read the post-state of the block they name, here a canonical ancestor of
    /// the EL head that holds other words: the head's words never leak into the answer, and
    /// every read names the requested hash of the staking contract.
    #[tokio::test]
    async fn reads_are_pinned_to_the_hash() {
        let block = header(H, B256::ZERO, 1);
        let head = header(H + 1, block.hash_slow(), 2);
        let (at, later) = (block.hash_slow(), head.hash_slow());
        let engine = MockEngine::with_chain([block, head]);
        let expected = store_snapshot(&engine, at, U256::from(H), min_stake(), 1);
        store_snapshot(&engine, later, U256::from(H), min_stake(), 2);

        let (a, b) = (Address::repeat_byte(0x0a), Address::repeat_byte(0x0b));
        for (address, at_word, later_word) in [(a, 0x0501, 0x0601), (b, 0x10301, 0)] {
            engine.set_storage(at, STAKING, key_to_seat_slot(address), U256::from(at_word));
            engine.set_storage(later, STAKING, key_to_seat_slot(address), U256::from(later_word));
        }

        let words = staking_words(&engine, STAKING, at, H, min_stake()).await.unwrap();
        assert_eq!(words, expected);
        let seats = seat_words(&engine, STAKING, at, &[b, a, b]).await.unwrap();
        assert_eq!(
            seats,
            BTreeMap::from([(a, U256::from(0x0501)), (b, U256::from(0x10301))]),
            "whole words, not decoded seats"
        );

        let reads = reads(&engine);
        assert_eq!(reads.len(), 3, "the snapshot header, its records, then the seats");
        for (address, hash, _) in &reads {
            assert_eq!((*address, *hash), (STAKING, at));
        }
        assert_eq!(reads[2].2, vec![key_to_seat_slot(a), key_to_seat_slot(b)], "each key once");
        assert_eq!(engine.calls().len(), 3, "nothing but storage reads");

        assert_eq!(seat_words(&engine, STAKING, at, &[]).await, Ok(BTreeMap::new()));
        assert_eq!(engine.calls().len(), 3, "no address, no read");
    }

    /// `snapshotHeight` and `snapshotTotalStake` are read first; when they already rule the
    /// candidate out, the 256 record words are not read and come back empty, which decides the
    /// same set. A usable header reads all 258 words.
    #[tokio::test]
    async fn records_are_skipped_when_the_header_rules_out_the_candidate() {
        let bit_48 = U256::from(1) << 48;
        for (case, snapshot_height, total_stake, minimum, read) in [
            ("the minimum is the largest word", U256::from(H), U256::MAX, U256::MAX, 2),
            ("an older snapshot", U256::from(H - 1), min_stake(), min_stake(), 2),
            ("bit 48 set", U256::from(H) | bit_48, min_stake(), min_stake(), 2),
            (
                "a total below the minimum",
                U256::from(H),
                min_stake() - U256::from(1),
                min_stake(),
                2,
            ),
            ("a usable header", U256::from(H), min_stake(), min_stake(), SNAPSHOT_SLOT_COUNT),
        ] {
            let hash = B256::repeat_byte(0x11);
            let engine = MockEngine::new();
            let stored = store_snapshot(&engine, hash, snapshot_height, total_stake, 3);

            let words = staking_words(&engine, STAKING, hash, H, minimum).await.unwrap();
            assert_eq!(slots_read(&engine), read, "{case}");
            if read == SNAPSHOT_SLOT_COUNT {
                assert_eq!(words, stored, "{case}");
            } else {
                assert_eq!(
                    words,
                    StakingWords::header_only(snapshot_height, total_stake),
                    "{case}"
                );
                assert_eq!(
                    reads(&engine)[0].2,
                    vec![snapshot_height_slot(), snapshot_total_stake_slot()],
                    "{case}"
                );
            }
        }
    }

    /// An engine that answers another number of words than slots asked for gives no value: a
    /// [`EngineError::BadReply`], never a shortened or padded snapshot.
    #[tokio::test]
    async fn wrong_reply_count_is_bad_reply() {
        let hash = B256::repeat_byte(0x22);
        let usable = vec![U256::from(H), min_stake()];
        let records = |n: usize| vec![U256::from(7); n];
        for (case, script) in [
            ("one header word", vec![vec![U256::from(H)]]),
            ("three header words", vec![vec![U256::from(H), min_stake(), U256::ZERO]]),
            ("255 record words", vec![usable.clone(), records(2 * RECORD_COUNT - 1)]),
            ("257 record words", vec![usable.clone(), records(2 * RECORD_COUNT + 1)]),
        ] {
            let engine = MockEngine::new();
            engine.state().storage_script.extend(script.into_iter().map(Ok));
            let err = staking_words(&engine, STAKING, hash, H, min_stake()).await.unwrap_err();
            assert!(matches!(err, EngineError::BadReply(_)), "{case}: {err:?}");
            assert!(!err.is_retryable(), "{case}");
        }

        let (a, b) = (Address::repeat_byte(0x0a), Address::repeat_byte(0x0b));
        for words in [vec![], vec![U256::ZERO], vec![U256::ZERO; 3]] {
            let engine = MockEngine::new();
            engine.state().storage_script.push_back(Ok(words.clone()));
            let err = seat_words(&engine, STAKING, hash, &[a, b]).await.unwrap_err();
            assert!(matches!(err, EngineError::BadReply(_)), "{} words: {err:?}", words.len());
        }
    }

    /// A block the EL does not hold, or holds off its canonical chain, is a node-local fault
    /// that a retry may cure, never a zero word.
    #[tokio::test]
    async fn unknown_block_is_retryable() {
        let block = header(H, B256::ZERO, 1);
        let side = header(H, B256::ZERO, 2);
        let engine = MockEngine::with_chain([block]);
        engine.insert_known(side.clone());
        let addr = Address::repeat_byte(0x0a);

        for hash in [B256::repeat_byte(0x33), side.hash_slow()] {
            let errors = [
                staking_words(&engine, STAKING, hash, H, min_stake()).await.unwrap_err(),
                seat_words(&engine, STAKING, hash, &[addr]).await.unwrap_err(),
            ];
            for err in errors {
                assert!(matches!(err, EngineError::Transport(_)), "{hash}: {err:?}");
                assert!(err.is_retryable(), "{hash}");
            }
        }
        assert_eq!(slots_read(&engine), 2 * 3, "the two header words and one seat, per hash");
    }
}

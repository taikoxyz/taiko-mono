//! Turns verified Inbox witnesses into facts. No I/O.
//!
//! [`verify_anchor_witness`] checks a per-block anchor witness's proofs against its own L1
//! header and decodes the Inbox facts; [`verify_genesis_inbox`] does the same for the genesis
//! witness and also decodes the genesis record. Neither checks that the L1 header is
//! canonical and final: that needs the node's own L1 and lives in `l1::source`.

use alloy_primitives::{Address, B256, U256};

use crate::{
    envelope::AnchorWitness,
    l1::{
        header::RawL1Header,
        layout::{inbox, word_u8, word_u48, word_u64},
        mpt::{MptError, VerifiedStorage, verify_account_witness},
    },
    types::{AccountWitness, AnchorState, GenesisRecord, InboxFacts},
};

/// Why an anchor or genesis witness was rejected.
#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum WitnessError {
    /// The witness proves an account other than the configured Inbox.
    #[error("witness proves {got}, expected the inbox at {expected}")]
    WrongContract {
        /// The configured Inbox address (chain constant).
        expected: Address,
        /// The address the witness proves.
        got: Address,
    },
    /// The account or storage proofs do not verify, or prove the wrong slot set.
    #[error(transparent)]
    Mpt(#[from] MptError),
    /// Genesis only: the Inbox's initialization status is not `ETNA_ACTIVE`.
    #[error("inbox status is {0}, expected ETNA_ACTIVE ({active})", active = inbox::ETNA_ACTIVE)]
    NotInitialized(u8),
    /// Genesis only: the genesis record's `genesisBlockHash` (H*) is zero.
    #[error("genesis record has a zero genesis block hash")]
    ZeroGenesisHash,
    /// Genesis only: `genesisCommitteeRecordHash` is zero, so no genesis committee was recorded.
    #[error("genesis committee record hash is zero")]
    ZeroCommitteeRecord,
    /// Genesis only: the genesis record's `epochLenL2` (L) is zero.
    #[error("genesis record has a zero epoch length")]
    ZeroEpochLength,
    /// The Inbox names an existing L2 block rather than genesis block 0.
    #[error("genesis height {0} is unsupported; Etna must start at L2 block 0")]
    NonzeroGenesisHeight(u64),
    /// Genesis only: `genesisCutoff` is not before the initialization block `L1_0`, so the genesis
    /// committee's snapshot would not be one the genesis could have seen.
    #[error("genesis cutoff {genesis_cutoff} is not before the genesis block L1_0 = {l1_0}")]
    GenesisCutoffNotBeforeInitialization {
        /// The proven `genesisCutoff` (slot 279).
        genesis_cutoff: u64,
        /// The genesis record's `L1_0`.
        l1_0: u64,
    },
    /// Genesis requires a positive delay and maximum anchor age of at least 1152 seconds.
    #[error(
        "forced inclusion delay {delay} s must be positive and maximum anchor age {max_anchor_age} s at least 1152"
    )]
    InvalidForcedInclusionConfig {
        /// The proven `forcedInclusionDelay` (slot 282, bits 0–63).
        delay: u64,
        /// The proven `maxAnchorAge` (slot 282, bits 64–127).
        max_anchor_age: u64,
    },
}

/// Authenticates the fixed Inbox anchor slots under the anchor's L1 header and decodes its facts.
///
/// Checks the configured Inbox account and exact slot order. Header number, hash, timestamp
/// and state root come from the embedded raw header; canonicality/finality is checked separately.
pub fn verify_anchor_witness(
    w: &AnchorWitness,
    inbox: Address,
) -> Result<AnchorState, WitnessError> {
    check_contract(&w.inbox, inbox)?;
    let header = &w.l1_header;
    let storage = verify_account_witness(header.state_root(), &w.inbox, &inbox::anchor_slots())?;
    let head_tail = inbox_word(&storage, inbox::FORCED_INCLUSION_HEAD_TAIL);
    let facts = InboxFacts {
        status: word_u8(inbox_word(&storage, inbox::STATUS), 0),
        recovery_generation: word_u64(inbox_word(&storage, inbox::RECOVERY_GENERATION), 0),
        last_checkpoint_height: word_u64(inbox_word(&storage, inbox::LAST_CHECKPOINT_HEIGHT), 0),
        last_checkpoint_hash: inbox_word(&storage, inbox::LAST_CHECKPOINT_HASH).into(),
        forced_inclusion_head: word_u48(head_tail, 0),
        forced_inclusion_tail: word_u48(head_tail, 48),
    };
    Ok(anchor_state(header, facts))
}

/// The anchor at L1 header `header` with the Inbox facts `inbox` proven against its `stateRoot`:
/// its number, hash (`keccak256` of the raw header), state root and timestamp come from `header`.
pub(crate) fn anchor_state(header: &RawL1Header, inbox: InboxFacts) -> AnchorState {
    AnchorState {
        number: header.number(),
        hash: header.hash(),
        state_root: header.state_root(),
        timestamp: header.timestamp(),
        inbox,
    }
}

/// Verifies the genesis Inbox witness against `state_root` (the `L1_0` header's) and returns the
/// genesis record (with `genesisCutoff`), the Inbox facts at genesis and the
/// `genesisCommitteeRecordHash` record hash.
///
/// The witness must prove the account at `inbox` and `layout::inbox::genesis_slots()`. The
/// returned facts take the last checkpoint from the genesis record (`(B*, H*)`, the L2 genesis
/// block's number and hash) and an empty forced inclusion queue (head = tail = 0: Etna
/// starts with an empty queue, slot 281 is not part of the genesis witness, and the first block
/// always carries its own anchor witness). Rejects, in this order: `status != ETNA_ACTIVE`, a
/// zero genesis hash, a zero bootstrap committee hash, a zero
/// epoch length, `genesisCutoff >= L1_0`, a forced inclusion delay outside
/// a positive delay and maximum anchor age of at least 1152 seconds. The remaining schedule bounds
/// are checked by [`crate::Schedule::validate`].
pub fn verify_genesis_inbox(
    state_root: B256,
    w: &AccountWitness,
    inbox: Address,
) -> Result<(GenesisRecord, InboxFacts, B256), WitnessError> {
    check_contract(w, inbox)?;
    let storage = verify_account_witness(state_root, w, &inbox::genesis_slots())?;

    let status = word_u8(inbox_word(&storage, inbox::STATUS), 0);
    if status != inbox::ETNA_ACTIVE {
        return Err(WitnessError::NotInitialized(status));
    }
    let packed = inbox_word(&storage, inbox::GENESIS_PACKED);
    let forced_config = inbox_word(&storage, inbox::FORCED_INCLUSION_CONFIG);
    let genesis = GenesisRecord {
        genesis_height: word_u64(packed, 0),
        l1_0: word_u64(packed, 64),
        epoch_len: word_u64(packed, 128),
        genesis_hash: inbox_word(&storage, inbox::GENESIS_BLOCK_HASH).into(),
        genesis_state_root: inbox_word(&storage, inbox::GENESIS_STATE_ROOT).into(),
        genesis_cutoff: word_u64(inbox_word(&storage, inbox::GENESIS_CUTOFF), 0),
        committee_config_hash: inbox_word(&storage, inbox::COMMITTEE_CONFIG_HASH).into(),
        forced_inclusion_delay: word_u64(forced_config, 0),
        max_anchor_age: word_u64(forced_config, 64),
    };
    if genesis.genesis_height != 0 {
        return Err(WitnessError::NonzeroGenesisHeight(genesis.genesis_height));
    }
    if genesis.genesis_hash.is_zero() {
        return Err(WitnessError::ZeroGenesisHash);
    }
    let committee_record: B256 = inbox_word(&storage, inbox::GENESIS_COMMITTEE_HASH).into();
    if committee_record.is_zero() {
        return Err(WitnessError::ZeroCommitteeRecord);
    }
    if genesis.epoch_len == 0 {
        return Err(WitnessError::ZeroEpochLength);
    }
    if genesis.genesis_cutoff >= genesis.l1_0 {
        return Err(WitnessError::GenesisCutoffNotBeforeInitialization {
            genesis_cutoff: genesis.genesis_cutoff,
            l1_0: genesis.l1_0,
        });
    }
    let (delay, max_anchor_age) = (genesis.forced_inclusion_delay, genesis.max_anchor_age);
    if delay == 0 || max_anchor_age < 1152 {
        return Err(WitnessError::InvalidForcedInclusionConfig { delay, max_anchor_age });
    }

    let facts = InboxFacts {
        status,
        recovery_generation: word_u64(inbox_word(&storage, inbox::RECOVERY_GENERATION), 0),
        last_checkpoint_height: genesis.genesis_height,
        last_checkpoint_hash: genesis.genesis_hash,
        forced_inclusion_head: 0,
        forced_inclusion_tail: 0,
    };
    Ok((genesis, facts, committee_record))
}

/// Rejects a witness that proves an account other than the configured Inbox.
fn check_contract(w: &AccountWitness, inbox: Address) -> Result<(), WitnessError> {
    if w.address != inbox {
        return Err(WitnessError::WrongContract { expected: inbox, got: w.address });
    }
    Ok(())
}

/// The proven word at `slot`.
///
/// Panics if `slot` was not verified; callers only read slots of the set they passed to
/// [`verify_account_witness`], which succeeds only when the witness proves exactly that set.
fn word(storage: &VerifiedStorage, slot: B256) -> U256 {
    storage.get(slot).expect("slot belongs to the verified slot set")
}

/// The proven word at the plain Inbox slot `n` ([`inbox::slot`]); panics like [`word`].
fn inbox_word(storage: &VerifiedStorage, n: u64) -> U256 {
    word(storage, inbox::slot(n))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::{
        AccountSpec, InboxStorage, TestState, anchor_witness, anchor_witness_in, edit_l1_header,
        filler_accounts, genesis_inbox_witness, l1_header, sample_genesis_record, vectors,
    };
    use alloy_primitives::{address, keccak256};

    const INBOX: Address = address!("00000000000000000000000000000000e7a10001");
    const OTHER: Address = address!("00000000000000000000000000000000e7a10002");

    /// A live Inbox with every anchor field distinct and using its full width.
    fn live_storage() -> InboxStorage {
        InboxStorage {
            status: inbox::ETNA_ACTIVE,
            recovery_generation: u64::MAX - 1,
            last_checkpoint_height: 0x0123_4567_89ab_cdef,
            last_checkpoint_hash: B256::repeat_byte(0xc4),
            forced_inclusion_head: 0x0000_8765_4321_0fed,
            forced_inclusion_tail: 0x0000_ffff_ffff_fffe,
            forced_inclusion_queue: vec![],
            genesis: Some(sample_genesis_record()),
            genesis_committee_hash: Some(B256::repeat_byte(0xe0)),
        }
    }

    fn committee_e0() -> B256 {
        B256::repeat_byte(0xc0)
    }

    /// Inbox words packed per the shared layout vectors (`testdata/etna_vectors`: the vector
    /// slots, offsets and widths, which the contracts check against a deployed Inbox) decode
    /// through both witness verifiers to the packed values, every field using its full width.
    #[test]
    fn witnesses_decode_the_shared_inbox_packing() {
        let slot =
            |name: &str| inbox::slot(vectors::u64_at(&format!("/layout/inbox/slots/{name}")));
        let packed = |name: &str, fields: &[(&str, u64)]| {
            let fields: Vec<(&str, U256)> =
                fields.iter().map(|(field, value)| (*field, U256::from(*value))).collect();
            (slot(name), vectors::pack(&format!("/layout/inbox/packing/{name}"), &fields))
        };
        let word = |name: &str, byte: u8| (slot(name), U256::from_be_bytes([byte; 32]));
        let max48 = (1u64 << 48) - 1;
        let words = vec![
            packed("status", &[("status", vectors::u64_at("/layout/inbox/status_active"))]),
            packed("recovery_generation", &[("recovery_generation", u64::MAX - 1)]),
            packed("last_checkpoint_height", &[("height", 0x0123_4567_89ab_cdef)]),
            word("last_checkpoint_hash", 0xc4),
            packed("forced_inclusion_head_tail", &[("head", max48 - 1), ("tail", max48)]),
            packed(
                "activation_packed",
                &[
                    ("genesis_height", 0),
                    ("l1_block", u64::MAX - 2),
                    ("epoch_len_l2", 0x0102_0304_0506_0708),
                ],
            ),
            word("genesis_block_hash", 0xa1),
            word("genesis_state_root", 0xa2),
            packed("genesis_cutoff", &[("genesis_cutoff", u64::MAX - 4)]),
            word("committee_config_hash", 0xa3),
            word("genesis_committee_hash", 0xa4),
            packed(
                "forced_inclusion_config",
                &[("delay", u64::MAX - 5), ("max_anchor_age", u64::MAX)],
            ),
        ];
        let mut accounts = filler_accounts();
        accounts.push((INBOX, 1, U256::ZERO, keccak256(b"etna inbox code"), words));
        let state = TestState::new(accounts);

        let genesis_witness = state.witness(INBOX, &inbox::genesis_slots());
        let (genesis, _, committee) =
            verify_genesis_inbox(state.state_root(), &genesis_witness, INBOX).unwrap();
        assert_eq!(
            genesis,
            GenesisRecord {
                committee_config_hash: B256::repeat_byte(0xa3),
                genesis_height: 0,
                l1_0: u64::MAX - 2,
                epoch_len: 0x0102_0304_0506_0708,
                genesis_hash: B256::repeat_byte(0xa1),
                genesis_state_root: B256::repeat_byte(0xa2),
                genesis_cutoff: u64::MAX - 4,
                forced_inclusion_delay: u64::MAX - 5,
                max_anchor_age: u64::MAX,
            }
        );
        assert_eq!(committee, B256::repeat_byte(0xa4));

        let anchor = anchor_witness_in(&state, INBOX, l1_header(4_242, 1_760_000_123));
        assert_eq!(
            verify_anchor_witness(&anchor, INBOX).unwrap().inbox,
            InboxFacts {
                status: inbox::ETNA_ACTIVE,
                recovery_generation: u64::MAX - 1,
                last_checkpoint_height: 0x0123_4567_89ab_cdef,
                last_checkpoint_hash: B256::repeat_byte(0xc4),
                forced_inclusion_head: max48 - 1,
                forced_inclusion_tail: max48,
            }
        );
    }

    #[test]
    fn anchor_decodes_every_field() {
        let storage = live_storage();
        let (w, state) = anchor_witness(INBOX, &storage, l1_header(4_242, 1_760_000_123));
        let anchor = verify_anchor_witness(&w, INBOX).unwrap();

        assert_eq!(anchor.number, 4_242);
        assert_eq!(anchor.timestamp, 1_760_000_123);
        assert_eq!(anchor.state_root, state.state_root());
        assert_eq!(
            anchor.inbox,
            InboxFacts {
                status: inbox::ETNA_ACTIVE,
                recovery_generation: u64::MAX - 1,
                last_checkpoint_height: 0x0123_4567_89ab_cdef,
                last_checkpoint_hash: B256::repeat_byte(0xc4),
                forced_inclusion_head: 0x0000_8765_4321_0fed,
                forced_inclusion_tail: 0x0000_ffff_ffff_fffe,
            }
        );
    }

    #[test]
    fn anchor_witness_decodes_forced_inclusion_head_and_tail() {
        let storage =
            InboxStorage { forced_inclusion_head: 3, forced_inclusion_tail: 9, ..live_storage() };
        let (w, _) = anchor_witness(INBOX, &storage, l1_header(9, 99));
        let head_tail = w
            .inbox
            .storage
            .iter()
            .find(|proof| proof.slot == inbox::slot(inbox::FORCED_INCLUSION_HEAD_TAIL))
            .expect("slot 281 is proven")
            .value;
        assert_eq!(head_tail, U256::from(3u64) | (U256::from(9u64) << 48));

        let facts = verify_anchor_witness(&w, INBOX).unwrap().inbox;
        assert_eq!((facts.forced_inclusion_head, facts.forced_inclusion_tail), (3, 9));
    }

    #[test]
    fn anchor_hash_is_the_l1_header_hash() {
        let (w, _) = anchor_witness(INBOX, &live_storage(), l1_header(9, 99));
        let anchor = verify_anchor_witness(&w, INBOX).unwrap();
        assert_eq!(anchor.hash, w.l1_header.hash());
        assert_eq!(anchor.hash, keccak256(w.l1_header.raw()));
    }

    #[test]
    fn anchor_proves_only_the_fixed_slots() {
        let (w, _) = anchor_witness(INBOX, &live_storage(), l1_header(9, 99));
        assert_eq!(
            w.inbox.storage.iter().map(|proof| proof.slot).collect::<Vec<_>>(),
            inbox::anchor_slots()
        );
        verify_anchor_witness(&w, INBOX).unwrap();
    }

    #[test]
    fn anchor_ignores_bits_above_packed_fields() {
        // Other variables Solidity packs into the same slots must not leak into the facts.
        let dirty = |n: u64, low: U256, width: usize| {
            (inbox::slot(n), ((U256::MAX >> width) << width) | low)
        };
        let mut accounts: Vec<AccountSpec> = filler_accounts();
        accounts.push((
            INBOX,
            1,
            U256::ZERO,
            keccak256(b"code"),
            vec![
                dirty(inbox::STATUS, U256::from(3u64), 8),
                dirty(inbox::RECOVERY_GENERATION, U256::from(5u64), 64),
                dirty(inbox::LAST_CHECKPOINT_HEIGHT, U256::from(77u64), 64),
                dirty(
                    inbox::FORCED_INCLUSION_HEAD_TAIL,
                    U256::from(4u64) | (U256::from(6u64) << 48),
                    96,
                ),
            ],
        ));
        let state = TestState::new(accounts);
        let w = anchor_witness_in(&state, INBOX, l1_header(1, 1));
        let facts = verify_anchor_witness(&w, INBOX).unwrap().inbox;
        assert_eq!(facts.status, 3);
        assert_eq!(facts.recovery_generation, 5);
        assert_eq!(facts.last_checkpoint_height, 77);
        assert_eq!(facts.last_checkpoint_hash, B256::ZERO);
        assert_eq!((facts.forced_inclusion_head, facts.forced_inclusion_tail), (4, 6));
    }

    #[test]
    fn anchor_rejects_another_contract() {
        let (w, _) = anchor_witness(INBOX, &live_storage(), l1_header(9, 99));
        let err = verify_anchor_witness(&w, OTHER).unwrap_err();
        assert_eq!(err, WitnessError::WrongContract { expected: OTHER, got: INBOX });
    }

    #[test]
    fn anchor_rejects_a_tampered_header_state_root() {
        let (mut w, _) = anchor_witness(INBOX, &live_storage(), l1_header(9, 99));
        w.l1_header = edit_l1_header(&w.l1_header, |h| h.state_root = B256::repeat_byte(0x01));
        let err = verify_anchor_witness(&w, INBOX).unwrap_err();
        assert!(matches!(err, WitnessError::Mpt(MptError::Account(_))), "{err:?}");
    }

    #[test]
    fn anchor_rejects_a_tampered_storage_value() {
        let (mut w, _) = anchor_witness(INBOX, &live_storage(), l1_header(9, 99));
        w.inbox.storage[2].value += U256::from(1u64);
        let err = verify_anchor_witness(&w, INBOX).unwrap_err();
        assert!(matches!(err, WitnessError::Mpt(MptError::Storage { .. })), "{err:?}");
    }

    #[test]
    fn genesis_decodes_the_record_and_facts() {
        let genesis = GenesisRecord {
            committee_config_hash: B256::repeat_byte(0xb1),
            genesis_height: 0,
            l1_0: 0x0102_0304_0506_0708,
            epoch_len: 0xfedc_ba98_7654_3210,
            genesis_hash: B256::repeat_byte(0xa1),
            genesis_state_root: B256::repeat_byte(0xa2),
            genesis_cutoff: 0x0102_0304_0506_0707,
            forced_inclusion_delay: 1_209_599,
            max_anchor_age: u64::MAX,
        };
        let storage = InboxStorage {
            recovery_generation: 6,
            // The genesis witness does not prove slots 270/271/281; the facts must ignore them.
            last_checkpoint_height: 1,
            last_checkpoint_hash: B256::repeat_byte(0x01),
            forced_inclusion_head: 2,
            forced_inclusion_tail: 5,
            ..InboxStorage::genesis(genesis.clone(), committee_e0())
        };
        let (w, state) = genesis_inbox_witness(INBOX, &storage);
        let (decoded, facts, record) = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap();

        assert_eq!(decoded, genesis);
        assert_eq!((decoded.forced_inclusion_delay, decoded.max_anchor_age), (1_209_599, u64::MAX));
        assert_eq!(
            facts,
            InboxFacts {
                status: inbox::ETNA_ACTIVE,
                recovery_generation: 6,
                last_checkpoint_height: genesis.genesis_height,
                last_checkpoint_hash: genesis.genesis_hash,
                forced_inclusion_head: 0,
                forced_inclusion_tail: 0,
            }
        );
        assert_eq!(record, committee_e0());
    }

    /// Bits 192–255 of the activation word are unused; the decoder does not read them.
    #[test]
    fn genesis_ignores_the_unused_activation_bits() {
        let genesis = sample_genesis_record();
        let mut words = InboxStorage::genesis(genesis.clone(), committee_e0()).slots();
        let activation = inbox::slot(inbox::GENESIS_PACKED);
        let (_, word) = words.iter_mut().find(|(slot, _)| *slot == activation).unwrap();
        *word |= U256::from(u64::MAX) << 192;
        let mut accounts = filler_accounts();
        accounts.push((INBOX, 1, U256::ZERO, keccak256(b"etna inbox code"), words));
        let state = TestState::new(accounts);

        let w = state.witness(INBOX, &inbox::genesis_slots());
        let (decoded, _, _) = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap();
        assert_eq!(decoded, genesis);
    }

    /// A valid storage proof cannot make a non-genesis L2 height a supported bootstrap.
    #[test]
    fn genesis_rejects_nonzero_l2_height() {
        let mut genesis = sample_genesis_record();
        genesis.genesis_height = 1;
        let storage = InboxStorage::genesis(genesis, committee_e0());
        let (w, state) = genesis_inbox_witness(INBOX, &storage);
        assert!(verify_genesis_inbox(state.state_root(), &w, INBOX).is_err());
    }

    #[test]
    fn genesis_rejects_another_contract() {
        let storage = InboxStorage::genesis(sample_genesis_record(), committee_e0());
        let (w, state) = genesis_inbox_witness(INBOX, &storage);
        let err = verify_genesis_inbox(state.state_root(), &w, OTHER).unwrap_err();
        assert_eq!(err, WitnessError::WrongContract { expected: OTHER, got: INBOX });
    }

    #[test]
    fn genesis_rejects_a_wrong_state_root() {
        let storage = InboxStorage::genesis(sample_genesis_record(), committee_e0());
        let (w, _) = genesis_inbox_witness(INBOX, &storage);
        let err = verify_genesis_inbox(B256::repeat_byte(0x01), &w, INBOX).unwrap_err();
        assert!(matches!(err, WitnessError::Mpt(MptError::Account(_))), "{err:?}");
    }

    #[test]
    fn genesis_rejects_an_anchor_slot_set() {
        let storage = InboxStorage::genesis(sample_genesis_record(), committee_e0());
        let (w, state) = anchor_witness(INBOX, &storage, l1_header(9, 99));
        let err = verify_genesis_inbox(state.state_root(), &w.inbox, INBOX).unwrap_err();
        assert!(matches!(err, WitnessError::Mpt(MptError::SlotSet { .. })), "{err:?}");
    }

    #[test]
    fn genesis_rejects_an_inactive_inbox() {
        for state_value in [0u8, 1, 2, 4, u8::MAX] {
            let storage = InboxStorage {
                status: state_value,
                ..InboxStorage::genesis(sample_genesis_record(), committee_e0())
            };
            let (w, state) = genesis_inbox_witness(INBOX, &storage);
            let err = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap_err();
            assert_eq!(err, WitnessError::NotInitialized(state_value));
        }
    }

    #[test]
    fn genesis_rejects_a_zero_genesis_hash() {
        let genesis = GenesisRecord { genesis_hash: B256::ZERO, ..sample_genesis_record() };
        let storage = InboxStorage::genesis(genesis, committee_e0());
        let (w, state) = genesis_inbox_witness(INBOX, &storage);
        let err = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap_err();
        assert_eq!(err, WitnessError::ZeroGenesisHash);
    }

    #[test]
    fn genesis_rejects_a_missing_committee_record() {
        let storage = InboxStorage {
            genesis_committee_hash: None,
            ..InboxStorage::genesis(sample_genesis_record(), committee_e0())
        };
        let (w, state) = genesis_inbox_witness(INBOX, &storage);
        let err = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap_err();
        assert_eq!(err, WitnessError::ZeroCommitteeRecord);
    }

    #[test]
    fn genesis_rejects_a_zero_epoch_length() {
        let genesis = GenesisRecord { epoch_len: 0, ..sample_genesis_record() };
        let storage = InboxStorage::genesis(genesis, committee_e0());
        let (w, state) = genesis_inbox_witness(INBOX, &storage);
        let err = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap_err();
        assert_eq!(err, WitnessError::ZeroEpochLength);
    }

    /// `genesisCutoff` must lie before `L1_0`, and the check comes after the epoch length's.
    #[test]
    fn genesis_rejects_a_cutoff_not_before_l1_0() {
        let l1_0 = sample_genesis_record().l1_0;
        for genesis_cutoff in [l1_0, l1_0 + 1, u64::MAX] {
            let genesis = GenesisRecord { genesis_cutoff, ..sample_genesis_record() };
            let storage = InboxStorage::genesis(genesis.clone(), committee_e0());
            let (w, state) = genesis_inbox_witness(INBOX, &storage);
            let err = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap_err();
            assert_eq!(
                err,
                WitnessError::GenesisCutoffNotBeforeInitialization { genesis_cutoff, l1_0 }
            );

            let storage =
                InboxStorage::genesis(GenesisRecord { epoch_len: 0, ..genesis }, committee_e0());
            let (w, state) = genesis_inbox_witness(INBOX, &storage);
            let err = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap_err();
            assert_eq!(err, WitnessError::ZeroEpochLength);
        }

        // The block right before L1_0, and block 0, are accepted.
        for genesis_cutoff in [l1_0 - 1, 0] {
            let genesis = GenesisRecord { genesis_cutoff, ..sample_genesis_record() };
            let storage = InboxStorage::genesis(genesis, committee_e0());
            let (w, state) = genesis_inbox_witness(INBOX, &storage);
            let (decoded, _, _) = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap();
            assert_eq!(decoded.genesis_cutoff, genesis_cutoff);
        }
    }

    /// The delay must be positive and the maximum anchor age at least 1152 seconds; the check comes
    /// after the genesis cutoff's.
    #[test]
    fn genesis_rejects_invalid_forced_inclusion_config() {
        for (delay, max_anchor_age) in [(0, 7_200), (1, 1151), (3_600, 0)] {
            let genesis = GenesisRecord {
                forced_inclusion_delay: delay,
                max_anchor_age,
                ..sample_genesis_record()
            };
            let storage = InboxStorage::genesis(genesis.clone(), committee_e0());
            let (w, state) = genesis_inbox_witness(INBOX, &storage);
            let err = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap_err();
            assert_eq!(err, WitnessError::InvalidForcedInclusionConfig { delay, max_anchor_age });

            let genesis = GenesisRecord { genesis_cutoff: genesis.l1_0, ..genesis };
            let storage = InboxStorage::genesis(genesis.clone(), committee_e0());
            let (w, state) = genesis_inbox_witness(INBOX, &storage);
            let err = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap_err();
            assert!(
                matches!(err, WitnessError::GenesisCutoffNotBeforeInitialization { .. }),
                "{err:?}"
            );
        }

        // The extremes of the accepted ranges.
        for (delay, max_anchor_age) in [(1, 1152), (u64::MAX, u64::MAX)] {
            let genesis = GenesisRecord {
                forced_inclusion_delay: delay,
                max_anchor_age,
                ..sample_genesis_record()
            };
            let storage = InboxStorage::genesis(genesis.clone(), committee_e0());
            let (w, state) = genesis_inbox_witness(INBOX, &storage);
            let (decoded, _, _) = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap();
            assert_eq!(decoded, genesis);
        }
    }

    /// Variables packed above `maxAnchorAge` in slot 282 do not leak into it.
    #[test]
    fn genesis_ignores_bits_above_the_max_anchor_age() {
        let storage = InboxStorage::genesis(sample_genesis_record(), committee_e0());
        let config_slot = inbox::slot(inbox::FORCED_INCLUSION_CONFIG);
        let slots = storage
            .slots()
            .into_iter()
            .map(|(slot, word)| {
                (slot, if slot == config_slot { word | ((U256::MAX >> 128) << 128) } else { word })
            })
            .collect();
        let mut accounts: Vec<AccountSpec> = filler_accounts();
        accounts.push((INBOX, 1, U256::ZERO, keccak256(b"code"), slots));
        let state = TestState::new(accounts);
        let w = state.witness(INBOX, &inbox::genesis_slots());
        let (decoded, _, _) = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap();
        assert_eq!(decoded, sample_genesis_record());
    }

    /// Variables packed above `genesisCutoff` in slot 279 do not leak into it.
    #[test]
    fn genesis_ignores_bits_above_the_genesis_cutoff() {
        let storage = InboxStorage::genesis(sample_genesis_record(), committee_e0());
        let cutoff_slot = inbox::slot(inbox::GENESIS_CUTOFF);
        let slots = storage
            .slots()
            .into_iter()
            .map(|(slot, word)| {
                (slot, if slot == cutoff_slot { word | ((U256::MAX >> 64) << 64) } else { word })
            })
            .collect();
        let mut accounts: Vec<AccountSpec> = filler_accounts();
        accounts.push((INBOX, 1, U256::ZERO, keccak256(b"code"), slots));
        let state = TestState::new(accounts);
        let w = state.witness(INBOX, &inbox::genesis_slots());
        let (decoded, _, _) = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap();
        assert_eq!(decoded, sample_genesis_record());
    }

    #[test]
    fn genesis_rejects_an_uninitialized_record() {
        // Genesis slots empty but initialized status set: the zero genesis hash trips first.
        let storage = InboxStorage {
            genesis: None,
            ..InboxStorage::genesis(sample_genesis_record(), committee_e0())
        };
        let (w, state) = genesis_inbox_witness(INBOX, &storage);
        let err = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap_err();
        assert_eq!(err, WitnessError::ZeroGenesisHash);
    }
}

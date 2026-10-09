//! Turns verified Inbox witnesses into facts. No I/O.
//!
//! [`verify_anchor_witness`] checks a per-block anchor witness's proofs against its own L1
//! header and decodes the Inbox facts; [`verify_genesis_inbox`] does the same for the genesis
//! witness and also decodes the activation record. Neither checks that the L1 header is
//! canonical and final: that needs the node's own L1 and lives in `l1::source`.

use alloy_primitives::{Address, B256, U256};

use crate::{
    envelope::AnchorWitness,
    l1::{
        layout::{inbox, word_u8, word_u64},
        mpt::{MptError, VerifiedStorage, verify_account_witness},
    },
    schedule::Schedule,
    types::{AccountWitness, ActivationRecord, AnchorState, InboxFacts},
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
    /// Genesis only: the Inbox's `migrationState` is not `ETNA_ACTIVE`.
    #[error("inbox migrationState is {0}, expected ETNA_ACTIVE ({active})", active = inbox::ETNA_ACTIVE)]
    NotActivated(u8),
    /// Genesis only: the activation record's `genesisBlockHash` (H*) is zero.
    #[error("activation record has a zero genesis block hash")]
    ZeroGenesisHash,
    /// Genesis only: `committee[e_0]` is zero, so no genesis committee was recorded.
    #[error("committee[e0] record hash is zero")]
    ZeroCommitteeRecord,
    /// Genesis only: the activation record's `epochLenL2` (L) is zero.
    #[error("activation record has a zero epoch length")]
    ZeroEpochLength,
}

/// Verifies an anchor witness and returns the anchor it proves.
///
/// Checks that `w.inbox` proves the account at `inbox` and the slot set
/// `layout::inbox::anchor_slots(committee_epoch)` against the raw L1 header's `stateRoot`, then
/// decodes the Inbox facts (`committee` is `Some((epoch, committee[epoch]))` iff
/// `committee_epoch` is set; a zero record hash is returned as is). The anchor's number,
/// timestamp and hash (`keccak256` of the raw header) come from the raw header. Does not check
/// the header's canonicality or finality, nor any value of the facts.
pub fn verify_anchor_witness(
    w: &AnchorWitness,
    inbox: Address,
    committee_epoch: Option<u64>,
) -> Result<AnchorState, WitnessError> {
    check_contract(&w.inbox, inbox)?;
    let header = &w.l1_header;
    let storage = verify_account_witness(
        header.state_root(),
        &w.inbox,
        &inbox::anchor_slots(committee_epoch),
    )?;
    let facts = InboxFacts {
        migration_state: word_u8(word(&storage, inbox::slot(inbox::MIGRATION_STATE)), 0),
        recovery_generation: word_u64(word(&storage, inbox::slot(inbox::RECOVERY_GENERATION)), 0),
        last_checkpoint_height: word_u64(
            word(&storage, inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT)),
            0,
        ),
        last_checkpoint_hash: word(&storage, inbox::slot(inbox::LAST_CHECKPOINT_HASH)).into(),
        committee: committee_epoch.map(|e| (e, word(&storage, inbox::committee_slot(e)).into())),
    };
    Ok(AnchorState {
        number: header.number(),
        hash: header.hash(),
        state_root: header.state_root(),
        timestamp: header.timestamp(),
        inbox: facts,
    })
}

/// Verifies the genesis Inbox witness against `state_root` (the `L1_0` header's) and returns the
/// activation record, the Inbox facts at genesis and the `committee[e_0]` record hash.
///
/// The witness must prove the account at `inbox` and `layout::inbox::genesis_slots(E0)`. The
/// returned facts take the last checkpoint from the activation record (`(B*, H*)`, the genesis
/// record of #22262's MIG rules) and set `committee = Some((E0, committee[E0]))`. Rejects, in this
/// order: `migrationState != ETNA_ACTIVE`, a zero genesis hash, a zero `committee[E0]`, a zero
/// epoch length. The remaining schedule bounds are checked by [`Schedule::validate`].
pub fn verify_genesis_inbox(
    state_root: B256,
    w: &AccountWitness,
    inbox: Address,
) -> Result<(ActivationRecord, InboxFacts, B256), WitnessError> {
    check_contract(w, inbox)?;
    let storage = verify_account_witness(state_root, w, &inbox::genesis_slots(Schedule::E0))?;

    let migration_state = word_u8(word(&storage, inbox::slot(inbox::MIGRATION_STATE)), 0);
    if migration_state != inbox::ETNA_ACTIVE {
        return Err(WitnessError::NotActivated(migration_state));
    }
    let packed = word(&storage, inbox::slot(inbox::ACTIVATION_PACKED));
    let activation = ActivationRecord {
        genesis_height: word_u64(packed, 0),
        l1_0: word_u64(packed, 64),
        epoch_len: word_u64(packed, 128),
        epoch_len_l1: word_u64(packed, 192),
        genesis_hash: word(&storage, inbox::slot(inbox::ACTIVATION_GENESIS_HASH)).into(),
        genesis_state_root: word(&storage, inbox::slot(inbox::ACTIVATION_GENESIS_STATE_ROOT))
            .into(),
    };
    if activation.genesis_hash.is_zero() {
        return Err(WitnessError::ZeroGenesisHash);
    }
    let committee_record: B256 = word(&storage, inbox::committee_slot(Schedule::E0)).into();
    if committee_record.is_zero() {
        return Err(WitnessError::ZeroCommitteeRecord);
    }
    if activation.epoch_len == 0 {
        return Err(WitnessError::ZeroEpochLength);
    }

    let facts = InboxFacts {
        migration_state,
        recovery_generation: word_u64(word(&storage, inbox::slot(inbox::RECOVERY_GENERATION)), 0),
        last_checkpoint_height: activation.genesis_height,
        last_checkpoint_hash: activation.genesis_hash,
        committee: Some((Schedule::E0, committee_record)),
    };
    Ok((activation, facts, committee_record))
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::{
        AccountSpec, InboxStorage, TestState, anchor_witness, anchor_witness_in, edit_l1_header,
        filler_accounts, genesis_inbox_witness, l1_header, sample_activation,
    };
    use alloy_primitives::{address, keccak256};

    const INBOX: Address = address!("00000000000000000000000000000000e7a10001");
    const OTHER: Address = address!("00000000000000000000000000000000e7a10002");

    /// A live Inbox with every anchor field distinct and using its full width.
    fn live_storage() -> InboxStorage {
        InboxStorage {
            migration_state: inbox::ETNA_ACTIVE,
            recovery_generation: u64::MAX - 1,
            last_checkpoint_height: 0x0123_4567_89ab_cdef,
            last_checkpoint_hash: B256::repeat_byte(0xc4),
            activation: Some(sample_activation()),
            committee: vec![(0, B256::repeat_byte(0xe0)), (3, B256::repeat_byte(0xe3))],
        }
    }

    fn committee_e0() -> B256 {
        B256::repeat_byte(0xc0)
    }

    #[test]
    fn anchor_decodes_every_field() {
        let storage = live_storage();
        let (w, state) = anchor_witness(INBOX, &storage, l1_header(4_242, 1_760_000_123), None);
        let anchor = verify_anchor_witness(&w, INBOX, None).unwrap();

        assert_eq!(anchor.number, 4_242);
        assert_eq!(anchor.timestamp, 1_760_000_123);
        assert_eq!(anchor.state_root, state.state_root());
        assert_eq!(
            anchor.inbox,
            InboxFacts {
                migration_state: inbox::ETNA_ACTIVE,
                recovery_generation: u64::MAX - 1,
                last_checkpoint_height: 0x0123_4567_89ab_cdef,
                last_checkpoint_hash: B256::repeat_byte(0xc4),
                committee: None,
            }
        );
    }

    #[test]
    fn anchor_hash_is_the_l1_header_hash() {
        let (w, _) = anchor_witness(INBOX, &live_storage(), l1_header(9, 99), None);
        let anchor = verify_anchor_witness(&w, INBOX, None).unwrap();
        assert_eq!(anchor.hash, w.l1_header.hash());
        assert_eq!(anchor.hash, keccak256(w.l1_header.raw()));
    }

    #[test]
    fn anchor_decodes_the_committee_record_at_switch_heights() {
        let (w, _) = anchor_witness(INBOX, &live_storage(), l1_header(9, 99), Some(3));
        let anchor = verify_anchor_witness(&w, INBOX, Some(3)).unwrap();
        assert_eq!(anchor.inbox.committee, Some((3, B256::repeat_byte(0xe3))));
        assert_eq!(anchor.inbox.last_checkpoint_hash, B256::repeat_byte(0xc4));
    }

    #[test]
    fn anchor_returns_an_unrecorded_committee_as_zero() {
        let (w, _) = anchor_witness(INBOX, &live_storage(), l1_header(9, 99), Some(4));
        let anchor = verify_anchor_witness(&w, INBOX, Some(4)).unwrap();
        assert_eq!(anchor.inbox.committee, Some((4, B256::ZERO)));
    }

    #[test]
    fn anchor_slot_set_follows_the_committee_epoch() {
        let storage = live_storage();
        let (without, _) = anchor_witness(INBOX, &storage, l1_header(9, 99), None);
        let (with, _) = anchor_witness(INBOX, &storage, l1_header(9, 99), Some(3));

        for (w, epoch) in [(&without, Some(3)), (&with, None), (&with, Some(0))] {
            let err = verify_anchor_witness(w, INBOX, epoch).unwrap_err();
            assert!(matches!(err, WitnessError::Mpt(MptError::SlotSet { .. })), "{err:?}");
        }
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
                dirty(inbox::MIGRATION_STATE, U256::from(3u64), 8),
                dirty(inbox::RECOVERY_GENERATION, U256::from(5u64), 64),
                dirty(inbox::LAST_CHECKPOINT_HEIGHT, U256::from(77u64), 64),
            ],
        ));
        let state = TestState::new(accounts);
        let w = anchor_witness_in(&state, INBOX, l1_header(1, 1), None);
        let facts = verify_anchor_witness(&w, INBOX, None).unwrap().inbox;
        assert_eq!(facts.migration_state, 3);
        assert_eq!(facts.recovery_generation, 5);
        assert_eq!(facts.last_checkpoint_height, 77);
        assert_eq!(facts.last_checkpoint_hash, B256::ZERO);
    }

    #[test]
    fn anchor_rejects_another_contract() {
        let (w, _) = anchor_witness(INBOX, &live_storage(), l1_header(9, 99), None);
        let err = verify_anchor_witness(&w, OTHER, None).unwrap_err();
        assert_eq!(err, WitnessError::WrongContract { expected: OTHER, got: INBOX });
    }

    #[test]
    fn anchor_rejects_a_tampered_header_state_root() {
        let (mut w, _) = anchor_witness(INBOX, &live_storage(), l1_header(9, 99), None);
        w.l1_header = edit_l1_header(&w.l1_header, |h| h.state_root = B256::repeat_byte(0x01));
        let err = verify_anchor_witness(&w, INBOX, None).unwrap_err();
        assert!(matches!(err, WitnessError::Mpt(MptError::Account(_))), "{err:?}");
    }

    #[test]
    fn anchor_rejects_a_tampered_storage_value() {
        let (mut w, _) = anchor_witness(INBOX, &live_storage(), l1_header(9, 99), None);
        w.inbox.storage[2].value += U256::from(1u64);
        let err = verify_anchor_witness(&w, INBOX, None).unwrap_err();
        assert!(matches!(err, WitnessError::Mpt(MptError::Storage { .. })), "{err:?}");
    }

    #[test]
    fn genesis_decodes_the_activation_record_and_facts() {
        let activation = ActivationRecord {
            genesis_height: u64::MAX - 3,
            l1_0: 0x0102_0304_0506_0708,
            epoch_len: 0xfedc_ba98_7654_3210,
            epoch_len_l1: u64::MAX,
            genesis_hash: B256::repeat_byte(0xa1),
            genesis_state_root: B256::repeat_byte(0xa2),
        };
        let storage = InboxStorage {
            recovery_generation: 6,
            // The genesis witness does not prove slots 270/271; the facts must ignore them.
            last_checkpoint_height: 1,
            last_checkpoint_hash: B256::repeat_byte(0x01),
            ..InboxStorage::genesis(activation.clone(), committee_e0())
        };
        let (w, state) = genesis_inbox_witness(INBOX, &storage);
        let (decoded, facts, record) = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap();

        assert_eq!(decoded, activation);
        assert_eq!(
            facts,
            InboxFacts {
                migration_state: inbox::ETNA_ACTIVE,
                recovery_generation: 6,
                last_checkpoint_height: activation.genesis_height,
                last_checkpoint_hash: activation.genesis_hash,
                committee: Some((Schedule::E0, committee_e0())),
            }
        );
        assert_eq!(record, committee_e0());
    }

    #[test]
    fn genesis_rejects_another_contract() {
        let storage = InboxStorage::genesis(sample_activation(), committee_e0());
        let (w, state) = genesis_inbox_witness(INBOX, &storage);
        let err = verify_genesis_inbox(state.state_root(), &w, OTHER).unwrap_err();
        assert_eq!(err, WitnessError::WrongContract { expected: OTHER, got: INBOX });
    }

    #[test]
    fn genesis_rejects_a_wrong_state_root() {
        let storage = InboxStorage::genesis(sample_activation(), committee_e0());
        let (w, _) = genesis_inbox_witness(INBOX, &storage);
        let err = verify_genesis_inbox(B256::repeat_byte(0x01), &w, INBOX).unwrap_err();
        assert!(matches!(err, WitnessError::Mpt(MptError::Account(_))), "{err:?}");
    }

    #[test]
    fn genesis_rejects_an_anchor_slot_set() {
        let storage = InboxStorage::genesis(sample_activation(), committee_e0());
        let (w, state) = anchor_witness(INBOX, &storage, l1_header(9, 99), Some(0));
        let err = verify_genesis_inbox(state.state_root(), &w.inbox, INBOX).unwrap_err();
        assert!(matches!(err, WitnessError::Mpt(MptError::SlotSet { .. })), "{err:?}");
    }

    #[test]
    fn genesis_rejects_an_inactive_inbox() {
        for state_value in [0u8, 1, 2, 4, u8::MAX] {
            let storage = InboxStorage {
                migration_state: state_value,
                ..InboxStorage::genesis(sample_activation(), committee_e0())
            };
            let (w, state) = genesis_inbox_witness(INBOX, &storage);
            let err = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap_err();
            assert_eq!(err, WitnessError::NotActivated(state_value));
        }
    }

    #[test]
    fn genesis_rejects_a_zero_genesis_hash() {
        let activation = ActivationRecord { genesis_hash: B256::ZERO, ..sample_activation() };
        let storage = InboxStorage::genesis(activation, committee_e0());
        let (w, state) = genesis_inbox_witness(INBOX, &storage);
        let err = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap_err();
        assert_eq!(err, WitnessError::ZeroGenesisHash);
    }

    #[test]
    fn genesis_rejects_a_missing_committee_record() {
        let storage = InboxStorage {
            committee: vec![(1, committee_e0())],
            ..InboxStorage::genesis(sample_activation(), committee_e0())
        };
        let (w, state) = genesis_inbox_witness(INBOX, &storage);
        let err = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap_err();
        assert_eq!(err, WitnessError::ZeroCommitteeRecord);
    }

    #[test]
    fn genesis_rejects_a_zero_epoch_length() {
        let activation = ActivationRecord { epoch_len: 0, ..sample_activation() };
        let storage = InboxStorage::genesis(activation, committee_e0());
        let (w, state) = genesis_inbox_witness(INBOX, &storage);
        let err = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap_err();
        assert_eq!(err, WitnessError::ZeroEpochLength);
    }

    #[test]
    fn genesis_rejects_an_unactivated_record() {
        // Activation slots empty but migrationState set: the zero genesis hash trips first.
        let storage = InboxStorage {
            activation: None,
            ..InboxStorage::genesis(sample_activation(), committee_e0())
        };
        let (w, state) = genesis_inbox_witness(INBOX, &storage);
        let err = verify_genesis_inbox(state.state_root(), &w, INBOX).unwrap_err();
        assert_eq!(err, WitnessError::ZeroGenesisHash);
    }
}

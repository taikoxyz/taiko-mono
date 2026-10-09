//! EIP-1186 account and storage proof verification (spec §6.3). No I/O.
//!
//! The account proof is checked against an L1 header's `stateRoot` at key `keccak256(address)`;
//! each storage proof is then checked against the proven `storageRoot` at key `keccak256(slot)`.
//! A storage value of zero must come with an exclusion proof, and a non-zero value with an
//! inclusion proof of `rlp(value)`.

use std::collections::BTreeMap;

use alloy_primitives::{B256, U256, keccak256};
use alloy_trie::{
    Nibbles, TrieAccount,
    proof::{ProofVerificationError, verify_proof},
};

use crate::types::AccountWitness;

/// Errors from [`verify_account_witness`].
#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum MptError {
    /// The account proof does not prove the witnessed account fields under the state root.
    #[error("invalid account proof: {0}")]
    Account(#[source] ProofVerificationError),
    /// The witness proves a different slot list than the verifier expects (order matters).
    #[error("storage slot set mismatch: expected {expected:?}, got {got:?}")]
    SlotSet {
        /// The slots the verifier requires, in order.
        expected: Vec<B256>,
        /// The slots the witness carries, in order.
        got: Vec<B256>,
    },
    /// A storage proof does not prove the witnessed value under the account's storage root.
    #[error("invalid storage proof for slot {slot}: {source}")]
    Storage {
        /// The un-hashed slot whose proof failed.
        slot: B256,
        /// The underlying trie verification failure (boxed to keep `MptError` small).
        #[source]
        source: Box<ProofVerificationError>,
    },
}

/// Storage words proven by [`verify_account_witness`], keyed by un-hashed slot.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct VerifiedStorage {
    /// Proven slot values (zero for proven-absent slots), ordered by slot.
    values: BTreeMap<B256, U256>,
}

impl VerifiedStorage {
    /// The proven value of `slot`, or `None` if `slot` was not part of the verified set.
    pub fn get(&self, slot: B256) -> Option<U256> {
        self.values.get(&slot).copied()
    }
}

/// Verifies an [`AccountWitness`] against `state_root` and returns its proven storage words.
///
/// Checks, in order: (a) the account proof proves `rlp([nonce, balance, storage_root,
/// code_hash])` at `keccak256(address)` under `state_root` (the account must exist); (b) the
/// witness's storage slots equal `expected_slots` exactly (same order, same length); (c) every
/// storage proof proves its value under `storage_root` at `keccak256(slot)`, with value zero
/// accepted only through an exclusion proof.
pub fn verify_account_witness(
    state_root: B256,
    w: &AccountWitness,
    expected_slots: &[B256],
) -> Result<VerifiedStorage, MptError> {
    let account = TrieAccount {
        nonce: w.nonce,
        balance: w.balance,
        storage_root: w.storage_root,
        code_hash: w.code_hash,
    };
    verify_proof(
        state_root,
        Nibbles::unpack(keccak256(w.address)),
        Some(alloy_rlp::encode(account)),
        &w.account_proof,
    )
    .map_err(MptError::Account)?;

    if !w.storage.iter().map(|p| &p.slot).eq(expected_slots) {
        return Err(MptError::SlotSet {
            expected: expected_slots.to_vec(),
            got: w.storage.iter().map(|p| p.slot).collect(),
        });
    }

    let mut values = BTreeMap::new();
    for p in &w.storage {
        let expected = (!p.value.is_zero()).then(|| alloy_rlp::encode(p.value));
        verify_proof(w.storage_root, Nibbles::unpack(keccak256(p.slot)), expected, &p.proof)
            .map_err(|source| MptError::Storage { slot: p.slot, source: Box::new(source) })?;
        values.insert(p.slot, p.value);
    }
    Ok(VerifiedStorage { values })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::{AccountSpec, TestState};
    use alloy_primitives::{Address, address};
    use alloy_trie::EMPTY_ROOT_HASH;

    const INBOX: Address = address!("00000000000000000000000000000000e7a10001");
    const EMPTY: Address = address!("00000000000000000000000000000000e7a10002");

    fn slot(n: u64) -> B256 {
        B256::from(U256::from(n))
    }

    /// The inbox with three non-zero slots and one zero-valued entry, an empty-storage account,
    /// and filler accounts so the account proof walks through branch nodes.
    fn state() -> TestState {
        let mut accounts: Vec<AccountSpec> = vec![
            (
                INBOX,
                1,
                U256::from(5u64),
                keccak256(b"inbox code"),
                vec![
                    (slot(258), U256::from(3u64)),
                    (slot(268), U256::from(2u64)),
                    (slot(271), U256::from_be_bytes([0xab; 32])),
                    (slot(270), U256::ZERO),
                    (slot(999), U256::from(1u64)),
                ],
            ),
            (EMPTY, 0, U256::from(1u64), keccak256(b""), vec![]),
        ];
        for i in 0..32u8 {
            accounts.push((
                Address::repeat_byte(i + 1),
                u64::from(i),
                U256::from(i),
                keccak256([i]),
                vec![(slot(u64::from(i)), U256::from(i) + U256::from(1u64))],
            ));
        }
        TestState::new(accounts)
    }

    fn anchor_slots() -> Vec<B256> {
        [258u64, 268, 270, 271].map(slot).to_vec()
    }

    #[test]
    fn accepts_a_valid_witness() {
        let state = state();
        let slots = anchor_slots();
        let witness = state.witness(INBOX, &slots);
        let verified = verify_account_witness(state.state_root(), &witness, &slots).unwrap();
        assert_eq!(verified.get(slot(258)), Some(U256::from(3u64)));
        assert_eq!(verified.get(slot(268)), Some(U256::from(2u64)));
        assert_eq!(verified.get(slot(270)), Some(U256::ZERO));
        assert_eq!(verified.get(slot(271)), Some(U256::from_be_bytes([0xab; 32])));
        assert_eq!(verified.get(slot(999)), None, "unrequested slots are not exposed");
    }

    #[test]
    fn accepts_an_empty_slot_list() {
        let state = state();
        let witness = state.witness(INBOX, &[]);
        let verified = verify_account_witness(state.state_root(), &witness, &[]).unwrap();
        assert_eq!(verified.get(slot(258)), None);
    }

    #[test]
    fn accepts_zero_values_with_exclusion_proofs() {
        let state = state();
        let slots = vec![slot(270), slot(12_345)];
        let witness = state.witness(INBOX, &slots);
        assert!(witness.storage.iter().all(|p| p.value.is_zero()));
        let verified = verify_account_witness(state.state_root(), &witness, &slots).unwrap();
        assert_eq!(verified.get(slot(270)), Some(U256::ZERO));
        assert_eq!(verified.get(slot(12_345)), Some(U256::ZERO));
    }

    #[test]
    fn accepts_exclusion_proofs_against_an_empty_storage_trie() {
        let state = state();
        let slots = anchor_slots();
        let witness = state.witness(EMPTY, &slots);
        assert_eq!(witness.storage_root, EMPTY_ROOT_HASH);
        let verified = verify_account_witness(state.state_root(), &witness, &slots).unwrap();
        assert_eq!(verified.get(slot(258)), Some(U256::ZERO));
    }

    #[test]
    fn rejects_a_wrong_state_root() {
        let state = state();
        let slots = anchor_slots();
        let witness = state.witness(INBOX, &slots);
        let err = verify_account_witness(B256::repeat_byte(0x01), &witness, &slots).unwrap_err();
        assert!(matches!(err, MptError::Account(_)), "{err:?}");
    }

    #[test]
    fn rejects_tampered_account_fields() {
        let state = state();
        let slots = anchor_slots();
        let witness = state.witness(INBOX, &slots);

        let mut tampered = witness.clone();
        tampered.balance += U256::from(1u64);
        let err = verify_account_witness(state.state_root(), &tampered, &slots).unwrap_err();
        assert!(matches!(err, MptError::Account(_)), "{err:?}");

        let mut tampered = witness.clone();
        tampered.nonce += 1;
        let err = verify_account_witness(state.state_root(), &tampered, &slots).unwrap_err();
        assert!(matches!(err, MptError::Account(_)), "{err:?}");

        let mut tampered = witness.clone();
        tampered.storage_root = EMPTY_ROOT_HASH;
        let err = verify_account_witness(state.state_root(), &tampered, &slots).unwrap_err();
        assert!(matches!(err, MptError::Account(_)), "{err:?}");

        let mut tampered = witness;
        tampered.address = EMPTY;
        let err = verify_account_witness(state.state_root(), &tampered, &slots).unwrap_err();
        assert!(matches!(err, MptError::Account(_)), "{err:?}");
    }

    #[test]
    fn rejects_a_tampered_storage_value() {
        let state = state();
        let slots = anchor_slots();
        let mut witness = state.witness(INBOX, &slots);
        witness.storage[1].value = U256::from(7u64);
        let err = verify_account_witness(state.state_root(), &witness, &slots).unwrap_err();
        assert!(matches!(err, MptError::Storage { slot: s, .. } if s == slot(268)), "{err:?}");
    }

    #[test]
    fn rejects_a_non_zero_value_claimed_zero() {
        let state = state();
        let slots = anchor_slots();
        let mut witness = state.witness(INBOX, &slots);
        witness.storage[0].value = U256::ZERO;
        let err = verify_account_witness(state.state_root(), &witness, &slots).unwrap_err();
        assert!(matches!(err, MptError::Storage { slot: s, .. } if s == slot(258)), "{err:?}");
    }

    #[test]
    fn rejects_an_absent_slot_claimed_non_zero() {
        let state = state();
        let slots = anchor_slots();
        let mut witness = state.witness(INBOX, &slots);
        witness.storage[2].value = U256::from(1u64);
        let err = verify_account_witness(state.state_root(), &witness, &slots).unwrap_err();
        assert!(matches!(err, MptError::Storage { slot: s, .. } if s == slot(270)), "{err:?}");
    }

    #[test]
    fn rejects_swapped_storage_proofs() {
        let state = state();
        let slots = anchor_slots();
        let mut witness = state.witness(INBOX, &slots);
        let first = witness.storage[0].proof.clone();
        witness.storage[0].proof = witness.storage[1].proof.clone();
        witness.storage[1].proof = first;
        let err = verify_account_witness(state.state_root(), &witness, &slots).unwrap_err();
        assert!(matches!(err, MptError::Storage { slot: s, .. } if s == slot(258)), "{err:?}");
    }

    #[test]
    fn rejects_slot_order_or_set_mismatch() {
        let state = state();
        let slots = anchor_slots();

        // Same slots, different order.
        let mut reordered = slots.clone();
        reordered.swap(0, 1);
        let witness = state.witness(INBOX, &reordered);
        let err = verify_account_witness(state.state_root(), &witness, &slots).unwrap_err();
        assert_eq!(err, MptError::SlotSet { expected: slots.clone(), got: reordered });

        // Missing slot.
        let witness = state.witness(INBOX, &slots[..3]);
        let err = verify_account_witness(state.state_root(), &witness, &slots).unwrap_err();
        assert!(matches!(err, MptError::SlotSet { .. }), "{err:?}");

        // Extra slot.
        let mut extra = slots.clone();
        extra.push(slot(999));
        let witness = state.witness(INBOX, &extra);
        let err = verify_account_witness(state.state_root(), &witness, &slots).unwrap_err();
        assert!(matches!(err, MptError::SlotSet { .. }), "{err:?}");

        // Substituted slot.
        let mut substituted = slots.clone();
        substituted[3] = slot(999);
        let witness = state.witness(INBOX, &substituted);
        let err = verify_account_witness(state.state_root(), &witness, &slots).unwrap_err();
        assert!(matches!(err, MptError::SlotSet { .. }), "{err:?}");
    }
}

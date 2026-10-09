//! EIP-1186 account and storage proof verification (spec §6.3). No I/O.
//!
//! The account proof is checked against an L1 header's `stateRoot` at key `keccak256(address)`;
//! each storage proof is then checked against the proven `storageRoot` at key `keccak256(slot)`.
//! A storage value of zero must come with a complete exclusion proof (one that ends where the trie
//! diverges from the key), and a non-zero value with an inclusion proof of `rlp(value)`.

use std::collections::BTreeMap;

use alloy_primitives::{B256, Bytes, U256, keccak256};
use alloy_rlp::{Decodable, EMPTY_STRING_CODE};
use alloy_trie::{
    EMPTY_ROOT_HASH, Nibbles, TrieAccount,
    nodes::TrieNode,
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
        /// The underlying trie verification failure (boxed to keep `MptError` small). A zero value
        /// whose proof stops before the trie diverges from the slot's key is reported as a
        /// `ValueMismatch` carrying the proof's last node.
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
/// accepted only through a complete exclusion proof.
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
        verify_storage_value(w.storage_root, Nibbles::unpack(keccak256(p.slot)), p.value, &p.proof)
            .map_err(|source| MptError::Storage { slot: p.slot, source: Box::new(source) })?;
        values.insert(p.slot, p.value);
    }
    Ok(VerifiedStorage { values })
}

/// Verifies that `proof` proves `value` at `key` under `storage_root`: an inclusion proof of
/// `rlp(value)` for a non-zero value, an exclusion proof that passes [`proves_absence`] for zero.
fn verify_storage_value(
    storage_root: B256,
    key: Nibbles,
    value: U256,
    proof: &[Bytes],
) -> Result<(), ProofVerificationError> {
    if !value.is_zero() {
        return verify_proof(storage_root, key, Some(alloy_rlp::encode(value)), proof);
    }
    verify_proof(storage_root, key, None, proof)?;
    if proves_absence(storage_root, &key, proof) {
        Ok(())
    } else {
        Err(ProofVerificationError::ValueMismatch {
            path: key,
            got: proof.last().cloned(),
            expected: None,
        })
    }
}

/// Whether `proof` proves that `key` is absent from the trie under `root`.
///
/// `verify_proof` accepts any proof that stops short of `key` as an exclusion proof, so a proof
/// cut off at a node that still points further along `key` (just the root node, say) would prove
/// any slot zero. This walk checks the proof on its own: it follows `key` from `root`, requires
/// each proof node to hash to the reference its parent holds (children encoded in place are
/// walked inside their parent without consuming a proof node), and accepts only when the path
/// provably ends before `key`: the empty trie (no proof nodes, or the single empty node), a
/// branch with no child at the next nibble, or an extension or leaf whose key diverges from the
/// rest of `key`. It rejects a proof that runs out while a child on the path is still unopened,
/// and one that carries nodes past the divergence.
fn proves_absence(root: B256, key: &Nibbles, proof: &[Bytes]) -> bool {
    if proof.is_empty() || matches!(proof, [node] if node[..] == [EMPTY_STRING_CODE]) {
        return root == EMPTY_ROOT_HASH;
    }
    let mut next_hash = root;
    // Number of leading nibbles of `key` the walk has consumed; never exceeds `key.len()`.
    let mut walked = 0;
    for (index, encoded) in proof.iter().enumerate() {
        let is_last = index + 1 == proof.len();
        if keccak256(encoded) != next_hash {
            return false;
        }
        let Ok(mut node) = TrieNode::decode(&mut &encoded[..]) else { return false };
        // Follow `key` through this node and any children encoded in place inside it, until the
        // path ends or reaches a child referenced by hash (the next proof node).
        next_hash = loop {
            let child = match node {
                TrieNode::EmptyRoot => return false,
                TrieNode::Branch(branch) => {
                    let Some(nibble) = key.get(walked) else { return false };
                    let branch = branch.as_ref();
                    let child = branch.children().nth(usize::from(nibble)).and_then(|c| c.1);
                    let Some(child) = child.cloned() else { return is_last };
                    walked += 1;
                    child
                }
                TrieNode::Extension(extension) => {
                    if !key.slice(walked..).starts_with(&extension.key) {
                        return is_last;
                    }
                    walked += extension.key.len();
                    extension.child
                }
                TrieNode::Leaf(leaf) => return is_last && leaf.key != key.slice(walked..),
            };
            if let Some(hash) = child.as_hash() {
                break hash;
            }
            let Ok(inline) = TrieNode::decode(&mut child.as_slice()) else { return false };
            node = inline;
        };
    }
    // The proof ran out while a child on the path to `key` was still unopened.
    false
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::{AccountSpec, TestState};
    use alloy_primitives::{Address, address, b256};
    use alloy_trie::{HashBuilder, proof::ProofRetainer};

    const INBOX: Address = address!("00000000000000000000000000000000e7a10001");
    const EMPTY: Address = address!("00000000000000000000000000000000e7a10002");
    const DEEP: Address = address!("00000000000000000000000000000000e7a10003");

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

    /// An account with 40 non-zero slots, so its storage proofs walk through nested branches.
    fn deep_state() -> TestState {
        let storage = (1..=40u64).map(|n| (slot(n), U256::from(n))).collect();
        TestState::new(vec![(DEEP, 0, U256::ZERO, keccak256(b"deep code"), storage)])
    }

    /// The first of `candidates` whose storage proof in [`deep_state`] has at least three nodes.
    fn slot_with_deep_proof(state: &TestState, candidates: impl IntoIterator<Item = u64>) -> B256 {
        candidates
            .into_iter()
            .map(slot)
            .find(|s| state.witness(DEEP, &[*s]).storage[0].proof.len() >= 3)
            .expect("some candidate has a proof of at least three nodes")
    }

    #[test]
    fn rejects_a_non_zero_slot_claimed_zero_with_a_truncated_proof() {
        let state = deep_state();
        let present = slot_with_deep_proof(&state, 1..=40);
        let witness = state.witness(DEEP, &[present]);
        assert!(!witness.storage[0].value.is_zero());
        let full = witness.storage[0].proof.clone();

        // Only the root node, and the full proof minus its last node.
        for proof in [full[..1].to_vec(), full[..full.len() - 1].to_vec()] {
            let mut forged = witness.clone();
            forged.storage[0].value = U256::ZERO;
            forged.storage[0].proof = proof;
            let err = verify_account_witness(state.state_root(), &forged, &[present]).unwrap_err();
            assert!(matches!(err, MptError::Storage { slot: s, .. } if s == present), "{err:?}");
        }
    }

    #[test]
    fn rejects_a_truncated_exclusion_proof_for_an_absent_slot() {
        let state = deep_state();
        let absent = slot_with_deep_proof(&state, 1_000..2_000);
        let mut witness = state.witness(DEEP, &[absent]);
        assert!(witness.storage[0].value.is_zero());
        verify_account_witness(state.state_root(), &witness, &[absent]).unwrap();

        witness.storage[0].proof.pop();
        let err = verify_account_witness(state.state_root(), &witness, &[absent]).unwrap_err();
        assert!(matches!(err, MptError::Storage { slot: s, .. } if s == absent), "{err:?}");
    }

    #[test]
    fn rejects_a_byte_tampered_middle_proof_node() {
        let state = deep_state();
        let present = slot_with_deep_proof(&state, 1..=40);
        let absent = slot_with_deep_proof(&state, 1_000..2_000);
        for s in [present, absent] {
            let mut witness = state.witness(DEEP, &[s]);
            let mut node = witness.storage[0].proof[1].to_vec();
            let mid = node.len() / 2;
            node[mid] ^= 0x01;
            witness.storage[0].proof[1] = node.into();
            let err = verify_account_witness(state.state_root(), &witness, &[s]).unwrap_err();
            assert!(matches!(err, MptError::Storage { slot: got, .. } if got == s), "{err:?}");
        }
    }

    /// Account proofs only ever prove inclusion, so no truncation of one is accepted.
    #[test]
    fn rejects_a_truncated_account_proof() {
        let state = state();
        let slots = anchor_slots();
        let witness = state.witness(INBOX, &slots);
        assert!(witness.account_proof.len() >= 2);
        for len in 0..witness.account_proof.len() {
            let mut truncated = witness.clone();
            truncated.account_proof.truncate(len);
            let err = verify_account_witness(state.state_root(), &truncated, &slots).unwrap_err();
            assert!(matches!(err, MptError::Account(_)), "{len} nodes: {err:?}");
        }
    }

    // A hand-built trie whose shape is fixed by its keys rather than by `keccak256`:
    //
    //   root branch
    //   ├─ 5: leaf(KEY_5)
    //   └─ a: extension "aaa" -> branch { 0: leaf(KEY_A0), 1: leaf(KEY_A1) }
    const KEY_5: B256 = b256!("5555555555555555555555555555555555555555555555555555555555555555");
    const KEY_A0: B256 = b256!("aaaa000000000000000000000000000000000000000000000000000000000000");
    const KEY_A1: B256 = b256!("aaaa111111111111111111111111111111111111111111111111111111111111");
    /// Absent: the root branch has no child at nibble `1`.
    const ABSENT_AT_ROOT: B256 =
        b256!("1111111111111111111111111111111111111111111111111111111111111111");
    /// Absent: the extension key `aaa` diverges from the key's `bbb…`.
    const ABSENT_AT_EXTENSION: B256 =
        b256!("abbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb");
    /// Absent: the branch below the extension has no child at nibble `2`.
    const ABSENT_AT_NESTED_BRANCH: B256 =
        b256!("aaaa222222222222222222222222222222222222222222222222222222222222");
    /// Absent: the leaf under nibble `5` holds a different key.
    const ABSENT_AT_LEAF: B256 =
        b256!("5444444444444444444444444444444444444444444444444444444444444444");
    /// The word every hand-built leaf holds.
    const WORD: U256 = U256::from_limbs([0xdead_beef, 0, 0, 0]);

    /// Builds a trie mapping each of `keys` to `value` and returns its root with the proof for
    /// `target`: the nodes on the path to it, root first, leaving out nodes encoded in place in
    /// their parent (as `eth_getProof` does, only hash-referenced nodes are proof elements).
    fn trie_proof(keys: &[B256], value: U256, target: B256) -> (B256, Vec<Bytes>) {
        let target = Nibbles::unpack(target);
        let mut builder =
            HashBuilder::default().with_proof_retainer(ProofRetainer::new(vec![target]));
        let mut keys = keys.to_vec();
        keys.sort();
        for key in keys {
            builder.add_leaf(Nibbles::unpack(key), &alloy_rlp::encode(value));
        }
        let root = builder.root();
        let proof = builder
            .take_proof_nodes()
            .matching_nodes_sorted(&target)
            .into_iter()
            .filter(|(path, node)| path.is_empty() || node.len() >= 32)
            .map(|(_, node)| node)
            .collect();
        (root, proof)
    }

    /// The root of the hand-built trie and the proof for `target`.
    fn hand_trie_proof(target: B256) -> (B256, Vec<Bytes>) {
        trie_proof(&[KEY_5, KEY_A0, KEY_A1], WORD, target)
    }

    /// Whether `proof` is accepted as proving that `key` holds zero under `root`.
    fn accepts_zero(root: B256, key: B256, proof: &[Bytes]) -> bool {
        verify_storage_value(root, Nibbles::unpack(key), U256::ZERO, proof).is_ok()
    }

    #[test]
    fn accepts_genuine_exclusion_proofs() {
        for (key, nodes) in [
            (ABSENT_AT_ROOT, 1),
            (ABSENT_AT_EXTENSION, 2),
            (ABSENT_AT_LEAF, 2),
            (ABSENT_AT_NESTED_BRANCH, 3),
        ] {
            let (root, proof) = hand_trie_proof(key);
            assert_eq!(proof.len(), nodes, "{key}");
            assert!(accepts_zero(root, key, &proof), "{key}");
        }

        // The empty trie: an empty proof, or the single empty node.
        let empty_node = Bytes::from_static(&[EMPTY_STRING_CODE]);
        assert!(accepts_zero(EMPTY_ROOT_HASH, KEY_5, &[]));
        assert!(accepts_zero(EMPTY_ROOT_HASH, KEY_5, std::slice::from_ref(&empty_node)));
        let (root, _) = hand_trie_proof(KEY_5);
        assert!(!accepts_zero(root, ABSENT_AT_ROOT, &[]));
        assert!(!accepts_zero(root, ABSENT_AT_ROOT, &[empty_node]));
    }

    #[test]
    fn rejects_present_keys_claimed_zero_at_every_truncation() {
        for key in [KEY_5, KEY_A0, KEY_A1] {
            let (root, proof) = hand_trie_proof(key);
            verify_storage_value(root, Nibbles::unpack(key), WORD, &proof).unwrap();
            for len in 1..=proof.len() {
                assert!(!accepts_zero(root, key, &proof[..len]), "{key}: {len}/{}", proof.len());
            }
        }
    }

    #[test]
    fn rejects_an_exclusion_proof_cut_off_after_an_extension() {
        let (root, proof) = hand_trie_proof(ABSENT_AT_NESTED_BRANCH);
        assert_eq!(proof.len(), 3);
        assert!(matches!(TrieNode::decode(&mut &proof[1][..]), Ok(TrieNode::Extension(_))));
        // These two nodes do prove ABSENT_AT_EXTENSION absent, but this key matches the extension,
        // which points on to the branch the proof leaves out.
        assert!(accepts_zero(root, ABSENT_AT_EXTENSION, &proof[..2]));
        assert!(!accepts_zero(root, ABSENT_AT_NESTED_BRANCH, &proof[..2]));
        assert!(!accepts_zero(root, ABSENT_AT_NESTED_BRANCH, &proof[..1]));
    }

    #[test]
    fn rejects_nodes_past_the_divergence() {
        let (root, mut proof) = hand_trie_proof(ABSENT_AT_EXTENSION);
        // Append the branch the diverging extension points to.
        proof.push(hand_trie_proof(ABSENT_AT_NESTED_BRANCH).1[2].clone());
        assert!(!accepts_zero(root, ABSENT_AT_EXTENSION, &proof));
    }

    #[test]
    fn walks_children_encoded_in_place() {
        // Two keys sharing 63 nibbles: the root is an extension whose branch child, holding two
        // in-place leaves, is itself encoded in place, so every proof is the root node alone.
        let (one, two, three) =
            (B256::with_last_byte(1), B256::with_last_byte(2), B256::with_last_byte(3));
        let (root, proof) = trie_proof(&[one, two], U256::from(1u64), three);
        assert_eq!(proof.len(), 1);
        assert!(accepts_zero(root, three, &proof), "the in-place branch has no child at 3");
        assert!(accepts_zero(root, B256::repeat_byte(0x11), &proof), "diverges at the extension");
        assert!(!accepts_zero(root, one, &proof), "the in-place leaf holds a value");
        verify_storage_value(root, Nibbles::unpack(one), U256::from(1u64), &proof).unwrap();
    }
}

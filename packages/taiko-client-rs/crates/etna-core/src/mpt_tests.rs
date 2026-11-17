//! Regression vectors extracted with the canonical witness verifier.
use super::*;
use crate::{
    test_utils::{AccountSpec, TestState},
    witness::StorageProof,
};
use alloc::vec;
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
    let mut builder = HashBuilder::default().with_proof_retainer(ProofRetainer::new(vec![target]));
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

// Malformed nodes that `alloy-trie` or `nybbles` assert on. Whoever chooses the state root can
// make them hash-link to it, so verification must reject them, never panic.

/// RLP-encodes `items` (each already RLP-encoded) as a list.
fn rlp_list(items: &[&[u8]]) -> Vec<u8> {
    let payload = items.concat();
    let mut out = Vec::new();
    Header { list: true, payload_length: payload.len() }.encode(&mut out);
    out.extend_from_slice(&payload);
    out
}

/// A reference to `node` by hash, as a parent node holds it.
fn hash_ref(node: &[u8]) -> Vec<u8> {
    alloy_rlp::encode(keccak256(node))
}

/// A leaf (flag `0x2`/`0x3`) or extension (`0x0`/`0x1`) node with the raw compact path
/// `compact` and a one-byte value or a dummy hash child.
fn short_node(compact: &[u8]) -> Vec<u8> {
    let second = if compact[0] & 0x20 == 0 { hash_ref(b"child") } else { vec![0x01] };
    rlp_list(&[&alloy_rlp::encode(compact), &second])
}

/// A branch node holding `child` (raw RLP: a hash reference or an in-place node) at `nibble`
/// and a dummy hash reference at the next nibble, so it is itself referenced by hash.
fn branch_with(nibble: u8, child: &[u8]) -> Vec<u8> {
    let filler = alloy_rlp::encode(B256::repeat_byte(0x11));
    let empty = [EMPTY_STRING_CODE];
    let items: Vec<&[u8]> = (0..17u8)
        .map(|i| match i {
            _ if i == nibble => child,
            _ if i == (nibble + 1) % 16 => &filler[..],
            _ => &empty[..],
        })
        .collect();
    rlp_list(&items)
}

/// A `len`-byte compact path: the flag byte `flag`, then zero bytes.
fn compact_path(flag: u8, len: usize) -> Vec<u8> {
    let mut path = vec![0u8; len];
    path[0] = flag;
    path
}

/// Root nodes whose compact path holds more than 64 nibbles (`Nibbles::unpack` or
/// `Nibbles::join` assert on them), as one-node proofs.
fn overlong_path_proofs() -> Vec<(&'static str, Vec<Bytes>)> {
    [
        ("even leaf, 66 nibbles", 0x20, 34),
        ("odd leaf, 65 nibbles", 0x30, 33),
        ("even extension, 66 nibbles", 0x00, 34),
        ("odd extension, 65 nibbles", 0x10, 33),
    ]
    .into_iter()
    .map(|(name, flag, len)| (name, vec![short_node(&compact_path(flag, len)).into()]))
    .collect()
}

/// Proofs for `key` that hash-link to their first node but that `alloy-trie` or `nybbles`
/// cannot process, each flagged with whether the verifier rejects it before calling into the
/// compact-path guard (`true`) or the bounded geometry checks (`false`).
fn malformed_proofs(key: B256) -> Vec<(&'static str, Vec<Bytes>, bool)> {
    let nibble = key[0] >> 4;
    // (a) A branch whose in-place extension child points at a leaf: `unreachable!`.
    let in_place_leaf = rlp_list(&[&[0x20], &[0x01]]);
    let in_place_extension = rlp_list(&[&[0x15], &in_place_leaf]);
    let a = vec![branch_with(nibble, &in_place_extension).into()];
    // (b) A branch then a leaf with a full 64-nibble path: the walked path overflows.
    let leaf = short_node(&compact_path(0x20, 33));
    let b = vec![branch_with(nibble, &hash_ref(&leaf)).into(), leaf.into()];

    let mut proofs = vec![
        ("in-place extension over a leaf", a, false),
        ("64-nibble leaf under a branch", b, false),
    ];
    // (c) A root node whose compact path is longer than 64 nibbles.
    proofs.extend(overlong_path_proofs().into_iter().map(|(name, proof)| (name, proof, true)));
    proofs
}

/// A witness for `INBOX` with a genuine account proof (from a one-account state trie) that
/// carries `storage_root` and `storage`, and the root of that state trie.
fn witness_over(storage_root: B256, storage: Vec<StorageProof>) -> (B256, AccountWitness) {
    let (nonce, balance, code_hash) = (1, U256::from(5u64), keccak256(b"inbox code"));
    let account = TrieAccount { nonce, balance, storage_root, code_hash };
    let key = Nibbles::unpack(keccak256(INBOX));
    let mut builder = HashBuilder::default().with_proof_retainer(ProofRetainer::new(vec![key]));
    builder.add_leaf(key, &alloy_rlp::encode(account));
    let root = builder.root();
    let account_proof =
        builder.take_proof_nodes().into_nodes_sorted().into_iter().map(|(_, n)| n).collect();
    let witness = AccountWitness {
        address: INBOX,
        nonce,
        balance,
        storage_root,
        code_hash,
        account_proof,
        storage,
    };
    (root, witness)
}

#[test]
fn rejects_malformed_account_proofs_without_panicking() {
    for (name, proof, guarded) in malformed_proofs(keccak256(INBOX)) {
        let state_root = keccak256(&proof[0]);
        let (_, mut witness) = witness_over(EMPTY_ROOT_HASH, vec![]);
        witness.account_proof = proof;
        let err = verify_account_witness(state_root, &witness, &[]).unwrap_err();
        if guarded {
            assert!(matches!(err, MptError::Account(ProofVerificationError::Rlp(_))), "{name}");
        } else {
            assert_eq!(err, MptError::MalformedProof, "{name}");
        }
    }
}

#[test]
fn rejects_malformed_storage_proofs_without_panicking() {
    let s = slot(258);
    let absent = StorageProof { slot: s, value: U256::ZERO, proof: vec![] };
    let (root, witness) = witness_over(EMPTY_ROOT_HASH, vec![absent]);
    verify_account_witness(root, &witness, &[s]).unwrap();

    for (name, proof, guarded) in malformed_proofs(keccak256(s)) {
        for value in [U256::ZERO, WORD] {
            let storage = vec![StorageProof { slot: s, value, proof: proof.clone() }];
            let (root, witness) = witness_over(keccak256(&proof[0]), storage);
            let err = verify_account_witness(root, &witness, &[s]).unwrap_err();
            if guarded {
                assert!(
                    matches!(&err, MptError::Storage { slot: got, source }
                        if *got == s && matches!(**source, ProofVerificationError::Rlp(_))),
                    "{name}, value {value}: {err:?}"
                );
            } else {
                assert_eq!(err, MptError::MalformedProof, "{name}, value {value}");
            }
        }
    }
}

#[test]
fn exclusion_verification_rejects_overlong_paths() {
    let key = Nibbles::unpack(B256::ZERO);
    for (name, proof) in overlong_path_proofs() {
        assert!(
            verify_storage_value(keccak256(&proof[0]), key, U256::ZERO, &proof).is_err(),
            "{name}"
        );
    }
}

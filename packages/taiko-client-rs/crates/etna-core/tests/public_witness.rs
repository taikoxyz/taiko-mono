//! The portable public seam must authenticate both account fields and ordered storage slots.
use alloy_primitives::{Address, B256, Bytes, U256, keccak256};
use alloy_rlp::{EMPTY_STRING_CODE, Header};
use alloy_trie::{EMPTY_ROOT_HASH, HashBuilder, Nibbles, TrieAccount, proof::ProofRetainer};
use etna_core::{AccountWitness, StorageProof, verify_account_witness};

fn slot(n: u64) -> B256 {
    B256::from(U256::from(n))
}

fn account_over(storage_root: B256, storage: Vec<StorageProof>) -> (B256, AccountWitness) {
    let address = Address::repeat_byte(0x42);
    let account = TrieAccount {
        nonce: 1,
        balance: U256::from(7u64),
        storage_root,
        code_hash: keccak256(b"fixture code"),
    };
    let key = Nibbles::unpack(keccak256(address));
    let mut builder = HashBuilder::default().with_proof_retainer(ProofRetainer::new(vec![key]));
    builder.add_leaf(key, &alloy_rlp::encode(account));
    let root = builder.root();
    let account_proof =
        builder.take_proof_nodes().into_nodes_sorted().into_iter().map(|(_, node)| node).collect();
    (
        root,
        AccountWitness {
            address,
            nonce: account.nonce,
            balance: account.balance,
            storage_root,
            code_hash: account.code_hash,
            account_proof,
            storage,
        },
    )
}

fn storage_fixture(target: B256) -> (B256, AccountWitness) {
    let key = Nibbles::unpack(keccak256(target));
    let mut leaves: Vec<_> = (1..=40).map(|n| (keccak256(slot(n)), U256::from(n))).collect();
    leaves.sort_by_key(|(key, _)| *key);
    let mut builder = HashBuilder::default().with_proof_retainer(ProofRetainer::new(vec![key]));
    for (key, value) in leaves {
        builder.add_leaf(Nibbles::unpack(key), &alloy_rlp::encode(value));
    }
    let root = builder.root();
    let proof = builder
        .take_proof_nodes()
        .matching_nodes_sorted(&key)
        .into_iter()
        .filter(|(path, node)| path.is_empty() || node.len() >= 32)
        .map(|(_, node)| node)
        .collect();
    let value = (1..=40).find(|n| slot(*n) == target).map(U256::from).unwrap_or_default();
    account_over(root, vec![StorageProof { slot: target, value, proof }])
}

#[test]
fn public_api_accepts_inclusion_and_complete_exclusion() {
    for (target, expected) in [(slot(12), U256::from(12u64)), (slot(1000), U256::ZERO)] {
        let (root, witness) = storage_fixture(target);
        assert_eq!(
            verify_account_witness(root, &witness, &[target]).unwrap().get(target),
            Some(expected)
        );
    }
    let target = slot(12);
    let (root, witness) = account_over(
        EMPTY_ROOT_HASH,
        vec![StorageProof { slot: target, value: U256::ZERO, proof: vec![] }],
    );
    assert_eq!(
        verify_account_witness(root, &witness, &[target]).unwrap().get(target),
        Some(U256::ZERO)
    );
}

#[test]
fn public_api_rejects_every_truncated_proof() {
    for target in [slot(12), slot(1000)] {
        let (root, witness) = storage_fixture(target);
        let full_len = witness.storage[0].proof.len();
        assert!(full_len >= 2);
        for len in 0..full_len {
            let mut truncated = witness.clone();
            truncated.storage[0].proof.truncate(len);
            truncated.storage[0].value = U256::ZERO;
            assert!(
                verify_account_witness(root, &truncated, &[target]).is_err(),
                "slot {target}, length {len}"
            );
        }
    }
}

#[test]
fn public_api_preserves_account_fields_and_slot_order() {
    let target = slot(12);
    let (root, mut witness) = storage_fixture(target);
    assert!(verify_account_witness(root, &witness, &[slot(13)]).is_err());
    assert!(verify_account_witness(root, &witness, &[]).is_err());
    witness.balance += U256::from(1u64);
    assert!(verify_account_witness(root, &witness, &[target]).is_err());
}

fn list(items: &[&[u8]]) -> Vec<u8> {
    let payload = items.concat();
    let mut out = Vec::new();
    Header { list: true, payload_length: payload.len() }.encode(&mut out);
    out.extend(payload);
    out
}

#[test]
fn public_api_rejects_overlong_overwalking_and_inline_extension_nodes() {
    let target = slot(12);
    let nibble = usize::from(keccak256(target)[0] >> 4);
    let leaf = list(&[&alloy_rlp::encode([vec![0x20], vec![0; 32]].concat().as_slice()), &[0x01]]);
    let leaf_hash = alloy_rlp::encode(keccak256(&leaf));
    let inline_leaf = list(&[&[0x20], &[0x01]]);
    let inline_extension = list(&[&[0x15], &inline_leaf]);
    let empty = [EMPTY_STRING_CODE];
    let filler = alloy_rlp::encode(B256::repeat_byte(0x11));
    let branch = |child: &[u8]| {
        list(
            &(0..17)
                .map(|i| {
                    if i == nibble {
                        child
                    } else if i == (nibble + 1) % 16 {
                        filler.as_slice()
                    } else {
                        &empty
                    }
                })
                .collect::<Vec<_>>(),
        )
    };
    let overlong =
        list(&[&alloy_rlp::encode([vec![0x30], vec![0; 32]].concat().as_slice()), &[0x01]]);
    let proofs: Vec<Vec<Bytes>> = vec![
        vec![overlong.into()],
        vec![branch(&leaf_hash).into(), leaf.into()],
        vec![branch(&inline_extension).into()],
    ];
    for proof in proofs {
        for value in [U256::ZERO, U256::from(1u64)] {
            let (root, witness) = account_over(
                keccak256(&proof[0]),
                vec![StorageProof { slot: target, value, proof: proof.clone() }],
            );
            assert!(verify_account_witness(root, &witness, &[target]).is_err());
        }
    }
}

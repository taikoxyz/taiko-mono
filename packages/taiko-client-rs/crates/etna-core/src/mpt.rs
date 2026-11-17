//! EIP-1186 account and storage proof verification. No I/O.
//!
//! The account proof is checked against an L1 header's `stateRoot` at key `keccak256(address)`;
//! each storage proof is checked against the proven `storageRoot` at key `keccak256(slot)`.
//! A zero storage value requires a complete exclusion proof; nonzero values require inclusion.

use crate::witness::AccountWitness;
use alloc::{boxed::Box, collections::BTreeMap, vec::Vec};
use alloy_primitives::{B256, Bytes, U256, keccak256};
use alloy_rlp::{Decodable, EMPTY_STRING_CODE, Header, PayloadView};
use alloy_trie::{
    EMPTY_ROOT_HASH, Nibbles, TrieAccount,
    nodes::{RlpNode, TrieNode},
    proof::ProofVerificationError,
};

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
        /// `ValueMismatch` carrying the unopened child reference.
        #[source]
        source: Box<ProofVerificationError>,
    },
    /// A proof node that the trie library cannot process; never valid. Whoever chooses the state
    /// root can make such a node hash-link to it, so this is an invalid witness, not a local fault.
    #[error("malformed proof node")]
    MalformedProof,
}

impl Clone for MptError {
    /// A field-by-field copy, as `alloy_trie`'s [`ProofVerificationError`] is not `Clone`.
    fn clone(&self) -> Self {
        match self {
            Self::Account(error) => Self::Account(clone_proof_error(error)),
            Self::SlotSet { expected, got } => {
                Self::SlotSet { expected: expected.clone(), got: got.clone() }
            }
            Self::Storage { slot, source } => {
                Self::Storage { slot: *slot, source: Box::new(clone_proof_error(source)) }
            }
            Self::MalformedProof => Self::MalformedProof,
        }
    }
}

/// A copy of `error`, which `alloy_trie` does not make `Clone`.
fn clone_proof_error(error: &ProofVerificationError) -> ProofVerificationError {
    match error {
        ProofVerificationError::RootMismatch { got, expected } => {
            ProofVerificationError::RootMismatch { got: *got, expected: *expected }
        }
        ProofVerificationError::ValueMismatch { path, got, expected } => {
            ProofVerificationError::ValueMismatch {
                path: *path,
                got: got.clone(),
                expected: expected.clone(),
            }
        }
        ProofVerificationError::UnexpectedEmptyRoot => ProofVerificationError::UnexpectedEmptyRoot,
        ProofVerificationError::Rlp(error) => ProofVerificationError::Rlp(*error),
    }
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
///
/// Malformed nodes are rejected through checked decoding and a bounded path walk. The walk
/// never extends a fixed-capacity nibble path or relies on unwinding, and uses the same checks
/// with `panic = "abort"`. Inline children are traversed without consuming a proof element;
/// unopened hash children, trailing proof nodes and nodes past a divergence are rejected.
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
    verify_nodes(
        state_root,
        Nibbles::unpack(keccak256(w.address)),
        Some(alloy_rlp::encode(account)),
        &w.account_proof,
    )
    .map_err(|error| match error {
        ProofFailure::Invalid(source) => MptError::Account(source),
        ProofFailure::Malformed => MptError::MalformedProof,
    })?;

    if !w.storage.iter().map(|p| &p.slot).eq(expected_slots) {
        return Err(MptError::SlotSet {
            expected: expected_slots.to_vec(),
            got: w.storage.iter().map(|p| p.slot).collect(),
        });
    }
    let mut values = BTreeMap::new();
    for p in &w.storage {
        verify_storage_value(w.storage_root, Nibbles::unpack(keccak256(p.slot)), p.value, &p.proof)
            .map_err(|error| match error {
                ProofFailure::Invalid(source) => {
                    MptError::Storage { slot: p.slot, source: Box::new(source) }
                }
                ProofFailure::Malformed => MptError::MalformedProof,
            })?;
        values.insert(p.slot, p.value);
    }
    Ok(VerifiedStorage { values })
}

/// Checked traversal failures, keeping the existing public malformed-node classification.
#[derive(Debug)]
enum ProofFailure {
    /// A normal proof mismatch or invalid RLP encoding.
    Invalid(ProofVerificationError),
    /// Invalid path geometry or an inline extension over a non-branch node.
    Malformed,
}

impl From<alloy_rlp::Error> for ProofFailure {
    /// Retains the underlying RLP failure for account/storage error context.
    fn from(error: alloy_rlp::Error) -> Self {
        Self::Invalid(ProofVerificationError::Rlp(error))
    }
}

/// Verifies inclusion of `rlp(value)` for nonzero words and complete exclusion for zero words.
fn verify_storage_value(
    storage_root: B256,
    key: Nibbles,
    value: U256,
    proof: &[Bytes],
) -> Result<(), ProofFailure> {
    verify_nodes(storage_root, key, (!value.is_zero()).then(|| alloy_rlp::encode(value)), proof)
}

/// Walks one authenticated path, checking its bounds before any nibble slicing or decoding.
///
/// Only an empty trie, a missing branch child or a divergent compact path proves absence.
/// Reaching a hash reference always requires another proof node, even at the key boundary.
fn verify_nodes(
    root: B256,
    key: Nibbles,
    expected: Option<Vec<u8>>,
    proof: &[Bytes],
) -> Result<(), ProofFailure> {
    if proof.is_empty() || matches!(proof, [node] if node[..] == [EMPTY_STRING_CODE]) {
        if root != EMPTY_ROOT_HASH {
            return Err(ProofFailure::Invalid(ProofVerificationError::RootMismatch {
                got: EMPTY_ROOT_HASH,
                expected: root,
            }));
        }
        return finish_proof(key, expected, None, proof.len(), proof.len());
    }
    let mut index = 0;
    if keccak256(&proof[index]) != root {
        return Err(ProofFailure::Invalid(ProofVerificationError::RootMismatch {
            got: keccak256(&proof[index]),
            expected: root,
        }));
    }
    let mut node = decode_node(&proof[index])?;
    let mut walked = 0;
    loop {
        let child = match node {
            TrieNode::EmptyRoot => {
                return Err(ProofFailure::Invalid(ProofVerificationError::UnexpectedEmptyRoot))
            }
            TrieNode::Branch(branch) => {
                let Some(nibble) = key.get(walked) else { return Err(ProofFailure::Malformed) };
                let child = branch
                    .as_ref()
                    .children()
                    .nth(usize::from(nibble))
                    .and_then(|(_, child)| child.cloned());
                let Some(child) = child else {
                    return finish_proof(key, expected, None, index + 1, proof.len())
                };
                walked += 1;
                child
            }
            TrieNode::Extension(extension) => {
                if extension.key.len() > key.len() - walked {
                    return Err(ProofFailure::Malformed)
                }
                // Canonical extensions end in branches. The upstream decoder assumes this
                // for inline children; check it explicitly, including on divergent paths.
                if extension.child.as_hash().is_none() &&
                    !matches!(decode_node(extension.child.as_slice())?, TrieNode::Branch(_))
                {
                    return Err(ProofFailure::Malformed);
                }
                if !key.slice(walked..).starts_with(&extension.key) {
                    return finish_proof(key, expected, None, index + 1, proof.len());
                }
                walked += extension.key.len();
                extension.child
            }
            TrieNode::Leaf(leaf) => {
                if leaf.key.len() > key.len() - walked {
                    return Err(ProofFailure::Malformed)
                }
                let value = (leaf.key == key.slice(walked..)).then_some(leaf.value);
                return finish_proof(key, expected, value, index + 1, proof.len());
            }
        };
        if let Some(hash) = child.as_hash() {
            index += 1;
            let Some(encoded) = proof.get(index) else {
                return Err(ProofFailure::Invalid(ProofVerificationError::ValueMismatch {
                    path: key,
                    got: Some(Bytes::copy_from_slice(child.as_slice())),
                    expected: expected.map(Bytes::from),
                }));
            };
            // Non-root nodes shorter than 32 bytes must be encoded inline in their parent.
            if encoded.len() < 32 || keccak256(encoded) != hash {
                return Err(ProofFailure::Invalid(ProofVerificationError::ValueMismatch {
                    path: key,
                    got: Some(encoded.clone()),
                    expected: Some(Bytes::from(alloy_rlp::encode(hash))),
                }));
            }
            node = decode_node(encoded)?;
        } else {
            node = decode_node(child.as_slice())?;
        }
    }
}

/// Checks that traversal ended at the claimed value and consumed exactly the supplied proof.
fn finish_proof(
    key: Nibbles,
    expected: Option<Vec<u8>>,
    got: Option<Vec<u8>>,
    consumed: usize,
    proof_len: usize,
) -> Result<(), ProofFailure> {
    if consumed == proof_len && got == expected {
        Ok(())
    } else {
        Err(ProofFailure::Invalid(ProofVerificationError::ValueMismatch {
            path: key,
            got: got.map(Bytes::from),
            expected: expected.map(Bytes::from),
        }))
    }
}

/// Decodes one complete trie node after checking the compact-path capacity and canonical padding.
/// Child references must be a 32-byte RLP string or an inline list shorter than 32 bytes.
fn decode_node(node: &[u8]) -> Result<TrieNode, ProofFailure> {
    let mut remaining = node;
    let view = Header::decode_raw(&mut remaining)?;
    if !remaining.is_empty() {
        return Err(alloy_rlp::Error::Custom("trailing trie node bytes").into())
    }
    if let PayloadView::List(ref items) = view &&
        let [mut path, _] = items[..]
    {
        let path = Header::decode_bytes(&mut path, false)?;
        if let Some((flag, rest)) = path.split_first() {
            if 2 * rest.len() + usize::from(flag & 0x10 != 0) > 64 {
                return Err(alloy_rlp::Error::Custom("trie node path longer than 64 nibbles").into());
            }
            if flag & 0x10 == 0 && flag & 0x0f != 0 {
                return Err(alloy_rlp::Error::Custom("nonzero compact path padding").into());
            }
        }
    }
    let decoded = TrieNode::decode(&mut &node[..])?;
    match &decoded {
        TrieNode::Branch(branch) => {
            for (_, child) in branch.as_ref().children() {
                if let Some(child) = child {
                    check_child(child)?;
                }
            }
        }
        TrieNode::Extension(extension) => {
            if extension.key.is_empty() {
                return Err(alloy_rlp::Error::Custom("empty extension path").into())
            }
            check_child(&extension.child)?;
        }
        TrieNode::EmptyRoot | TrieNode::Leaf(_) => {}
    }
    Ok(decoded)
}

/// Rejects child encodings that the upstream fixed-size container alone does not validate.
fn check_child(child: &RlpNode) -> Result<(), ProofFailure> {
    let bytes = child.as_slice();
    if (bytes.len() == 33 && bytes[0] == 0xa0) ||
        (bytes.len() < 32 && bytes.first().is_some_and(|byte| *byte >= 0xc0))
    {
        Ok(())
    } else {
        Err(alloy_rlp::Error::Custom("invalid trie child reference").into())
    }
}

#[cfg(test)]
#[path = "mpt_tests.rs"]
mod tests;

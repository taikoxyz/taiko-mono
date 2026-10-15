//! Authenticated calldata forced inclusion classification. No I/O.
//!
//! Each pending entry commits to at most 8192 bytes of one transaction. A canonical transaction
//! consumes its entry only at position zero, including before its delay elapses. At or after the
//! delay, invalid bytes consume the entry directly; canonical bytes absent from position zero
//! require the caller to validate a skip. This rule has no expiry and never consults the EL.

use alloy_consensus::TxEnvelope;
use alloy_eips::eip2718::{Decodable2718, Encodable2718};
use alloy_primitives::{Address, B256, Bytes, U256, keccak256};
use alloy_rlp::{RlpDecodable, RlpEncodable};

use super::ForcedError;
use crate::{
    l1::{
        layout::{inbox, word_u48, word_u64},
        mpt::verify_account_witness,
    },
    types::{AccountWitness, AnchorState},
};

/// Maximum byte length of a forced transaction committed by the Inbox.
pub const MAX_FORCED_TX_BYTES: usize = 8192;

/// One authenticated calldata queue entry decoded from two Inbox storage words.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ForcedEntry {
    /// Queue index whose two slots were authenticated.
    pub index: u64,
    /// Keccak-256 of the exact submitted transaction bytes, including invalid input.
    pub tx_hash: B256,
    /// L1 submission time in Unix seconds, stored as a `uint48`.
    pub timestamp: u64,
    /// L1 submission block number, stored as a `uint64`.
    pub l1_block: u64,
    /// Submission fee in gwei, stored as a `uint64`.
    pub fee_in_gwei: u64,
}

/// Proof and exact transaction bytes for the entry at a block's parent cursor.
///
/// RLP: `[index, entry, tx]`; this local witness does not change the active v4 envelope.
#[derive(Clone, Debug, PartialEq, Eq, RlpEncodable, RlpDecodable)]
pub struct ForcedWitness {
    /// Queue index, required to equal the parent cursor.
    pub index: u64,
    /// EIP-1186 proof of the Inbox and exactly the entry's two storage slots.
    pub entry: AccountWitness,
    /// Exact submitted bytes, required to match the proven hash and byte limit.
    pub tx: Bytes,
}

/// The pure rule's classification of one block against its authenticated queue entry.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ForcedDecision {
    /// No entry is pending, or it is not due and was not included at position zero.
    Ordinary,
    /// The canonical transaction at position zero consumes this queue index.
    Included(u64),
    /// Due bytes are not a canonical transaction, so this queue index is consumed directly.
    SkippedInvalid(u64),
    /// A due canonical transaction needs a separate authenticated skip decision.
    NeedsSkip {
        /// Pending queue index; this classification alone does not authorize consumption.
        index: u64,
        /// Exact canonical bytes whose skip the caller must validate.
        tx: Bytes,
    },
}

/// Authenticated block facts and genesis configuration needed to classify forced inclusion.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ForcedContext<'a> {
    /// Parent queue cursor: the only entry this block may consume.
    pub cursor: u64,
    /// Anchor proving the queue tail and the state root used for the entry proof.
    pub anchor: &'a AnchorState,
    /// Positive forced inclusion delay in seconds, validated by genesis configuration.
    pub delay: u64,
    /// Inbox contract address whose entry must be proven.
    pub inbox: Address,
}

/// Two storage slots of `queue[index]`: the transaction hash followed by packed metadata.
///
/// `base = keccak256(abi.encode(uint256(index), uint256(280)))`; the second slot is
/// `base + 1`, with addition wrapping in 256 bits as in Solidity.
pub fn entry_slots(index: u64) -> [B256; 2] {
    let mut preimage = [0u8; 64];
    preimage[..32].copy_from_slice(&U256::from(index).to_be_bytes::<32>());
    preimage[32..].copy_from_slice(&U256::from(inbox::FORCED_INCLUSION_QUEUE).to_be_bytes::<32>());
    let base = U256::from_be_bytes(keccak256(preimage).0);
    [base.into(), base.wrapping_add(U256::from(1)).into()]
}

/// Decodes exactly one canonical EIP-2718 transaction with no trailing bytes.
///
/// Re-encoding equality rejects alternative encodings of the same transaction. Empty, malformed
/// and network-wrapped typed input is invalid and returns `None`.
pub fn decode_canonical(bytes: &[u8]) -> Option<TxEnvelope> {
    let mut remaining = bytes;
    let tx = TxEnvelope::decode_2718(&mut remaining).ok()?;
    (remaining.is_empty() && tx.encoded_2718().as_slice() == bytes).then_some(tx)
}

/// Authenticates `index` at `inbox` under `state_root` and decodes the two storage words.
///
/// Returns [`ForcedError::Entry`] for another account, a non-exact slot set or an invalid MPT
/// proof. Metadata packs timestamp at bit 0, L1 block at bit 48 and fee in gwei at bit 112;
/// unused high bits do not contribute to any field.
pub fn verify_entry(
    state_root: B256,
    witness: &AccountWitness,
    inbox: Address,
    index: u64,
) -> Result<ForcedEntry, ForcedError> {
    if witness.address != inbox {
        return Err(ForcedError::Entry(format!(
            "witness proves {}, expected the inbox at {inbox}",
            witness.address
        )));
    }
    let slots = entry_slots(index);
    let storage = verify_account_witness(state_root, witness, &slots)
        .map_err(|e| ForcedError::Entry(e.to_string()))?;
    let [hash, metadata] =
        slots.map(|slot| storage.get(slot).expect("slot belongs to the verified slot set"));
    Ok(ForcedEntry {
        index,
        tx_hash: hash.into(),
        timestamp: word_u48(metadata, 0),
        l1_block: word_u64(metadata, 48),
        fee_in_gwei: word_u64(metadata, 112),
    })
}

/// Whether an anchor timestamp reaches the submission timestamp plus delay, in seconds.
/// Wide arithmetic prevents overflow from making an entry due prematurely.
fn is_due(timestamp: u64, delay: u64, anchor_timestamp: u64) -> bool {
    u128::from(anchor_timestamp) >= u128::from(timestamp) + u128::from(delay)
}

/// Classifies one block's forced entry after authenticating its index, proof and exact bytes.
///
/// An exhausted queue forbids a witness; a pending entry requires one. Proof, size and hash
/// failures are errors even before the entry is due. Only a canonical transaction matching
/// `first_tx` byte-for-byte counts as inclusion. Due canonical bytes absent from position zero
/// return [`ForcedDecision::NeedsSkip`], which requires further caller validation before
/// consumption. Invalid bytes cannot be skipped early; there is no expiry.
pub fn check(
    context: ForcedContext<'_>,
    witness: Option<&ForcedWitness>,
    first_tx: Option<&[u8]>,
) -> Result<ForcedDecision, ForcedError> {
    if context.cursor >= context.anchor.inbox.forced_inclusion_tail {
        return match witness {
            None => Ok(ForcedDecision::Ordinary),
            Some(_) => Err(ForcedError::UnexpectedWitness),
        };
    }
    let w = witness.ok_or(ForcedError::MissingWitness { index: context.cursor })?;
    if w.index != context.cursor {
        return Err(ForcedError::WrongIndex { expected: context.cursor, got: w.index });
    }
    let entry = verify_entry(context.anchor.state_root, &w.entry, context.inbox, context.cursor)?;
    if w.tx.len() > MAX_FORCED_TX_BYTES {
        return Err(ForcedError::TxTooLarge { size: w.tx.len(), max: MAX_FORCED_TX_BYTES });
    }
    let got = keccak256(&w.tx);
    if got != entry.tx_hash {
        return Err(ForcedError::TxHashMismatch { expected: entry.tx_hash, got });
    }
    let canonical = decode_canonical(&w.tx).is_some();
    if canonical && first_tx == Some(w.tx.as_ref()) {
        return Ok(ForcedDecision::Included(context.cursor));
    }
    if !is_due(entry.timestamp, context.delay, context.anchor.timestamp) {
        return Ok(ForcedDecision::Ordinary);
    }
    Ok(if canonical {
        ForcedDecision::NeedsSkip { index: context.cursor, tx: w.tx.clone() }
    } else {
        ForcedDecision::SkippedInvalid(context.cursor)
    })
}

#[cfg(test)]
#[path = "calldata_tests.rs"]
mod tests;

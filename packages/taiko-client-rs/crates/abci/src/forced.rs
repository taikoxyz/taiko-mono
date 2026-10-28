//! Authenticated calldata forced inclusion classification. No I/O.
//!
//! Each pending entry commits to at most 8192 bytes of one transaction. A canonical transaction
//! consumes its entry only at position zero, including before its delay elapses. At or after the
//! delay, canonically ineligible bytes consume the entry directly; eligible bytes, including
//! those with low or zero fee caps,
//! absent from position zero require the caller to validate a skip. This rule has no expiry
//! and never consults the EL.

use alloy_consensus::{Transaction, TxEnvelope, transaction::SignerRecoverable};
use alloy_eips::eip2718::{Decodable2718, Encodable2718};
use alloy_primitives::{Address, B256, Bytes, U256, keccak256};
use alloy_rlp::{Decodable, RlpEncodable};

use crate::{
    l1::{
        layout::{inbox, word_u48},
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
    /// L1 submission block number, stored as a `uint48`.
    pub l1_block: u64,
}

/// Proof and optional skip preimage for the entry at a block's parent cursor.
///
/// RLP: `[index, entry, tx]`. Empty `tx` omits the preimage for an ordinary or included block;
/// a skip authenticates `tx`, including an actually empty admission, against the proven hash.
#[derive(Clone, Debug, PartialEq, Eq, RlpEncodable)]
pub struct ForcedWitness {
    /// Queue index, required to equal the parent cursor.
    pub index: u64,
    /// EIP-1186 proof of the Inbox and exactly the entry's two storage slots.
    pub entry: AccountWitness,
    /// Skip preimage, or empty when omitted. Nonempty bytes always match the proven hash and
    /// byte limit; skips also authenticate empty bytes. Proposers omit this field's contents
    /// unless skipping, since inclusion authenticates the canonical first block transaction.
    pub tx: Bytes,
}

impl Decodable for ForcedWitness {
    /// Decodes exactly three fields, bounding borrowed transaction bytes before copying them.
    /// Empty bytes remain valid witness input for the invalid-transaction classification.
    fn decode(buf: &mut &[u8]) -> alloy_rlp::Result<Self> {
        let mut payload = alloy_rlp::Header::decode_bytes(buf, true)?;
        let payload_length = payload.len();
        let index = u64::decode(&mut payload)?;
        let entry = AccountWitness::decode(&mut payload)?;
        let tx = alloy_rlp::Header::decode_bytes(&mut payload, false)?;
        if tx.len() > MAX_FORCED_TX_BYTES {
            return Err(alloy_rlp::Error::Custom("forced transaction exceeds byte limit"));
        }
        if !payload.is_empty() {
            return Err(alloy_rlp::Error::ListLengthMismatch {
                expected: payload_length,
                got: payload_length - payload.len(),
            });
        }
        Ok(Self { index, entry, tx: Bytes::copy_from_slice(tx) })
    }
}

/// The pure rule's classification of one block against its authenticated queue entry.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum ForcedDecision {
    /// No entry is pending, or it is not due and was not included at position zero.
    Ordinary,
    /// The canonical transaction at position zero consumes this queue index.
    Included(u64),
    /// Due bytes are malformed or below the execution fee floor, consuming the index directly.
    SkippedInvalid(u64),
    /// A due canonical transaction meeting the fee floor needs an authenticated skip decision.
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
    /// Execution chain identity required by protected and typed transactions.
    pub l2_chain_id: u64,
    /// Maximum transaction gas, in execution gas units.
    pub block_gas_limit: u64,
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

/// Decodes an eligible FI transaction without consulting execution state or fees.
/// Canonical decoding enforces field widths, parity and exact re-encoding. Authorization
/// tuple signatures remain the EL's responsibility and do not affect this predicate.
pub fn decode_eligible(bytes: &[u8], l2_chain_id: u64, block_gas_limit: u64) -> Option<TxEnvelope> {
    let tx = decode_canonical(bytes)?;
    if tx.is_eip4844() || tx.gas_limit() > block_gas_limit {
        return None;
    }
    if tx.chain_id().is_some_and(|chain| chain != l2_chain_id) {
        return None;
    }
    if !tx.is_legacy() && tx.chain_id() != Some(l2_chain_id) {
        return None;
    }
    if tx.signature().normalize_s().is_some() || tx.recover_signer().is_err() {
        return None;
    }
    Some(tx)
}

/// Authenticates `index` at `inbox` under `state_root` and decodes the two storage words.
///
/// Returns [`ForcedError::Entry`] for another account, a non-exact slot set or an invalid MPT
/// proof. Metadata packs timestamp at bit 0 and L1 block at bit 48. The L1-only fee at bit 112
/// and high padding bits are authenticated with the word but do not participate in L2 rules.
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
        l1_block: word_u48(metadata, 48),
    })
}

/// Whether an anchor timestamp reaches the submission timestamp plus delay, in seconds.
/// Wide arithmetic prevents overflow from making an entry due prematurely.
pub(crate) fn is_due(timestamp: u64, delay: u64, anchor_timestamp: u64) -> bool {
    u128::from(anchor_timestamp) >= u128::from(timestamp) + u128::from(delay)
}

/// Authenticates the queue head and any supplied preimage before every acceptance branch.
/// Only an eligible matching transaction at position zero consumes an inclusion. Before due,
/// omission consumes nothing. A due ineligible preimage can be skipped directly; every eligible
/// omission requires a completed singleton build, independent of its fee cap.
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
    if !w.tx.is_empty() && got != entry.tx_hash {
        return Err(ForcedError::TxHashMismatch { expected: entry.tx_hash, got });
    }
    if first_tx.is_some_and(|tx| {
        tx.len() <= MAX_FORCED_TX_BYTES &&
            keccak256(tx) == entry.tx_hash &&
            decode_eligible(tx, context.l2_chain_id, context.block_gas_limit).is_some()
    }) {
        return Ok(ForcedDecision::Included(context.cursor));
    }
    if !is_due(entry.timestamp, context.delay, context.anchor.timestamp) {
        return Ok(ForcedDecision::Ordinary);
    }
    // Omission never proves an invalid admission: only an actual empty admission hashes to
    // empty bytes. Every nonempty due entry still needs its authenticated preimage to skip.
    if got != entry.tx_hash {
        return Err(ForcedError::TxHashMismatch { expected: entry.tx_hash, got });
    }
    Ok(if decode_eligible(&w.tx, context.l2_chain_id, context.block_gas_limit).is_some() {
        ForcedDecision::NeedsSkip { index: context.cursor, tx: w.tx.clone() }
    } else {
        ForcedDecision::SkippedInvalid(context.cursor)
    })
}

/// Why a block breaks the forced inclusion rule.
#[derive(Debug, thiserror::Error, Clone, PartialEq, Eq)]
pub enum ForcedError {
    /// The queue holds entry `index` at the cursor, but the block carries no forced witness.
    #[error("the block lacks the forced inclusion witness of pending entry {index}")]
    MissingWitness {
        /// The cursor: the pending entry the block must name.
        index: u64,
    },
    /// The cursor has reached the anchor's queue tail, yet the block carries a forced witness.
    #[error("the block carries a forced inclusion witness, but no entry is pending")]
    UnexpectedWitness,
    /// The forced witness names another entry than the cursor.
    #[error("the forced inclusion witness names entry {got}, expected the cursor {expected}")]
    WrongIndex {
        /// The cursor.
        expected: u64,
        /// The witness's index.
        got: u64,
    },
    /// The forced transaction exceeds the Inbox's maximum byte length.
    #[error("forced transaction has {size} bytes, exceeding the {max}-byte limit")]
    TxTooLarge {
        /// Actual transaction byte length.
        size: usize,
        /// Maximum permitted transaction byte length.
        max: usize,
    },
    /// The exact transaction bytes do not match the authenticated entry hash.
    #[error("transaction hash {got} differs from the entry's {expected}")]
    TxHashMismatch {
        /// Hash stored in the proven queue entry.
        expected: B256,
        /// Keccak-256 of the carried transaction bytes.
        got: B256,
    },
    /// The entry proof does not verify against the anchor (another account, a wrong slot set or
    /// an invalid proof).
    #[error("forced inclusion entry proof rejected: {0}")]
    Entry(String),
}

#[cfg(test)]
mod tests;

//! Etna forced inclusion: the per-block rule, entry proofs and the blob → transaction list
//! derivation. No I/O.
//!
//! The Inbox keeps a queue of forced inclusion entries (layout in
//! [`l1::layout::inbox`](crate::l1::layout::inbox)); the genesis record carries the delay `D`
//! after which an entry is due and every anchor proves the queue's tail. The chain tracks its own
//! cursor `c` ([`AppState::forced_cursor`](crate::store::AppState::forced_cursor)): the number of
//! entries its blocks have consumed. [`check`] judges one block against its anchor `A`:
//!
//! - `c >= tail(A)`: the block is ordinary and carries no [`ForcedWitness`];
//! - `c < tail(A)`: the block carries a witness for entry `c`, proven against `A`'s state root. A
//!   non-empty blob makes it the forced inclusion block consuming entry `c` (early or due, never
//!   expired); an empty blob consumes an expired entry as an empty block, and is otherwise a peek
//!   that proves the entry is not yet due (an ordinary block).
//!
//! [`derive_tx_list`] turns a consumed entry's blob into the EL transaction list exactly as
//! Shasta derivation reads a forced inclusion source. Its KZG commitment needs the Ethereum
//! trusted setup, which takes seconds to load: [`warm_kzg_settings`] loads it at startup.

/// Authenticated calldata forced inclusion rules for the next envelope generation.
pub mod calldata;

use alloy_eips::eip4844::{Blob, c_kzg, kzg_to_versioned_hash};
use alloy_primitives::{Address, B256, Bytes, U256};
use protocol::shasta::{BlobCoder, encode_transactions, manifest::DerivationSourceManifest};

use crate::{
    envelope::ForcedWitness,
    l1::{
        layout::{inbox, word_u32, word_u48, word_u64},
        mpt::verify_account_witness,
    },
    types::{AccountWitness, AnchorState},
};

/// Expiry `E`, in seconds (14 days): an entry whose timestamp plus `E` an anchor has reached is
/// expired. The genesis forced inclusion delay must be below it.
pub const FORCED_INCLUSION_EXPIRY_SECS: u64 = 1_209_600;

/// The most bytes a forced inclusion manifest may decompress to (1 MiB); a larger one is treated
/// like any other invalid manifest, so its entry is consumed as an empty block.
pub const FI_MAX_DECOMPRESSED_BYTES: usize = 1 << 20;

/// The EL transaction list of an empty forced inclusion block: the RLP empty list `0xc0`.
pub const EMPTY_TX_LIST: Bytes = Bytes::from_static(&[alloy_rlp::EMPTY_LIST_CODE]);

/// The `uint24` mask of an entry's `offset`.
const OFFSET_MASK: u32 = (1 << 24) - 1;

/// One forced inclusion queue entry, as proven from the Inbox's `queue[index]`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ForcedEntry {
    /// The entry's queue index.
    pub index: u64,
    /// The fee paid at submission, in gwei (`feeInGwei`).
    pub fee_in_gwei: u64,
    /// The versioned hash of the entry's single blob (`blobHashes[0]`).
    pub blob_hash: B256,
    /// Byte offset of the manifest in the blob's decoded bytes (`uint24`).
    pub offset: u32,
    /// The L1 timestamp of the submission (`uint48`).
    pub timestamp: u64,
}

/// What a forced inclusion block consumes: the entry at the cursor and the EL transaction list
/// its block is built from.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ForcedConsumption {
    /// The consumed entry's index (the parent's cursor).
    pub index: u64,
    /// The RLP list of the entry's transactions; [`EMPTY_TX_LIST`] for an expired entry or an
    /// invalid source.
    pub tx_list: Bytes,
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
    /// Entry `index` is due at the block's anchor, but the block does not consume it (a peek).
    #[error("forced inclusion entry {index} is due, so the block must consume it")]
    Due {
        /// The due entry.
        index: u64,
    },
    /// Entry `index` is expired, so its block must carry no blob.
    #[error("forced inclusion entry {index} is expired, so its block must carry no blob")]
    BlobForExpired {
        /// The expired entry.
        index: u64,
    },
    /// The carried blob's KZG versioned hash is not the entry's.
    #[error("blob versioned hash {got} differs from the entry's {expected}")]
    BlobHashMismatch {
        /// The entry's `blobHashes[0]`.
        expected: B256,
        /// The versioned hash of the carried blob.
        got: B256,
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
    /// The carried blob is not an EIP-4844 blob: not 131,072 bytes, or a field element not below
    /// the BLS modulus.
    #[error("the carried blob is not a valid EIP-4844 blob")]
    BadBlob,
    /// The entry proof does not verify against the anchor (another account, a wrong slot set or
    /// an invalid proof), or the proven entry does not hold exactly one blob hash.
    #[error("forced inclusion entry proof rejected: {0}")]
    Entry(String),
}

/// Verifies `witness` as the EIP-1186 proof of the Inbox at `inbox` and the four slots of queue
/// entry `index` ([`inbox::forced_inclusion_entry_slots`], in order) under `state_root`, and
/// decodes the entry.
///
/// Fails with [`ForcedError::Entry`] when the witness proves another account or slot set, a
/// proof does not verify, or the entry's blob-hash array does not have length one (the store
/// accepts exactly one blob per entry).
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
    let slots = inbox::forced_inclusion_entry_slots(index);
    let storage = verify_account_witness(state_root, witness, &slots)
        .map_err(|e| ForcedError::Entry(e.to_string()))?;
    let [fee, length, slice, hash] =
        slots.map(|slot| storage.get(slot).expect("slot belongs to the verified slot set"));
    if length != U256::from(1) {
        return Err(ForcedError::Entry(format!(
            "entry {index} holds {length} blob hashes, expected 1"
        )));
    }
    Ok(ForcedEntry {
        index,
        fee_in_gwei: word_u64(fee, 0),
        blob_hash: hash.into(),
        offset: word_u32(slice, 0) & OFFSET_MASK,
        timestamp: word_u48(slice, 24),
    })
}

/// Whether `entry` is due at an anchor with timestamp `anchor_timestamp`:
/// `anchor_timestamp >= entry.timestamp + delay` (inclusive). The caller checks that the entry is
/// below the anchor's tail.
pub fn is_due(entry: &ForcedEntry, anchor_timestamp: u64, delay: u64) -> bool {
    anchor_timestamp >= entry.timestamp.saturating_add(delay)
}

/// Whether `entry` is expired at an anchor with timestamp `anchor_timestamp`:
/// `anchor_timestamp >= entry.timestamp + `[`FORCED_INCLUSION_EXPIRY_SECS`] (inclusive).
pub fn is_expired(entry: &ForcedEntry, anchor_timestamp: u64) -> bool {
    is_due(entry, anchor_timestamp, FORCED_INCLUSION_EXPIRY_SECS)
}

/// The EL transaction list of the forced inclusion block consuming `entry` with the raw blob
/// `blob`.
///
/// The blob must be a valid EIP-4844 blob ([`ForcedError::BadBlob`]) whose KZG versioned hash is
/// the entry's ([`ForcedError::BlobHashMismatch`]). Its bytes are then read as Shasta derivation
/// reads a forced inclusion source: [`BlobCoder`] decoding, then the manifest at `entry.offset`
/// (version word, size word, zlib inflated to at most [`FI_MAX_DECOMPRESSED_BYTES`], exact RLP,
/// engine-encodable transactions, at most one block). A manifest of exactly one block gives the
/// RLP list of its transactions (its other fields are ignored); anything else, including a blob
/// the coder cannot decode, gives [`EMPTY_TX_LIST`].
pub fn derive_tx_list(entry: &ForcedEntry, blob: &[u8]) -> Result<Bytes, ForcedError> {
    let blob = <&Blob>::try_from(blob).map_err(|_| ForcedError::BadBlob)?;
    let got = versioned_hash(blob)?;
    if got != entry.blob_hash {
        return Err(ForcedError::BlobHashMismatch { expected: entry.blob_hash, got });
    }
    let Some(bytes) = BlobCoder::decode_blob(blob) else {
        return Ok(EMPTY_TX_LIST);
    };
    let manifest = DerivationSourceManifest::decompress_and_decode_with_limits(
        &bytes,
        entry.offset as usize,
        1,
        FI_MAX_DECOMPRESSED_BYTES,
    );
    Ok(match manifest.as_ref().map(|m| m.blocks.as_slice()) {
        Ok([block]) => encode_transactions(&block.transactions),
        _ => EMPTY_TX_LIST,
    })
}

/// The forced inclusion rule for a block with parent cursor `cursor`, anchor `anchor`, genesis
/// delay `delay`, Inbox `inbox` and optional forced `witness`.
///
/// With `tail = anchor.inbox.forced_inclusion_tail`:
///
/// - `cursor >= tail`: the block is ordinary (`Ok(None)`); a witness is
///   [`ForcedError::UnexpectedWitness`].
/// - `cursor < tail`: a witness is required ([`ForcedError::MissingWitness`]), must name `cursor`
///   ([`ForcedError::WrongIndex`]) and must prove the entry under `anchor.state_root`
///   ([`verify_entry`]). Then:
///   - a non-empty blob consumes the entry with [`derive_tx_list`]'s list, unless the entry is
///     expired ([`ForcedError::BlobForExpired`]);
///   - an empty blob consumes an expired entry with [`EMPTY_TX_LIST`]; for a due entry it is
///     [`ForcedError::Due`]; otherwise it is a peek and the block is ordinary (`Ok(None)`).
pub fn check(
    cursor: u64,
    anchor: &AnchorState,
    delay: u64,
    inbox: Address,
    witness: Option<&ForcedWitness>,
) -> Result<Option<ForcedConsumption>, ForcedError> {
    if cursor >= anchor.inbox.forced_inclusion_tail {
        return match witness {
            None => Ok(None),
            Some(_) => Err(ForcedError::UnexpectedWitness),
        };
    }
    let w = witness.ok_or(ForcedError::MissingWitness { index: cursor })?;
    if w.index != cursor {
        return Err(ForcedError::WrongIndex { expected: cursor, got: w.index });
    }
    let entry = verify_entry(anchor.state_root, &w.entry, inbox, cursor)?;
    let expired = is_expired(&entry, anchor.timestamp);
    let tx_list = match (w.blob.is_empty(), expired) {
        (false, true) => return Err(ForcedError::BlobForExpired { index: cursor }),
        (false, false) => derive_tx_list(&entry, &w.blob)?,
        (true, true) => EMPTY_TX_LIST,
        (true, false) if is_due(&entry, anchor.timestamp, delay) => {
            return Err(ForcedError::Due { index: cursor });
        }
        (true, false) => return Ok(None),
    };
    Ok(Some(ForcedConsumption { index: cursor, tx_list }))
}

/// Loads the Ethereum KZG trusted setup [`derive_tx_list`] commits blobs under, unless loaded
/// already (the setup is process-wide and shared with `rpc::blob`).
///
/// The first load takes seconds of CPU, so call it once at startup, off the async runtime
/// (e.g. on `spawn_blocking`), before serving: no consensus handler then pays it.
pub fn warm_kzg_settings() {
    kzg_settings();
}

/// The Ethereum KZG trusted setup without precomputation: commitments do not use it, and
/// alloy's default (precomputation 8) would add about 96 MiB.
fn kzg_settings() -> &'static c_kzg::KzgSettings {
    c_kzg::ethereum_kzg_settings(0)
}

/// The KZG versioned hash of `blob` under the Ethereum trusted setup.
///
/// The 128 KiB `c_kzg::Blob` lives on the heap: handlers run on async worker stacks.
fn versioned_hash(blob: &Blob) -> Result<B256, ForcedError> {
    let mut kzg_blob = Box::<c_kzg::Blob>::default();
    kzg_blob.copy_from_slice(blob.as_slice());
    let commitment =
        kzg_settings().blob_to_kzg_commitment(&kzg_blob).map_err(|_| ForcedError::BadBlob)?;
    Ok(kzg_to_versioned_hash(commitment.as_slice()))
}

#[cfg(test)]
mod tests;

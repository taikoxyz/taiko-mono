//! SSZ container definitions and conversions for preconfirmation gossip and req/resp payloads.
//!
//! This module mirrors the wire-format structures from the specification (see
//! `docs/specification.md`) and provides helpers for bridging between SSZ types and alloy
//! primitives.

use alloy_primitives::{Address, B256, U256};
use ssz_rs::prelude::{List, SimpleSerialize, U256 as SSZU256, Vector, *};

use crate::constants::{MAX_COMMITMENTS_PER_RESPONSE, MAX_TXLIST_BYTES};

// ---------- SSZ aliases ----------

/// 20-byte fixed vector used for Ethereum addresses.
pub type Bytes20 = Vector<u8, 20>;
/// 32-byte fixed vector used for cryptographic hashes (e.g., Keccak-256).
pub type Bytes32 = Vector<u8, 32>;
/// 65-byte fixed vector used for secp256k1 signatures, including recovery ID (r,s,v).
pub type Bytes65 = Vector<u8, 65>;
/// Variable-length raw transaction list bytes, capped by `MAX_TXLIST_BYTES`.
pub type TxListBytes = List<u8, MAX_TXLIST_BYTES>;
/// List of `SignedCommitment`s, capped by `MAX_COMMITMENTS_PER_RESPONSE`.
pub type CommitmentList = List<SignedCommitment, MAX_COMMITMENTS_PER_RESPONSE>;
/// SSZ 256-bit unsigned integer alias, compatible with `alloy_primitives::U256`.
pub type Uint256 = SSZU256;

// ---------- Core containers (spec §3) ----------

/// Core preconfirmation data structure (spec §3.1).
#[derive(Debug, Clone, PartialEq, Eq, Default, SimpleSerialize)]
pub struct Preconfirmation {
    /// Whether the preconfirmation marks end-of-proposal.
    pub eop: bool,
    /// L1 block number referenced by the preconfirmation.
    pub block_number: Uint256,
    /// Timestamp for the preconfirmation window.
    pub timestamp: Uint256,
    /// Suggested gas limit for the window.
    pub gas_limit: Uint256,
    /// Coinbase for fee attribution.
    pub coinbase: Bytes20,
    /// Anchor block number for the raw tx list.
    pub anchor_block_number: Uint256,
    /// Hash of the associated raw tx list.
    pub raw_tx_list_hash: Bytes32,
    /// Parent preconfirmation hash to link commitment chain.
    pub parent_preconfirmation_hash: Bytes32,
    /// Submission window end timestamp.
    pub submission_window_end: Uint256,
    /// Prover authorization address.
    pub prover_auth: Bytes20,
    /// Proposal identifier from the sequencer.
    pub proposal_id: Uint256,
}

/// Represents a commitment to a `Preconfirmation` (spec §3.2).
#[derive(Debug, Clone, PartialEq, Eq, Default, SimpleSerialize)]
pub struct PreconfCommitment {
    /// The preconfirmation body being committed to.
    pub preconf: Preconfirmation,
    /// Address permitted to slash in case of fraud related to this commitment.
    pub slasher_address: Bytes20,
}

/// Represents a `PreconfCommitment` signed by a sequencer (spec §3.3).
/// The signature covers the SSZ serialization of the `PreconfCommitment`.
#[derive(Debug, Clone, PartialEq, Eq, Default, SimpleSerialize)]
pub struct SignedCommitment {
    /// The commitment payload.
    pub commitment: PreconfCommitment,
    /// The secp256k1 signature over the SSZ-serialized `commitment`.
    pub signature: Bytes65, // secp256k1 signature over SSZ(commitment)
}

/// Represents a raw transaction list gossip message (spec §3.4).
#[allow(clippy::collapsible_if)]
#[derive(Debug, Clone, PartialEq, Eq, Default, SimpleSerialize)]
pub struct RawTxListGossip {
    /// Hash of the raw tx list payload.
    pub raw_tx_list_hash: Bytes32,
    /// Raw RLP-encoded tx list bytes.
    pub txlist: TxListBytes, // raw RLP(tx list)
}

// ---------- Req/Resp (spec §10, §11) ----------

/// Represents the current head of preconfirmations, used in `get_head` response (spec §10.2).
#[derive(Debug, Clone, PartialEq, Eq, Default, SimpleSerialize)]
pub struct PreconfHead {
    /// The block number of the current preconfirmation head.
    pub block_number: Uint256,
    /// The submission window end timestamp of the current preconfirmation head.
    pub submission_window_end: Uint256,
}

/// Empty container used as the request body for `get_head` req/resp (spec §10.1).
///
/// Kept as an SSZ container with a zero-capacity list to satisfy SSZ shape requirements
/// while carrying no data.
#[allow(clippy::collapsible_if)]
#[derive(Debug, Clone, PartialEq, Eq, Default, SimpleSerialize)]
pub struct GetHeadRequest {
    /// Reserved for future extensions; always empty.
    pub reserved: List<u8, 0>,
}

/// Request for commitments by block number (spec §10.1).
#[derive(Debug, Clone, PartialEq, Eq, Default, SimpleSerialize)]
pub struct GetCommitmentsByNumberRequest {
    /// Starting block number from which to request commitments.
    pub start_block_number: Uint256,
    /// Maximum number of commitments to return.
    pub max_count: u32,
}

/// Response for commitments by block number (spec §10.2).
#[allow(clippy::collapsible_if)]
#[derive(Debug, Clone, PartialEq, Eq, Default, SimpleSerialize)]
pub struct GetCommitmentsByNumberResponse {
    /// List of commitments in the requested range.
    pub commitments: CommitmentList,
}

/// Request for a raw transaction list by hash (spec §11.2).
#[derive(Debug, Clone, PartialEq, Eq, Default, SimpleSerialize)]
pub struct GetRawTxListRequest {
    /// Hash of the raw transaction list being requested.
    pub raw_tx_list_hash: Bytes32,
}

/// Response for a raw transaction list (spec §11.3).
#[allow(clippy::collapsible_if)]
#[derive(Debug, Clone, PartialEq, Eq, Default, SimpleSerialize)]
pub struct GetRawTxListResponse {
    /// Hash of the raw transaction list payload.
    pub raw_tx_list_hash: Bytes32,
    /// Raw RLP-encoded transaction list bytes.
    pub txlist: TxListBytes,
}

// ---------- Convenience conversions between alloy U256 and SSZ Uint256 ----------

/// Convert an `alloy_primitives::U256` into the SSZ `Uint256` wrapper.
///
/// # Arguments
///
/// * `value` - The `U256` value to convert.
///
/// # Returns
///
/// The corresponding SSZ `Uint256` value.
pub fn u256_to_uint256(value: U256) -> Uint256 {
    Uint256::from_bytes_le(value.to_le_bytes())
}

/// Convert an SSZ `Uint256` back to `alloy_primitives::U256`.
///
/// # Arguments
///
/// * `value` - A reference to the SSZ `Uint256` value to convert.
///
/// # Returns
///
/// The corresponding `alloy_primitives::U256` value.
pub fn uint256_to_u256(value: &Uint256) -> U256 {
    let bytes = value.to_bytes_le();
    let mut buf = [0u8; 32];
    buf.copy_from_slice(&bytes);
    U256::from_le_bytes(buf)
}

// ---------- Helpers for address/hash bridging ----------

/// Convert an Ethereum `Address` into an SSZ fixed `Bytes20`.
///
/// # Arguments
///
/// * `addr` - The `Address` to convert.
///
/// # Returns
///
/// The corresponding SSZ `Bytes20` value.
pub fn address_to_bytes20(addr: Address) -> Bytes20 {
    Vector::try_from(addr.0.to_vec()).expect("addr length 20")
}

/// Convert a `B256` hash into an SSZ fixed `Bytes32`.
///
/// # Arguments
///
/// * `value` - The `B256` hash to convert.
///
/// # Returns
///
/// The corresponding SSZ `Bytes32` value.
pub fn b256_to_bytes32(value: B256) -> Bytes32 {
    Vector::try_from(value.to_vec()).expect("hash length 32")
}

/// Convert an SSZ `Bytes32` hash back into a `B256`.
///
/// # Arguments
///
/// * `value` - A reference to the SSZ `Bytes32` hash to convert.
///
/// # Returns
///
/// The corresponding `B256` hash.
pub fn bytes32_to_b256(value: &Bytes32) -> B256 {
    B256::from_slice(value.as_ref())
}

// ---------- Tests ----------

#[cfg(test)]
mod tests {
    use super::*;

    /// Construct a deterministic preconfirmation used across tests.
    fn sample_preconf() -> Preconfirmation {
        Preconfirmation {
            eop: false,
            block_number: Uint256::from(1u64),
            timestamp: Uint256::from(2u64),
            gas_limit: Uint256::from(3u64),
            coinbase: Vector::try_from(vec![0u8; 20]).unwrap(),
            anchor_block_number: Uint256::from(4u64),
            raw_tx_list_hash: Vector::try_from(vec![1u8; 32]).unwrap(),
            parent_preconfirmation_hash: Vector::try_from(vec![2u8; 32]).unwrap(),
            submission_window_end: Uint256::from(5u64),
            prover_auth: Vector::try_from(vec![3u8; 20]).unwrap(),
            proposal_id: Uint256::from(6u64),
        }
    }

    /// SSZ roundtrip for `Preconfirmation` preserves all fields.
    #[test]
    fn ssz_roundtrip_preconf() {
        let preconf = sample_preconf();
        let bytes = ssz_rs::serialize(&preconf).unwrap();
        let decoded = Preconfirmation::deserialize(&bytes).unwrap();
        assert_eq!(preconf, decoded);
    }

    /// SSZ roundtrip for `SignedCommitment` preserves commitment and signature.
    #[test]
    fn ssz_roundtrip_signed_commitment() {
        let commit = PreconfCommitment {
            preconf: sample_preconf(),
            slasher_address: Vector::try_from(vec![9u8; 20]).unwrap(),
        };
        let signed = SignedCommitment {
            commitment: commit,
            signature: Vector::try_from(vec![0xAAu8; 65]).unwrap(),
        };
        let bytes = ssz_rs::serialize(&signed).unwrap();
        let decoded = SignedCommitment::deserialize(&bytes).unwrap();
        assert_eq!(signed, decoded);
    }

    /// Txlist container allows a payload exactly at the configured size cap.
    #[test]
    fn txlist_size_cap_allows_equal_limit() {
        let txlist = TxListBytes::try_from(vec![0u8; MAX_TXLIST_BYTES]).unwrap();
        let msg =
            RawTxListGossip { raw_tx_list_hash: Vector::try_from(vec![5u8; 32]).unwrap(), txlist };
        let bytes = ssz_rs::serialize(&msg).unwrap();
        let decoded = RawTxListGossip::deserialize(&bytes).unwrap();
        assert_eq!(msg, decoded);
    }
}

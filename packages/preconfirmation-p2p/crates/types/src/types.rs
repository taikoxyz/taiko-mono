use alloy_primitives::{Address, B256, U256};
use ssz_rs::prelude::{List, SimpleSerialize, U256 as SSZU256, Vector, *};

use crate::constants::{MAX_COMMITMENTS_PER_RESPONSE, MAX_TXLIST_BYTES};

// ---------- SSZ aliases ----------

/// 20-byte fixed vector used for addresses.
pub type Bytes20 = Vector<u8, 20>;
/// 32-byte fixed vector used for hashes.
pub type Bytes32 = Vector<u8, 32>;
/// 65-byte fixed vector used for secp256k1 signatures (r,s,v).
pub type Bytes65 = Vector<u8, 65>;
/// Variable-length txlist bytes capped by `MAX_TXLIST_BYTES`.
pub type TxListBytes = List<u8, MAX_TXLIST_BYTES>;
/// List of commitments capped by `MAX_COMMITMENTS_PER_RESPONSE`.
pub type CommitmentList = List<SignedCommitment, MAX_COMMITMENTS_PER_RESPONSE>;
/// SSZ 256-bit integer alias.
pub type Uint256 = SSZU256;

// ---------- Core containers (spec §3) ----------

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

#[derive(Debug, Clone, PartialEq, Eq, Default, SimpleSerialize)]
pub struct PreconfCommitment {
    /// The preconfirmation body being committed to.
    pub preconf: Preconfirmation,
    /// Address permitted to slash in case of fraud.
    pub slasher_address: Bytes20,
}

#[derive(Debug, Clone, PartialEq, Eq, Default, SimpleSerialize)]
pub struct SignedCommitment {
    /// Commitment payload.
    pub commitment: PreconfCommitment,
    /// secp256k1 signature over SSZ(commitment).
    pub signature: Bytes65, // secp256k1 signature over SSZ(commitment)
}

#[allow(clippy::collapsible_if)]
#[derive(Debug, Clone, PartialEq, Eq, Default, SimpleSerialize)]
pub struct RawTxListGossip {
    /// Hash of the raw tx list payload.
    pub raw_tx_list_hash: Bytes32,
    /// Anchor block number tied to the tx list.
    pub anchor_block_number: Uint256,
    /// Compressed RLP-encoded tx list bytes.
    pub txlist: TxListBytes, // compressed RLP(tx list)
}

// ---------- Req/Resp (spec §11, §12) ----------

#[derive(Debug, Clone, PartialEq, Eq, Default, SimpleSerialize)]
pub struct PreconfHead {
    pub block_number: Uint256,
    pub submission_window_end: Uint256,
}

/// Empty container used as the request body for `get_head` req/resp. Kept as an SSZ container
/// with a zero-capacity list to satisfy SSZ shape requirements while carrying no data.
#[allow(clippy::collapsible_if)]
#[derive(Debug, Clone, PartialEq, Eq, Default, SimpleSerialize)]
pub struct GetHeadRequest {
    /// Reserved for future extensions; always empty.
    pub reserved: List<u8, 0>,
}

#[derive(Debug, Clone, PartialEq, Eq, Default, SimpleSerialize)]
pub struct GetCommitmentsByNumberRequest {
    /// Starting block number to request commitments from.
    pub start_block_number: Uint256,
    /// Maximum number of commitments to return.
    pub max_count: u32,
}

#[allow(clippy::collapsible_if)]
#[derive(Debug, Clone, PartialEq, Eq, Default, SimpleSerialize)]
pub struct GetCommitmentsByNumberResponse {
    /// List of commitments in the requested range.
    pub commitments: CommitmentList,
}

#[derive(Debug, Clone, PartialEq, Eq, Default, SimpleSerialize)]
pub struct GetRawTxListRequest {
    /// Hash of the raw tx list being requested.
    pub raw_tx_list_hash: Bytes32,
}

#[allow(clippy::collapsible_if)]
#[derive(Debug, Clone, PartialEq, Eq, Default, SimpleSerialize)]
pub struct GetRawTxListResponse {
    pub raw_tx_list_hash: Bytes32,
    pub anchor_block_number: Uint256,
    pub txlist: TxListBytes,
}

// ---------- Convenience conversions between alloy U256 and SSZ Uint256 ----------

/// Convert an `alloy_primitives::U256` into the SSZ `Uint256` wrapper.
pub fn u256_to_uint256(value: U256) -> Uint256 {
    Uint256::from_bytes_le(value.to_le_bytes())
}

/// Convert an SSZ `Uint256` back to `alloy_primitives::U256`.
pub fn uint256_to_u256(value: &Uint256) -> U256 {
    let bytes = value.to_bytes_le();
    let mut buf = [0u8; 32];
    buf.copy_from_slice(&bytes);
    U256::from_le_bytes(buf)
}

// ---------- Helpers for address/hash bridging ----------

/// Convert an Ethereum address into an SSZ fixed `Bytes20`.
pub fn address_to_bytes20(addr: Address) -> Bytes20 {
    Vector::try_from(addr.0.to_vec()).expect("addr length 20")
}

/// Convert a `B256` hash into an SSZ fixed `Bytes32`.
pub fn b256_to_bytes32(value: B256) -> Bytes32 {
    Vector::try_from(value.to_vec()).expect("hash length 32")
}

/// Convert an SSZ `Bytes32` hash back into a `B256`.
pub fn bytes32_to_b256(value: &Bytes32) -> B256 {
    B256::from_slice(value.as_ref())
}

// ---------- Tests ----------

#[cfg(test)]
mod tests {
    use super::*;

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

    #[test]
    fn ssz_roundtrip_preconf() {
        let preconf = sample_preconf();
        let bytes = ssz_rs::serialize(&preconf).unwrap();
        let decoded = Preconfirmation::deserialize(&bytes).unwrap();
        assert_eq!(preconf, decoded);
    }

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

    #[test]
    fn txlist_size_cap_allows_equal_limit() {
        let txlist = TxListBytes::try_from(vec![0u8; MAX_TXLIST_BYTES]).unwrap();
        let msg = RawTxListGossip {
            raw_tx_list_hash: Vector::try_from(vec![5u8; 32]).unwrap(),
            anchor_block_number: Uint256::from(10u64),
            txlist,
        };
        let bytes = ssz_rs::serialize(&msg).unwrap();
        let decoded = RawTxListGossip::deserialize(&bytes).unwrap();
        assert_eq!(msg, decoded);
    }
}

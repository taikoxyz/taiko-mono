//! Shasta payload helper utilities.

use alloy::{
    primitives::{B256, Bytes, U256, keccak256},
    sol_types::{SolValue, sol},
};
use alloy_consensus::TxEnvelope;
use alloy_rlp::{BytesMut, encode_list};
use alloy_rpc_types_engine::PayloadId;

/// Engine API `engine_getPayloadV2` discriminator.
///
/// The 8-byte payload identifier prepends this version byte to match the Execution API spec.
pub const PAYLOAD_ID_VERSION_V2: u8 = 2;

sol! {
    struct ShastaDifficultyInput {
        bytes32 parentDifficulty;
        uint256 blockNumber;
    }
}

/// Calculate the Shasta difficulty for a new block based on the parent difficulty (randao digest)
/// and block number.
pub fn calculate_shasta_difficulty(parent_difficulty: B256, block_number: u64) -> B256 {
    let params = ShastaDifficultyInput {
        parentDifficulty: parent_difficulty,
        blockNumber: U256::from(block_number),
    };
    B256::from(keccak256(params.abi_encode()))
}

/// Encode the extra data field for a Shasta block header.
///
/// The first byte contains the basefee sharing percentage, followed by a 6-byte
/// big-endian proposal id.
pub fn encode_extra_data(basefee_sharing_pctg: u8, proposal_id: u64) -> Bytes {
    let mut data = [0u8; 7];
    data[0] = basefee_sharing_pctg;
    let proposal_bytes = proposal_id.to_be_bytes();
    data[1..7].copy_from_slice(&proposal_bytes[2..8]);
    Bytes::from(data.to_vec())
}

/// Encode a list of transactions into the format expected by the execution engine.
pub fn encode_transactions(transactions: &[TxEnvelope]) -> Bytes {
    let mut buf = BytesMut::new();
    encode_list(transactions, &mut buf);
    Bytes::from(buf.freeze())
}

/// Encode a list of raw transaction bytes into the format expected by the execution engine.
pub fn encode_tx_list(transactions: &[Bytes]) -> Bytes {
    let mut buf = BytesMut::new();
    encode_list::<Bytes, [u8]>(transactions, &mut buf);
    Bytes::from(buf.freeze())
}

/// Convert a `PayloadId` into an array of bytes.
pub fn payload_id_to_bytes(payload_id: PayloadId) -> [u8; 8] {
    payload_id.0.0
}

use alloy::{
    primitives::{B256, Bytes, U256, keccak256},
    sol_types::{SolValue, sol},
};
use alloy_consensus::TxEnvelope;
use alloy_rlp::{BytesMut, encode_list};
use alloy_rpc_types::eth::Withdrawal;
use sha2::{Digest, Sha256};

sol! {
    struct ShastaDifficultyInput {
        bytes32 parentDifficulty;
        uint256 blockNumber;
    }
}

/// Calculate the Shasta difficulty for a new block based on the parent difficulty (randao digest)
/// and block number.
pub(super) fn calculate_shasta_difficulty(parent_difficulty: B256, block_number: u64) -> B256 {
    let params = ShastaDifficultyInput {
        parentDifficulty: parent_difficulty,
        blockNumber: U256::from(block_number),
    };
    B256::from(keccak256(params.abi_encode()))
}

/// Encode a list of transactions into the format expected by the execution engine.
pub(super) fn encode_transactions(transactions: &[TxEnvelope]) -> Bytes {
    let mut buf = BytesMut::new();
    encode_list(transactions, &mut buf);
    Bytes::from(buf.freeze())
}

/// Engine API `engine_getPayloadV2` discriminator.
///
/// The 8-byte payload identifier prepends this version byte to match the Execution API spec.
const PAYLOAD_ID_VERSION_V2: u8 = 2;

/// Compute the payload identifier used when interacting with the execution engine.
pub(super) fn compute_build_payload_args_id(
    parent_hash: B256,
    timestamp: u64,
    random: B256,
    fee_recipient: alloy::primitives::Address,
    withdrawals: &[Withdrawal],
    tx_list: &Bytes,
) -> [u8; 8] {
    let mut hasher = Sha256::new();
    hasher.update(parent_hash.as_slice());
    hasher.update(timestamp.to_be_bytes());
    hasher.update(random.as_slice());
    hasher.update(fee_recipient.as_slice());

    let mut withdrawals_buf = BytesMut::new();
    encode_list(withdrawals, &mut withdrawals_buf);
    let withdrawals_bytes = withdrawals_buf.freeze();
    hasher.update(withdrawals_bytes.as_ref());

    let tx_list_hash = keccak256(tx_list);
    hasher.update(tx_list_hash.as_slice());

    let mut id = [0u8; 8];
    let digest = hasher.finalize();
    id.copy_from_slice(&digest[..8]);
    id[0] = PAYLOAD_ID_VERSION_V2;
    id
}

use alloy::{
    primitives::{B256, Bytes, U256, keccak256},
    sol_types::{SolValue, sol},
};
use alloy_consensus::TxEnvelope;
use alloy_rlp::{BytesMut, encode_list};

use bindings::taiko_anchor::LibBonds::BondInstruction;

sol! {
    struct ShastaDifficultyInput {
        bytes32 parentDifficulty;
        uint256 blockNumber;
    }
}

// Calculate the Shasta difficulty for a new block based on the parent randao and block number.
pub(super) fn calculate_shasta_difficulty(parent_randao: B256, block_number: u64) -> B256 {
    let params = ShastaDifficultyInput {
        parentDifficulty: parent_randao,
        blockNumber: U256::from(block_number),
    };
    B256::from(keccak256(params.abi_encode()))
}

// Encode a list of transactions into the format expected by the execution engine.
pub(super) fn encode_transactions(transactions: &[TxEnvelope]) -> Bytes {
    let mut buf = BytesMut::new();
    encode_list(transactions, &mut buf);
    Bytes::from(buf.freeze())
}

// Encode the extra data field for a Shasta block header.
pub(super) fn encode_extra_data(basefee_sharing_pctg: u8, is_low_bond_proposal: bool) -> Bytes {
    let mut data = Vec::with_capacity(2);
    data.push(basefee_sharing_pctg);
    data.push(u8::from(is_low_bond_proposal));
    Bytes::from(data)
}

/// Calculate the rolling bond instruction hash for a new instruction.
pub(super) fn calculate_bond_instruction_hash(
    previous_hash: B256,
    instruction: &BondInstruction,
) -> B256 {
    if instruction.proposalId.to::<u64>() == 0 || instruction.bondType == 0 {
        return previous_hash;
    }

    let encoded = instruction.abi_encode();
    let mut data = Vec::with_capacity(previous_hash.as_slice().len() + encoded.len());
    data.extend_from_slice(previous_hash.as_slice());
    data.extend_from_slice(&encoded);

    B256::from_slice(keccak256(&data).as_slice())
}

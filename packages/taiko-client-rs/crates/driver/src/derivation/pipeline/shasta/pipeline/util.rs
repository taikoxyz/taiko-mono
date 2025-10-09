use alethia_reth_consensus::validation::ANCHOR_V3_GAS_LIMIT;
use alloy::primitives::{B256, Bytes, U256, keccak256};
use alloy_consensus::{Transaction, TxEnvelope};
use alloy_rlp::{BytesMut, encode_list};
use alloy_sol_types::{SolValue, sol};

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

// Estimate the gas used by a set of transactions, capping it to the provided gas limit
pub(super) fn estimate_gas_used(transactions: &[TxEnvelope], gas_limit: u64) -> u64 {
    let used: u128 = transactions.iter().fold(0u128, |acc, tx| acc + tx.gas_limit() as u128);
    let capped = used.min(gas_limit as u128);
    capped.max(ANCHOR_V3_GAS_LIMIT.min(gas_limit) as u128).min(gas_limit as u128) as u64
}

// Encode a list of transactions into the format expected by the execution engine.
pub(super) fn encode_transactions(transactions: &[TxEnvelope]) -> Bytes {
    let mut buf = BytesMut::new();
    encode_list(transactions, &mut buf);
    Bytes::from(buf.freeze())
}

// Encode the extra data field for a Shasta block header.
pub(super) fn encode_extra_data(
    basefee_sharing_pctg: u8,
    is_low_bond_proposal: bool,
    bond_hash: B256,
) -> Bytes {
    let mut data = Vec::with_capacity(2 + bond_hash.as_slice().len());
    data.push(basefee_sharing_pctg);
    data.push(u8::from(is_low_bond_proposal));
    data.extend_from_slice(bond_hash.as_slice());
    Bytes::from(data)
}

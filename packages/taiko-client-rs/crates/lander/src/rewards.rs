//! Canonical L2 reward receipts and checked host accounting over authenticated execution headers.
//!
//! Header multiplication is a host implementation pending the real EL fee identity checks. A
//! future guest must authenticate each transaction's actual charges by reexecution.

use crate::{LanderError, Result};
use alloy::sol_types::SolValue;
use alloy_consensus::Header;
use alloy_primitives::{B256, U256, keccak256};

alloy::sol! {
    /// Exact field order and Solidity types of `LibEtnaRewards.Receipt`.
    #[derive(Debug, PartialEq, Eq)]
    #[sol(all_derives)]
    struct Receipt {
        /// L1 chain authenticating the Inbox receipt.
        uint256 l1ChainId;
        /// L2 execution chain that pays the reward.
        uint64 l2ChainId;
        /// Fixed L1 Inbox proxy address.
        address inbox;
        /// Inbox recovery generation.
        uint64 generation;
        /// Exclusive beginning of the batch range.
        uint64 parentHeight;
        /// Execution block hash at the beginning of the range.
        bytes32 parentHash;
        /// Inclusive end of the batch range.
        uint64 lastHeight;
        /// Execution block hash at the end of the range.
        bytes32 lastBlockHash;
        /// Nonzero L2 payout address.
        address l2RewardRecipient;
        /// Total execution base fees in wei.
        uint256 baseFeeAmount;
    }
}

/// Encode an ASCII domain in Solidity's right-padded `bytes32` representation.
fn domain(value: &[u8]) -> B256 {
    let mut word = [0; 32];
    word[..value.len()].copy_from_slice(value);
    B256::from(word)
}

/// Identify a batch by its chain, Inbox, recovery generation and execution endpoints.
pub fn batch_id(receipt: &Receipt) -> B256 {
    keccak256(
        (
            domain(b"ETNA_L2_REWARD_BATCH_V1"),
            receipt.l1ChainId,
            receipt.l2ChainId,
            receipt.inbox,
            receipt.generation,
            receipt.parentHeight,
            receipt.parentHash,
            receipt.lastHeight,
            receipt.lastBlockHash,
        )
            .abi_encode(),
    )
}

/// Commit the batch identity, L2 recipient and exact amount, including zero amounts.
pub fn commitment(receipt: &Receipt) -> B256 {
    keccak256(
        (
            domain(b"ETNA_L2_REWARD_RECEIPT_V1"),
            batch_id(receipt),
            receipt.l2RewardRecipient,
            receipt.baseFeeAmount,
        )
            .abi_encode(),
    )
}

/// Compute the Inbox mapping slot of a batch receipt, whose mapping base slot is 283.
pub fn receipt_slot(id: B256) -> B256 {
    keccak256((id, U256::from(283)).abi_encode())
}

/// Sum base fee times gas used over already authenticated headers, rejecting missing base fees
/// and arithmetic overflow. This host formula still requires the Task10 real EL fee identity
/// acceptance; a future guest must authenticate transaction charges by reexecution.
pub fn basefee_sum(headers: &[Header]) -> Result<U256> {
    headers.iter().try_fold(U256::ZERO, |sum, header| {
        let fee = header
            .base_fee_per_gas
            .ok_or_else(|| LanderError::Safety("Etna header has no base fee".into()))?;
        let amount = U256::from(fee)
            .checked_mul(U256::from(header.gas_used))
            .ok_or_else(|| LanderError::Safety("base fee multiplication overflow".into()))?;
        sum.checked_add(amount)
            .ok_or_else(|| LanderError::Safety("batch base fee sum overflow".into()))
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::vectors;
    alloy::sol!(Vault, "tests/fixtures/contracts/L2FeeVault.json");

    fn vector() -> Receipt {
        let p = |s: &str| format!("/land_statement/inputs/{s}");
        Receipt {
            l1ChainId: vectors::u256_at(&p("l1_chain_id")),
            l2ChainId: vectors::u64_at(&p("l2_chain_id")),
            inbox: vectors::address_at(&p("inbox")),
            generation: vectors::u64_at(&p("generation")),
            parentHeight: vectors::u64_at(&p("parent_height")),
            parentHash: vectors::b256_at(&p("parent_hash")),
            lastHeight: vectors::u64_at(&p("last_height")),
            lastBlockHash: vectors::b256_at(&p("last_block_hash")),
            l2RewardRecipient: vectors::address_at(&p("l2_reward_recipient")),
            baseFeeAmount: vectors::u256_at(&p("base_fee_amount")),
        }
    }

    #[test]
    fn receipt_matches_independent_cast_vectors() {
        let receipt = vector();
        assert_eq!(receipt.abi_encode().len(), 320);
        assert_eq!(batch_id(&receipt), vectors::b256_at("/reward_receipt/batch_id"));
        assert_eq!(commitment(&receipt), vectors::b256_at("/reward_receipt/commitment"));
        assert_eq!(receipt_slot(batch_id(&receipt)), vectors::b256_at("/reward_receipt/slot"));
        let mut changed = receipt.clone();
        changed.l2RewardRecipient = alloy_primitives::Address::ZERO;
        assert_eq!(batch_id(&changed), batch_id(&receipt));
        assert_ne!(commitment(&changed), commitment(&receipt));
        changed = receipt.clone();
        changed.baseFeeAmount = U256::ZERO;
        assert_eq!(batch_id(&changed), batch_id(&receipt));
        assert_ne!(commitment(&changed), commitment(&receipt));
        assert_eq!(commitment(&changed), vectors::b256_at("/zero_fee/reward_receipt/commitment"));
    }

    #[test]
    fn checked_header_fees_sum_in_wei_and_require_base_fee() {
        let headers = [
            Header { base_fee_per_gas: Some(7), gas_used: 11, ..Default::default() },
            Header { base_fee_per_gas: Some(13), gas_used: 17, ..Default::default() },
        ];
        assert_eq!(basefee_sum(&headers).unwrap(), U256::from(298));
        assert_eq!(basefee_sum(&[]).unwrap(), U256::ZERO);
        assert_eq!(
            basefee_sum(&[Header {
                base_fee_per_gas: Some(0),
                gas_used: u64::MAX,
                ..Default::default()
            }])
            .unwrap(),
            U256::ZERO
        );
        assert!(matches!(basefee_sum(&[Header::default()]), Err(LanderError::Safety(_))));
        assert_eq!(
            basefee_sum(&[Header {
                base_fee_per_gas: Some(u64::MAX),
                gas_used: u64::MAX,
                ..Default::default()
            }])
            .unwrap(),
            U256::from(u64::MAX) * U256::from(u64::MAX)
        );
    }

    #[test]
    fn claim_abi_matches_actual_generated_vault_artifact() {
        use alloy::sol_types::SolCall;
        assert_eq!(Vault::claimCall::SELECTOR, vectors::bytes_at("/claim_selector").as_ref());
        let call = Vault::claimCall {
            _receipt: LibEtnaRewards::Receipt::abi_decode(&vector().abi_encode()).unwrap(),
            _anchorTimestamp: U256::from(1),
            _accountProof: vec![],
            _storageProof: vec![],
        };
        assert_eq!(
            Vault::claimCall::abi_decode(&call.abi_encode()).unwrap()._receipt.abi_encode(),
            vector().abi_encode()
        );
    }
}

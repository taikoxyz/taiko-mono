//! Shared test fixtures for driver unit tests.
#![cfg(test)]

use alethia_reth_primitives::payload::attributes::{
    RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes,
};
use alloy::primitives::{Address, B256, Bytes, U256};
use alloy_rpc_types_engine_2::PayloadAttributes as EthPayloadAttributes;

/// Canonical preconf payload fixture used across sync and production tests.
///
/// Moved verbatim from the duplicate definitions that previously lived in the
/// `sync::event` and `production::path` test modules. Returns a
/// [`TaikoPayloadAttributes`]; call sites wrap it in `PreconfPayload::new(..)`
/// (and `Arc::new(..)`) as needed.
pub(crate) fn sample_payload(block_number: u64) -> TaikoPayloadAttributes {
    let payload_attributes = EthPayloadAttributes {
        timestamp: 0,
        prev_randao: B256::ZERO,
        suggested_fee_recipient: Address::ZERO,
        withdrawals: Some(Vec::new()),
        parent_beacon_block_root: None,
        slot_number: None,
    };
    let block_metadata = TaikoBlockMetadata {
        beneficiary: Address::ZERO,
        gas_limit: 0,
        timestamp: U256::ZERO,
        mix_hash: B256::ZERO,
        tx_list: Some(Bytes::new()),
        extra_data: Bytes::new(),
    };
    let l1_origin = RpcL1Origin {
        block_id: U256::from(block_number),
        l2_block_hash: B256::ZERO,
        l1_block_height: None,
        l1_block_hash: None,
        build_payload_args_id: [0u8; 8],
        is_forced_inclusion: false,
        signature: [0u8; 65],
    };

    TaikoPayloadAttributes {
        payload_attributes,
        base_fee_per_gas: U256::ZERO,
        block_metadata,
        l1_origin,
        anchor_transaction: None,
    }
}

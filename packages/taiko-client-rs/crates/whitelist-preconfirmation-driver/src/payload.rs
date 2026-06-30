//! Shared construction of driver payload attributes for preconfirmation blocks.

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_primitives::{B256, Bytes};
use alloy_rpc_types_engine::ExecutionPayloadV1;
use protocol::shasta::{PayloadAttributesInput, build_payload_attributes_with_id};

/// Build the [`TaikoPayloadAttributes`] submitted to the driver for a preconfirmation block.
///
/// `tx_list` carries the already-decompressed transaction list bytes; the L1 origin
/// `signature` is zeroed for local builds and carries the sequencer signature for
/// P2P imports.
pub(crate) fn build_driver_payload(
    execution_payload: &ExecutionPayloadV1,
    tx_list: Vec<u8>,
    parent_beacon_block_root: Option<B256>,
    is_forced_inclusion: bool,
    signature: [u8; 65],
) -> TaikoPayloadAttributes {
    build_payload_attributes_with_id(
        PayloadAttributesInput {
            beneficiary: execution_payload.fee_recipient,
            timestamp: execution_payload.timestamp,
            mix_hash: execution_payload.prev_randao,
            gas_limit: execution_payload.gas_limit,
            tx_list: Some(Bytes::from(tx_list)),
            extra_data: execution_payload.extra_data.clone(),
            base_fee_per_gas: execution_payload.base_fee_per_gas,
            block_number: execution_payload.block_number,
            l1_block_height: None,
            l1_block_hash: None,
            is_forced_inclusion,
            signature,
            parent_beacon_block_root,
            anchor_transaction: None,
        },
        &execution_payload.parent_hash,
    )
}

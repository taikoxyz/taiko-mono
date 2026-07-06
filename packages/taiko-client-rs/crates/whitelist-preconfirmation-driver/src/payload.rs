//! Shared construction of driver payload attributes and wire payloads for
//! preconfirmation blocks.

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_primitives::{B256, Bytes, U256};
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

/// Build the wire [`ExecutionPayloadV1`] view of an executed L2 block header.
///
/// `base_fee_per_gas` is caller-resolved because the header field is optional, and
/// `transactions` carries the single compressed tx-list entry used on the wire.
pub(crate) fn execution_payload_from_header(
    header: &alloy_rpc_types::Header,
    base_fee_per_gas: u64,
    transactions: Vec<Bytes>,
) -> ExecutionPayloadV1 {
    ExecutionPayloadV1 {
        parent_hash: header.parent_hash,
        fee_recipient: header.beneficiary,
        state_root: header.state_root,
        receipts_root: header.receipts_root,
        logs_bloom: header.logs_bloom,
        prev_randao: header.mix_hash,
        block_number: header.number,
        gas_limit: header.gas_limit,
        gas_used: header.gas_used,
        timestamp: header.timestamp,
        extra_data: header.extra_data.clone(),
        base_fee_per_gas: U256::from(base_fee_per_gas),
        block_hash: header.hash,
        transactions,
    }
}

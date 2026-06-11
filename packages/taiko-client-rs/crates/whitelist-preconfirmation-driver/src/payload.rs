//! Shared construction of driver payload attributes for preconfirmation blocks.

use alethia_reth_primitives::payload::{
    attributes::{RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes},
    builder::payload_id_taiko,
};
use alloy_primitives::{B256, Bytes, U256};
use alloy_rpc_types_engine::ExecutionPayloadV1;
use alloy_rpc_types_engine_2::PayloadAttributes as EthPayloadAttributes;
use protocol::shasta::{PAYLOAD_ID_VERSION_V2, payload_id_to_bytes};

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
    let block_metadata = TaikoBlockMetadata {
        beneficiary: execution_payload.fee_recipient,
        gas_limit: execution_payload.gas_limit,
        timestamp: U256::from(execution_payload.timestamp),
        mix_hash: execution_payload.prev_randao,
        tx_list: Some(Bytes::from(tx_list)),
        extra_data: execution_payload.extra_data.clone(),
    };

    let payload_attributes = EthPayloadAttributes {
        timestamp: execution_payload.timestamp,
        prev_randao: execution_payload.prev_randao,
        suggested_fee_recipient: execution_payload.fee_recipient,
        withdrawals: Some(Vec::new()),
        parent_beacon_block_root,
        slot_number: None,
    };

    let mut payload = TaikoPayloadAttributes {
        payload_attributes,
        base_fee_per_gas: execution_payload.base_fee_per_gas,
        block_metadata,
        l1_origin: RpcL1Origin {
            block_id: U256::from(execution_payload.block_number),
            l2_block_hash: B256::ZERO,
            l1_block_height: None,
            l1_block_hash: None,
            build_payload_args_id: [0u8; 8],
            is_forced_inclusion,
            signature,
        },
        anchor_transaction: None,
    };

    let payload_id =
        payload_id_taiko(&execution_payload.parent_hash, &payload, PAYLOAD_ID_VERSION_V2);
    payload.l1_origin.build_payload_args_id = payload_id_to_bytes(payload_id);
    payload
}

//! Shared driver-payload construction for the whitelist preconfirmation paths.
//!
//! Both the P2P ingress path (`importer::payload`) and the REST
//! `build_preconf_block` path (`api::service::payload_build`) need to produce
//! the same `TaikoPayloadAttributes` shape from slightly different inputs.
//! This module owns the construction so the two paths cannot drift.

use alethia_reth_primitives::payload::{
    attributes::{RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes},
    builder::payload_id_taiko,
};
use alloy_primitives::{Address, B256, Bytes, U256};
use alloy_rpc_types_engine_2::PayloadAttributes as EthPayloadAttributes;
use protocol::shasta::{PAYLOAD_ID_VERSION_V2, payload_id_to_bytes};

/// Inputs to `build_driver_payload`, unified across the ingress and API call sites.
pub(crate) struct DriverPayloadInputs<'a> {
    /// Parent block hash used for the payload-id domain and L1 origin tracking.
    pub(crate) parent_hash: B256,
    /// L2 block number this payload will produce.
    pub(crate) block_number: u64,
    /// Block fee recipient (also used as `beneficiary` in block metadata).
    pub(crate) fee_recipient: Address,
    /// Gas limit for the produced block.
    pub(crate) gas_limit: u64,
    /// Block timestamp (seconds).
    pub(crate) timestamp: u64,
    /// `prev_randao` / `mix_hash` for the block.
    pub(crate) prev_randao: B256,
    /// Extra data field carried into block metadata.
    pub(crate) extra_data: &'a Bytes,
    /// Base fee per gas as a U256 (already converted from u64 if needed).
    pub(crate) base_fee_per_gas: U256,
    /// Fully decompressed transaction list bytes.
    pub(crate) tx_list: Bytes,
    /// 65-byte signature stored in the L1 origin.
    pub(crate) signature: [u8; 65],
    /// Parent beacon block root, when known (ingress path only).
    pub(crate) parent_beacon_block_root: Option<B256>,
    /// Forced-inclusion marker carried in L1 origin.
    pub(crate) is_forced_inclusion: bool,
}

/// Build the driver payload attributes from the shared input set.
///
/// Constructs `TaikoBlockMetadata`, `EthPayloadAttributes`, and `RpcL1Origin`
/// identically for both ingress and API paths, then derives and assigns
/// `build_payload_args_id` via `payload_id_taiko`.
pub(crate) fn build_driver_payload(inputs: DriverPayloadInputs<'_>) -> TaikoPayloadAttributes {
    let DriverPayloadInputs {
        parent_hash,
        block_number,
        fee_recipient,
        gas_limit,
        timestamp,
        prev_randao,
        extra_data,
        base_fee_per_gas,
        tx_list,
        signature,
        parent_beacon_block_root,
        is_forced_inclusion,
    } = inputs;

    let block_metadata = TaikoBlockMetadata {
        beneficiary: fee_recipient,
        gas_limit,
        timestamp: U256::from(timestamp),
        mix_hash: prev_randao,
        tx_list: Some(tx_list),
        extra_data: extra_data.clone(),
    };

    let payload_attributes = EthPayloadAttributes {
        timestamp,
        prev_randao,
        suggested_fee_recipient: fee_recipient,
        withdrawals: Some(Vec::new()),
        parent_beacon_block_root,
        slot_number: None,
    };

    let l1_origin = RpcL1Origin {
        block_id: U256::from(block_number),
        l2_block_hash: B256::ZERO,
        l1_block_height: None,
        l1_block_hash: None,
        build_payload_args_id: [0u8; 8],
        is_forced_inclusion,
        signature,
    };

    let mut payload = TaikoPayloadAttributes {
        payload_attributes,
        base_fee_per_gas,
        block_metadata,
        l1_origin,
        anchor_transaction: None,
    };

    let payload_id = payload_id_taiko(&parent_hash, &payload, PAYLOAD_ID_VERSION_V2);
    payload.l1_origin.build_payload_args_id = payload_id_to_bytes(payload_id);
    payload
}

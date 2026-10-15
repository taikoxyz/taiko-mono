//! Shared construction of driver payload attributes and wire payloads for
//! preconfirmation blocks.

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_primitives::{B256, Bytes, U256};
use alloy_rpc_types_engine::ExecutionPayloadV1;
use protocol::shasta::{PayloadAttributesInput, build_payload_attributes_with_id};

use crate::codec::WhitelistExecutionPayloadEnvelope;

/// Build the [`TaikoPayloadAttributes`] submitted to the driver for a preconfirmation block.
///
/// `tx_list` carries the already-decompressed transaction list bytes; the L1 origin
/// `signature` is zeroed for local builds and carries the sequencer signature for
/// P2P imports. `parent_beacon_block_root` is the request's or envelope's root: an Etna block's
/// nonzero root is sent as is, and an absent one (pre-Etna REST requests that omit it, and P2P
/// envelopes whose zero root decodes to `None`) is sent as `Some(B256::ZERO)`, the root every
/// pre-Etna `engine_forkchoiceUpdatedV3` build requires.
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
            parent_beacon_block_root: Some(parent_beacon_block_root.unwrap_or_default()),
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

/// Build the signed wire envelope of an executed L2 block from its header, so a receiver can
/// rebuild the block hash byte for byte.
///
/// The payload is [`execution_payload_from_header`] over the single `compressed_tx_list` entry.
/// A zero `parent_beacon_block_root` is carried as `None` (both encode as the same 32 zero bytes
/// on the wire), and the header difficulty (the block's zk gas) only when it is nonzero.
pub(crate) fn signed_envelope_from_header(
    header: &alloy_rpc_types::Header,
    base_fee_per_gas: u64,
    compressed_tx_list: Bytes,
    parent_beacon_block_root: Option<B256>,
    end_of_sequencing: Option<bool>,
    is_forced_inclusion: Option<bool>,
    signature: [u8; 65],
) -> WhitelistExecutionPayloadEnvelope {
    WhitelistExecutionPayloadEnvelope {
        end_of_sequencing,
        is_forced_inclusion,
        parent_beacon_block_root: parent_beacon_block_root.filter(|root| !root.is_zero()),
        header_difficulty: (!header.difficulty.is_zero()).then_some(header.difficulty),
        execution_payload: execution_payload_from_header(
            header,
            base_fee_per_gas,
            vec![compressed_tx_list],
        ),
        signature: Some(signature),
    }
}

#[cfg(test)]
mod tests {
    use alloy_primitives::{Address, Bloom};

    use super::*;

    fn sample_execution_payload() -> ExecutionPayloadV1 {
        ExecutionPayloadV1 {
            parent_hash: B256::from([0x01u8; 32]),
            fee_recipient: Address::from([0x11u8; 20]),
            state_root: B256::from([0x02u8; 32]),
            receipts_root: B256::from([0x03u8; 32]),
            logs_bloom: Bloom::default(),
            prev_randao: B256::from([0x04u8; 32]),
            block_number: 42,
            gas_limit: 30_000_000,
            gas_used: 21000,
            timestamp: 1_735_000_000,
            extra_data: Bytes::from(vec![0x32, 0, 0, 0, 0, 0, 7]),
            base_fee_per_gas: U256::from(1_000_000_000u64),
            block_hash: B256::from([0x05u8; 32]),
            transactions: vec![],
        }
    }

    /// A REST build (no root) and a P2P import (zero envelope roots decode to `None`, but a
    /// peer may also send an explicit zero) both send the zero root every pre-Etna FCUv3
    /// requires, and bind the same payload fingerprint.
    #[test]
    fn driver_payload_sends_a_zero_root_for_rest_and_p2p_builds() {
        let payload = sample_execution_payload();
        let rest = build_driver_payload(&payload, vec![0xc0], None, false, [0u8; 65]);
        let p2p = build_driver_payload(&payload, vec![0xc0], Some(B256::ZERO), false, [0u8; 65]);

        assert_eq!(rest.payload_attributes.parent_beacon_block_root, Some(B256::ZERO));
        assert_eq!(p2p.payload_attributes.parent_beacon_block_root, Some(B256::ZERO));
        assert_eq!(rest.l1_origin.build_payload_args_id, p2p.l1_origin.build_payload_args_id);
    }

    /// The same Etna block built from a REST request (whose payload view zeroes the hash and
    /// post-execution fields) and imported from a P2P envelope (which carries them) sends the
    /// request's root, passes the gas limit through, and binds the same payload fingerprint,
    /// which differs from the zero-root one.
    #[test]
    fn driver_payload_binds_the_etna_root_identically_for_rest_and_p2p_builds() {
        let root = B256::from([0x5au8; 32]);
        let mut p2p_payload = sample_execution_payload();
        p2p_payload.extra_data = Bytes::from(vec![0x32u8; 13]);
        let rest_payload = ExecutionPayloadV1 {
            state_root: B256::ZERO,
            receipts_root: B256::ZERO,
            gas_used: 0,
            block_hash: B256::ZERO,
            ..p2p_payload.clone()
        };

        let rest = build_driver_payload(&rest_payload, vec![0xc0], Some(root), false, [0u8; 65]);
        let p2p = build_driver_payload(&p2p_payload, vec![0xc0], Some(root), false, [0x22u8; 65]);
        let zero_root = build_driver_payload(&p2p_payload, vec![0xc0], None, false, [0x22u8; 65]);

        assert_eq!(rest.payload_attributes.parent_beacon_block_root, Some(root));
        assert_eq!(p2p.payload_attributes.parent_beacon_block_root, Some(root));
        assert_eq!(rest.block_metadata.gas_limit, p2p_payload.gas_limit);
        assert_eq!(rest.l1_origin.build_payload_args_id, p2p.l1_origin.build_payload_args_id);
        assert_ne!(p2p.l1_origin.build_payload_args_id, zero_root.l1_origin.build_payload_args_id);
    }
}

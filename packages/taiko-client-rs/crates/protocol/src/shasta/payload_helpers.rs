//! Shasta payload helper utilities.

use alethia_reth_primitives::payload::{
    attributes::{RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes},
    builder::payload_id_taiko,
};
use alloy::{
    primitives::{Address, B256, Bytes, U256, keccak256},
    sol_types::SolValue,
};
use alloy_consensus::{Header, TxEnvelope};
use alloy_rlp::{BytesMut, encode_list};
use alloy_rpc_types_engine_2::{PayloadAttributes as EthPayloadAttributes, PayloadId};

/// Engine API `engine_getPayloadV2` discriminator.
///
/// The 8-byte payload identifier prepends this version byte to match the Execution API spec.
const PAYLOAD_ID_VERSION_V2: u8 = 2;

alloy::sol! {
    struct ShastaMixHashInput {
        bytes32 parentMixHash;
        uint256 blockNumber;
    }
}

/// Calculate the Shasta mix hash for a new block based on the parent mix hash (randao digest)
/// and block number.
pub fn calculate_shasta_mix_hash(parent_mix_hash: B256, block_number: u64) -> B256 {
    let params = ShastaMixHashInput {
        parentMixHash: parent_mix_hash,
        blockNumber: U256::from(block_number),
    };
    B256::from(keccak256(params.abi_encode()))
}

/// Encode the extra data field for a Shasta block header.
///
/// The first byte contains the basefee sharing percentage, followed by a 6-byte
/// big-endian proposal id.
pub fn encode_extra_data(basefee_sharing_pctg: u8, proposal_id: u64) -> Bytes {
    let mut data = [0u8; 7];
    data[0] = basefee_sharing_pctg;
    let proposal_bytes = proposal_id.to_be_bytes();
    data[1..7].copy_from_slice(&proposal_bytes[2..8]);
    Bytes::from(data.to_vec())
}

/// Compare the execution-header fields that [`build_payload_attributes`] derives from
/// [`TaikoPayloadAttributes`] against an observed header.
///
/// Returns the name of the first mismatching field, or `None` when the header matches the
/// attributes. This is the single source of truth for "would these attributes produce this
/// header"; callers layer context-specific checks (L1 origin records, anchor transactions,
/// fork-specific header fields) on top.
pub fn payload_core_mismatch(
    header: &Header,
    expected_block_number: u64,
    attrs: &TaikoPayloadAttributes,
) -> Option<&'static str> {
    if header.number != expected_block_number {
        return Some("block number");
    }
    if header.beneficiary != attrs.payload_attributes.suggested_fee_recipient {
        return Some("coinbase");
    }
    if header.mix_hash != attrs.payload_attributes.prev_randao {
        return Some("mix hash");
    }
    if header.gas_limit != attrs.block_metadata.gas_limit {
        return Some("gas limit");
    }
    if header.timestamp != attrs.payload_attributes.timestamp {
        return Some("timestamp");
    }
    if header.extra_data != attrs.block_metadata.extra_data {
        return Some("extra data");
    }
    match header.base_fee_per_gas {
        Some(base_fee) if U256::from(base_fee) == attrs.base_fee_per_gas => None,
        _ => Some("base fee"),
    }
}

/// Encode a list of transactions into the format expected by the execution engine.
pub fn encode_transactions(transactions: &[TxEnvelope]) -> Bytes {
    let mut buf = BytesMut::new();
    encode_list(transactions, &mut buf);
    Bytes::from(buf.freeze())
}

/// Convert a `PayloadId` into an array of bytes.
fn payload_id_to_bytes(payload_id: PayloadId) -> [u8; 8] {
    payload_id.0.0
}

/// Per-block fields for assembling [`TaikoPayloadAttributes`] for a Shasta block.
///
/// [`build_payload_attributes`] owns the invariants shared by every construction site:
/// `prev_randao` mirrors the mix hash, the suggested fee recipient mirrors the beneficiary,
/// the timestamp is carried both as `u64` and `U256`, withdrawals are present-but-empty,
/// and the L1 origin starts with a zeroed `l2_block_hash` and `build_payload_args_id`.
#[derive(Debug, Clone)]
pub struct PayloadAttributesInput {
    /// Block beneficiary, mirrored into the engine's suggested fee recipient.
    pub beneficiary: Address,
    /// Block timestamp in seconds.
    pub timestamp: u64,
    /// Shasta mix hash, mirrored into the engine's `prev_randao`.
    pub mix_hash: B256,
    /// Block gas limit.
    pub gas_limit: u64,
    /// Encoded transaction list, or `None` to let the engine build from its mempool.
    pub tx_list: Option<Bytes>,
    /// Encoded extra data carrying the basefee sharing percentage and proposal id.
    pub extra_data: Bytes,
    /// Base fee per gas for the block.
    pub base_fee_per_gas: U256,
    /// L2 block number recorded as the L1 origin block id.
    pub block_number: u64,
    /// Emitting L1 block number, when the block derives from an L1 proposal.
    pub l1_block_height: Option<U256>,
    /// Emitting L1 block hash, when the block derives from an L1 proposal.
    pub l1_block_hash: Option<B256>,
    /// Whether the block stems from a forced-inclusion source.
    pub is_forced_inclusion: bool,
    /// Sequencer signature carried by P2P imports; zeroed for local builds.
    pub signature: [u8; 65],
    /// Parent beacon block root forwarded to the engine.
    pub parent_beacon_block_root: Option<B256>,
    /// Encoded anchor transaction injected by engine-mode proposing.
    pub anchor_transaction: Option<Bytes>,
}

/// Assemble [`TaikoPayloadAttributes`] from per-block fields, leaving
/// `build_payload_args_id` zeroed.
pub fn build_payload_attributes(input: PayloadAttributesInput) -> TaikoPayloadAttributes {
    let PayloadAttributesInput {
        beneficiary,
        timestamp,
        mix_hash,
        gas_limit,
        tx_list,
        extra_data,
        base_fee_per_gas,
        block_number,
        l1_block_height,
        l1_block_hash,
        is_forced_inclusion,
        signature,
        parent_beacon_block_root,
        anchor_transaction,
    } = input;

    TaikoPayloadAttributes {
        payload_attributes: EthPayloadAttributes {
            timestamp,
            prev_randao: mix_hash,
            suggested_fee_recipient: beneficiary,
            withdrawals: Some(Vec::new()),
            parent_beacon_block_root,
            slot_number: None,
        },
        base_fee_per_gas,
        block_metadata: TaikoBlockMetadata {
            beneficiary,
            gas_limit,
            timestamp: U256::from(timestamp),
            mix_hash,
            tx_list,
            extra_data,
        },
        l1_origin: RpcL1Origin {
            block_id: U256::from(block_number),
            l2_block_hash: B256::ZERO,
            l1_block_height,
            l1_block_hash,
            build_payload_args_id: [0u8; 8],
            is_forced_inclusion,
            signature,
        },
        anchor_transaction,
    }
}

/// Assemble [`TaikoPayloadAttributes`] and stamp `build_payload_args_id` from the parent hash.
pub fn build_payload_attributes_with_id(
    input: PayloadAttributesInput,
    parent_hash: &B256,
) -> TaikoPayloadAttributes {
    let mut payload = build_payload_attributes(input);
    let payload_id = payload_id_taiko(parent_hash, &payload, PAYLOAD_ID_VERSION_V2);
    payload.l1_origin.build_payload_args_id = payload_id_to_bytes(payload_id);
    payload
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::primitives::address;

    /// Build a matching (header, attributes) pair sharing the same core field values.
    fn matching_header_and_attrs() -> (Header, TaikoPayloadAttributes, u64) {
        let block_number = 42u64;
        let attrs = build_payload_attributes(PayloadAttributesInput {
            beneficiary: address!("00000000000000000000000000000000000000aa"),
            timestamp: 1_700_000_000,
            mix_hash: B256::from([0x11; 32]),
            gas_limit: 30_000_000,
            tx_list: None,
            extra_data: encode_extra_data(75, 7),
            base_fee_per_gas: U256::from(1_000_000u64),
            block_number,
            l1_block_height: None,
            l1_block_hash: None,
            is_forced_inclusion: false,
            signature: [0; 65],
            parent_beacon_block_root: None,
            anchor_transaction: None,
        });
        let header = Header {
            number: block_number,
            beneficiary: attrs.payload_attributes.suggested_fee_recipient,
            mix_hash: attrs.payload_attributes.prev_randao,
            gas_limit: attrs.block_metadata.gas_limit,
            timestamp: attrs.payload_attributes.timestamp,
            extra_data: attrs.block_metadata.extra_data.clone(),
            base_fee_per_gas: Some(1_000_000),
            ..Default::default()
        };
        (header, attrs, block_number)
    }

    #[test]
    fn payload_core_mismatch_accepts_matching_header() {
        let (header, attrs, block_number) = matching_header_and_attrs();
        assert_eq!(payload_core_mismatch(&header, block_number, &attrs), None);
    }

    #[test]
    fn payload_core_mismatch_reports_first_divergent_field() {
        let (header, attrs, block_number) = matching_header_and_attrs();

        assert_eq!(payload_core_mismatch(&header, block_number + 1, &attrs), Some("block number"));

        let mut tweaked = header.clone();
        tweaked.beneficiary = Address::ZERO;
        assert_eq!(payload_core_mismatch(&tweaked, block_number, &attrs), Some("coinbase"));

        let mut tweaked = header.clone();
        tweaked.mix_hash = B256::ZERO;
        assert_eq!(payload_core_mismatch(&tweaked, block_number, &attrs), Some("mix hash"));

        let mut tweaked = header.clone();
        tweaked.gas_limit += 1;
        assert_eq!(payload_core_mismatch(&tweaked, block_number, &attrs), Some("gas limit"));

        let mut tweaked = header.clone();
        tweaked.timestamp += 1;
        assert_eq!(payload_core_mismatch(&tweaked, block_number, &attrs), Some("timestamp"));

        let mut tweaked = header.clone();
        tweaked.extra_data = Bytes::from_static(&[0xde, 0xad]);
        assert_eq!(payload_core_mismatch(&tweaked, block_number, &attrs), Some("extra data"));

        let mut tweaked = header.clone();
        tweaked.base_fee_per_gas = Some(999_999);
        assert_eq!(payload_core_mismatch(&tweaked, block_number, &attrs), Some("base fee"));

        let mut tweaked = header;
        tweaked.base_fee_per_gas = None;
        assert_eq!(payload_core_mismatch(&tweaked, block_number, &attrs), Some("base fee"));
    }
}

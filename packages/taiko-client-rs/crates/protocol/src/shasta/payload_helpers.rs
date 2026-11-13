//! Shasta payload helper utilities.

use alethia_reth_primitives::{
    ETNA_EXTRA_DATA_LEN, SHASTA_EXTRA_DATA_LEN,
    payload::attributes::{RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes},
};
use alloy::{
    primitives::{Address, B256, Bytes, U256, keccak256},
    sol_types::SolValue,
};
use alloy_consensus::TxEnvelope;
use alloy_rlp::{BytesMut, encode_list};
use alloy_rpc_types_engine::PayloadAttributes as EthPayloadAttributes;

use crate::shasta::error::{ProtocolError, Result};

/// Largest value a 6-byte big-endian `uint48` `extraData` field can carry.
const UINT48_MAX: u64 = (1 << 48) - 1;

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

/// Encode the 13-byte `extraData` of a non-genesis Etna block header:
/// `[basefeeSharingPctg | generation(6) | anchorBlockNumber(6)]`, both numbers big-endian
/// `uint48` (Etna spec 3.2).
///
/// The first 7 bytes keep the pre-Etna `[basefeeSharingPctg | proposalId]` layout: the 6-byte
/// slot that holds the proposal id before Etna holds the recovery generation from Etna on. A
/// `generation` or `anchor_block_number` above `uint48` is an error.
pub fn encode_etna_extra_data(
    basefee_sharing_pctg: u8,
    generation: u64,
    anchor_block_number: u64,
) -> Result<Bytes> {
    let mut data = [0u8; ETNA_EXTRA_DATA_LEN];
    data[0] = basefee_sharing_pctg;
    data[1..SHASTA_EXTRA_DATA_LEN].copy_from_slice(&uint48_be_bytes("generation", generation)?);
    data[SHASTA_EXTRA_DATA_LEN..]
        .copy_from_slice(&uint48_be_bytes("anchor_block_number", anchor_block_number)?);
    Ok(Bytes::from(data.to_vec()))
}

/// Encode `value` as a 6-byte big-endian `uint48`, naming `field` when it does not fit.
fn uint48_be_bytes(field: &'static str, value: u64) -> Result<[u8; 6]> {
    if value > UINT48_MAX {
        return Err(ProtocolError::EtnaExtraDataFieldOverflow { field, value });
    }

    let mut bytes = [0u8; 6];
    bytes.copy_from_slice(&value.to_be_bytes()[2..]);
    Ok(bytes)
}

/// Encode a list of transactions into the format expected by the execution engine.
pub fn encode_transactions(transactions: &[TxEnvelope]) -> Bytes {
    let mut buf = BytesMut::new();
    encode_list(transactions, &mut buf);
    Bytes::from(buf.freeze())
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
    /// Header `extraData`: the 13-byte Etna layout ([`encode_etna_extra_data`]).
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
            target_gas_limit: None,
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
        max_block_bytes: None,
    }
}

#[cfg(test)]
mod tests {
    use super::{UINT48_MAX, encode_etna_extra_data};
    use crate::shasta::ProtocolError;
    use alethia_reth_primitives::decode_shasta_proposal_id;
    use alloy::primitives::hex;

    /// `[pctg | generation(6) | anchorBlockNumber(6)]`, both numbers big-endian `uint48`.
    #[test]
    fn etna_extra_data_encodes_the_13_byte_layout() {
        let extra_data = encode_etna_extra_data(50, 7, 123_456).expect("fields fit uint48");

        assert_eq!(extra_data.as_ref(), hex!("3200000000000700000001e240"));
        assert_eq!(extra_data.len(), 13);
        assert_eq!(decode_shasta_proposal_id(&extra_data), Some(7));
        assert_eq!(&extra_data[7..13], hex!("00000001e240"));
    }

    #[test]
    fn etna_extra_data_round_trips_the_largest_uint48_values() {
        let extra_data =
            encode_etna_extra_data(u8::MAX, UINT48_MAX, UINT48_MAX).expect("max uint48 fits");

        assert_eq!(extra_data.as_ref(), hex!("ffffffffffffffffffffffffff"));
        assert_eq!(decode_shasta_proposal_id(&extra_data), Some(UINT48_MAX));
    }

    #[test]
    fn etna_extra_data_rejects_fields_beyond_uint48() {
        assert!(matches!(
            encode_etna_extra_data(50, UINT48_MAX + 1, 1),
            Err(ProtocolError::EtnaExtraDataFieldOverflow { field: "generation", value })
                if value == UINT48_MAX + 1
        ));
        assert!(matches!(
            encode_etna_extra_data(50, 1, UINT48_MAX + 1),
            Err(ProtocolError::EtnaExtraDataFieldOverflow { field: "anchor_block_number", value })
                if value == UINT48_MAX + 1
        ));
    }
}

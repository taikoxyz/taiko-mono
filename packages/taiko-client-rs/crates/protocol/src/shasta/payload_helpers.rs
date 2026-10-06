//! Shasta payload helper utilities.

use alethia_reth_primitives::{
    ETNA_EXTRA_DATA_LEN, SHASTA_EXTRA_DATA_LEN,
    payload::{
        attributes::{RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes},
        builder::{PAYLOAD_ID_VERSION_V2, payload_id_taiko},
    },
};
use alloy::{
    primitives::{Address, B256, Bytes, U256, keccak256},
    sol_types::SolValue,
};
use alloy_consensus::TxEnvelope;
use alloy_rlp::{BytesMut, encode_list};
use alloy_rpc_types_engine_2::{PayloadAttributes as EthPayloadAttributes, PayloadId};

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

/// Encode the 7-byte `extraData` of a pre-Etna (Shasta or Unzen) block header.
///
/// The first byte contains the basefee sharing percentage, followed by a 6-byte
/// big-endian proposal id. An Etna block uses the 13-byte [`encode_etna_extra_data`] instead,
/// which appends the anchor block number to this layout.
pub fn encode_extra_data(basefee_sharing_pctg: u8, proposal_id: u64) -> Bytes {
    let mut data = [0u8; 7];
    data[0] = basefee_sharing_pctg;
    let proposal_bytes = proposal_id.to_be_bytes();
    data[1..7].copy_from_slice(&proposal_bytes[2..8]);
    Bytes::from(data.to_vec())
}

/// Encode the 13-byte `extraData` of a non-genesis Etna block header:
/// `[basefeeSharingPctg | proposalId(6) | anchorBlockNumber(6)]`, both numbers big-endian
/// `uint48`.
///
/// The first 7 bytes equal [`encode_extra_data`]'s pre-Etna layout, so proposal-id readers work
/// for both forks. A `proposal_id` or `anchor_block_number` above `uint48` is an error.
pub fn encode_etna_extra_data(
    basefee_sharing_pctg: u8,
    proposal_id: u64,
    anchor_block_number: u64,
) -> Result<Bytes> {
    let mut data = [0u8; ETNA_EXTRA_DATA_LEN];
    data[0] = basefee_sharing_pctg;
    data[1..SHASTA_EXTRA_DATA_LEN].copy_from_slice(&uint48_be_bytes("proposal_id", proposal_id)?);
    data[SHASTA_EXTRA_DATA_LEN..]
        .copy_from_slice(&uint48_be_bytes("anchor_block_number", anchor_block_number)?);
    Ok(Bytes::from(data.to_vec()))
}

/// Decode the anchor block number of an existing Etna block from its header `extraData`.
///
/// The L2 genesis block (`block_number == 0`) anchors to L1 block 0 whatever its bytes are.
/// Every other block must carry exactly 13 bytes; the anchor number is the big-endian `uint48`
/// in bytes 7..13. Pure: it never reads L1 or the anchor contract.
pub fn decode_etna_anchor_block_number(block_number: u64, extra_data: &[u8]) -> Result<u64> {
    if block_number == 0 {
        return Ok(0);
    }
    if extra_data.len() != ETNA_EXTRA_DATA_LEN {
        return Err(ProtocolError::InvalidEtnaExtraDataLength {
            block_number,
            length: extra_data.len(),
        });
    }

    let mut buf = [0u8; 8];
    buf[2..].copy_from_slice(&extra_data[SHASTA_EXTRA_DATA_LEN..]);
    Ok(u64::from_be_bytes(buf))
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
    /// Header `extraData`: the 7-byte `[basefeeSharingPctg | proposalId]` before Etna
    /// ([`encode_extra_data`]), or the 13-byte layout that also carries the anchor block number
    /// for an Etna block ([`encode_etna_extra_data`]).
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
    use super::{
        PayloadAttributesInput, UINT48_MAX, build_payload_attributes_with_id,
        decode_etna_anchor_block_number, encode_etna_extra_data, encode_extra_data,
    };
    use crate::shasta::ProtocolError;
    use alethia_reth_primitives::decode_shasta_proposal_id;
    use alloy::primitives::{Address, B256, Bytes, U256, hex};

    /// Pre-Etna fingerprint of [`fingerprint_input`] without a beacon root, recorded with the
    /// pre-Osaka alethia-reth pin (`0fb47d9`) so the Osaka pin is checked against V2-era IDs.
    const PRE_ETNA_FINGERPRINT: [u8; 8] = hex!("02e3bcbe79b748d7");

    /// Etna fingerprint of [`fingerprint_input`] with root `0x…55` and the 13-byte `extraData`
    /// for anchor block 123456, recorded with the alethia-reth pin `53d2cd8`, so a re-pin that
    /// changes the Etna preimage fails here instead of silently changing stored payload IDs.
    const ETNA_FINGERPRINT: [u8; 8] = hex!("0291cb0f178787cf");

    /// Parent hash shared by the fingerprint vectors.
    fn fingerprint_parent() -> B256 {
        B256::with_last_byte(0x44)
    }

    /// Fixed pre-Etna attributes input whose only varying field is the beacon root.
    fn fingerprint_input(parent_beacon_block_root: Option<B256>) -> PayloadAttributesInput {
        PayloadAttributesInput {
            beneficiary: Address::with_last_byte(0x11),
            timestamp: 1_700_000_000,
            mix_hash: B256::with_last_byte(0x22),
            gas_limit: 30_000_000,
            tx_list: Some(Bytes::from_static(&[0xc0])),
            extra_data: encode_extra_data(50, 7),
            base_fee_per_gas: U256::from(10_000_000u64),
            block_number: 42,
            l1_block_height: Some(U256::from(100u64)),
            l1_block_hash: Some(B256::with_last_byte(0x33)),
            is_forced_inclusion: false,
            signature: [0; 65],
            parent_beacon_block_root,
            anchor_transaction: None,
        }
    }

    #[test]
    fn payload_id_ignores_zero_parent_beacon_root() {
        let parent = fingerprint_parent();
        let without_root = build_payload_attributes_with_id(fingerprint_input(None), &parent);
        let zero_root =
            build_payload_attributes_with_id(fingerprint_input(Some(B256::ZERO)), &parent);

        assert_eq!(without_root.l1_origin.build_payload_args_id, PRE_ETNA_FINGERPRINT);
        assert_eq!(zero_root.l1_origin.build_payload_args_id, PRE_ETNA_FINGERPRINT);
    }

    /// An Etna fingerprint binds the nonzero root and the 13-byte `extraData`: changing either
    /// one (a zero or another root, the 7-byte pre-Etna `extraData`, another anchor number)
    /// changes the payload ID.
    #[test]
    fn etna_payload_id_binds_the_root_and_the_13_byte_extra_data() {
        let parent = fingerprint_parent();
        let payload_id = |parent_beacon_block_root: Option<B256>, extra_data: Bytes| {
            let input = PayloadAttributesInput {
                parent_beacon_block_root,
                extra_data,
                ..fingerprint_input(None)
            };
            build_payload_attributes_with_id(input, &parent).l1_origin.build_payload_args_id
        };
        let root = B256::with_last_byte(0x55);
        let extra_data = encode_etna_extra_data(50, 7, 123_456).expect("fields fit uint48");
        let etna = payload_id(Some(root), extra_data.clone());

        assert_eq!(etna, ETNA_FINGERPRINT);
        assert_ne!(etna, PRE_ETNA_FINGERPRINT);
        assert_ne!(etna, payload_id(Some(B256::ZERO), extra_data.clone()), "zero root");
        assert_ne!(etna, payload_id(None, extra_data.clone()), "missing root");
        assert_ne!(etna, payload_id(Some(B256::with_last_byte(0x56)), extra_data), "other root");
        assert_ne!(etna, payload_id(Some(root), encode_extra_data(50, 7)), "7-byte extraData");
        assert_ne!(
            etna,
            payload_id(Some(root), encode_etna_extra_data(50, 7, 123_457).expect("fits uint48")),
            "other anchor number"
        );
    }

    /// `[pctg | proposalId(6) | anchorBlockNumber(6)]`, both numbers big-endian `uint48`.
    #[test]
    fn etna_extra_data_encodes_the_13_byte_layout() {
        let extra_data = encode_etna_extra_data(50, 7, 123_456).expect("fields fit uint48");

        assert_eq!(extra_data.as_ref(), hex!("3200000000000700000001e240"));
        assert_eq!(extra_data.len(), 13);
        assert_eq!(&extra_data[..7], encode_extra_data(50, 7).as_ref());
        assert_eq!(decode_shasta_proposal_id(&extra_data), Some(7));
        assert_eq!(decode_etna_anchor_block_number(1, &extra_data).unwrap(), 123_456);
    }

    #[test]
    fn etna_extra_data_round_trips_the_largest_uint48_values() {
        let extra_data =
            encode_etna_extra_data(u8::MAX, UINT48_MAX, UINT48_MAX).expect("max uint48 fits");

        assert_eq!(extra_data.as_ref(), hex!("ffffffffffffffffffffffffff"));
        assert_eq!(decode_shasta_proposal_id(&extra_data), Some(UINT48_MAX));
        assert_eq!(decode_etna_anchor_block_number(1, &extra_data).unwrap(), UINT48_MAX);
    }

    #[test]
    fn etna_extra_data_rejects_fields_beyond_uint48() {
        assert!(matches!(
            encode_etna_extra_data(50, UINT48_MAX + 1, 1),
            Err(ProtocolError::EtnaExtraDataFieldOverflow { field: "proposal_id", value })
                if value == UINT48_MAX + 1
        ));
        assert!(matches!(
            encode_etna_extra_data(50, 1, UINT48_MAX + 1),
            Err(ProtocolError::EtnaExtraDataFieldOverflow { field: "anchor_block_number", value })
                if value == UINT48_MAX + 1
        ));
    }

    /// The L2 genesis header has no Etna layout; its anchor number is 0 whatever its bytes are.
    #[test]
    fn genesis_anchor_block_number_is_zero() {
        for extra_data in [&[][..], &[0x32; 7][..], &[0xff; 13][..]] {
            assert_eq!(decode_etna_anchor_block_number(0, extra_data).unwrap(), 0);
        }
    }

    #[test]
    fn non_genesis_anchor_block_number_requires_13_bytes() {
        for length in [0, 7, 12, 14] {
            let extra_data = vec![0u8; length];
            assert!(
                matches!(
                    decode_etna_anchor_block_number(5, &extra_data),
                    Err(ProtocolError::InvalidEtnaExtraDataLength { block_number: 5, length: l })
                        if l == length
                ),
                "length {length} must be rejected"
            );
        }
    }
}

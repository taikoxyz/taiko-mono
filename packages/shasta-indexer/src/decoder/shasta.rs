use alloy::primitives::Uint;
use alloy::primitives::{Address, B256};
use alloy::sol;

use super::error::DecodeError;

// Generate contract bindings from ABI JSON
sol!(
    #[allow(missing_docs)]
    #[sol(rpc)]
    #[derive(Debug)]
    ShastaInbox,
    "abis/ShastaInbox.json"
);

pub use IInbox::{
    BlockMiniHeader, CoreState, Derivation, Proposal, ProposedEventPayload, ProvedEventPayload,
    Transition, TransitionRecord,
};
pub use LibBlobs::BlobSlice;
pub use LibBonds::BondInstruction;

/// Decode the data field from a Proposed event into a ProposedEventPayload
///
/// The Proposed event uses a custom compact encoding format:
/// - Proposal: id(6) + proposer(20) + timestamp(6) = 32 bytes
/// - Derivation: originBlockNumber(6) + isForcedInclusion(1) + basefeeSharingPctg(1) = 8 bytes
/// - BlobSlice: arrayLength(3) + blobHashes(32*n) + offset(3) + timestamp(6) = 12 + 32n bytes
/// - Proposal (cont): coreStateHash(32) + derivationHash(32) = 64 bytes
/// - CoreState: nextProposalId(6) + lastFinalizedProposalId(6) +
///              lastFinalizedTransitionHash(32) + bondInstructionsHash(32) = 76 bytes
/// Total fixed size: 192 bytes + (32 * blob_hashes_count)
pub fn decode_proposed_data_shasta(data: &[u8]) -> Result<ProposedEventPayload, DecodeError> {
    let mut ptr = 0;

    // Helper functions for unpacking different types
    let unpack_uint48 = |data: &[u8], ptr: &mut usize, field: &str| -> Result<u64, DecodeError> {
        if *ptr + 6 > data.len() {
            return Err(DecodeError::InsufficientData {
                expected: 6,
                available: data.len() - *ptr,
                field: field.to_string(),
            });
        }
        let mut bytes = [0u8; 8];
        bytes[2..8].copy_from_slice(&data[*ptr..*ptr + 6]);
        *ptr += 6;
        Ok(u64::from_be_bytes(bytes))
    };

    let unpack_uint24 = |data: &[u8], ptr: &mut usize, field: &str| -> Result<u32, DecodeError> {
        if *ptr + 3 > data.len() {
            return Err(DecodeError::InsufficientData {
                expected: 3,
                available: data.len() - *ptr,
                field: field.to_string(),
            });
        }
        let mut bytes = [0u8; 4];
        bytes[1..4].copy_from_slice(&data[*ptr..*ptr + 3]);
        *ptr += 3;
        Ok(u32::from_be_bytes(bytes))
    };

    let unpack_uint8 = |data: &[u8], ptr: &mut usize, field: &str| -> Result<u8, DecodeError> {
        if *ptr >= data.len() {
            return Err(DecodeError::InsufficientData {
                expected: 1,
                available: 0,
                field: field.to_string(),
            });
        }
        let value = data[*ptr];
        *ptr += 1;
        Ok(value)
    };

    let unpack_address =
        |data: &[u8], ptr: &mut usize, field: &str| -> Result<Address, DecodeError> {
            if *ptr + 20 > data.len() {
                return Err(DecodeError::InsufficientData {
                    expected: 20,
                    available: data.len() - *ptr,
                    field: field.to_string(),
                });
            }
            let mut bytes = [0u8; 20];
            bytes.copy_from_slice(&data[*ptr..*ptr + 20]);
            *ptr += 20;
            Ok(Address::from(bytes))
        };

    let unpack_bytes32 = |data: &[u8], ptr: &mut usize, field: &str| -> Result<B256, DecodeError> {
        if *ptr + 32 > data.len() {
            return Err(DecodeError::InsufficientData {
                expected: 32,
                available: data.len() - *ptr,
                field: field.to_string(),
            });
        }
        let mut bytes = [0u8; 32];
        bytes.copy_from_slice(&data[*ptr..*ptr + 32]);
        *ptr += 32;
        Ok(B256::from(bytes))
    };

    // Decode Proposal
    let proposal_id = unpack_uint48(data, &mut ptr, "proposal.id")?;
    let proposer = unpack_address(data, &mut ptr, "proposal.proposer")?;
    let proposal_timestamp = unpack_uint48(data, &mut ptr, "proposal.timestamp")?;

    // Decode Derivation fields
    let origin_block_number = unpack_uint48(data, &mut ptr, "derivation.originBlockNumber")?;
    let is_forced_inclusion_byte = unpack_uint8(data, &mut ptr, "derivation.isForcedInclusion")?;
    let is_forced_inclusion = is_forced_inclusion_byte != 0;
    let basefee_sharing_pctg = unpack_uint8(data, &mut ptr, "derivation.basefeeSharingPctg")?;

    // Decode BlobSlice
    let blob_hashes_length = unpack_uint24(data, &mut ptr, "blobSlice.length")? as usize;

    // Validate blob hashes length
    if blob_hashes_length > 16777215 {
        return Err(DecodeError::InvalidData {
            field: "blobSlice.length".to_string(),
            details: format!(
                "Blob hashes length {} exceeds maximum of 16777215",
                blob_hashes_length
            ),
        });
    }

    let mut blob_hashes = Vec::with_capacity(blob_hashes_length);
    for i in 0..blob_hashes_length {
        blob_hashes.push(unpack_bytes32(
            data,
            &mut ptr,
            &format!("blobSlice.blobHashes[{}]", i),
        )?);
    }

    let blob_offset = unpack_uint24(data, &mut ptr, "blobSlice.offset")?;
    let blob_timestamp = unpack_uint48(data, &mut ptr, "blobSlice.timestamp")?;

    // Decode coreStateHash (part of Proposal)
    let core_state_hash = unpack_bytes32(data, &mut ptr, "proposal.coreStateHash")?;

    // Decode derivationHash (part of Proposal)
    let derivation_hash = unpack_bytes32(data, &mut ptr, "proposal.derivationHash")?;

    // Decode CoreState
    let next_proposal_id = unpack_uint48(data, &mut ptr, "coreState.nextProposalId")?;
    let last_finalized_proposal_id =
        unpack_uint48(data, &mut ptr, "coreState.lastFinalizedProposalId")?;
    let last_finalized_transition_hash =
        unpack_bytes32(data, &mut ptr, "coreState.lastFinalizedTransitionHash")?;
    let bond_instructions_hash = unpack_bytes32(data, &mut ptr, "coreState.bondInstructionsHash")?;

    // Build the ProposedEventPayload
    // Note: Uint<48, 1> is used for 48-bit values, Uint<24, 1> for 24-bit values
    Ok(ProposedEventPayload {
        proposal: Proposal {
            id: Uint::<48, 1>::from(proposal_id),
            proposer,
            timestamp: Uint::<48, 1>::from(proposal_timestamp),
            coreStateHash: core_state_hash,
            derivationHash: derivation_hash,
        },
        derivation: Derivation {
            originBlockNumber: Uint::<48, 1>::from(origin_block_number),
            originBlockHash: B256::ZERO, // Not included in the compact encoding
            isForcedInclusion: is_forced_inclusion,
            basefeeSharingPctg: basefee_sharing_pctg,
            blobSlice: BlobSlice {
                blobHashes: blob_hashes,
                offset: Uint::<24, 1>::from(blob_offset),
                timestamp: Uint::<48, 1>::from(blob_timestamp),
            },
        },
        coreState: CoreState {
            nextProposalId: Uint::<48, 1>::from(next_proposal_id),
            lastFinalizedProposalId: Uint::<48, 1>::from(last_finalized_proposal_id),
            lastFinalizedTransitionHash: last_finalized_transition_hash,
            bondInstructionsHash: bond_instructions_hash,
        },
    })
}

/// Decode the data field from a Proved event into a ProvedEventPayload
///
/// The Proved event uses a custom compact encoding format:
/// - proposalId: 6 bytes
/// - Transition: proposalHash(32) + parentTransitionHash(32) = 64 bytes
///   - endBlockMiniHeader: number(6) + hash(32) + stateRoot(32) = 70 bytes
///   - designatedProver(20) + actualProver(20) = 40 bytes
/// - TransitionRecord: span(1) + transitionHash(32) + endBlockMiniHeaderHash(32) = 65 bytes
/// - bondInstructions array length: 2 bytes
/// - Each bond instruction: proposalId(6) + bondType(1) + payer(20) + receiver(20) = 47 bytes
/// Total fixed size: 247 bytes + (47 * bond_instructions_count)
pub fn decode_proved_data_shasta(data: &[u8]) -> Result<ProvedEventPayload, DecodeError> {
    let mut ptr = 0;

    // Helper functions for unpacking different types
    let unpack_uint48 = |data: &[u8], ptr: &mut usize, field: &str| -> Result<u64, DecodeError> {
        if *ptr + 6 > data.len() {
            return Err(DecodeError::InsufficientData {
                expected: 6,
                available: data.len() - *ptr,
                field: field.to_string(),
            });
        }
        let mut bytes = [0u8; 8];
        bytes[2..8].copy_from_slice(&data[*ptr..*ptr + 6]);
        *ptr += 6;
        Ok(u64::from_be_bytes(bytes))
    };

    let unpack_uint16 = |data: &[u8], ptr: &mut usize, field: &str| -> Result<u16, DecodeError> {
        if *ptr + 2 > data.len() {
            return Err(DecodeError::InsufficientData {
                expected: 2,
                available: data.len() - *ptr,
                field: field.to_string(),
            });
        }
        let mut bytes = [0u8; 2];
        bytes.copy_from_slice(&data[*ptr..*ptr + 2]);
        *ptr += 2;
        Ok(u16::from_be_bytes(bytes))
    };

    let unpack_uint8 = |data: &[u8], ptr: &mut usize, field: &str| -> Result<u8, DecodeError> {
        if *ptr >= data.len() {
            return Err(DecodeError::InsufficientData {
                expected: 1,
                available: 0,
                field: field.to_string(),
            });
        }
        let value = data[*ptr];
        *ptr += 1;
        Ok(value)
    };

    let unpack_address =
        |data: &[u8], ptr: &mut usize, field: &str| -> Result<Address, DecodeError> {
            if *ptr + 20 > data.len() {
                return Err(DecodeError::InsufficientData {
                    expected: 20,
                    available: data.len() - *ptr,
                    field: field.to_string(),
                });
            }
            let mut bytes = [0u8; 20];
            bytes.copy_from_slice(&data[*ptr..*ptr + 20]);
            *ptr += 20;
            Ok(Address::from(bytes))
        };

    let unpack_bytes32 = |data: &[u8], ptr: &mut usize, field: &str| -> Result<B256, DecodeError> {
        if *ptr + 32 > data.len() {
            return Err(DecodeError::InsufficientData {
                expected: 32,
                available: data.len() - *ptr,
                field: field.to_string(),
            });
        }
        let mut bytes = [0u8; 32];
        bytes.copy_from_slice(&data[*ptr..*ptr + 32]);
        *ptr += 32;
        Ok(B256::from(bytes))
    };

    // Decode proposalId
    let proposal_id = unpack_uint48(data, &mut ptr, "proposalId")?;

    // Decode Transition struct
    let proposal_hash = unpack_bytes32(data, &mut ptr, "transition.proposalHash")?;
    let parent_transition_hash = unpack_bytes32(data, &mut ptr, "transition.parentTransitionHash")?;

    // Decode endBlockMiniHeader
    let end_block_number = unpack_uint48(data, &mut ptr, "endBlockMiniHeader.number")?;
    let end_block_hash = unpack_bytes32(data, &mut ptr, "endBlockMiniHeader.hash")?;
    let end_block_state_root = unpack_bytes32(data, &mut ptr, "endBlockMiniHeader.stateRoot")?;

    // Decode provers
    let designated_prover = unpack_address(data, &mut ptr, "transition.designatedProver")?;
    let actual_prover = unpack_address(data, &mut ptr, "transition.actualProver")?;

    // Decode TransitionRecord
    let span = unpack_uint8(data, &mut ptr, "transitionRecord.span")?;
    let transition_hash = unpack_bytes32(data, &mut ptr, "transitionRecord.transitionHash")?;
    let end_block_mini_header_hash =
        unpack_bytes32(data, &mut ptr, "transitionRecord.endBlockMiniHeaderHash")?;

    // Decode bond instructions array length
    let bond_instructions_length =
        unpack_uint16(data, &mut ptr, "bondInstructions.length")? as usize;

    // Validate bond instructions length
    if bond_instructions_length > 65535 {
        return Err(DecodeError::InvalidData {
            field: "bondInstructions.length".to_string(),
            details: format!(
                "Bond instructions length {} exceeds maximum of 65535",
                bond_instructions_length
            ),
        });
    }

    // Decode bond instructions
    let mut bond_instructions = Vec::with_capacity(bond_instructions_length);
    for i in 0..bond_instructions_length {
        let bond_proposal_id = unpack_uint48(
            data,
            &mut ptr,
            &format!("bondInstructions[{}].proposalId", i),
        )?;
        let bond_type_value =
            unpack_uint8(data, &mut ptr, &format!("bondInstructions[{}].bondType", i))?;

        // Validate bond type (0 = NONE, 1 = PROPOSER, 2 = CHALLENGER, 3 = PROVER, 4 = LIVENESS)
        if bond_type_value > 4 {
            return Err(DecodeError::InvalidData {
                field: format!("bondInstructions[{}].bondType", i),
                details: format!("Invalid bond type value: {}", bond_type_value),
            });
        }

        let payer = unpack_address(data, &mut ptr, &format!("bondInstructions[{}].payer", i))?;
        let receiver =
            unpack_address(data, &mut ptr, &format!("bondInstructions[{}].receiver", i))?;

        bond_instructions.push(BondInstruction {
            proposalId: Uint::<48, 1>::from(bond_proposal_id),
            bondType: bond_type_value,
            payer,
            receiver,
        });
    }

    // Build the ProvedEventPayload
    Ok(ProvedEventPayload {
        proposalId: Uint::<48, 1>::from(proposal_id),
        transition: Transition {
            proposalHash: proposal_hash,
            parentTransitionHash: parent_transition_hash,
            endBlockMiniHeader: BlockMiniHeader {
                number: Uint::<48, 1>::from(end_block_number),
                hash: end_block_hash,
                stateRoot: end_block_state_root,
            },
            designatedProver: designated_prover,
            actualProver: actual_prover,
        },
        transitionRecord: TransitionRecord {
            span: span,
            transitionHash: transition_hash,
            endBlockMiniHeaderHash: end_block_mini_header_hash,
            bondInstructions: bond_instructions,
        },
    })
}

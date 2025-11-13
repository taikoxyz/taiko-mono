//! Local implementation of the `CodecOptimized` decoder contracts.
//!
//! The routines below mirror the Solidity implementations found in
//! `contracts/layer1/core/impl/CodecOptimized.sol` which internally defer to
//! `LibProposedEventEncoder` and `LibProvedEventEncoder`. They operate on the
//! raw bytes emitted by the Shasta inbox events and therefore must stay
//! byte-for-byte compatible with the on-chain logic.

use alloy_primitives::{
    Address, FixedBytes,
    aliases::{U24, U48},
};
use bindings::codec_optimized::{
    ICheckpointStore::Checkpoint,
    IInbox::{
        CoreState, Derivation, DerivationSource, Proposal, ProposedEventPayload,
        ProvedEventPayload, Transition, TransitionMetadata, TransitionRecord,
    },
    LibBlobs::BlobSlice,
    LibBonds::BondInstruction,
};

use super::error::{ProtocolError, Result};

/// Maximum valid value for [`LibBonds::BondType`] (`LibBonds.BondType.LIVENESS`).
const MAX_BOND_TYPE: u8 = 2;

#[allow(clippy::field_reassign_with_default)]
/// Decode a compactly encoded proposed event payload emitted by the inbox.
pub fn decode_proposed_event(data: &[u8]) -> Result<ProposedEventPayload> {
    let mut decoder = Decoder::new(data);

    let mut proposal = Proposal::default();
    proposal.id = decoder.read_u48()?;
    proposal.proposer = decoder.read_address()?;
    proposal.timestamp = decoder.read_u48()?;
    proposal.endOfSubmissionWindowTimestamp = decoder.read_u48()?;

    let mut derivation = Derivation::default();
    derivation.originBlockNumber = decoder.read_u48()?;
    derivation.originBlockHash = decoder.read_bytes32()?;
    derivation.basefeeSharingPctg = decoder.read_u8()?;

    let sources_len = decoder.read_u16()? as usize;
    let mut sources = Vec::with_capacity(sources_len);
    for _ in 0..sources_len {
        let is_forced_inclusion = decoder.read_u8()? != 0;
        let blob_slice = read_blob_slice(&mut decoder)?;
        sources.push(DerivationSource {
            isForcedInclusion: is_forced_inclusion,
            blobSlice: blob_slice,
        });
    }
    derivation.sources = sources;

    proposal.coreStateHash = decoder.read_bytes32()?;
    proposal.derivationHash = decoder.read_bytes32()?;

    let mut core_state = CoreState::default();
    core_state.nextProposalId = decoder.read_u48()?;
    core_state.lastProposalBlockId = decoder.read_u48()?;
    core_state.lastFinalizedProposalId = decoder.read_u48()?;
    core_state.lastCheckpointTimestamp = decoder.read_u48()?;
    core_state.lastFinalizedTransitionHash = decoder.read_bytes32()?;
    core_state.bondInstructionsHash = decoder.read_bytes32()?;

    let bond_instructions = read_bond_instructions(&mut decoder, false)?;

    decoder.finish()?;

    Ok(ProposedEventPayload {
        proposal,
        derivation,
        coreState: core_state,
        bondInstructions: bond_instructions,
    })
}

#[allow(clippy::field_reassign_with_default)]
/// Decode a compactly encoded proved event payload emitted by the inbox.
pub fn decode_proved_event(data: &[u8]) -> Result<ProvedEventPayload> {
    let mut decoder = Decoder::new(data);

    let proposal_id = decoder.read_u48()?;

    let transition = Transition {
        proposalHash: decoder.read_bytes32()?,
        parentTransitionHash: decoder.read_bytes32()?,
        checkpoint: Checkpoint {
            blockNumber: decoder.read_u48()?,
            blockHash: decoder.read_bytes32()?,
            stateRoot: decoder.read_bytes32()?,
        },
    };

    let mut transition_record = TransitionRecord {
        span: decoder.read_u8()?,
        bondInstructions: Vec::new(),
        transitionHash: decoder.read_bytes32()?,
        checkpointHash: decoder.read_bytes32()?,
    };

    let mut metadata = TransitionMetadata::default();
    metadata.designatedProver = decoder.read_address()?;
    metadata.actualProver = decoder.read_address()?;

    transition_record.bondInstructions = read_bond_instructions(&mut decoder, true)?;

    decoder.finish()?;

    Ok(ProvedEventPayload {
        proposalId: proposal_id,
        transition,
        transitionRecord: transition_record,
        metadata,
    })
}

/// Byte-slice cursor that mirrors the unchecked Solidity pack/unpack helpers.
#[derive(Clone, Copy, Debug)]
struct Decoder<'a> {
    /// ABI-encoded bytes being decoded.
    data: &'a [u8],
    /// Current cursor offset into `data`.
    offset: usize,
}

impl<'a> Decoder<'a> {
    fn new(data: &'a [u8]) -> Self {
        Self { data, offset: 0 }
    }

    /// Read the next `len` bytes from the buffer.
    fn read_bytes(&mut self, len: usize) -> Result<&'a [u8]> {
        let end = self
            .offset
            .checked_add(len)
            .ok_or_else(|| ProtocolError::InvalidPayload("offset overflow".into()))?;
        let bytes =
            self.data.get(self.offset..end).ok_or_else(|| insufficient_bytes(len, self.offset))?;
        self.offset = end;
        Ok(bytes)
    }

    /// Read a single `u8`.
    fn read_u8(&mut self) -> Result<u8> {
        Ok(self.read_bytes(1)?[0])
    }

    /// Read a big-endian `u16`.
    fn read_u16(&mut self) -> Result<u16> {
        let bytes = self.read_bytes(2)?;
        Ok(u16::from_be_bytes([bytes[0], bytes[1]]))
    }

    /// Read a big-endian 24-bit unsigned integer.
    fn read_u24(&mut self) -> Result<U24> {
        let bytes = self.read_bytes(3)?;
        let value = ((bytes[0] as u32) << 16) | ((bytes[1] as u32) << 8) | (bytes[2] as u32);
        Ok(U24::from(value))
    }

    /// Read a big-endian 48-bit unsigned integer.
    fn read_u48(&mut self) -> Result<U48> {
        let bytes = self.read_bytes(6)?;
        let value = (bytes[0] as u64) << 40 |
            (bytes[1] as u64) << 32 |
            (bytes[2] as u64) << 24 |
            (bytes[3] as u64) << 16 |
            (bytes[4] as u64) << 8 |
            bytes[5] as u64;
        Ok(U48::from(value))
    }

    /// Read a `bytes32`.
    fn read_bytes32(&mut self) -> Result<FixedBytes<32>> {
        let bytes = self.read_bytes(32)?;
        Ok(FixedBytes::<32>::from_slice(bytes))
    }

    /// Read an `address`.
    fn read_address(&mut self) -> Result<Address> {
        let bytes = self.read_bytes(20)?;
        Ok(Address::from_slice(bytes))
    }

    /// Ensure the entire buffer has been consumed.
    fn finish(&self) -> Result<()> {
        if self.offset == self.data.len() {
            Ok(())
        } else {
            Err(ProtocolError::InvalidPayload(format!(
                "unexpected trailing bytes: {}",
                self.data.len() - self.offset
            )))
        }
    }
}

/// Read a `BlobSlice` structure.
fn read_blob_slice(decoder: &mut Decoder<'_>) -> Result<BlobSlice> {
    let blob_hashes_len = decoder.read_u16()? as usize;
    let mut blob_hashes = Vec::with_capacity(blob_hashes_len);
    for _ in 0..blob_hashes_len {
        blob_hashes.push(decoder.read_bytes32()?);
    }
    Ok(BlobSlice {
        blobHashes: blob_hashes,
        offset: decoder.read_u24()?,
        timestamp: decoder.read_u48()?,
    })
}

fn read_bond_instructions(
    decoder: &mut Decoder<'_>,
    enforce_type: bool,
) -> Result<Vec<BondInstruction>> {
    let len = decoder.read_u16()? as usize;
    let mut instructions = Vec::with_capacity(len);
    for _ in 0..len {
        instructions.push(read_bond_instruction(decoder, enforce_type)?);
    }
    Ok(instructions)
}

fn read_bond_instruction(decoder: &mut Decoder<'_>, enforce_type: bool) -> Result<BondInstruction> {
    let proposal_id = decoder.read_u48()?;
    let bond_type = decoder.read_u8()?;
    if enforce_type && bond_type > MAX_BOND_TYPE {
        return Err(ProtocolError::InvalidPayload(format!(
            "invalid bond type {bond_type} (max {MAX_BOND_TYPE})"
        )));
    }
    Ok(BondInstruction {
        proposalId: proposal_id,
        bondType: bond_type,
        payer: decoder.read_address()?,
        payee: decoder.read_address()?,
    })
}

/// Construct a standard "insufficient bytes" error message.
fn insufficient_bytes(len: usize, offset: usize) -> ProtocolError {
    ProtocolError::InvalidPayload(format!("insufficient bytes: need {len} at offset {offset}"))
}

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

/// Decode a sequence of bond instructions, optionally enforcing the Solidity bond-type bound.
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

/// Decode a single bond instruction, optionally enforcing the Solidity bond-type bound.
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

#[cfg(test)]
mod tests {
    use super::*;
    use alloy::{providers::ProviderBuilder, transports::http::reqwest::Url};
    use alloy_provider::{Provider, RootProvider};
    use anyhow::{Context, Result};
    use bindings::{
        codec_optimized::{
            CodecOptimized::{self, CodecOptimizedInstance},
            LibBonds::BondType,
        },
        i_inbox::IInbox::IInboxInstance,
    };
    use rand::{Rng, RngCore, SeedableRng, rngs::StdRng};
    use std::{env, iter::zip, str::FromStr};

    /// Generates random payloads for Shasta codec round-trip validation.
    struct PayloadFactory {
        rng: StdRng,
    }

    impl PayloadFactory {
        fn new(seed: u64) -> Self {
            Self { rng: StdRng::seed_from_u64(seed) }
        }

        fn random_u48(&mut self) -> U48 {
            U48::from(self.rng.next_u64() & ((1 << 48) - 1))
        }

        fn random_u24(&mut self) -> U24 {
            U24::from((self.rng.next_u32() & ((1 << 24) - 1)) as u32)
        }

        fn random_bytes32(&mut self) -> FixedBytes<32> {
            let mut buf = [0u8; 32];
            self.rng.fill_bytes(&mut buf);
            FixedBytes::<32>::from_slice(&buf)
        }

        fn random_address(&mut self) -> Address {
            let mut buf = [0u8; 20];
            self.rng.fill_bytes(&mut buf);
            Address::from_slice(&buf)
        }

        fn random_blob_slice(&mut self) -> BlobSlice {
            let blob_count = self.rng.gen_range(0..=3);
            let blob_hashes = (0..blob_count).map(|_| self.random_bytes32()).collect();
            BlobSlice {
                blobHashes: blob_hashes,
                offset: self.random_u24(),
                timestamp: self.random_u48(),
            }
        }

        fn random_derivation_source(&mut self) -> DerivationSource {
            DerivationSource {
                isForcedInclusion: self.rng.gen_bool(0.5),
                blobSlice: self.random_blob_slice(),
            }
        }

        fn random_bond_instruction(&mut self) -> BondInstruction {
            let bond_type = BondType::from_underlying(self.rng.gen_range(0..=MAX_BOND_TYPE));
            BondInstruction {
                proposalId: self.random_u48(),
                bondType: bond_type.into(),
                payer: self.random_address(),
                payee: self.random_address(),
            }
        }

        fn random_proposed_payload(&mut self) -> ProposedEventPayload {
            let proposal = Proposal {
                id: self.random_u48(),
                timestamp: self.random_u48(),
                endOfSubmissionWindowTimestamp: self.random_u48(),
                proposer: self.random_address(),
                coreStateHash: self.random_bytes32(),
                derivationHash: self.random_bytes32(),
            };
            let sources_len = self.rng.gen_range(0..=3);
            let derivation = Derivation {
                originBlockNumber: self.random_u48(),
                originBlockHash: self.random_bytes32(),
                basefeeSharingPctg: self.rng.r#gen(),
                sources: (0..sources_len).map(|_| self.random_derivation_source()).collect(),
            };
            let core_state = CoreState {
                nextProposalId: self.random_u48(),
                lastProposalBlockId: self.random_u48(),
                lastFinalizedProposalId: self.random_u48(),
                lastCheckpointTimestamp: self.random_u48(),
                lastFinalizedTransitionHash: self.random_bytes32(),
                bondInstructionsHash: self.random_bytes32(),
            };
            let bond_len = self.rng.gen_range(0..=4);
            let bond_instructions = (0..bond_len).map(|_| self.random_bond_instruction()).collect();
            ProposedEventPayload {
                proposal,
                derivation,
                coreState: core_state,
                bondInstructions: bond_instructions,
            }
        }

        fn random_proved_payload(&mut self) -> ProvedEventPayload {
            let checkpoint = Checkpoint {
                blockNumber: self.random_u48(),
                blockHash: self.random_bytes32(),
                stateRoot: self.random_bytes32(),
            };
            let transition = Transition {
                proposalHash: self.random_bytes32(),
                parentTransitionHash: self.random_bytes32(),
                checkpoint,
            };
            let bond_len = self.rng.gen_range(0..=4);
            let transition_record = TransitionRecord {
                span: self.rng.r#gen(),
                bondInstructions: (0..bond_len).map(|_| self.random_bond_instruction()).collect(),
                transitionHash: self.random_bytes32(),
                checkpointHash: self.random_bytes32(),
            };
            let metadata = TransitionMetadata {
                designatedProver: self.random_address(),
                actualProver: self.random_address(),
            };
            ProvedEventPayload {
                proposalId: self.random_u48(),
                transition,
                transitionRecord: transition_record,
                metadata,
            }
        }
    }

    fn assert_proposed_payload_eq(lhs: &ProposedEventPayload, rhs: &ProposedEventPayload) {
        assert_proposal_eq(&lhs.proposal, &rhs.proposal);
        assert_derivation_eq(&lhs.derivation, &rhs.derivation);
        assert_core_state_eq(&lhs.coreState, &rhs.coreState);
        assert_eq!(lhs.bondInstructions.len(), rhs.bondInstructions.len());
        for (l, r) in zip(&lhs.bondInstructions, &rhs.bondInstructions) {
            assert_bond_instruction_eq(l, r);
        }
    }

    fn assert_proved_payload_eq(lhs: &ProvedEventPayload, rhs: &ProvedEventPayload) {
        assert_eq!(lhs.proposalId, rhs.proposalId);
        assert_transition_eq(&lhs.transition, &rhs.transition);
        assert_transition_record_eq(&lhs.transitionRecord, &rhs.transitionRecord);
        assert_transition_metadata_eq(&lhs.metadata, &rhs.metadata);
    }

    fn assert_proposal_eq(lhs: &Proposal, rhs: &Proposal) {
        assert_eq!(lhs.id, rhs.id);
        assert_eq!(lhs.timestamp, rhs.timestamp);
        assert_eq!(lhs.endOfSubmissionWindowTimestamp, rhs.endOfSubmissionWindowTimestamp);
        assert_eq!(lhs.proposer, rhs.proposer);
        assert_eq!(lhs.coreStateHash, rhs.coreStateHash);
        assert_eq!(lhs.derivationHash, rhs.derivationHash);
    }

    fn assert_derivation_eq(lhs: &Derivation, rhs: &Derivation) {
        assert_eq!(lhs.originBlockNumber, rhs.originBlockNumber);
        assert_eq!(lhs.originBlockHash, rhs.originBlockHash);
        assert_eq!(lhs.basefeeSharingPctg, rhs.basefeeSharingPctg);
        assert_eq!(lhs.sources.len(), rhs.sources.len());
        for (l, r) in zip(&lhs.sources, &rhs.sources) {
            assert_derivation_source_eq(l, r);
        }
    }

    fn assert_derivation_source_eq(lhs: &DerivationSource, rhs: &DerivationSource) {
        assert_eq!(lhs.isForcedInclusion, rhs.isForcedInclusion);
        assert_blob_slice_eq(&lhs.blobSlice, &rhs.blobSlice);
    }

    fn assert_blob_slice_eq(lhs: &BlobSlice, rhs: &BlobSlice) {
        assert_eq!(lhs.offset, rhs.offset);
        assert_eq!(lhs.timestamp, rhs.timestamp);
        assert_eq!(lhs.blobHashes, rhs.blobHashes);
    }

    fn assert_core_state_eq(lhs: &CoreState, rhs: &CoreState) {
        assert_eq!(lhs.nextProposalId, rhs.nextProposalId);
        assert_eq!(lhs.lastProposalBlockId, rhs.lastProposalBlockId);
        assert_eq!(lhs.lastFinalizedProposalId, rhs.lastFinalizedProposalId);
        assert_eq!(lhs.lastCheckpointTimestamp, rhs.lastCheckpointTimestamp);
        assert_eq!(lhs.lastFinalizedTransitionHash, rhs.lastFinalizedTransitionHash);
        assert_eq!(lhs.bondInstructionsHash, rhs.bondInstructionsHash);
    }

    fn assert_bond_instruction_eq(lhs: &BondInstruction, rhs: &BondInstruction) {
        assert_eq!(lhs.proposalId, rhs.proposalId);
        assert_eq!(lhs.bondType, rhs.bondType);
        assert_eq!(lhs.payer, rhs.payer);
        assert_eq!(lhs.payee, rhs.payee);
    }

    fn assert_transition_eq(lhs: &Transition, rhs: &Transition) {
        assert_eq!(lhs.proposalHash, rhs.proposalHash);
        assert_eq!(lhs.parentTransitionHash, rhs.parentTransitionHash);
        assert_checkpoint_eq(&lhs.checkpoint, &rhs.checkpoint);
    }

    fn assert_checkpoint_eq(lhs: &Checkpoint, rhs: &Checkpoint) {
        assert_eq!(lhs.blockNumber, rhs.blockNumber);
        assert_eq!(lhs.blockHash, rhs.blockHash);
        assert_eq!(lhs.stateRoot, rhs.stateRoot);
    }

    fn assert_transition_record_eq(lhs: &TransitionRecord, rhs: &TransitionRecord) {
        assert_eq!(lhs.span, rhs.span);
        assert_eq!(lhs.transitionHash, rhs.transitionHash);
        assert_eq!(lhs.checkpointHash, rhs.checkpointHash);
        assert_eq!(lhs.bondInstructions.len(), rhs.bondInstructions.len());
        for (l, r) in zip(&lhs.bondInstructions, &rhs.bondInstructions) {
            assert_bond_instruction_eq(l, r);
        }
    }

    fn assert_transition_metadata_eq(lhs: &TransitionMetadata, rhs: &TransitionMetadata) {
        assert_eq!(lhs.designatedProver, rhs.designatedProver);
        assert_eq!(lhs.actualProver, rhs.actualProver);
    }

    async fn codec_from_env() -> Result<CodecOptimizedInstance<RootProvider>> {
        let http_url = env::var("L1_HTTP").context("L1_HTTP env var is required")?;
        let inbox_address = Address::from_str(
            &env::var("SHASTA_INBOX").context("SHASTA_INBOX env var is required")?,
        )
        .context("invalid SHASTA_INBOX address")?;

        let provider = ProviderBuilder::default().connect_http(Url::from_str(&http_url)?);
        let inbox = IInboxInstance::new(inbox_address, provider.clone());
        let codec_address = inbox.getConfig().call().await?.codec;

        Ok(CodecOptimized::new(codec_address, provider.root().clone()))
    }

    #[tokio::test(flavor = "multi_thread")]
    async fn proposed_payloads_round_trip_via_onchain_codec() -> Result<()> {
        let codec = codec_from_env().await?;
        let mut factory = PayloadFactory::new(0xC0DEC0DE);
        for _ in 0..12 {
            let payload = factory.random_proposed_payload();
            let encoded = codec.encodeProposedEvent(payload.clone()).call().await?;
            let decoded = decode_proposed_event(encoded.as_ref())?;
            assert_proposed_payload_eq(&payload, &decoded);
        }
        Ok(())
    }

    #[tokio::test(flavor = "multi_thread")]
    async fn proved_payloads_round_trip_via_onchain_codec() -> Result<()> {
        let codec = codec_from_env().await?;
        let mut factory = PayloadFactory::new(0xBAD5EED);
        for _ in 0..12 {
            let payload = factory.random_proved_payload();
            let encoded = codec.encodeProvedEvent(payload.clone()).call().await?;
            let decoded = decode_proved_event(encoded.as_ref())?;
            assert_proved_payload_eq(&payload, &decoded);
        }
        Ok(())
    }
}

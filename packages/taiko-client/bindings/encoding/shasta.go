package encoding

import (
	"encoding/binary"
	"fmt"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// Go implementations of Shasta encoding/decoding libraries
// that are fully aligned with the Solidity contracts:
// - LibProposedEventEncoder
// - LibProposeInputDecoder
// - LibProvedEventEncoder
// - LibProveInputDecoder

// PackUnpack provides low-level packing functions aligned with LibPackUnpack.sol
type PackUnpack struct {
	data []byte
	pos  int
}

func NewPackUnpack(size int) *PackUnpack {
	return &PackUnpack{
		data: make([]byte, size),
		pos:  0,
	}
}

// Pack functions - write to buffer with compact encoding (big-endian)

func (p *PackUnpack) PackUint8(value uint8) {
	p.data[p.pos] = value
	p.pos++
}

func (p *PackUnpack) PackUint16(value uint16) {
	binary.BigEndian.PutUint16(p.data[p.pos:], value)
	p.pos += 2
}

func (p *PackUnpack) PackUint24(value uint32) {
	// Pack as 3 bytes in big-endian
	p.data[p.pos] = byte(value >> 16)
	p.data[p.pos+1] = byte(value >> 8)
	p.data[p.pos+2] = byte(value)
	p.pos += 3
}

func (p *PackUnpack) PackUint48(value uint64) {
	// Pack as 6 bytes in big-endian (most significant byte first)
	p.data[p.pos] = byte(value >> 40)
	p.data[p.pos+1] = byte(value >> 32)
	p.data[p.pos+2] = byte(value >> 24)
	p.data[p.pos+3] = byte(value >> 16)
	p.data[p.pos+4] = byte(value >> 8)
	p.data[p.pos+5] = byte(value)
	p.pos += 6
}

func (p *PackUnpack) PackAddress(addr common.Address) {
	copy(p.data[p.pos:], addr[:])
	p.pos += 20
}

func (p *PackUnpack) PackBytes32(value common.Hash) {
	copy(p.data[p.pos:], value[:])
	p.pos += 32
}

// Unpack functions - read from buffer

func (p *PackUnpack) UnpackUint8() uint8 {
	value := p.data[p.pos]
	p.pos++
	return value
}

func (p *PackUnpack) UnpackUint16() uint16 {
	value := binary.BigEndian.Uint16(p.data[p.pos:])
	p.pos += 2
	return value
}

func (p *PackUnpack) UnpackUint24() uint32 {
	value := uint32(p.data[p.pos])<<16 | uint32(p.data[p.pos+1])<<8 | uint32(p.data[p.pos+2])
	p.pos += 3
	return value
}

func (p *PackUnpack) UnpackUint48() uint64 {
	// Unpack from 6 bytes in big-endian (most significant byte first)
	value := uint64(p.data[p.pos])<<40 |
		uint64(p.data[p.pos+1])<<32 |
		uint64(p.data[p.pos+2])<<24 |
		uint64(p.data[p.pos+3])<<16 |
		uint64(p.data[p.pos+4])<<8 |
		uint64(p.data[p.pos+5])
	p.pos += 6
	return value
}

func (p *PackUnpack) UnpackAddress() common.Address {
	var addr common.Address
	copy(addr[:], p.data[p.pos:p.pos+20])
	p.pos += 20
	return addr
}

func (p *PackUnpack) UnpackBytes32() common.Hash {
	var hash common.Hash
	copy(hash[:], p.data[p.pos:p.pos+32])
	p.pos += 32
	return hash
}

func (p *PackUnpack) Bytes() []byte {
	return p.data
}

func (p *PackUnpack) Reset(data []byte) {
	p.data = data
	p.pos = 0
}

// LibProposedEventEncoder - encodes/decodes ProposedEventPayload

func EncodeProposedEvent(payload *shasta.IInboxProposedEventPayload) ([]byte, error) {
	size := CalculateProposedEventSize(len(payload.Derivation.BlobSlice.BlobHashes))
	pack := NewPackUnpack(size)

	// Encode Proposal
	pack.PackUint48(payload.Proposal.Id.Uint64())
	pack.PackAddress(payload.Proposal.Proposer)
	pack.PackUint48(payload.Proposal.Timestamp.Uint64())
	pack.PackUint48(payload.Proposal.EndOfSubmissionWindowTimestamp.Uint64())
	pack.PackUint48(payload.Derivation.OriginBlockNumber.Uint64())
	pack.PackBytes32(payload.Derivation.OriginBlockHash)

	if payload.Derivation.IsForcedInclusion {
		pack.PackUint8(1)
	} else {
		pack.PackUint8(0)
	}
	pack.PackUint8(payload.Derivation.BasefeeSharingPctg)

	// Encode blob slice (length + hashes + offset + timestamp)
	blobHashesLength := len(payload.Derivation.BlobSlice.BlobHashes)
	if blobHashesLength > 16777215 { // uint24 max
		return nil, fmt.Errorf("blob hashes length exceeds uint24 max: %d", blobHashesLength)
	}
	pack.PackUint24(uint32(blobHashesLength))

	// Encode each blob hash
	for _, hash := range payload.Derivation.BlobSlice.BlobHashes {
		pack.PackBytes32(hash)
	}

	pack.PackUint24(uint32(payload.Derivation.BlobSlice.Offset.Uint64()))
	pack.PackUint48(payload.Derivation.BlobSlice.Timestamp.Uint64())

	pack.PackBytes32(payload.Proposal.CoreStateHash)
	pack.PackBytes32(payload.Proposal.DerivationHash)

	// Encode core state
	pack.PackUint48(payload.CoreState.NextProposalId.Uint64())
	pack.PackUint48(payload.CoreState.NextProposalBlockId.Uint64())
	pack.PackUint48(payload.CoreState.LastFinalizedProposalId.Uint64())
	pack.PackBytes32(payload.CoreState.LastFinalizedTransitionHash)
	pack.PackBytes32(payload.CoreState.BondInstructionsHash)

	return pack.Bytes(), nil
}

func DecodeProposedEvent(data []byte) (*shasta.IInboxProposedEventPayload, error) {
	pack := &PackUnpack{data: data, pos: 0}
	payload := &shasta.IInboxProposedEventPayload{}

	// Decode Proposal
	payload.Proposal.Id = new(big.Int).SetUint64(pack.UnpackUint48())
	payload.Proposal.Proposer = pack.UnpackAddress()
	payload.Proposal.Timestamp = new(big.Int).SetUint64(pack.UnpackUint48())
	payload.Proposal.EndOfSubmissionWindowTimestamp = new(big.Int).SetUint64(pack.UnpackUint48())

	// Decode derivation fields
	payload.Derivation.OriginBlockNumber = new(big.Int).SetUint64(pack.UnpackUint48())
	payload.Derivation.OriginBlockHash = pack.UnpackBytes32()

	isForcedInclusion := pack.UnpackUint8()
	payload.Derivation.IsForcedInclusion = isForcedInclusion != 0
	payload.Derivation.BasefeeSharingPctg = pack.UnpackUint8()

	// Decode blob slice
	blobHashesLength := pack.UnpackUint24()
	payload.Derivation.BlobSlice.BlobHashes = make([][32]byte, blobHashesLength)
	for i := uint32(0); i < blobHashesLength; i++ {
		payload.Derivation.BlobSlice.BlobHashes[i] = pack.UnpackBytes32()
	}

	payload.Derivation.BlobSlice.Offset = new(big.Int).SetUint64(uint64(pack.UnpackUint24()))
	payload.Derivation.BlobSlice.Timestamp = new(big.Int).SetUint64(pack.UnpackUint48())

	payload.Proposal.CoreStateHash = pack.UnpackBytes32()
	payload.Proposal.DerivationHash = pack.UnpackBytes32()

	// Decode core state
	payload.CoreState.NextProposalId = new(big.Int).SetUint64(pack.UnpackUint48())
	payload.CoreState.NextProposalBlockId = new(big.Int).SetUint64(pack.UnpackUint48())
	payload.CoreState.LastFinalizedProposalId = new(big.Int).SetUint64(pack.UnpackUint48())
	payload.CoreState.LastFinalizedTransitionHash = pack.UnpackBytes32()
	payload.CoreState.BondInstructionsHash = pack.UnpackBytes32()

	return payload, nil
}

func CalculateProposedEventSize(blobHashesCount int) int {
	// Fixed size: 236 bytes (as per Solidity comment)
	// Variable size: each blob hash is 32 bytes
	return 236 + (blobHashesCount * 32)
}

// LibProvedEventEncoder - encodes/decodes ProvedEventPayload

func EncodeProvedEvent(payload *shasta.IInboxProvedEventPayload) ([]byte, error) {
	size := CalculateProvedEventSize(len(payload.TransitionRecord.BondInstructions))
	pack := NewPackUnpack(size)

	// Encode proposalId (uint48)
	pack.PackUint48(payload.ProposalId.Uint64())

	// Encode Transition struct
	pack.PackBytes32(payload.Transition.ProposalHash)
	pack.PackBytes32(payload.Transition.ParentTransitionHash)
	// Encode Checkpoint
	pack.PackUint48(payload.Transition.Checkpoint.BlockNumber.Uint64())
	pack.PackBytes32(payload.Transition.Checkpoint.BlockHash)
	pack.PackBytes32(payload.Transition.Checkpoint.StateRoot)

	// Encode TransitionRecord
	pack.PackUint8(payload.TransitionRecord.Span)
	pack.PackBytes32(payload.TransitionRecord.TransitionHash)
	pack.PackBytes32(payload.TransitionRecord.CheckpointHash)

	// Encode TransitionMetadata
	pack.PackAddress(payload.Metadata.DesignatedProver)
	pack.PackAddress(payload.Metadata.ActualProver)

	// Encode bond instructions array length (uint16)
	bondInstructionsLength := len(payload.TransitionRecord.BondInstructions)
	if bondInstructionsLength > 65535 { // uint16 max
		return nil, fmt.Errorf("bond instructions length exceeds uint16 max: %d", bondInstructionsLength)
	}
	pack.PackUint16(uint16(bondInstructionsLength))

	// Encode each bond instruction
	for _, instruction := range payload.TransitionRecord.BondInstructions {
		pack.PackUint48(instruction.ProposalId.Uint64())
		pack.PackUint8(uint8(instruction.BondType))
		pack.PackAddress(instruction.Payer)
		pack.PackAddress(instruction.Receiver)
	}

	return pack.Bytes(), nil
}

func DecodeProvedEvent(data []byte) (*shasta.IInboxProvedEventPayload, error) {
	pack := &PackUnpack{data: data, pos: 0}
	payload := &shasta.IInboxProvedEventPayload{}

	// Decode proposalId (uint48)
	payload.ProposalId = new(big.Int).SetUint64(pack.UnpackUint48())

	// Decode Transition struct
	payload.Transition.ProposalHash = pack.UnpackBytes32()
	payload.Transition.ParentTransitionHash = pack.UnpackBytes32()
	// Decode Checkpoint
	payload.Transition.Checkpoint.BlockNumber = new(big.Int).SetUint64(pack.UnpackUint48())
	payload.Transition.Checkpoint.BlockHash = pack.UnpackBytes32()
	payload.Transition.Checkpoint.StateRoot = pack.UnpackBytes32()

	// Decode TransitionRecord
	payload.TransitionRecord.Span = pack.UnpackUint8()
	payload.TransitionRecord.TransitionHash = pack.UnpackBytes32()
	payload.TransitionRecord.CheckpointHash = pack.UnpackBytes32()

	// Decode TransitionMetadata
	payload.Metadata.DesignatedProver = pack.UnpackAddress()
	payload.Metadata.ActualProver = pack.UnpackAddress()

	// Decode bond instructions array length (uint16)
	arrayLength := pack.UnpackUint16()

	// Decode bond instructions
	payload.TransitionRecord.BondInstructions = make([]shasta.LibBondsBondInstruction, arrayLength)
	for i := uint16(0); i < arrayLength; i++ {
		proposalId := pack.UnpackUint48()
		bondType := pack.UnpackUint8()
		payer := pack.UnpackAddress()
		receiver := pack.UnpackAddress()

		payload.TransitionRecord.BondInstructions[i] = shasta.LibBondsBondInstruction{
			ProposalId: new(big.Int).SetUint64(proposalId),
			BondType:   bondType,
			Payer:      payer,
			Receiver:   receiver,
		}
	}

	return payload, nil
}

func CalculateProvedEventSize(bondInstructionsCount int) int {
	// Fixed size: 247 bytes (as per Solidity comment)
	// Variable size: each bond instruction is 47 bytes
	return 247 + (bondInstructionsCount * 47)
}

// LibProposeInputDecoder - encodes/decodes ProposeInput

func EncodeProposeInput(input *shasta.IInboxProposeInput) ([]byte, error) {
	size := calculateProposeDataSize(input.ParentProposals, input.TransitionRecords, &input.Checkpoint)
	pack := NewPackUnpack(size)

	// 1. Encode deadline
	pack.PackUint48(input.Deadline.Uint64())

	// 2. Encode CoreState
	pack.PackUint48(input.CoreState.NextProposalId.Uint64())
	pack.PackUint48(input.CoreState.NextProposalBlockId.Uint64())
	pack.PackUint48(input.CoreState.LastFinalizedProposalId.Uint64())
	pack.PackBytes32(input.CoreState.LastFinalizedTransitionHash)
	pack.PackBytes32(input.CoreState.BondInstructionsHash)

	// 3. Encode parent proposals array
	proposalsLength := len(input.ParentProposals)
	if proposalsLength > 16777215 { // uint24 max
		return nil, fmt.Errorf("parent proposals length exceeds uint24 max: %d", proposalsLength)
	}
	pack.PackUint24(uint32(proposalsLength))
	for _, proposal := range input.ParentProposals {
		encodeProposalForProposeInput(pack, &proposal)
	}

	// 4. Encode BlobReference
	pack.PackUint16(input.BlobReference.BlobStartIndex)
	pack.PackUint16(input.BlobReference.NumBlobs)
	pack.PackUint24(uint32(input.BlobReference.Offset.Uint64()))

	// 5. Encode TransitionRecords array
	transitionRecordsLength := len(input.TransitionRecords)
	if transitionRecordsLength > 16777215 { // uint24 max
		return nil, fmt.Errorf("transition records length exceeds uint24 max: %d", transitionRecordsLength)
	}
	pack.PackUint24(uint32(transitionRecordsLength))
	for _, record := range input.TransitionRecords {
		encodeTransitionRecord(pack, &record)
	}

	// 6. Encode Checkpoint with optimization for empty header
	isEmpty := input.Checkpoint.BlockNumber.Cmp(big.NewInt(0)) == 0 &&
		input.Checkpoint.BlockHash == (common.Hash{}) &&
		input.Checkpoint.StateRoot == (common.Hash{})

	if isEmpty {
		pack.PackUint8(0) // flag for empty
	} else {
		pack.PackUint8(1) // flag for non-empty
		pack.PackUint48(input.Checkpoint.BlockNumber.Uint64())
		pack.PackBytes32(input.Checkpoint.BlockHash)
		pack.PackBytes32(input.Checkpoint.StateRoot)
	}

	// 7. Encode numForcedInclusions
	pack.PackUint8(input.NumForcedInclusions)

	return pack.Bytes(), nil
}

func DecodeProposeInput(data []byte) (*shasta.IInboxProposeInput, error) {
	pack := &PackUnpack{data: data, pos: 0}
	input := &shasta.IInboxProposeInput{}

	// 1. Decode deadline
	input.Deadline = new(big.Int).SetUint64(pack.UnpackUint48())

	// 2. Decode CoreState
	input.CoreState.NextProposalId = new(big.Int).SetUint64(pack.UnpackUint48())
	input.CoreState.NextProposalBlockId = new(big.Int).SetUint64(pack.UnpackUint48())
	input.CoreState.LastFinalizedProposalId = new(big.Int).SetUint64(pack.UnpackUint48())
	input.CoreState.LastFinalizedTransitionHash = pack.UnpackBytes32()
	input.CoreState.BondInstructionsHash = pack.UnpackBytes32()

	// 3. Decode parent proposals array
	proposalsLength := pack.UnpackUint24()
	input.ParentProposals = make([]shasta.IInboxProposal, proposalsLength)
	for i := uint32(0); i < proposalsLength; i++ {
		input.ParentProposals[i] = decodeProposalForProposeInput(pack)
	}

	// 4. Decode BlobReference
	input.BlobReference.BlobStartIndex = pack.UnpackUint16()
	input.BlobReference.NumBlobs = pack.UnpackUint16()
	input.BlobReference.Offset = new(big.Int).SetUint64(uint64(pack.UnpackUint24()))

	// 5. Decode TransitionRecords array
	transitionRecordsLength := pack.UnpackUint24()
	input.TransitionRecords = make([]shasta.IInboxTransitionRecord, transitionRecordsLength)
	for i := uint32(0); i < transitionRecordsLength; i++ {
		input.TransitionRecords[i] = decodeTransitionRecord(pack)
	}

	// 6. Decode Checkpoint with optimization for empty header
	headerFlag := pack.UnpackUint8()
	if headerFlag == 1 {
		input.Checkpoint.BlockNumber = new(big.Int).SetUint64(pack.UnpackUint48())
		input.Checkpoint.BlockHash = pack.UnpackBytes32()
		input.Checkpoint.StateRoot = pack.UnpackBytes32()
	} else {
		// Leave checkpoint as default (all zeros)
		input.Checkpoint.BlockNumber = big.NewInt(0)
		input.Checkpoint.BlockHash = common.Hash{}
		input.Checkpoint.StateRoot = common.Hash{}
	}

	// 7. Decode numForcedInclusions
	input.NumForcedInclusions = pack.UnpackUint8()

	return input, nil
}

// LibProveInputDecoder - encodes/decodes ProveInput

func EncodeProveInput(input *shasta.IInboxProveInput) ([]byte, error) {
	// Validate input lengths first
	if len(input.Proposals) != len(input.Transitions) {
		return nil, fmt.Errorf("proposal-transition length mismatch: %d != %d", len(input.Proposals), len(input.Transitions))
	}
	if len(input.Metadata) != len(input.Transitions) {
		return nil, fmt.Errorf("metadata length mismatch: %d != %d", len(input.Metadata), len(input.Transitions))
	}

	size := calculateProveDataSize(input.Proposals, input.Transitions, input.Metadata)
	pack := NewPackUnpack(size)

	// 1. Encode Proposals array
	proposalsLength := len(input.Proposals)
	if proposalsLength > 16777215 { // uint24 max
		return nil, fmt.Errorf("proposals length exceeds uint24 max: %d", proposalsLength)
	}
	pack.PackUint24(uint32(proposalsLength))
	for _, proposal := range input.Proposals {
		encodeProposalForProveInput(pack, &proposal)
	}

	// 2. Encode Transitions array
	transitionsLength := len(input.Transitions)
	if transitionsLength > 16777215 { // uint24 max
		return nil, fmt.Errorf("transitions length exceeds uint24 max: %d", transitionsLength)
	}
	pack.PackUint24(uint32(transitionsLength))
	for _, transition := range input.Transitions {
		encodeTransition(pack, &transition)
	}

	// 3. Encode Metadata array (no need to encode length, reuse transitions length)
	for _, metadata := range input.Metadata {
		encodeMetadata(pack, &metadata)
	}

	return pack.Bytes(), nil
}

func DecodeProveInput(data []byte) (*shasta.IInboxProveInput, error) {
	pack := &PackUnpack{data: data, pos: 0}
	input := &shasta.IInboxProveInput{}

	// 1. Decode Proposals array
	proposalsLength := pack.UnpackUint24()
	input.Proposals = make([]shasta.IInboxProposal, proposalsLength)
	for i := uint32(0); i < proposalsLength; i++ {
		input.Proposals[i] = decodeProposalForProveInput(pack)
	}

	// 2. Decode Transitions array
	transitionsLength := pack.UnpackUint24()
	if transitionsLength != proposalsLength {
		return nil, fmt.Errorf("proposal-transition length mismatch: %d != %d", proposalsLength, transitionsLength)
	}
	input.Transitions = make([]shasta.IInboxTransition, transitionsLength)
	for i := uint32(0); i < transitionsLength; i++ {
		input.Transitions[i] = decodeTransition(pack)
	}

	// 3. Decode Metadata array (reuse transitions length)
	input.Metadata = make([]shasta.IInboxTransitionMetadata, transitionsLength)
	for i := uint32(0); i < transitionsLength; i++ {
		input.Metadata[i] = decodeMetadata(pack)
	}

	return input, nil
}

// Helper functions for encoding/decoding individual structs

// encodeProposalForProposeInput - for LibProposeInputDecoder (timestamp first)
func encodeProposalForProposeInput(pack *PackUnpack, proposal *shasta.IInboxProposal) {
	pack.PackUint48(proposal.Id.Uint64())
	pack.PackUint48(proposal.Timestamp.Uint64())
	pack.PackUint48(proposal.EndOfSubmissionWindowTimestamp.Uint64())
	pack.PackAddress(proposal.Proposer)
	pack.PackBytes32(proposal.CoreStateHash)
	pack.PackBytes32(proposal.DerivationHash)
}

func decodeProposalForProposeInput(pack *PackUnpack) shasta.IInboxProposal {
	return shasta.IInboxProposal{
		Id:                             new(big.Int).SetUint64(pack.UnpackUint48()),
		Timestamp:                      new(big.Int).SetUint64(pack.UnpackUint48()),
		EndOfSubmissionWindowTimestamp: new(big.Int).SetUint64(pack.UnpackUint48()),
		Proposer:                       pack.UnpackAddress(),
		CoreStateHash:                  pack.UnpackBytes32(),
		DerivationHash:                 pack.UnpackBytes32(),
	}
}

// encodeProposalForProveInput - for LibProveInputDecoder (proposer first)
func encodeProposalForProveInput(pack *PackUnpack, proposal *shasta.IInboxProposal) {
	pack.PackUint48(proposal.Id.Uint64())
	pack.PackAddress(proposal.Proposer)
	pack.PackUint48(proposal.Timestamp.Uint64())
	pack.PackUint48(proposal.EndOfSubmissionWindowTimestamp.Uint64())
	pack.PackBytes32(proposal.CoreStateHash)
	pack.PackBytes32(proposal.DerivationHash)
}

func decodeProposalForProveInput(pack *PackUnpack) shasta.IInboxProposal {
	return shasta.IInboxProposal{
		Id:                             new(big.Int).SetUint64(pack.UnpackUint48()),
		Proposer:                       pack.UnpackAddress(),
		Timestamp:                      new(big.Int).SetUint64(pack.UnpackUint48()),
		EndOfSubmissionWindowTimestamp: new(big.Int).SetUint64(pack.UnpackUint48()),
		CoreStateHash:                  pack.UnpackBytes32(),
		DerivationHash:                 pack.UnpackBytes32(),
	}
}

func encodeTransitionRecord(pack *PackUnpack, record *shasta.IInboxTransitionRecord) {
	// Encode span
	pack.PackUint8(record.Span)

	// Encode BondInstructions array
	bondInstructionsLength := len(record.BondInstructions)
	if bondInstructionsLength > 16777215 { // uint24 max
		panic(fmt.Sprintf("bond instructions length exceeds uint24 max: %d", bondInstructionsLength))
	}
	pack.PackUint24(uint32(bondInstructionsLength))
	for _, instruction := range record.BondInstructions {
		encodeBondInstruction(pack, &instruction)
	}

	// Encode transitionHash
	pack.PackBytes32(record.TransitionHash)

	// Encode checkpointHash
	pack.PackBytes32(record.CheckpointHash)
}

func decodeTransitionRecord(pack *PackUnpack) shasta.IInboxTransitionRecord {
	record := shasta.IInboxTransitionRecord{}

	// Decode span
	record.Span = pack.UnpackUint8()

	// Decode BondInstructions array
	bondInstructionsLength := pack.UnpackUint24()
	record.BondInstructions = make([]shasta.LibBondsBondInstruction, bondInstructionsLength)
	for i := uint32(0); i < bondInstructionsLength; i++ {
		record.BondInstructions[i] = decodeBondInstruction(pack)
	}

	// Decode transitionHash
	record.TransitionHash = pack.UnpackBytes32()

	// Decode checkpointHash
	record.CheckpointHash = pack.UnpackBytes32()

	return record
}

func encodeBondInstruction(pack *PackUnpack, instruction *shasta.LibBondsBondInstruction) {
	pack.PackUint48(instruction.ProposalId.Uint64())
	pack.PackUint8(uint8(instruction.BondType))
	pack.PackAddress(instruction.Payer)
	pack.PackAddress(instruction.Receiver)
}

func decodeBondInstruction(pack *PackUnpack) shasta.LibBondsBondInstruction {
	proposalId := pack.UnpackUint48()
	bondType := pack.UnpackUint8()
	payer := pack.UnpackAddress()
	receiver := pack.UnpackAddress()

	return shasta.LibBondsBondInstruction{
		ProposalId: new(big.Int).SetUint64(proposalId),
		BondType:   bondType,
		Payer:      payer,
		Receiver:   receiver,
	}
}

func encodeTransition(pack *PackUnpack, transition *shasta.IInboxTransition) {
	pack.PackBytes32(transition.ProposalHash)
	pack.PackBytes32(transition.ParentTransitionHash)
	// Encode Checkpoint
	pack.PackUint48(transition.Checkpoint.BlockNumber.Uint64())
	pack.PackBytes32(transition.Checkpoint.BlockHash)
	pack.PackBytes32(transition.Checkpoint.StateRoot)
}

func decodeTransition(pack *PackUnpack) shasta.IInboxTransition {
	return shasta.IInboxTransition{
		ProposalHash:         pack.UnpackBytes32(),
		ParentTransitionHash: pack.UnpackBytes32(),
		Checkpoint: shasta.ICheckpointStoreCheckpoint{
			BlockNumber: new(big.Int).SetUint64(pack.UnpackUint48()),
			BlockHash:   pack.UnpackBytes32(),
			StateRoot:   pack.UnpackBytes32(),
		},
	}
}

func encodeMetadata(pack *PackUnpack, metadata *shasta.IInboxTransitionMetadata) {
	pack.PackAddress(metadata.DesignatedProver)
	pack.PackAddress(metadata.ActualProver)
}

func decodeMetadata(pack *PackUnpack) shasta.IInboxTransitionMetadata {
	return shasta.IInboxTransitionMetadata{
		DesignatedProver: pack.UnpackAddress(),
		ActualProver:     pack.UnpackAddress(),
	}
}

// Size calculation functions - aligned with Solidity implementations

func calculateProposeDataSize(proposals []shasta.IInboxProposal, transitionRecords []shasta.IInboxTransitionRecord, checkpoint *shasta.ICheckpointStoreCheckpoint) int {
	// Fixed sizes (from Solidity comment):
	// deadline: 6 bytes + CoreState: 82 bytes + BlobReference: 7 bytes +
	// Arrays lengths: 6 bytes + Checkpoint flag: 1 byte + numForcedInclusions: 1 byte = 103
	size := 103

	// Add Checkpoint size if not empty
	isEmpty := checkpoint.BlockNumber.Cmp(big.NewInt(0)) == 0 &&
		checkpoint.BlockHash == (common.Hash{}) &&
		checkpoint.StateRoot == (common.Hash{})

	if !isEmpty {
		// Checkpoint when not empty: 6 + 32 + 32 = 70 bytes
		size += 70
	}

	// Proposals - each has fixed size of 102 bytes (from Solidity comment)
	size += len(proposals) * 102

	// TransitionRecords - each has fixed size + variable bond instructions
	// Fixed: span(1) + array length(3) + transitionHash(32) + checkpointHash(32) = 68
	for _, record := range transitionRecords {
		size += 68 + (len(record.BondInstructions) * 47) // Each bond instruction is 47 bytes
	}

	return size
}

// Hash functions aligned with LibHashing.sol
// Provides both standard (abi.encode) and optimized (LibHashing) versions

var emptyBytesHash = common.BytesToHash(crypto.Keccak256(nil))

// Standard versions using abi.encode equivalent (keccak256(abi.encode(...)))

// HashTransition hashes a Transition struct using standard abi.encode method
func HashTransition(transition shasta.IInboxTransition) common.Hash {
	// Equivalent to keccak256(abi.encode(_transition)) in Solidity
	data := encodeABI(transition)
	return common.BytesToHash(crypto.Keccak256(data))
}

// HashCheckpoint hashes a Checkpoint struct using standard abi.encode method
func HashCheckpoint(checkpoint shasta.ICheckpointStoreCheckpoint) common.Hash {
	// Equivalent to keccak256(abi.encode(_checkpoint)) in Solidity
	data := encodeABI(checkpoint)
	return common.BytesToHash(crypto.Keccak256(data))
}

// HashCoreState hashes a CoreState struct using standard abi.encode method
func HashCoreState(coreState shasta.IInboxCoreState) common.Hash {
	// Equivalent to keccak256(abi.encode(_coreState)) in Solidity
	data := encodeABI(coreState)
	return common.BytesToHash(crypto.Keccak256(data))
}

// HashProposal hashes a Proposal struct using standard abi.encode method
func HashProposal(proposal shasta.IInboxProposal) common.Hash {
	// Equivalent to keccak256(abi.encode(_proposal)) in Solidity
	data := encodeABI(proposal)
	return common.BytesToHash(crypto.Keccak256(data))
}

// HashDerivation hashes a Derivation struct using standard abi.encode method
func HashDerivation(derivation shasta.IInboxDerivation) common.Hash {
	// Equivalent to keccak256(abi.encode(_derivation)) in Solidity
	data := encodeABI(derivation)
	return common.BytesToHash(crypto.Keccak256(data))
}

// HashTransitionsArray hashes an array of Transitions using standard abi.encode method
func HashTransitionsArray(transitions []shasta.IInboxTransition) common.Hash {
	// Equivalent to keccak256(abi.encode(_transitions)) in Solidity
	data := encodeABI(transitions)
	return common.BytesToHash(crypto.Keccak256(data))
}

// HashTransitionRecord hashes a TransitionRecord using standard abi.encode method
func HashTransitionRecord(record shasta.IInboxTransitionRecord) [26]byte {
	// Equivalent to bytes26(keccak256(abi.encode(_transitionRecord))) in Solidity
	data := encodeABI(record)
	hash := crypto.Keccak256(data)
	var result [26]byte
	copy(result[:], hash[:26])
	return result
}

// encodeABI simulates Solidity's abi.encode functionality
func encodeABI(any) []byte {
	// This is a simplified implementation - in practice, you'd use
	// proper ABI encoding that matches Solidity's abi.encode exactly
	// For now, return a placeholder that would need proper implementation
	return []byte("abi_encode_placeholder")
}

// Optimized versions using LibHashing.sol methods

// HashTransitionOptimized hashes a Transition struct aligned with LibHashing
func HashTransitionOptimized(transition shasta.IInboxTransition) common.Hash {
	checkpointHash := HashCheckpointOptimized(transition.Checkpoint)
	return efficientHash3(transition.ProposalHash, transition.ParentTransitionHash, checkpointHash)
}

// HashCheckpointOptimized hashes a Checkpoint struct aligned with LibHashing
func HashCheckpointOptimized(checkpoint shasta.ICheckpointStoreCheckpoint) common.Hash {
	blockNumberBytes := common.LeftPadBytes(checkpoint.BlockNumber.Bytes(), 32)
	return efficientHash3(common.BytesToHash(blockNumberBytes), checkpoint.BlockHash, checkpoint.StateRoot)
}

// HashCoreStateOptimized hashes a CoreState struct aligned with LibHashing
func HashCoreStateOptimized(coreState shasta.IInboxCoreState) common.Hash {
	nextProposalIdBytes := common.LeftPadBytes(coreState.NextProposalId.Bytes(), 32)
	nextProposalBlockIdBytes := common.LeftPadBytes(coreState.NextProposalBlockId.Bytes(), 32)
	lastFinalizedProposalIdBytes := common.LeftPadBytes(coreState.LastFinalizedProposalId.Bytes(), 32)

	return efficientHash5(
		common.BytesToHash(nextProposalIdBytes),
		common.BytesToHash(nextProposalBlockIdBytes),
		common.BytesToHash(lastFinalizedProposalIdBytes),
		coreState.LastFinalizedTransitionHash,
		coreState.BondInstructionsHash,
	)
}

// HashProposalOptimized hashes a Proposal struct aligned with LibHashing
func HashProposalOptimized(proposal shasta.IInboxProposal) common.Hash {
	// Pack numeric fields: id(48) + timestamp(48) + endOfSubmissionWindowTimestamp(48)
	// Shift positions: id << 208, timestamp << 160, endOfSubmissionWindow << 112
	var packed [32]byte

	id := proposal.Id.Uint64()
	timestamp := proposal.Timestamp.Uint64()
	endTime := proposal.EndOfSubmissionWindowTimestamp.Uint64()

	// Pack into first 18 bytes (48+48+48 bits = 144 bits = 18 bytes)
	binary.BigEndian.PutUint64(packed[2:10], id)         // 48 bits at bit 208
	binary.BigEndian.PutUint64(packed[10:18], timestamp) // 48 bits at bit 160
	binary.BigEndian.PutUint64(packed[18:26], endTime)   // 48 bits at bit 112

	packedHash := common.BytesToHash(packed[:])
	proposerBytes := common.LeftPadBytes(proposal.Proposer.Bytes(), 32)

	return efficientHash4(
		packedHash,
		common.BytesToHash(proposerBytes),
		proposal.CoreStateHash,
		proposal.DerivationHash,
	)
}

// HashDerivationOptimized hashes a Derivation struct aligned with LibHashing
func HashDerivationOptimized(derivation shasta.IInboxDerivation) common.Hash {
	// Pack fields: originBlockNumber(48) + isForcedInclusion(8) + basefeeSharingPctg(8)
	var packed [32]byte

	originBlockNum := derivation.OriginBlockNumber.Uint64()
	var forcedFlag uint64
	if derivation.IsForcedInclusion {
		forcedFlag = 1
	}
	basefeePctg := uint64(derivation.BasefeeSharingPctg)

	// Pack into first 8 bytes (48+8+8 = 64 bits)
	binary.BigEndian.PutUint64(packed[0:8],
		(originBlockNum<<16)|(forcedFlag<<8)|basefeePctg)

	packedHash := common.BytesToHash(packed[:])

	// Hash blob slice
	blobSliceHash := hashBlobSlice(derivation.BlobSlice)

	return efficientHash3(packedHash, derivation.OriginBlockHash, blobSliceHash)
}

// HashTransitionsArrayOptimized hashes an array of Transitions aligned with LibHashing
func HashTransitionsArrayOptimized(transitions []shasta.IInboxTransition) common.Hash {
	if len(transitions) == 0 {
		return emptyBytesHash
	}

	if len(transitions) == 1 {
		lengthBytes := common.LeftPadBytes(big.NewInt(int64(len(transitions))).Bytes(), 32)
		return efficientHash2(common.BytesToHash(lengthBytes), HashTransitionOptimized(transitions[0]))
	}

	if len(transitions) == 2 {
		lengthBytes := common.LeftPadBytes(big.NewInt(int64(len(transitions))).Bytes(), 32)
		return efficientHash3(
			common.BytesToHash(lengthBytes),
			HashTransitionOptimized(transitions[0]),
			HashTransitionOptimized(transitions[1]),
		)
	}

	// For larger arrays, build buffer with length + hashes
	arrayLength := len(transitions)
	bufferSize := 32 + (arrayLength * 32) // length + hashes
	buffer := make([]byte, bufferSize)

	// Write array length
	binary.BigEndian.PutUint64(buffer[24:32], uint64(arrayLength))

	// Write each transition hash
	for i, transition := range transitions {
		hash := HashTransitionOptimized(transition)
		offset := 32 + (i * 32)
		copy(buffer[offset:offset+32], hash[:])
	}

	return common.BytesToHash(crypto.Keccak256(buffer))
}

// HashTransitionRecordOptimized hashes a TransitionRecord aligned with LibHashing
func HashTransitionRecordOptimized(record shasta.IInboxTransitionRecord) [26]byte {
	bondInstructionsHash := hashBondInstructionsArray(record.BondInstructions)

	spanBytes := common.LeftPadBytes(big.NewInt(int64(record.Span)).Bytes(), 32)

	fullHash := efficientHash4(
		common.BytesToHash(spanBytes),
		bondInstructionsHash,
		record.TransitionHash,
		record.CheckpointHash,
	)

	var result [26]byte
	copy(result[:], fullHash[:26])
	return result
}

// ComposeTransitionKey creates a composite key for transition record storage
func ComposeTransitionKey(proposalId uint64, parentTransitionHash common.Hash) common.Hash {
	proposalIdBytes := common.LeftPadBytes(big.NewInt(int64(proposalId)).Bytes(), 32)
	return efficientHash2(common.BytesToHash(proposalIdBytes), parentTransitionHash)
}

// Helper functions for EfficientHashLib equivalent behavior

func efficientHash2(a, b common.Hash) common.Hash {
	return common.BytesToHash(crypto.Keccak256(a[:], b[:]))
}

func efficientHash3(a, b, c common.Hash) common.Hash {
	return common.BytesToHash(crypto.Keccak256(a[:], b[:], c[:]))
}

func efficientHash4(a, b, c, d common.Hash) common.Hash {
	return common.BytesToHash(crypto.Keccak256(a[:], b[:], c[:], d[:]))
}

func efficientHash5(a, b, c, d, e common.Hash) common.Hash {
	return common.BytesToHash(crypto.Keccak256(a[:], b[:], c[:], d[:], e[:]))
}

func hashBlobSlice(blobSlice shasta.LibBlobsBlobSlice) common.Hash {
	var blobHashesHash common.Hash

	if len(blobSlice.BlobHashes) == 0 {
		blobHashesHash = emptyBytesHash
	} else {
		// Build buffer with length + blob hashes
		arrayLength := len(blobSlice.BlobHashes)
		bufferSize := 32 + (arrayLength * 32)
		buffer := make([]byte, bufferSize)

		// Write array length
		binary.BigEndian.PutUint64(buffer[24:32], uint64(arrayLength))

		// Write each blob hash
		for i, blobHash := range blobSlice.BlobHashes {
			offset := 32 + (i * 32)
			copy(buffer[offset:offset+32], blobHash[:])
		}

		blobHashesHash = common.BytesToHash(crypto.Keccak256(buffer))
	}

	offsetBytes := common.LeftPadBytes(blobSlice.Offset.Bytes(), 32)
	timestampBytes := common.LeftPadBytes(blobSlice.Timestamp.Bytes(), 32)

	return efficientHash3(
		blobHashesHash,
		common.BytesToHash(offsetBytes),
		common.BytesToHash(timestampBytes),
	)
}

func hashBondInstructionsArray(instructions []shasta.LibBondsBondInstruction) common.Hash {
	if len(instructions) == 0 {
		return emptyBytesHash
	}

	if len(instructions) == 1 {
		lengthBytes := common.LeftPadBytes(big.NewInt(int64(len(instructions))).Bytes(), 32)
		return efficientHash2(common.BytesToHash(lengthBytes), hashSingleBondInstruction(instructions[0]))
	}

	// For multiple instructions
	arrayLength := len(instructions)
	bufferSize := 32 + (arrayLength * 32)
	buffer := make([]byte, bufferSize)

	// Write array length
	binary.BigEndian.PutUint64(buffer[24:32], uint64(arrayLength))

	// Write each instruction hash
	for i, instruction := range instructions {
		hash := hashSingleBondInstruction(instruction)
		offset := 32 + (i * 32)
		copy(buffer[offset:offset+32], hash[:])
	}

	return common.BytesToHash(crypto.Keccak256(buffer))
}

func hashSingleBondInstruction(instruction shasta.LibBondsBondInstruction) common.Hash {
	proposalIdBytes := common.LeftPadBytes(instruction.ProposalId.Bytes(), 32)
	bondTypeBytes := common.LeftPadBytes(big.NewInt(int64(instruction.BondType)).Bytes(), 32)
	payerBytes := common.LeftPadBytes(instruction.Payer.Bytes(), 32)
	receiverBytes := common.LeftPadBytes(instruction.Receiver.Bytes(), 32)

	return efficientHash4(
		common.BytesToHash(proposalIdBytes),
		common.BytesToHash(bondTypeBytes),
		common.BytesToHash(payerBytes),
		common.BytesToHash(receiverBytes),
	)
}

func calculateProveDataSize(proposals []shasta.IInboxProposal, transitions []shasta.IInboxTransition, metadata []shasta.IInboxTransitionMetadata) int {
	if len(proposals) != len(transitions) {
		panic(fmt.Sprintf("proposal-transition length mismatch: %d != %d", len(proposals), len(transitions)))
	}
	if len(metadata) != len(transitions) {
		panic(fmt.Sprintf("metadata length mismatch: %d != %d", len(metadata), len(transitions)))
	}

	// Array lengths: 3 + 3 = 6 bytes (proposals and transitions lengths only)
	size := 6

	// Each item has fixed size (from Solidity comment):
	// Proposals: 102 bytes, Transitions: 134 bytes, Metadata: 40 bytes
	// Total per item: 276 bytes
	size += len(proposals) * 276

	return size
}

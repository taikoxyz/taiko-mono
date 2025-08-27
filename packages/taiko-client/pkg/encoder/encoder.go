package encoder

import (
	"fmt"
	"math/big"

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

// Encoder provides unified encoding and decoding for all Shasta protocol data structures
type Encoder struct{}

// NewEncoder creates a new Encoder instance
func NewEncoder() *Encoder {
	return &Encoder{}
}

// =====================================================
// ProposedEvent Encoding/Decoding
// =====================================================

// EncodeProposedEvent encodes a ProposedEventPayload into bytes using compact encoding
func (e *Encoder) EncodeProposedEvent(payload *shastaBindings.IInboxProposedEventPayload) ([]byte, error) {
	// Calculate total size needed
	bufferSize := e.calculateProposedEventSize(len(payload.Derivation.BlobSlice.BlobHashes))
	data := make([]byte, bufferSize)
	
	pos := 0
	
	// Encode Proposal
	pos = PackUint48(data, pos, payload.Proposal.Id.Uint64())
	pos = PackAddress(data, pos, payload.Proposal.Proposer)
	pos = PackUint48(data, pos, payload.Proposal.Timestamp.Uint64())
	pos = PackUint48(data, pos, payload.Derivation.OriginBlockNumber.Uint64())
	
	// Encode isForcedInclusion as uint8 (1 for true, 0 for false)
	forcedInclusionValue := uint8(0)
	if payload.Derivation.IsForcedInclusion {
		forcedInclusionValue = 1
	}
	pos = PackUint8(data, pos, forcedInclusionValue)
	pos = PackUint8(data, pos, payload.Derivation.BasefeeSharingPctg)
	
	// Encode BlobSlice
	// First encode the length of blobHashes array as uint24
	blobHashesLength := len(payload.Derivation.BlobSlice.BlobHashes)
	if !CheckArrayLength(blobHashesLength) {
		return nil, fmt.Errorf("blob hashes array length exceeds maximum: %d", blobHashesLength)
	}
	pos = PackUint24(data, pos, uint32(blobHashesLength))
	
	// Encode each blob hash
	for _, blobHash := range payload.Derivation.BlobSlice.BlobHashes {
		pos = PackBytes32(data, pos, blobHash)
	}
	
	pos = PackUint24(data, pos, uint32(payload.Derivation.BlobSlice.Offset.Uint64()))
	pos = PackUint48(data, pos, payload.Derivation.BlobSlice.Timestamp.Uint64())
	
	pos = PackBytes32(data, pos, payload.Proposal.CoreStateHash)
	
	// Encode CoreState
	pos = PackUint48(data, pos, payload.CoreState.NextProposalId.Uint64())
	pos = PackUint48(data, pos, payload.CoreState.LastFinalizedProposalId.Uint64())
	pos = PackBytes32(data, pos, payload.CoreState.LastFinalizedTransitionHash)
	_ = PackBytes32(data, pos, payload.CoreState.BondInstructionsHash)
	
	return data, nil
}

// DecodeProposedEvent decodes bytes into a ProposedEventPayload using compact encoding
func (e *Encoder) DecodeProposedEvent(data []byte) (*shastaBindings.IInboxProposedEventPayload, error) {
	payload := &shastaBindings.IInboxProposedEventPayload{}
	pos := 0
	
	// Decode Proposal
	proposalId, newPos := UnpackUint48(data, pos)
	payload.Proposal.Id = new(big.Int).SetUint64(proposalId)
	pos = newPos
	
	payload.Proposal.Proposer, pos = UnpackAddress(data, pos)
	
	timestamp, newPos := UnpackUint48(data, pos)
	payload.Proposal.Timestamp = new(big.Int).SetUint64(timestamp)
	pos = newPos
	
	// Decode Derivation fields
	originBlockNumber, newPos := UnpackUint48(data, pos)
	payload.Derivation.OriginBlockNumber = new(big.Int).SetUint64(originBlockNumber)
	pos = newPos
	
	isForcedInclusion, newPos := UnpackUint8(data, pos)
	payload.Derivation.IsForcedInclusion = isForcedInclusion != 0
	pos = newPos
	
	payload.Derivation.BasefeeSharingPctg, pos = UnpackUint8(data, pos)
	
	// Decode BlobSlice
	blobHashesLength, newPos := UnpackUint24(data, pos)
	pos = newPos
	
	payload.Derivation.BlobSlice.BlobHashes = make([][32]byte, blobHashesLength)
	for i := uint32(0); i < blobHashesLength; i++ {
		payload.Derivation.BlobSlice.BlobHashes[i], pos = UnpackBytes32(data, pos)
	}
	
	offset, newPos := UnpackUint24(data, pos)
	payload.Derivation.BlobSlice.Offset = new(big.Int).SetUint64(uint64(offset))
	pos = newPos
	
	blobTimestamp, newPos := UnpackUint48(data, pos)
	payload.Derivation.BlobSlice.Timestamp = new(big.Int).SetUint64(blobTimestamp)
	pos = newPos
	
	payload.Proposal.CoreStateHash, pos = UnpackBytes32(data, pos)
	
	// Decode CoreState
	nextProposalId, newPos := UnpackUint48(data, pos)
	payload.CoreState.NextProposalId = new(big.Int).SetUint64(nextProposalId)
	pos = newPos
	
	lastFinalizedProposalId, newPos := UnpackUint48(data, pos)
	payload.CoreState.LastFinalizedProposalId = new(big.Int).SetUint64(lastFinalizedProposalId)
	pos = newPos
	
	payload.CoreState.LastFinalizedTransitionHash, pos = UnpackBytes32(data, pos)
	payload.CoreState.BondInstructionsHash, _ = UnpackBytes32(data, pos)
	
	return payload, nil
}

// =====================================================
// ProposeInput Encoding/Decoding
// =====================================================

// EncodeProposeInput encodes ProposeInput data using compact encoding
func (e *Encoder) EncodeProposeInput(input *shastaBindings.IInboxProposeInput) ([]byte, error) {
	// Calculate total size needed
	bufferSize := e.calculateProposeDataSize(input)
	data := make([]byte, bufferSize)
	
	pos := 0
	
	// 1. Encode deadline
	pos = PackUint48(data, pos, input.Deadline.Uint64())
	
	// 2. Encode CoreState
	pos = PackUint48(data, pos, input.CoreState.NextProposalId.Uint64())
	pos = PackUint48(data, pos, input.CoreState.LastFinalizedProposalId.Uint64())
	pos = PackBytes32(data, pos, input.CoreState.LastFinalizedTransitionHash)
	pos = PackBytes32(data, pos, input.CoreState.BondInstructionsHash)
	
	// 3. Encode parent proposals array
	if !CheckArrayLength(len(input.ParentProposals)) {
		return nil, fmt.Errorf("parent proposals array length exceeds maximum: %d", len(input.ParentProposals))
	}
	pos = PackUint24(data, pos, uint32(len(input.ParentProposals)))
	for _, proposal := range input.ParentProposals {
		pos = e.encodeProposal(data, pos, &proposal)
	}
	
	// 4. Encode BlobReference
	pos = PackUint16(data, pos, input.BlobReference.BlobStartIndex)
	pos = PackUint16(data, pos, input.BlobReference.NumBlobs)
	pos = PackUint24(data, pos, uint32(input.BlobReference.Offset.Uint64()))
	
	// 5. Encode TransitionRecords array
	if !CheckArrayLength(len(input.TransitionRecords)) {
		return nil, fmt.Errorf("transition records array length exceeds maximum: %d", len(input.TransitionRecords))
	}
	pos = PackUint24(data, pos, uint32(len(input.TransitionRecords)))
	for _, record := range input.TransitionRecords {
		pos = e.encodeTransitionRecord(data, pos, &record)
	}
	
	// 6. Encode BlockMiniHeader with optimization for empty header
	isEmpty := input.EndBlockMiniHeader.Number.Cmp(big.NewInt(0)) == 0 &&
		input.EndBlockMiniHeader.Hash == [32]byte{} &&
		input.EndBlockMiniHeader.StateRoot == [32]byte{}
	
	if isEmpty {
		pos = PackUint8(data, pos, 0)
	} else {
		pos = PackUint8(data, pos, 1)
		pos = PackUint48(data, pos, input.EndBlockMiniHeader.Number.Uint64())
		pos = PackBytes32(data, pos, input.EndBlockMiniHeader.Hash)
		_ = PackBytes32(data, pos, input.EndBlockMiniHeader.StateRoot)
	}
	
	return data, nil
}

// DecodeProposeInput decodes propose data using optimized operations
func (e *Encoder) DecodeProposeInput(data []byte) (*shastaBindings.IInboxProposeInput, error) {
	input := &shastaBindings.IInboxProposeInput{}
	pos := 0
	
	// 1. Decode deadline
	deadline, newPos := UnpackUint48(data, pos)
	input.Deadline = new(big.Int).SetUint64(deadline)
	pos = newPos
	
	// 2. Decode CoreState
	nextProposalId, newPos := UnpackUint48(data, pos)
	input.CoreState.NextProposalId = new(big.Int).SetUint64(nextProposalId)
	pos = newPos
	
	lastFinalizedProposalId, newPos := UnpackUint48(data, pos)
	input.CoreState.LastFinalizedProposalId = new(big.Int).SetUint64(lastFinalizedProposalId)
	pos = newPos
	
	input.CoreState.LastFinalizedTransitionHash, pos = UnpackBytes32(data, pos)
	input.CoreState.BondInstructionsHash, pos = UnpackBytes32(data, pos)
	
	// 3. Decode parent proposals array
	proposalsLength, newPos := UnpackUint24(data, pos)
	pos = newPos
	
	input.ParentProposals = make([]shastaBindings.IInboxProposal, proposalsLength)
	for i := uint32(0); i < proposalsLength; i++ {
		proposal, newPos := e.decodeProposal(data, pos)
		input.ParentProposals[i] = *proposal
		pos = newPos
	}
	
	// 4. Decode BlobReference
	blobStartIndex, newPos := UnpackUint16(data, pos)
	input.BlobReference.BlobStartIndex = blobStartIndex
	pos = newPos
	
	numBlobs, newPos := UnpackUint16(data, pos)
	input.BlobReference.NumBlobs = numBlobs
	pos = newPos
	
	offset, newPos := UnpackUint24(data, pos)
	input.BlobReference.Offset = new(big.Int).SetUint64(uint64(offset))
	pos = newPos
	
	// 5. Decode TransitionRecords array
	transitionRecordsLength, newPos := UnpackUint24(data, pos)
	pos = newPos
	
	input.TransitionRecords = make([]shastaBindings.IInboxTransitionRecord, transitionRecordsLength)
	for i := uint32(0); i < transitionRecordsLength; i++ {
		record, newPos := e.decodeTransitionRecord(data, pos)
		input.TransitionRecords[i] = *record
		pos = newPos
	}
	
	// 6. Decode BlockMiniHeader with optimization for empty header
	headerFlag, newPos := UnpackUint8(data, pos)
	pos = newPos
	
	if headerFlag == 1 {
		number, newPos := UnpackUint48(data, pos)
		input.EndBlockMiniHeader.Number = new(big.Int).SetUint64(number)
		pos = newPos
		
		input.EndBlockMiniHeader.Hash, pos = UnpackBytes32(data, pos)
		input.EndBlockMiniHeader.StateRoot, _ = UnpackBytes32(data, pos)
	} else {
		// Initialize with zero values
		input.EndBlockMiniHeader.Number = big.NewInt(0)
		input.EndBlockMiniHeader.Hash = [32]byte{}
		input.EndBlockMiniHeader.StateRoot = [32]byte{}
	}
	
	return input, nil
}

// =====================================================
// ProvedEvent Encoding/Decoding
// =====================================================

// ProvedEventPayload represents the proved event payload structure
type ProvedEventPayload struct {
	ProposalId        *big.Int
	Transition        shastaBindings.IInboxTransition
	TransitionRecord  shastaBindings.IInboxTransitionRecord
}

// EncodeProvedEvent encodes a ProvedEventPayload into bytes using compact encoding
func (e *Encoder) EncodeProvedEvent(payload *ProvedEventPayload) ([]byte, error) {
	// For now, we don't handle bond instructions
	bondInstructionsCount := 0
	
	// Calculate total size needed
	bufferSize := e.calculateProvedEventSize(bondInstructionsCount)
	data := make([]byte, bufferSize)
	
	pos := 0
	
	// Encode proposalId (uint48)
	pos = PackUint48(data, pos, payload.ProposalId.Uint64())
	
	// Encode Transition struct
	pos = PackBytes32(data, pos, payload.Transition.ProposalHash)
	pos = PackBytes32(data, pos, payload.Transition.ParentTransitionHash)
	
	// Encode BlockMiniHeader
	pos = PackUint48(data, pos, payload.Transition.EndBlockMiniHeader.Number.Uint64())
	pos = PackBytes32(data, pos, payload.Transition.EndBlockMiniHeader.Hash)
	pos = PackBytes32(data, pos, payload.Transition.EndBlockMiniHeader.StateRoot)
	pos = PackAddress(data, pos, payload.Transition.DesignatedProver)
	pos = PackAddress(data, pos, payload.Transition.ActualProver)
	
	// Encode TransitionRecord
	pos = PackUint8(data, pos, payload.TransitionRecord.Span)
	pos = PackBytes32(data, pos, payload.TransitionRecord.TransitionHash)
	pos = PackBytes32(data, pos, payload.TransitionRecord.EndBlockMiniHeaderHash)
	
	// Encode bond instructions array length (uint16)
	// For now, we encode 0 bond instructions
	_ = PackUint16(data, pos, 0)
	
	return data, nil
}

// DecodeProvedEvent decodes bytes into a ProvedEventPayload using compact encoding
func (e *Encoder) DecodeProvedEvent(data []byte) (*ProvedEventPayload, error) {
	payload := &ProvedEventPayload{}
	pos := 0
	
	// Decode proposalId (uint48)
	proposalId, newPos := UnpackUint48(data, pos)
	payload.ProposalId = new(big.Int).SetUint64(proposalId)
	pos = newPos
	
	// Decode Transition struct
	payload.Transition.ProposalHash, pos = UnpackBytes32(data, pos)
	payload.Transition.ParentTransitionHash, pos = UnpackBytes32(data, pos)
	
	// Decode BlockMiniHeader
	number, newPos := UnpackUint48(data, pos)
	payload.Transition.EndBlockMiniHeader.Number = new(big.Int).SetUint64(number)
	pos = newPos
	
	payload.Transition.EndBlockMiniHeader.Hash, pos = UnpackBytes32(data, pos)
	payload.Transition.EndBlockMiniHeader.StateRoot, pos = UnpackBytes32(data, pos)
	payload.Transition.DesignatedProver, pos = UnpackAddress(data, pos)
	payload.Transition.ActualProver, pos = UnpackAddress(data, pos)
	
	// Decode TransitionRecord
	payload.TransitionRecord.Span, pos = UnpackUint8(data, pos)
	payload.TransitionRecord.TransitionHash, pos = UnpackBytes32(data, pos)
	payload.TransitionRecord.EndBlockMiniHeaderHash, pos = UnpackBytes32(data, pos)
	
	// Decode bond instructions array length (uint16)
	arrayLength, newPos := UnpackUint16(data, pos)
	pos = newPos
	
	// For now, we don't handle bond instructions decoding
	if arrayLength > 0 {
		return nil, fmt.Errorf("bond instructions decoding not implemented")
	}
	
	return payload, nil
}

// =====================================================
// ProveInput Encoding/Decoding
// =====================================================

// EncodeProveInput encodes prove input data using compact encoding
func (e *Encoder) EncodeProveInput(input *shastaBindings.IInboxProveInput) ([]byte, error) {
	// Calculate total size needed
	bufferSize := e.calculateProveDataSize(input.Proposals, input.Transitions)
	data := make([]byte, bufferSize)
	
	pos := 0
	
	// 1. Encode Proposals array
	if !CheckArrayLength(len(input.Proposals)) {
		return nil, fmt.Errorf("proposals array length exceeds maximum: %d", len(input.Proposals))
	}
	pos = PackUint24(data, pos, uint32(len(input.Proposals)))
	for _, proposal := range input.Proposals {
		pos = e.encodeProposal(data, pos, &proposal)
	}
	
	// 2. Encode Transitions array
	if !CheckArrayLength(len(input.Transitions)) {
		return nil, fmt.Errorf("transitions array length exceeds maximum: %d", len(input.Transitions))
	}
	pos = PackUint24(data, pos, uint32(len(input.Transitions)))
	for _, transition := range input.Transitions {
		pos = e.encodeTransition(data, pos, &transition)
	}
	
	return data, nil
}

// DecodeProveInput decodes prove input data using optimized operations
func (e *Encoder) DecodeProveInput(data []byte) (*shastaBindings.IInboxProveInput, error) {
	input := &shastaBindings.IInboxProveInput{}
	pos := 0
	
	// 1. Decode Proposals array
	proposalsLength, newPos := UnpackUint24(data, pos)
	pos = newPos
	
	input.Proposals = make([]shastaBindings.IInboxProposal, proposalsLength)
	for i := uint32(0); i < proposalsLength; i++ {
		proposal, newPos := e.decodeProposal(data, pos)
		input.Proposals[i] = *proposal
		pos = newPos
	}
	
	// 2. Decode Transitions array
	transitionsLength, newPos := UnpackUint24(data, pos)
	pos = newPos
	
	if transitionsLength != proposalsLength {
		return nil, fmt.Errorf("proposal and transition array lengths mismatch: %d != %d", 
			proposalsLength, transitionsLength)
	}
	
	input.Transitions = make([]shastaBindings.IInboxTransition, transitionsLength)
	for i := uint32(0); i < transitionsLength; i++ {
		transition, newPos := e.decodeTransition(data, pos)
		input.Transitions[i] = *transition
		pos = newPos
	}
	
	return input, nil
}

// =====================================================
// Helper Functions
// =====================================================

// encodeProposal encodes a single Proposal
func (e *Encoder) encodeProposal(data []byte, pos int, proposal *shastaBindings.IInboxProposal) int {
	pos = PackUint48(data, pos, proposal.Id.Uint64())
	pos = PackAddress(data, pos, proposal.Proposer)
	pos = PackUint48(data, pos, proposal.Timestamp.Uint64())
	pos = PackBytes32(data, pos, proposal.CoreStateHash)
	pos = PackBytes32(data, pos, proposal.DerivationHash)
	return pos
}

// decodeProposal decodes a single Proposal
func (e *Encoder) decodeProposal(data []byte, pos int) (*shastaBindings.IInboxProposal, int) {
	proposal := &shastaBindings.IInboxProposal{}
	
	id, newPos := UnpackUint48(data, pos)
	proposal.Id = new(big.Int).SetUint64(id)
	pos = newPos
	
	proposal.Proposer, pos = UnpackAddress(data, pos)
	
	timestamp, newPos := UnpackUint48(data, pos)
	proposal.Timestamp = new(big.Int).SetUint64(timestamp)
	pos = newPos
	
	proposal.CoreStateHash, pos = UnpackBytes32(data, pos)
	proposal.DerivationHash, pos = UnpackBytes32(data, pos)
	
	return proposal, pos
}

// encodeTransition encodes a single Transition
func (e *Encoder) encodeTransition(data []byte, pos int, transition *shastaBindings.IInboxTransition) int {
	pos = PackBytes32(data, pos, transition.ProposalHash)
	pos = PackBytes32(data, pos, transition.ParentTransitionHash)
	
	// Encode BlockMiniHeader
	pos = PackUint48(data, pos, transition.EndBlockMiniHeader.Number.Uint64())
	pos = PackBytes32(data, pos, transition.EndBlockMiniHeader.Hash)
	pos = PackBytes32(data, pos, transition.EndBlockMiniHeader.StateRoot)
	pos = PackAddress(data, pos, transition.DesignatedProver)
	pos = PackAddress(data, pos, transition.ActualProver)
	
	return pos
}

// decodeTransition decodes a single Transition
func (e *Encoder) decodeTransition(data []byte, pos int) (*shastaBindings.IInboxTransition, int) {
	transition := &shastaBindings.IInboxTransition{}
	
	transition.ProposalHash, pos = UnpackBytes32(data, pos)
	transition.ParentTransitionHash, pos = UnpackBytes32(data, pos)
	
	// Decode BlockMiniHeader
	number, newPos := UnpackUint48(data, pos)
	transition.EndBlockMiniHeader.Number = new(big.Int).SetUint64(number)
	pos = newPos
	
	transition.EndBlockMiniHeader.Hash, pos = UnpackBytes32(data, pos)
	transition.EndBlockMiniHeader.StateRoot, pos = UnpackBytes32(data, pos)
	transition.DesignatedProver, pos = UnpackAddress(data, pos)
	transition.ActualProver, pos = UnpackAddress(data, pos)
	
	return transition, pos
}

// encodeTransitionRecord encodes a single TransitionRecord
func (e *Encoder) encodeTransitionRecord(data []byte, pos int, record *shastaBindings.IInboxTransitionRecord) int {
	// Encode span
	pos = PackUint8(data, pos, record.Span)
	
	// Encode transitionHash
	pos = PackBytes32(data, pos, record.TransitionHash)
	
	// Encode endBlockMiniHeaderHash
	pos = PackBytes32(data, pos, record.EndBlockMiniHeaderHash)
	
	// Note: BondInstructions array encoding would go here if needed
	// For now, we encode an empty array
	pos = PackUint24(data, pos, 0)
	
	return pos
}

// decodeTransitionRecord decodes a single TransitionRecord
func (e *Encoder) decodeTransitionRecord(data []byte, pos int) (*shastaBindings.IInboxTransitionRecord, int) {
	record := &shastaBindings.IInboxTransitionRecord{}
	
	// Decode span
	record.Span, pos = UnpackUint8(data, pos)
	
	// Decode transitionHash
	record.TransitionHash, pos = UnpackBytes32(data, pos)
	
	// Decode endBlockMiniHeaderHash
	record.EndBlockMiniHeaderHash, pos = UnpackBytes32(data, pos)
	
	// Note: BondInstructions array decoding would go here if needed
	// For now, we skip the empty array
	_, pos = UnpackUint24(data, pos)
	
	return record, pos
}

// =====================================================
// Size Calculation Functions
// =====================================================

// calculateProposedEventSize calculates the exact byte size needed for encoding a ProposedEvent
func (e *Encoder) calculateProposedEventSize(blobHashesCount int) int {
	// Fixed size: 160 bytes
	// Proposal: id(6) + proposer(20) + timestamp(6) + originBlockNumber(6) +
	//           isForcedInclusion(1) + basefeeSharingPctg(1) = 40
	// BlobSlice: arrayLength(3) + offset(3) + timestamp(6) = 12
	// coreStateHash: 32
	// CoreState: nextProposalId(6) + lastFinalizedProposalId(6) +
	//           lastFinalizedTransitionHash(32) + bondInstructionsHash(32) = 76
	// Total fixed: 40 + 12 + 32 + 76 = 160
	
	// Variable size: each blob hash is 32 bytes
	return 160 + (blobHashesCount * 32)
}

// calculateProposeDataSize calculates the size needed for encoding
func (e *Encoder) calculateProposeDataSize(input *shastaBindings.IInboxProposeInput) int {
	// Fixed sizes:
	// deadline: 6 bytes (uint48)
	// CoreState: 6 + 6 + 32 + 32 = 76 bytes
	// BlobReference: 2 + 2 + 3 = 7 bytes
	// Arrays lengths: 3 + 3 = 6 bytes
	// BlockMiniHeader flag: 1 byte
	size := 96
	
	// Add BlockMiniHeader size if not empty
	isEmpty := input.EndBlockMiniHeader.Number.Cmp(big.NewInt(0)) == 0 &&
		input.EndBlockMiniHeader.Hash == [32]byte{} &&
		input.EndBlockMiniHeader.StateRoot == [32]byte{}
	
	if !isEmpty {
		// BlockMiniHeader when not empty: 6 + 32 + 32 = 70 bytes
		size += 70
	}
	
	// Proposals - each has fixed size
	// Fixed proposal fields: id(6) + proposer(20) + timestamp(6) + coreStateHash(32) +
	// derivationHash(32) = 96
	size += len(input.ParentProposals) * 96
	
	// TransitionRecords - each has fixed size + variable bond instructions
	// Fixed: span(1) + transitionHash(32) + endBlockMiniHeaderHash(32) + array length(3) = 68
	// For now, assuming no bond instructions (0 length array)
	size += len(input.TransitionRecords) * 68
	
	return size
}

// calculateProvedEventSize calculates the exact byte size needed for encoding a ProvedEventPayload
func (e *Encoder) calculateProvedEventSize(bondInstructionsCount int) int {
	// Fixed size: 247 bytes
	// proposalId: 6
	// Transition: proposalHash(32) + parentTransitionHash(32) = 64
	//        BlockMiniHeader: number(6) + hash(32) + stateRoot(32) = 70
	//        designatedProver(20) + actualProver(20) = 40
	// TransitionRecord: span(1) + transitionHash(32) + endBlockMiniHeaderHash(32) = 65
	// bondInstructions array length: 2
	// Total fixed: 6 + 64 + 70 + 40 + 65 + 2 = 247
	
	// Variable size: each bond instruction is 47 bytes
	// proposalId(6) + bondType(1) + payer(20) + receiver(20) = 47
	return 247 + (bondInstructionsCount * 47)
}

// calculateProveDataSize calculates the size needed for encoding
func (e *Encoder) calculateProveDataSize(
	proposals []shastaBindings.IInboxProposal,
	transitions []shastaBindings.IInboxTransition,
) int {
	if len(proposals) != len(transitions) {
		// Should not happen in valid input
		return 0
	}
	
	// Array lengths: 3 + 3 = 6 bytes
	size := 6
	
	// Proposals - each has fixed size
	// Fixed proposal fields: id(6) + proposer(20) + timestamp(6) + coreStateHash(32) +
	// derivationHash(32) = 96
	//
	// Transitions - each has fixed size: proposalHash(32) + parentTransitionHash(32) +
	// BlockMiniHeader(6 + 32 + 32) + designatedProver(20) + actualProver(20) = 174
	//
	size += len(proposals) * 270
	
	return size
}
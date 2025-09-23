package encoding

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

func TestPackUnpack(t *testing.T) {
	pack := NewPackUnpack(100)

	// Test uint8
	pack.PackUint8(0xFF)
	assert.Equal(t, 1, pack.pos)

	// Test uint16
	pack.PackUint16(0x1234)
	assert.Equal(t, 3, pack.pos)

	// Test uint24
	pack.PackUint24(0x123456)
	assert.Equal(t, 6, pack.pos)

	// Test uint48
	pack.PackUint48(0x123456789ABC)
	assert.Equal(t, 12, pack.pos)

	// Test address
	addr := common.HexToAddress("0x1234567890123456789012345678901234567890")
	pack.PackAddress(addr)
	assert.Equal(t, 32, pack.pos)

	// Test bytes32
	hash := common.HexToHash("0x1234567890123456789012345678901234567890123456789012345678901234")
	pack.PackBytes32(hash)
	assert.Equal(t, 64, pack.pos)

	// Reset and unpack
	pack.Reset(pack.data)

	// Test unpack
	assert.Equal(t, uint8(0xFF), pack.UnpackUint8())
	assert.Equal(t, uint16(0x1234), pack.UnpackUint16())
	assert.Equal(t, uint32(0x123456), pack.UnpackUint24())
	assert.Equal(t, uint64(0x123456789ABC), pack.UnpackUint48())
	assert.Equal(t, addr, pack.UnpackAddress())
	assert.Equal(t, hash, pack.UnpackBytes32())
}

func TestProposedEventEncodeDecode(t *testing.T) {
	// Create test payload
	payload := &shasta.IInboxProposedEventPayload{
		Proposal: shasta.IInboxProposal{
			Id:                             big.NewInt(123),
			Proposer:                       common.HexToAddress("0x1234567890123456789012345678901234567890"),
			Timestamp:                      big.NewInt(1234567890),
			EndOfSubmissionWindowTimestamp: big.NewInt(1234567999),
			CoreStateHash:                  common.HexToHash("0x1111111111111111111111111111111111111111111111111111111111111111"),
			DerivationHash:                 common.HexToHash("0x2222222222222222222222222222222222222222222222222222222222222222"),
		},
		Derivation: shasta.IInboxDerivation{
			OriginBlockNumber:  big.NewInt(456),
			OriginBlockHash:    common.HexToHash("0x3333333333333333333333333333333333333333333333333333333333333333"),
			IsForcedInclusion:  true,
			BasefeeSharingPctg: 25,
			BlobSlice: shasta.LibBlobsBlobSlice{
				BlobHashes: [][32]byte{
					common.HexToHash("0x4444444444444444444444444444444444444444444444444444444444444444"),
					common.HexToHash("0x5555555555555555555555555555555555555555555555555555555555555555"),
				},
				Offset:    big.NewInt(100),
				Timestamp: big.NewInt(1234567800),
			},
		},
		CoreState: shasta.IInboxCoreState{
			NextProposalId:              big.NewInt(124),
			NextProposalBlockId:         big.NewInt(457),
			LastFinalizedProposalId:     big.NewInt(122),
			LastFinalizedTransitionHash: common.HexToHash("0x6666666666666666666666666666666666666666666666666666666666666666"),
			BondInstructionsHash:        common.HexToHash("0x7777777777777777777777777777777777777777777777777777777777777777"),
		},
	}

	// Test encoding
	encoded, err := EncodeProposedEvent(payload)
	require.NoError(t, err)
	require.NotEmpty(t, encoded)

	// Test size calculation
	expectedSize := CalculateProposedEventSize(len(payload.Derivation.BlobSlice.BlobHashes))
	assert.Equal(t, expectedSize, len(encoded))

	// Test decoding
	decoded, err := DecodeProposedEvent(encoded)
	require.NoError(t, err)

	// Verify all fields
	assert.Equal(t, payload.Proposal.Id.Uint64(), decoded.Proposal.Id.Uint64())
	assert.Equal(t, payload.Proposal.Proposer, decoded.Proposal.Proposer)
	assert.Equal(t, payload.Proposal.Timestamp.Uint64(), decoded.Proposal.Timestamp.Uint64())
	assert.Equal(t, payload.Proposal.EndOfSubmissionWindowTimestamp.Uint64(), decoded.Proposal.EndOfSubmissionWindowTimestamp.Uint64())
	assert.Equal(t, payload.Proposal.CoreStateHash, decoded.Proposal.CoreStateHash)
	assert.Equal(t, payload.Proposal.DerivationHash, decoded.Proposal.DerivationHash)

	assert.Equal(t, payload.Derivation.OriginBlockNumber.Uint64(), decoded.Derivation.OriginBlockNumber.Uint64())
	assert.Equal(t, payload.Derivation.OriginBlockHash, decoded.Derivation.OriginBlockHash)
	assert.Equal(t, payload.Derivation.IsForcedInclusion, decoded.Derivation.IsForcedInclusion)
	assert.Equal(t, payload.Derivation.BasefeeSharingPctg, decoded.Derivation.BasefeeSharingPctg)

	assert.Equal(t, len(payload.Derivation.BlobSlice.BlobHashes), len(decoded.Derivation.BlobSlice.BlobHashes))
	for i, hash := range payload.Derivation.BlobSlice.BlobHashes {
		assert.Equal(t, hash, decoded.Derivation.BlobSlice.BlobHashes[i])
	}
	assert.Equal(t, payload.Derivation.BlobSlice.Offset.Uint64(), decoded.Derivation.BlobSlice.Offset.Uint64())
	assert.Equal(t, payload.Derivation.BlobSlice.Timestamp.Uint64(), decoded.Derivation.BlobSlice.Timestamp.Uint64())

	assert.Equal(t, payload.CoreState.NextProposalId.Uint64(), decoded.CoreState.NextProposalId.Uint64())
	assert.Equal(t, payload.CoreState.NextProposalBlockId.Uint64(), decoded.CoreState.NextProposalBlockId.Uint64())
	assert.Equal(t, payload.CoreState.LastFinalizedProposalId.Uint64(), decoded.CoreState.LastFinalizedProposalId.Uint64())
	assert.Equal(t, payload.CoreState.LastFinalizedTransitionHash, decoded.CoreState.LastFinalizedTransitionHash)
	assert.Equal(t, payload.CoreState.BondInstructionsHash, decoded.CoreState.BondInstructionsHash)
}

func TestProvedEventEncodeDecode(t *testing.T) {
	// Create test payload
	payload := &shasta.IInboxProvedEventPayload{
		ProposalId: big.NewInt(123),
		Transition: shasta.IInboxTransition{
			ProposalHash:         common.HexToHash("0x1111111111111111111111111111111111111111111111111111111111111111"),
			ParentTransitionHash: common.HexToHash("0x2222222222222222222222222222222222222222222222222222222222222222"),
			Checkpoint: shasta.ICheckpointStoreCheckpoint{
				BlockNumber: big.NewInt(456),
				BlockHash:   common.HexToHash("0x3333333333333333333333333333333333333333333333333333333333333333"),
				StateRoot:   common.HexToHash("0x4444444444444444444444444444444444444444444444444444444444444444"),
			},
		},
		TransitionRecord: shasta.IInboxTransitionRecord{
			Span:           5,
			TransitionHash: common.HexToHash("0x5555555555555555555555555555555555555555555555555555555555555555"),
			CheckpointHash: common.HexToHash("0x6666666666666666666666666666666666666666666666666666666666666666"),
			BondInstructions: []shasta.LibBondsBondInstruction{
				{
					ProposalId: big.NewInt(122),
					BondType:   1,
					Payer:      common.HexToAddress("0x1111111111111111111111111111111111111111"),
					Receiver:   common.HexToAddress("0x2222222222222222222222222222222222222222"),
				},
				{
					ProposalId: big.NewInt(123),
					BondType:   2,
					Payer:      common.HexToAddress("0x3333333333333333333333333333333333333333"),
					Receiver:   common.HexToAddress("0x4444444444444444444444444444444444444444"),
				},
			},
		},
		Metadata: shasta.IInboxTransitionMetadata{
			DesignatedProver: common.HexToAddress("0x5555555555555555555555555555555555555555"),
			ActualProver:     common.HexToAddress("0x6666666666666666666666666666666666666666"),
		},
	}

	// Test encoding
	encoded, err := EncodeProvedEvent(payload)
	require.NoError(t, err)
	require.NotEmpty(t, encoded)

	// Test size calculation
	expectedSize := CalculateProvedEventSize(len(payload.TransitionRecord.BondInstructions))
	assert.Equal(t, expectedSize, len(encoded))

	// Test decoding
	decoded, err := DecodeProvedEvent(encoded)
	require.NoError(t, err)

	// Verify all fields
	assert.Equal(t, payload.ProposalId.Uint64(), decoded.ProposalId.Uint64())
	assert.Equal(t, payload.Transition.ProposalHash, decoded.Transition.ProposalHash)
	assert.Equal(t, payload.Transition.ParentTransitionHash, decoded.Transition.ParentTransitionHash)
	assert.Equal(t, payload.Transition.Checkpoint.BlockNumber.Uint64(), decoded.Transition.Checkpoint.BlockNumber.Uint64())
	assert.Equal(t, payload.Transition.Checkpoint.BlockHash, decoded.Transition.Checkpoint.BlockHash)
	assert.Equal(t, payload.Transition.Checkpoint.StateRoot, decoded.Transition.Checkpoint.StateRoot)

	assert.Equal(t, payload.TransitionRecord.Span, decoded.TransitionRecord.Span)
	assert.Equal(t, payload.TransitionRecord.TransitionHash, decoded.TransitionRecord.TransitionHash)
	assert.Equal(t, payload.TransitionRecord.CheckpointHash, decoded.TransitionRecord.CheckpointHash)

	assert.Equal(t, len(payload.TransitionRecord.BondInstructions), len(decoded.TransitionRecord.BondInstructions))
	for i, instruction := range payload.TransitionRecord.BondInstructions {
		assert.Equal(t, instruction.ProposalId.Uint64(), decoded.TransitionRecord.BondInstructions[i].ProposalId.Uint64())
		assert.Equal(t, instruction.BondType, decoded.TransitionRecord.BondInstructions[i].BondType)
		assert.Equal(t, instruction.Payer, decoded.TransitionRecord.BondInstructions[i].Payer)
		assert.Equal(t, instruction.Receiver, decoded.TransitionRecord.BondInstructions[i].Receiver)
	}

	assert.Equal(t, payload.Metadata.DesignatedProver, decoded.Metadata.DesignatedProver)
	assert.Equal(t, payload.Metadata.ActualProver, decoded.Metadata.ActualProver)
}

func TestProposeInputEncodeDecode(t *testing.T) {
	// Create test input
	input := &shasta.IInboxProposeInput{
		Deadline: big.NewInt(1234567890),
		CoreState: shasta.IInboxCoreState{
			NextProposalId:              big.NewInt(124),
			NextProposalBlockId:         big.NewInt(457),
			LastFinalizedProposalId:     big.NewInt(122),
			LastFinalizedTransitionHash: common.HexToHash("0x1111111111111111111111111111111111111111111111111111111111111111"),
			BondInstructionsHash:        common.HexToHash("0x2222222222222222222222222222222222222222222222222222222222222222"),
		},
		ParentProposals: []shasta.IInboxProposal{
			{
				Id:                             big.NewInt(123),
				Timestamp:                      big.NewInt(1234567890),
				EndOfSubmissionWindowTimestamp: big.NewInt(1234567999),
				Proposer:                       common.HexToAddress("0x1234567890123456789012345678901234567890"),
				CoreStateHash:                  common.HexToHash("0x3333333333333333333333333333333333333333333333333333333333333333"),
				DerivationHash:                 common.HexToHash("0x4444444444444444444444444444444444444444444444444444444444444444"),
			},
		},
		BlobReference: shasta.LibBlobsBlobReference{
			BlobStartIndex: 0,
			NumBlobs:       2,
			Offset:         big.NewInt(100),
		},
		TransitionRecords: []shasta.IInboxTransitionRecord{
			{
				Span:           5,
				TransitionHash: common.HexToHash("0x5555555555555555555555555555555555555555555555555555555555555555"),
				CheckpointHash: common.HexToHash("0x6666666666666666666666666666666666666666666666666666666666666666"),
				BondInstructions: []shasta.LibBondsBondInstruction{
					{
						ProposalId: big.NewInt(122),
						BondType:   1,
						Payer:      common.HexToAddress("0x1111111111111111111111111111111111111111"),
						Receiver:   common.HexToAddress("0x2222222222222222222222222222222222222222"),
					},
				},
			},
		},
		Checkpoint: shasta.ICheckpointStoreCheckpoint{
			BlockNumber: big.NewInt(456),
			BlockHash:   common.HexToHash("0x7777777777777777777777777777777777777777777777777777777777777777"),
			StateRoot:   common.HexToHash("0x8888888888888888888888888888888888888888888888888888888888888888"),
		},
		NumForcedInclusions: 3,
	}

	// Test encoding
	encoded, err := EncodeProposeInput(input)
	require.NoError(t, err)
	require.NotEmpty(t, encoded)

	// Test decoding
	decoded, err := DecodeProposeInput(encoded)
	require.NoError(t, err)

	// Verify all fields
	assert.Equal(t, input.Deadline.Uint64(), decoded.Deadline.Uint64())

	assert.Equal(t, input.CoreState.NextProposalId.Uint64(), decoded.CoreState.NextProposalId.Uint64())
	assert.Equal(t, input.CoreState.NextProposalBlockId.Uint64(), decoded.CoreState.NextProposalBlockId.Uint64())
	assert.Equal(t, input.CoreState.LastFinalizedProposalId.Uint64(), decoded.CoreState.LastFinalizedProposalId.Uint64())
	assert.Equal(t, input.CoreState.LastFinalizedTransitionHash, decoded.CoreState.LastFinalizedTransitionHash)
	assert.Equal(t, input.CoreState.BondInstructionsHash, decoded.CoreState.BondInstructionsHash)

	assert.Equal(t, len(input.ParentProposals), len(decoded.ParentProposals))
	for i, proposal := range input.ParentProposals {
		assert.Equal(t, proposal.Id.Uint64(), decoded.ParentProposals[i].Id.Uint64())
		assert.Equal(t, proposal.Timestamp.Uint64(), decoded.ParentProposals[i].Timestamp.Uint64())
		assert.Equal(t, proposal.EndOfSubmissionWindowTimestamp.Uint64(), decoded.ParentProposals[i].EndOfSubmissionWindowTimestamp.Uint64())
		assert.Equal(t, proposal.Proposer, decoded.ParentProposals[i].Proposer)
		assert.Equal(t, proposal.CoreStateHash, decoded.ParentProposals[i].CoreStateHash)
		assert.Equal(t, proposal.DerivationHash, decoded.ParentProposals[i].DerivationHash)
	}

	assert.Equal(t, input.BlobReference.BlobStartIndex, decoded.BlobReference.BlobStartIndex)
	assert.Equal(t, input.BlobReference.NumBlobs, decoded.BlobReference.NumBlobs)
	assert.Equal(t, input.BlobReference.Offset.Uint64(), decoded.BlobReference.Offset.Uint64())

	assert.Equal(t, len(input.TransitionRecords), len(decoded.TransitionRecords))
	for i, record := range input.TransitionRecords {
		assert.Equal(t, record.Span, decoded.TransitionRecords[i].Span)
		assert.Equal(t, record.TransitionHash, decoded.TransitionRecords[i].TransitionHash)
		assert.Equal(t, record.CheckpointHash, decoded.TransitionRecords[i].CheckpointHash)
		assert.Equal(t, len(record.BondInstructions), len(decoded.TransitionRecords[i].BondInstructions))
		for j, instruction := range record.BondInstructions {
			assert.Equal(t, instruction.ProposalId.Uint64(), decoded.TransitionRecords[i].BondInstructions[j].ProposalId.Uint64())
			assert.Equal(t, instruction.BondType, decoded.TransitionRecords[i].BondInstructions[j].BondType)
			assert.Equal(t, instruction.Payer, decoded.TransitionRecords[i].BondInstructions[j].Payer)
			assert.Equal(t, instruction.Receiver, decoded.TransitionRecords[i].BondInstructions[j].Receiver)
		}
	}

	assert.Equal(t, input.Checkpoint.BlockNumber.Uint64(), decoded.Checkpoint.BlockNumber.Uint64())
	assert.Equal(t, input.Checkpoint.BlockHash, decoded.Checkpoint.BlockHash)
	assert.Equal(t, input.Checkpoint.StateRoot, decoded.Checkpoint.StateRoot)

	assert.Equal(t, input.NumForcedInclusions, decoded.NumForcedInclusions)
}

func TestProposeInputEncodeDecodeEmptyCheckpoint(t *testing.T) {
	// Create test input with empty checkpoint
	input := &shasta.IInboxProposeInput{
		Deadline: big.NewInt(1234567890),
		CoreState: shasta.IInboxCoreState{
			NextProposalId:              big.NewInt(124),
			NextProposalBlockId:         big.NewInt(457),
			LastFinalizedProposalId:     big.NewInt(122),
			LastFinalizedTransitionHash: common.HexToHash("0x1111111111111111111111111111111111111111111111111111111111111111"),
			BondInstructionsHash:        common.HexToHash("0x2222222222222222222222222222222222222222222222222222222222222222"),
		},
		ParentProposals: []shasta.IInboxProposal{},
		BlobReference: shasta.LibBlobsBlobReference{
			BlobStartIndex: 0,
			NumBlobs:       1,
			Offset:         big.NewInt(0),
		},
		TransitionRecords: []shasta.IInboxTransitionRecord{},
		Checkpoint: shasta.ICheckpointStoreCheckpoint{
			BlockNumber: big.NewInt(0),
			BlockHash:   common.Hash{},
			StateRoot:   common.Hash{},
		},
		NumForcedInclusions: 0,
	}

	// Test encoding
	encoded, err := EncodeProposeInput(input)
	require.NoError(t, err)
	require.NotEmpty(t, encoded)

	// Test decoding
	decoded, err := DecodeProposeInput(encoded)
	require.NoError(t, err)

	// Verify checkpoint is empty
	assert.Equal(t, int64(0), decoded.Checkpoint.BlockNumber.Int64())
	assert.Equal(t, [32]byte{}, decoded.Checkpoint.BlockHash)
	assert.Equal(t, [32]byte{}, decoded.Checkpoint.StateRoot)
}

func TestProveInputEncodeDecode(t *testing.T) {
	// Create test input
	input := &shasta.IInboxProveInput{
		Proposals: []shasta.IInboxProposal{
			{
				Id:                             big.NewInt(123),
				Proposer:                       common.HexToAddress("0x1234567890123456789012345678901234567890"),
				Timestamp:                      big.NewInt(1234567890),
				EndOfSubmissionWindowTimestamp: big.NewInt(1234567999),
				CoreStateHash:                  common.HexToHash("0x1111111111111111111111111111111111111111111111111111111111111111"),
				DerivationHash:                 common.HexToHash("0x2222222222222222222222222222222222222222222222222222222222222222"),
			},
		},
		Transitions: []shasta.IInboxTransition{
			{
				ProposalHash:         common.HexToHash("0x3333333333333333333333333333333333333333333333333333333333333333"),
				ParentTransitionHash: common.HexToHash("0x4444444444444444444444444444444444444444444444444444444444444444"),
				Checkpoint: shasta.ICheckpointStoreCheckpoint{
					BlockNumber: big.NewInt(456),
					BlockHash:   common.HexToHash("0x5555555555555555555555555555555555555555555555555555555555555555"),
					StateRoot:   common.HexToHash("0x6666666666666666666666666666666666666666666666666666666666666666"),
				},
			},
		},
		Metadata: []shasta.IInboxTransitionMetadata{
			{
				DesignatedProver: common.HexToAddress("0x7777777777777777777777777777777777777777"),
				ActualProver:     common.HexToAddress("0x8888888888888888888888888888888888888888"),
			},
		},
	}

	// Test encoding
	encoded, err := EncodeProveInput(input)
	require.NoError(t, err)
	require.NotEmpty(t, encoded)

	// Test decoding
	decoded, err := DecodeProveInput(encoded)
	require.NoError(t, err)

	// Verify all fields
	assert.Equal(t, len(input.Proposals), len(decoded.Proposals))
	for i, proposal := range input.Proposals {
		assert.Equal(t, proposal.Id.Uint64(), decoded.Proposals[i].Id.Uint64())
		assert.Equal(t, proposal.Proposer, decoded.Proposals[i].Proposer)
		assert.Equal(t, proposal.Timestamp.Uint64(), decoded.Proposals[i].Timestamp.Uint64())
		assert.Equal(t, proposal.EndOfSubmissionWindowTimestamp.Uint64(), decoded.Proposals[i].EndOfSubmissionWindowTimestamp.Uint64())
		assert.Equal(t, proposal.CoreStateHash, decoded.Proposals[i].CoreStateHash)
		assert.Equal(t, proposal.DerivationHash, decoded.Proposals[i].DerivationHash)
	}

	assert.Equal(t, len(input.Transitions), len(decoded.Transitions))
	for i, transition := range input.Transitions {
		assert.Equal(t, transition.ProposalHash, decoded.Transitions[i].ProposalHash)
		assert.Equal(t, transition.ParentTransitionHash, decoded.Transitions[i].ParentTransitionHash)
		assert.Equal(t, transition.Checkpoint.BlockNumber.Uint64(), decoded.Transitions[i].Checkpoint.BlockNumber.Uint64())
		assert.Equal(t, transition.Checkpoint.BlockHash, decoded.Transitions[i].Checkpoint.BlockHash)
		assert.Equal(t, transition.Checkpoint.StateRoot, decoded.Transitions[i].Checkpoint.StateRoot)
	}

	assert.Equal(t, len(input.Metadata), len(decoded.Metadata))
	for i, metadata := range input.Metadata {
		assert.Equal(t, metadata.DesignatedProver, decoded.Metadata[i].DesignatedProver)
		assert.Equal(t, metadata.ActualProver, decoded.Metadata[i].ActualProver)
	}
}

func TestProposalEncodingDifference(t *testing.T) {
	// Test that different contexts use different proposal encoding orders
	proposal := &shasta.IInboxProposal{
		Id:                             big.NewInt(123),
		Proposer:                       common.HexToAddress("0x1234567890123456789012345678901234567890"),
		Timestamp:                      big.NewInt(1234567890),
		EndOfSubmissionWindowTimestamp: big.NewInt(1234567999),
		CoreStateHash:                  common.HexToHash("0x1111111111111111111111111111111111111111111111111111111111111111"),
		DerivationHash:                 common.HexToHash("0x2222222222222222222222222222222222222222222222222222222222222222"),
	}

	// Encode with both functions
	pack1 := NewPackUnpack(102) // Fixed proposal size
	encodeProposalForProposeInput(pack1, proposal)
	data1 := pack1.Bytes()

	pack2 := NewPackUnpack(102)
	encodeProposalForProveInput(pack2, proposal)
	data2 := pack2.Bytes()

	// They should produce different encoded data due to different field ordering
	assert.NotEqual(t, data1, data2, "Different proposal encoding functions should produce different results")

	// But both should decode correctly with their respective decoders
	pack1.Reset(data1)
	decoded1 := decodeProposalForProposeInput(pack1)

	pack2.Reset(data2)
	decoded2 := decodeProposalForProveInput(pack2)

	// Both should decode to the same logical content
	assert.Equal(t, proposal.Id.Uint64(), decoded1.Id.Uint64())
	assert.Equal(t, proposal.Id.Uint64(), decoded2.Id.Uint64())
	assert.Equal(t, proposal.Proposer, decoded1.Proposer)
	assert.Equal(t, proposal.Proposer, decoded2.Proposer)
}

func TestSizeCalculations(t *testing.T) {
	// Test ProposedEvent size calculation
	blobCount := 3
	expectedSize := 236 + (blobCount * 32) // Fixed + variable
	actualSize := CalculateProposedEventSize(blobCount)
	assert.Equal(t, expectedSize, actualSize)

	// Test ProvedEvent size calculation
	bondInstructionCount := 2
	expectedSize = 247 + (bondInstructionCount * 47) // Fixed + variable
	actualSize = CalculateProvedEventSize(bondInstructionCount)
	assert.Equal(t, expectedSize, actualSize)
}

func TestErrorHandling(t *testing.T) {
	// Test uint24 overflow in blob hashes
	payload := &shasta.IInboxProposedEventPayload{
		Proposal: shasta.IInboxProposal{
			Id:                             big.NewInt(1),
			Proposer:                       common.HexToAddress("0x1234567890123456789012345678901234567890"),
			Timestamp:                      big.NewInt(1234567890),
			EndOfSubmissionWindowTimestamp: big.NewInt(1234567999),
		},
		Derivation: shasta.IInboxDerivation{
			OriginBlockNumber: big.NewInt(1),
			BlobSlice: shasta.LibBlobsBlobSlice{
				BlobHashes: make([][32]byte, 16777216), // uint24 max + 1
				Offset:     big.NewInt(0),
				Timestamp:  big.NewInt(1234567890),
			},
		},
	}
	_, err := EncodeProposedEvent(payload)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "blob hashes length exceeds uint24 max")

	// Test uint16 overflow in bond instructions
	provedPayload := &shasta.IInboxProvedEventPayload{
		ProposalId: big.NewInt(1),
		Transition: shasta.IInboxTransition{
			Checkpoint: shasta.ICheckpointStoreCheckpoint{
				BlockNumber: big.NewInt(1),
			},
		},
		TransitionRecord: shasta.IInboxTransitionRecord{
			BondInstructions: make([]shasta.LibBondsBondInstruction, 65536), // uint16 max + 1
		},
	}
	_, err = EncodeProvedEvent(provedPayload)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "bond instructions length exceeds uint16 max")

	// Test proposal-transition length mismatch in ProveInput
	proveInput := &shasta.IInboxProveInput{
		Proposals:   make([]shasta.IInboxProposal, 2),
		Transitions: make([]shasta.IInboxTransition, 1),         // Mismatch
		Metadata:    make([]shasta.IInboxTransitionMetadata, 2), // Also mismatch
	}
	_, err = EncodeProveInput(proveInput)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "proposal-transition length mismatch")
}

func TestBigEndianEncoding(t *testing.T) {
	// Test that our encoding matches expected big-endian byte order
	pack := NewPackUnpack(10)

	// Test uint16
	pack.PackUint16(0x1234)
	expected := []byte{0x12, 0x34}
	assert.Equal(t, expected, pack.data[:2])

	// Test uint24
	pack.PackUint24(0x123456)
	expected = []byte{0x12, 0x34, 0x12, 0x34, 0x56}
	assert.Equal(t, expected, pack.data[:5])

	// Test uint48 - corrected expected values
	pack.Reset(make([]byte, 10))
	pack.PackUint48(0x123456789ABC)
	expected = []byte{0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC}
	assert.Equal(t, expected, pack.data[:6], "uint48 should be encoded in big-endian format")

	// Test uint48 round-trip
	pack.Reset(pack.data[:6])
	value := pack.UnpackUint48()
	assert.Equal(t, uint64(0x123456789ABC), value, "uint48 round-trip should preserve value")

	// Test uint48 boundary - max uint48 value
	pack.Reset(make([]byte, 10))
	maxUint48 := uint64(281474976710655) // 2^48 - 1
	pack.PackUint48(maxUint48)
	pack.Reset(pack.data[:6])
	value = pack.UnpackUint48()
	assert.Equal(t, maxUint48, value, "uint48 should handle max value correctly")
}

// Test hash functions
func TestHashFunctions(t *testing.T) {
	// Test data setup
	checkpoint := shasta.ICheckpointStoreCheckpoint{
		BlockNumber: big.NewInt(123),
		BlockHash:   common.HexToHash("0x1234567890123456789012345678901234567890123456789012345678901234"),
		StateRoot:   common.HexToHash("0x9876543210987654321098765432109876543210987654321098765432109876"),
	}

	transition := shasta.IInboxTransition{
		ProposalHash:         common.HexToHash("0x1111111111111111111111111111111111111111111111111111111111111111"),
		ParentTransitionHash: common.HexToHash("0x2222222222222222222222222222222222222222222222222222222222222222"),
		Checkpoint:           checkpoint,
	}

	proposal := shasta.IInboxProposal{
		Id:                             big.NewInt(456),
		Proposer:                       common.HexToAddress("0xabcdefabcdefabcdefabcdefabcdefabcdefabcdef"),
		Timestamp:                      big.NewInt(1234567890),
		EndOfSubmissionWindowTimestamp: big.NewInt(1234567999),
		CoreStateHash:                  common.HexToHash("0x3333333333333333333333333333333333333333333333333333333333333333"),
		DerivationHash:                 common.HexToHash("0x4444444444444444444444444444444444444444444444444444444444444444"),
	}

	coreState := shasta.IInboxCoreState{
		NextProposalId:              big.NewInt(789),
		NextProposalBlockId:         big.NewInt(790),
		LastFinalizedProposalId:     big.NewInt(788),
		LastFinalizedTransitionHash: common.HexToHash("0x5555555555555555555555555555555555555555555555555555555555555555"),
		BondInstructionsHash:        common.HexToHash("0x6666666666666666666666666666666666666666666666666666666666666666"),
	}

	derivation := shasta.IInboxDerivation{
		OriginBlockNumber:  big.NewInt(100),
		OriginBlockHash:    common.HexToHash("0x7777777777777777777777777777777777777777777777777777777777777777"),
		IsForcedInclusion:  true,
		BasefeeSharingPctg: 25,
		BlobSlice: shasta.LibBlobsBlobSlice{
			BlobHashes: [][32]byte{
				common.HexToHash("0x8888888888888888888888888888888888888888888888888888888888888888"),
				common.HexToHash("0x9999999999999999999999999999999999999999999999999999999999999999"),
			},
			Offset:    big.NewInt(50),
			Timestamp: big.NewInt(1234567800),
		},
	}

	bondInstruction := shasta.LibBondsBondInstruction{
		ProposalId: big.NewInt(456),
		BondType:   1,
		Payer:      common.HexToAddress("0x1111111111111111111111111111111111111111"),
		Receiver:   common.HexToAddress("0x2222222222222222222222222222222222222222"),
	}

	transitionRecord := shasta.IInboxTransitionRecord{
		Span:             8,
		BondInstructions: []shasta.LibBondsBondInstruction{bondInstruction},
		TransitionHash:   common.HexToHash("0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
		CheckpointHash:   common.HexToHash("0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"),
	}

	// Test individual hash functions - Optimized versions
	t.Run("HashCheckpointOptimized", func(t *testing.T) {
		hash := HashCheckpointOptimized(checkpoint)
		require.NotEqual(t, common.Hash{}, hash)
		t.Logf("HashCheckpointOptimized: %x", hash)
	})

	t.Run("HashTransitionOptimized", func(t *testing.T) {
		hash := HashTransitionOptimized(transition)
		require.NotEqual(t, common.Hash{}, hash)
		t.Logf("HashTransitionOptimized: %x", hash)
	})

	t.Run("HashProposalOptimized", func(t *testing.T) {
		hash := HashProposalOptimized(proposal)
		require.NotEqual(t, common.Hash{}, hash)
		t.Logf("HashProposalOptimized: %x", hash)
	})

	t.Run("HashCoreStateOptimized", func(t *testing.T) {
		hash := HashCoreStateOptimized(coreState)
		require.NotEqual(t, common.Hash{}, hash)
		t.Logf("HashCoreStateOptimized: %x", hash)
	})

	t.Run("HashDerivationOptimized", func(t *testing.T) {
		hash := HashDerivationOptimized(derivation)
		require.NotEqual(t, common.Hash{}, hash)
		t.Logf("HashDerivationOptimized: %x", hash)
	})

	t.Run("HashTransitionsArrayOptimized", func(t *testing.T) {
		transitions := []shasta.IInboxTransition{transition}
		hash := HashTransitionsArrayOptimized(transitions)
		require.NotEqual(t, common.Hash{}, hash)
		t.Logf("HashTransitionsArrayOptimized: %x", hash)

		// Test empty array
		emptyHash := HashTransitionsArrayOptimized([]shasta.IInboxTransition{})
		require.Equal(t, emptyBytesHash, emptyHash)

		// Test multiple transitions
		transitions = append(transitions, transition)
		hashMultiple := HashTransitionsArrayOptimized(transitions)
		require.NotEqual(t, hash, hashMultiple) // Should be different
		t.Logf("HashTransitionsArrayOptimized (multiple): %x", hashMultiple)
	})

	t.Run("HashTransitionRecordOptimized", func(t *testing.T) {
		hash := HashTransitionRecordOptimized(transitionRecord)
		require.NotEqual(t, [26]byte{}, hash)
		t.Logf("HashTransitionRecordOptimized: %x", hash)
	})

	t.Run("ComposeTransitionKey", func(t *testing.T) {
		key := ComposeTransitionKey(456, common.HexToHash("0x1234567890123456789012345678901234567890123456789012345678901234"))
		require.NotEqual(t, common.Hash{}, key)
		t.Logf("ComposeTransitionKey: %x", key)
	})

	// Test standard versions (these use placeholder implementation)
	t.Run("HashCheckpointStandard", func(t *testing.T) {
		hash := HashCheckpoint(checkpoint)
		require.NotEqual(t, common.Hash{}, hash)
		t.Logf("HashCheckpoint (standard): %x", hash)
	})

	t.Run("HashTransitionStandard", func(t *testing.T) {
		hash := HashTransition(transition)
		require.NotEqual(t, common.Hash{}, hash)
		t.Logf("HashTransition (standard): %x", hash)
	})

	// Verify that optimized and standard versions produce different results
	// (since optimized uses LibHashing and standard uses abi.encode)
	t.Run("OptimizedVsStandardDifferent", func(t *testing.T) {
		optimizedHash := HashCheckpointOptimized(checkpoint)
		standardHash := HashCheckpoint(checkpoint)
		// They should be different since they use different algorithms
		require.NotEqual(t, optimizedHash, standardHash)
	})
}

// Test edge cases for hash functions
func TestHashFunctionsEdgeCases(t *testing.T) {
	// Test with zero values
	emptyCheckpoint := shasta.ICheckpointStoreCheckpoint{
		BlockNumber: big.NewInt(0),
		BlockHash:   common.Hash{},
		StateRoot:   common.Hash{},
	}

	t.Run("EmptyCheckpointHash", func(t *testing.T) {
		hash := HashCheckpointOptimized(emptyCheckpoint)
		require.NotEqual(t, common.Hash{}, hash)
		t.Logf("Empty checkpoint hash: %x", hash)
	})

	// Test with large arrays
	t.Run("LargeTransitionsArray", func(t *testing.T) {
		transition := shasta.IInboxTransition{
			ProposalHash:         common.HexToHash("0x1111111111111111111111111111111111111111111111111111111111111111"),
			ParentTransitionHash: common.HexToHash("0x2222222222222222222222222222222222222222222222222222222222222222"),
			Checkpoint: shasta.ICheckpointStoreCheckpoint{
				BlockNumber: big.NewInt(123),
				BlockHash:   common.HexToHash("0x3333333333333333333333333333333333333333333333333333333333333333"),
				StateRoot:   common.HexToHash("0x4444444444444444444444444444444444444444444444444444444444444444"),
			},
		}

		// Create array with 5 transitions (tests the "larger arrays" path)
		transitions := make([]shasta.IInboxTransition, 5)
		for i := range transitions {
			transitions[i] = transition
		}

		hash := HashTransitionsArrayOptimized(transitions)
		require.NotEqual(t, common.Hash{}, hash)
		t.Logf("Large transitions array hash: %x", hash)
	})

	// Test transition record with no bond instructions
	t.Run("TransitionRecordNoBonds", func(t *testing.T) {
		record := shasta.IInboxTransitionRecord{
			Span:             4,
			BondInstructions: []shasta.LibBondsBondInstruction{}, // Empty
			TransitionHash:   common.HexToHash("0x5555555555555555555555555555555555555555555555555555555555555555"),
			CheckpointHash:   common.HexToHash("0x6666666666666666666666666666666666666666666666666666666666666666"),
		}

		hash := HashTransitionRecordOptimized(record)
		require.NotEqual(t, [26]byte{}, hash)
		t.Logf("Transition record (no bonds) hash: %x", hash)
	})

	// Test with multiple bond instructions
	t.Run("TransitionRecordMultipleBonds", func(t *testing.T) {
		bondInstructions := []shasta.LibBondsBondInstruction{
			{
				ProposalId: big.NewInt(100),
				BondType:   1,
				Payer:      common.HexToAddress("0x1111111111111111111111111111111111111111"),
				Receiver:   common.HexToAddress("0x2222222222222222222222222222222222222222"),
			},
			{
				ProposalId: big.NewInt(101),
				BondType:   2,
				Payer:      common.HexToAddress("0x3333333333333333333333333333333333333333"),
				Receiver:   common.HexToAddress("0x4444444444444444444444444444444444444444"),
			},
		}

		record := shasta.IInboxTransitionRecord{
			Span:             8,
			BondInstructions: bondInstructions,
			TransitionHash:   common.HexToHash("0x7777777777777777777777777777777777777777777777777777777777777777"),
			CheckpointHash:   common.HexToHash("0x8888888888888888888888888888888888888888888888888888888888888888"),
		}

		hash := HashTransitionRecordOptimized(record)
		require.NotEqual(t, [26]byte{}, hash)
		t.Logf("Transition record (multiple bonds) hash: %x", hash)
	})
}

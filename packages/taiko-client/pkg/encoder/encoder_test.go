package encoder

import (
	"bytes"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

func TestEncodeDecodeProposedEvent(t *testing.T) {
	encoder := NewEncoder()
	
	// Create test payload
	payload := &shastaBindings.IInboxProposedEventPayload{
		Proposal: shastaBindings.IInboxProposal{
			Id:            big.NewInt(123),
			Proposer:      common.HexToAddress("0x1234567890123456789012345678901234567890"),
			Timestamp:     big.NewInt(456),
			CoreStateHash: [32]byte{1, 2, 3},
		},
		Derivation: shastaBindings.IInboxDerivation{
			OriginBlockNumber:  big.NewInt(789),
			OriginBlockHash:    [32]byte{4, 5, 6},
			IsForcedInclusion:  true,
			BasefeeSharingPctg: 10,
			BlobSlice: shastaBindings.LibBlobsBlobSlice{
				BlobHashes: [][32]byte{{7, 8, 9}},
				Offset:     big.NewInt(100),
				Timestamp:  big.NewInt(200),
			},
		},
		CoreState: shastaBindings.IInboxCoreState{
			NextProposalId:               big.NewInt(300),
			LastFinalizedProposalId:      big.NewInt(400),
			LastFinalizedTransitionHash:  [32]byte{10, 11, 12},
			BondInstructionsHash:         [32]byte{13, 14, 15},
		},
	}
	
	// Encode
	encoded, err := encoder.EncodeProposedEvent(payload)
	if err != nil {
		t.Fatalf("EncodeProposedEvent failed: %v", err)
	}
	
	// Decode
	decoded, err := encoder.DecodeProposedEvent(encoded)
	if err != nil {
		t.Fatalf("DecodeProposedEvent failed: %v", err)
	}
	
	// Verify
	if decoded.Proposal.Id.Cmp(payload.Proposal.Id) != 0 {
		t.Errorf("Proposal.Id mismatch: got %v, want %v", decoded.Proposal.Id, payload.Proposal.Id)
	}
	if decoded.Proposal.Proposer != payload.Proposal.Proposer {
		t.Errorf("Proposal.Proposer mismatch: got %v, want %v", decoded.Proposal.Proposer, payload.Proposal.Proposer)
	}
	if decoded.Derivation.IsForcedInclusion != payload.Derivation.IsForcedInclusion {
		t.Errorf("Derivation.IsForcedInclusion mismatch: got %v, want %v", 
			decoded.Derivation.IsForcedInclusion, payload.Derivation.IsForcedInclusion)
	}
	if decoded.Derivation.BasefeeSharingPctg != payload.Derivation.BasefeeSharingPctg {
		t.Errorf("Derivation.BasefeeSharingPctg mismatch: got %v, want %v", 
			decoded.Derivation.BasefeeSharingPctg, payload.Derivation.BasefeeSharingPctg)
	}
}

func TestEncodeDecodeProposeInput(t *testing.T) {
	encoder := NewEncoder()
	
	// Create test input
	input := &shastaBindings.IInboxProposeInput{
		Deadline: big.NewInt(100),
		CoreState: shastaBindings.IInboxCoreState{
			NextProposalId:               big.NewInt(200),
			LastFinalizedProposalId:      big.NewInt(300),
			LastFinalizedTransitionHash:  [32]byte{1, 2, 3},
			BondInstructionsHash:         [32]byte{4, 5, 6},
		},
		ParentProposals: []shastaBindings.IInboxProposal{
			{
				Id:             big.NewInt(400),
				Proposer:       common.HexToAddress("0x1111111111111111111111111111111111111111"),
				Timestamp:      big.NewInt(500),
				CoreStateHash:  [32]byte{7, 8, 9},
				DerivationHash: [32]byte{10, 11, 12},
			},
		},
		BlobReference: shastaBindings.LibBlobsBlobReference{
			BlobStartIndex: 1,
			NumBlobs:       2,
			Offset:         big.NewInt(3),
		},
		TransitionRecords: []shastaBindings.IInboxTransitionRecord{
			{
				Span:                    5,
				TransitionHash:          [32]byte{13, 14, 15},
				EndBlockMiniHeaderHash:  [32]byte{16, 17, 18},
			},
		},
		EndBlockMiniHeader: shastaBindings.IInboxBlockMiniHeader{
			Number:    big.NewInt(600),
			Hash:      [32]byte{19, 20, 21},
			StateRoot: [32]byte{22, 23, 24},
		},
	}
	
	// Encode
	encoded, err := encoder.EncodeProposeInput(input)
	if err != nil {
		t.Fatalf("EncodeProposeInput failed: %v", err)
	}
	
	// Decode
	decoded, err := encoder.DecodeProposeInput(encoded)
	if err != nil {
		t.Fatalf("DecodeProposeInput failed: %v", err)
	}
	
	// Verify
	if decoded.Deadline.Cmp(input.Deadline) != 0 {
		t.Errorf("Deadline mismatch: got %v, want %v", decoded.Deadline, input.Deadline)
	}
	if decoded.CoreState.NextProposalId.Cmp(input.CoreState.NextProposalId) != 0 {
		t.Errorf("CoreState.NextProposalId mismatch: got %v, want %v", 
			decoded.CoreState.NextProposalId, input.CoreState.NextProposalId)
	}
	if len(decoded.ParentProposals) != len(input.ParentProposals) {
		t.Errorf("ParentProposals length mismatch: got %d, want %d", 
			len(decoded.ParentProposals), len(input.ParentProposals))
	}
	if decoded.BlobReference.NumBlobs != input.BlobReference.NumBlobs {
		t.Errorf("BlobReference.NumBlobs mismatch: got %v, want %v", 
			decoded.BlobReference.NumBlobs, input.BlobReference.NumBlobs)
	}
}

func TestEncodeDecodeProvedEvent(t *testing.T) {
	encoder := NewEncoder()
	
	// Create test payload
	payload := &ProvedEventPayload{
		ProposalId: big.NewInt(999),
		Transition: shastaBindings.IInboxTransition{
			ProposalHash:         [32]byte{1, 2, 3, 4, 5},
			ParentTransitionHash: [32]byte{6, 7, 8, 9, 10},
			EndBlockMiniHeader: shastaBindings.IInboxBlockMiniHeader{
				Number:    big.NewInt(12345),
				Hash:      [32]byte{11, 12, 13, 14, 15},
				StateRoot: [32]byte{16, 17, 18, 19, 20},
			},
			DesignatedProver: common.HexToAddress("0x5555555555555555555555555555555555555555"),
			ActualProver:     common.HexToAddress("0x6666666666666666666666666666666666666666"),
		},
		TransitionRecord: shastaBindings.IInboxTransitionRecord{
			Span:                   10,
			TransitionHash:         [32]byte{21, 22, 23, 24, 25},
			EndBlockMiniHeaderHash: [32]byte{26, 27, 28, 29, 30},
			// Note: BondInstructions not implemented yet
		},
	}
	
	// Encode
	encoded, err := encoder.EncodeProvedEvent(payload)
	if err != nil {
		t.Fatalf("EncodeProvedEvent failed: %v", err)
	}
	
	// Check encoded size
	expectedSize := encoder.calculateProvedEventSize(0) // 0 bond instructions
	if len(encoded) != expectedSize {
		t.Errorf("Encoded size mismatch: got %d, want %d", len(encoded), expectedSize)
	}
	
	// Decode
	decoded, err := encoder.DecodeProvedEvent(encoded)
	if err != nil {
		t.Fatalf("DecodeProvedEvent failed: %v", err)
	}
	
	// Verify ProposalId
	if decoded.ProposalId.Cmp(payload.ProposalId) != 0 {
		t.Errorf("ProposalId mismatch: got %v, want %v", decoded.ProposalId, payload.ProposalId)
	}
	
	// Verify Transition fields
	if !bytes.Equal(decoded.Transition.ProposalHash[:], payload.Transition.ProposalHash[:]) {
		t.Errorf("Transition.ProposalHash mismatch")
	}
	if !bytes.Equal(decoded.Transition.ParentTransitionHash[:], payload.Transition.ParentTransitionHash[:]) {
		t.Errorf("Transition.ParentTransitionHash mismatch")
	}
	if decoded.Transition.EndBlockMiniHeader.Number.Cmp(payload.Transition.EndBlockMiniHeader.Number) != 0 {
		t.Errorf("Transition.EndBlockMiniHeader.Number mismatch: got %v, want %v",
			decoded.Transition.EndBlockMiniHeader.Number, payload.Transition.EndBlockMiniHeader.Number)
	}
	if !bytes.Equal(decoded.Transition.EndBlockMiniHeader.Hash[:], payload.Transition.EndBlockMiniHeader.Hash[:]) {
		t.Errorf("Transition.EndBlockMiniHeader.Hash mismatch")
	}
	if !bytes.Equal(decoded.Transition.EndBlockMiniHeader.StateRoot[:], payload.Transition.EndBlockMiniHeader.StateRoot[:]) {
		t.Errorf("Transition.EndBlockMiniHeader.StateRoot mismatch")
	}
	if decoded.Transition.DesignatedProver != payload.Transition.DesignatedProver {
		t.Errorf("Transition.DesignatedProver mismatch: got %v, want %v",
			decoded.Transition.DesignatedProver, payload.Transition.DesignatedProver)
	}
	if decoded.Transition.ActualProver != payload.Transition.ActualProver {
		t.Errorf("Transition.ActualProver mismatch: got %v, want %v",
			decoded.Transition.ActualProver, payload.Transition.ActualProver)
	}
	
	// Verify TransitionRecord fields
	if decoded.TransitionRecord.Span != payload.TransitionRecord.Span {
		t.Errorf("TransitionRecord.Span mismatch: got %v, want %v",
			decoded.TransitionRecord.Span, payload.TransitionRecord.Span)
	}
	if !bytes.Equal(decoded.TransitionRecord.TransitionHash[:], payload.TransitionRecord.TransitionHash[:]) {
		t.Errorf("TransitionRecord.TransitionHash mismatch")
	}
	if !bytes.Equal(decoded.TransitionRecord.EndBlockMiniHeaderHash[:], payload.TransitionRecord.EndBlockMiniHeaderHash[:]) {
		t.Errorf("TransitionRecord.EndBlockMiniHeaderHash mismatch")
	}
}

func TestEncodeDecodeProveInput(t *testing.T) {
	encoder := NewEncoder()
	
	// Create test input
	input := &shastaBindings.IInboxProveInput{
		Proposals: []shastaBindings.IInboxProposal{
			{
				Id:             big.NewInt(100),
				Proposer:       common.HexToAddress("0x2222222222222222222222222222222222222222"),
				Timestamp:      big.NewInt(200),
				CoreStateHash:  [32]byte{1, 2, 3},
				DerivationHash: [32]byte{4, 5, 6},
			},
		},
		Transitions: []shastaBindings.IInboxTransition{
			{
				ProposalHash:         [32]byte{7, 8, 9},
				ParentTransitionHash: [32]byte{10, 11, 12},
				EndBlockMiniHeader: shastaBindings.IInboxBlockMiniHeader{
					Number:    big.NewInt(300),
					Hash:      [32]byte{13, 14, 15},
					StateRoot: [32]byte{16, 17, 18},
				},
				DesignatedProver: common.HexToAddress("0x3333333333333333333333333333333333333333"),
				ActualProver:     common.HexToAddress("0x4444444444444444444444444444444444444444"),
			},
		},
	}
	
	// Encode
	encoded, err := encoder.EncodeProveInput(input)
	if err != nil {
		t.Fatalf("EncodeProveInput failed: %v", err)
	}
	
	// Decode
	decoded, err := encoder.DecodeProveInput(encoded)
	if err != nil {
		t.Fatalf("DecodeProveInput failed: %v", err)
	}
	
	// Verify
	if len(decoded.Proposals) != len(input.Proposals) {
		t.Errorf("Proposals length mismatch: got %d, want %d", 
			len(decoded.Proposals), len(input.Proposals))
	}
	if len(decoded.Transitions) != len(input.Transitions) {
		t.Errorf("Transitions length mismatch: got %d, want %d", 
			len(decoded.Transitions), len(input.Transitions))
	}
	if decoded.Proposals[0].Id.Cmp(input.Proposals[0].Id) != 0 {
		t.Errorf("Proposal.Id mismatch: got %v, want %v", 
			decoded.Proposals[0].Id, input.Proposals[0].Id)
	}
	if !bytes.Equal(decoded.Transitions[0].ProposalHash[:], input.Transitions[0].ProposalHash[:]) {
		t.Errorf("Transition.ProposalHash mismatch")
	}
	if decoded.Transitions[0].DesignatedProver != input.Transitions[0].DesignatedProver {
		t.Errorf("Transition.DesignatedProver mismatch: got %v, want %v",
			decoded.Transitions[0].DesignatedProver, input.Transitions[0].DesignatedProver)
	}
}

func TestEmptyBlockMiniHeaderOptimization(t *testing.T) {
	encoder := NewEncoder()
	
	// Test with empty BlockMiniHeader
	inputEmpty := &shastaBindings.IInboxProposeInput{
		Deadline: big.NewInt(100),
		CoreState: shastaBindings.IInboxCoreState{
			NextProposalId:               big.NewInt(200),
			LastFinalizedProposalId:      big.NewInt(300),
			LastFinalizedTransitionHash:  [32]byte{1, 2, 3},
			BondInstructionsHash:         [32]byte{4, 5, 6},
		},
		ParentProposals:   []shastaBindings.IInboxProposal{},
		BlobReference:     shastaBindings.LibBlobsBlobReference{
			BlobStartIndex: 0,
			NumBlobs:       0,
			Offset:         big.NewInt(0),
		},
		TransitionRecords: []shastaBindings.IInboxTransitionRecord{},
		EndBlockMiniHeader: shastaBindings.IInboxBlockMiniHeader{
			Number:    big.NewInt(0),
			Hash:      [32]byte{},
			StateRoot: [32]byte{},
		},
	}
	
	// Test with non-empty BlockMiniHeader
	inputNonEmpty := &shastaBindings.IInboxProposeInput{
		Deadline: big.NewInt(100),
		CoreState: shastaBindings.IInboxCoreState{
			NextProposalId:               big.NewInt(200),
			LastFinalizedProposalId:      big.NewInt(300),
			LastFinalizedTransitionHash:  [32]byte{1, 2, 3},
			BondInstructionsHash:         [32]byte{4, 5, 6},
		},
		ParentProposals:   []shastaBindings.IInboxProposal{},
		BlobReference:     shastaBindings.LibBlobsBlobReference{
			BlobStartIndex: 0,
			NumBlobs:       0,
			Offset:         big.NewInt(0),
		},
		TransitionRecords: []shastaBindings.IInboxTransitionRecord{},
		EndBlockMiniHeader: shastaBindings.IInboxBlockMiniHeader{
			Number:    big.NewInt(999),
			Hash:      [32]byte{1, 2, 3},
			StateRoot: [32]byte{4, 5, 6},
		},
	}
	
	// Encode both
	encodedEmpty, err := encoder.EncodeProposeInput(inputEmpty)
	if err != nil {
		t.Fatalf("EncodeProposeInput (empty) failed: %v", err)
	}
	
	encodedNonEmpty, err := encoder.EncodeProposeInput(inputNonEmpty)
	if err != nil {
		t.Fatalf("EncodeProposeInput (non-empty) failed: %v", err)
	}
	
	// Empty should be 70 bytes smaller (BlockMiniHeader size)
	if len(encodedNonEmpty) != len(encodedEmpty)+70 {
		t.Errorf("Size difference incorrect: empty=%d, non-empty=%d, diff=%d (expected 70)",
			len(encodedEmpty), len(encodedNonEmpty), len(encodedNonEmpty)-len(encodedEmpty))
	}
	
	// Decode and verify both
	decodedEmpty, err := encoder.DecodeProposeInput(encodedEmpty)
	if err != nil {
		t.Fatalf("DecodeProposeInput (empty) failed: %v", err)
	}
	
	if decodedEmpty.EndBlockMiniHeader.Number.Cmp(big.NewInt(0)) != 0 {
		t.Errorf("Empty BlockMiniHeader.Number should be 0")
	}
	
	decodedNonEmpty, err := encoder.DecodeProposeInput(encodedNonEmpty)
	if err != nil {
		t.Fatalf("DecodeProposeInput (non-empty) failed: %v", err)
	}
	
	if decodedNonEmpty.EndBlockMiniHeader.Number.Cmp(big.NewInt(999)) != 0 {
		t.Errorf("Non-empty BlockMiniHeader.Number mismatch: got %v, want 999",
			decodedNonEmpty.EndBlockMiniHeader.Number)
	}
}
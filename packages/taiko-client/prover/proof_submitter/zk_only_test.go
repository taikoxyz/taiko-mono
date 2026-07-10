package submitter

import (
	"context"
	"math/big"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

func TestRequestProposalProofZkOnlyPinsSP1AndSkipsSelection(t *testing.T) {
	base := &recordingProofProducer{proofType: proofProducer.ProofTypeSgx}
	zkvm := &recordingProofProducer{proofType: proofProducer.ProofTypeZKR0}
	submitter := &ProofSubmitter{
		baseLevelProofProducer:        base,
		zkvmProofProducer:             zkvm,
		maxRisc0ProofProposalDistance: big.NewInt(30),
		zkOnlyProofs:                  true,
	}

	// The proposal is within the RISC0 distance, so the RISC0/SP1 selection would pick
	// RISC0; ZK-only mode must pin SP1 as the primary lane regardless.
	resp, err := submitter.requestProposalProof(
		context.Background(),
		&proofProducer.ProposalProofRequestOptions{ProposalID: big.NewInt(40)},
		big.NewInt(40),
		metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{Id: big.NewInt(40)}, 0),
		time.Now(),
		big.NewInt(10),
	)

	require.NoError(t, err)
	require.Equal(t, proofProducer.ProofTypeZKSP1, resp.ProofType)
	require.Equal(t, 1, zkvm.requests)
	require.Equal(t, []proofProducer.ProofType{proofProducer.ProofTypeZKSP1}, zkvm.requestedTypes)
	require.Zero(t, base.requests)
}

func TestNewProofSubmitterZkOnlyRequiresZKVMProducer(t *testing.T) {
	_, err := NewProofSubmitter(
		context.Background(),
		&recordingProofProducer{proofType: proofProducer.ProofTypeSgx},
		nil,
		nil,
		nil,
		nil,
		&SenderOptions{},
		nil,
		0,
		nil,
		0,
		nil,
		nil,
		nil,
		nil,
		false,
		true,
	)

	require.ErrorContains(t, err, "ZK-only proof mode requires a ZKVM proof producer")
}

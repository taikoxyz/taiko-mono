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
	zkvm := &recordingProofProducer{proofType: proofProducer.ProofTypeZKR0}
	backlog := &fakeRisc0Backlog{cleared: make(chan struct{}, 1)}
	submitter := &ProofSubmitter{
		zkvmProofProducer:             zkvm,
		maxRisc0ProofProposalDistance: big.NewInt(30),
		forceSGXProof:                 true,
		zkOnlyProofs:                  true,
		risc0Backlog:                  backlog,
		ctx:                           context.Background(),
	}

	// The proposal is beyond the RISC0 distance, so the normal selection path would enter
	// SP1 fallback and clear the RISC0 backlog. ZK-only mode must pin SP1 as the primary
	// lane without running any fallback state or side effects.
	opts := &proofProducer.ProposalProofRequestOptions{ProposalID: big.NewInt(41)}
	resp, err := submitter.requestProposalProof(
		context.Background(),
		opts,
		big.NewInt(41),
		metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{Id: big.NewInt(41)}, 0),
		time.Now(),
		big.NewInt(10),
	)

	require.NoError(t, err)
	require.Equal(t, proofProducer.ProofTypeZKSP1, resp.ProofType)
	require.Equal(t, 1, zkvm.requests)
	require.Equal(t, []proofProducer.ProofType{proofProducer.ProofTypeZKSP1}, zkvm.requestedTypes)
	require.Equal(t, proofProducer.ProofTypeZKR0, opts.CompanionProofType)
	require.False(t, submitter.inSP1Fallback())
	select {
	case <-backlog.cleared:
		t.Fatal("ZK-only mode unexpectedly cleared the RISC0 backlog")
	case <-time.After(50 * time.Millisecond):
	}
	require.Zero(t, backlog.clearCalls.Load())
	require.Zero(t, backlog.statusCalls.Load())
}

func TestNewProofSubmitterRequiresZKVMProducer(t *testing.T) {
	_, err := NewProofSubmitter(
		context.Background(),
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
		false,
		false,
	)

	require.ErrorContains(t, err, "proof submitter requires a ZKVM proof producer")
}

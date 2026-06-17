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

type recordingProofProducer struct {
	proofType proofProducer.ProofType
	requests  int
}

func (p *recordingProofProducer) RequestProof(
	_ context.Context,
	opts proofProducer.ProofRequestOptions,
	batchID *big.Int,
	meta metadata.TaikoProposalMetaData,
	_ time.Time,
) (*proofProducer.ProofResponse, error) {
	p.requests++
	return &proofProducer.ProofResponse{
		BatchID:   batchID,
		Meta:      meta,
		Opts:      opts,
		ProofType: p.proofType,
	}, nil
}

func (p *recordingProofProducer) Aggregate(
	_ context.Context,
	items []*proofProducer.ProofResponse,
	_ time.Time,
) (*proofProducer.BatchProofs, error) {
	return &proofProducer.BatchProofs{ProofResponses: items, ProofType: p.proofType}, nil
}

func TestRequestProposalProofUsesRisc0FirstWhenZKVMConfigured(t *testing.T) {
	base := &recordingProofProducer{proofType: proofProducer.ProofTypeSgx}
	risc0 := &recordingProofProducer{proofType: proofProducer.ProofTypeZKR0}
	sp1 := &recordingProofProducer{proofType: proofProducer.ProofTypeZKSP1}
	submitter := &ProofSubmitter{
		baseLevelProofProducer:        base,
		zkvmProofProducer:             risc0,
		sp1FallbackProofProducer:      sp1,
		maxRisc0ProofProposalDistance: big.NewInt(30),
	}

	resp, err := submitter.requestProposalProof(
		context.Background(),
		&proofProducer.ProposalProofRequestOptions{ProposalID: big.NewInt(40)},
		big.NewInt(40),
		metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{Id: big.NewInt(40)}, 0),
		time.Now(),
		big.NewInt(10),
	)

	require.NoError(t, err)
	require.Equal(t, proofProducer.ProofTypeZKR0, resp.ProofType)
	require.Equal(t, 1, risc0.requests)
	require.Zero(t, sp1.requests)
	require.Zero(t, base.requests)
}

func TestRequestProposalProofUsesSP1FallbackWhenRisc0DistanceExceeded(t *testing.T) {
	base := &recordingProofProducer{proofType: proofProducer.ProofTypeSgx}
	risc0 := &recordingProofProducer{proofType: proofProducer.ProofTypeZKR0}
	sp1 := &recordingProofProducer{proofType: proofProducer.ProofTypeZKSP1}
	submitter := &ProofSubmitter{
		baseLevelProofProducer:        base,
		zkvmProofProducer:             risc0,
		sp1FallbackProofProducer:      sp1,
		maxRisc0ProofProposalDistance: big.NewInt(30),
	}

	resp, err := submitter.requestProposalProof(
		context.Background(),
		&proofProducer.ProposalProofRequestOptions{ProposalID: big.NewInt(41)},
		big.NewInt(41),
		metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{Id: big.NewInt(41)}, 0),
		time.Now(),
		big.NewInt(10),
	)

	require.NoError(t, err)
	require.Equal(t, proofProducer.ProofTypeZKSP1, resp.ProofType)
	require.Zero(t, risc0.requests)
	require.Equal(t, 1, sp1.requests)
	require.Zero(t, base.requests)
}

func TestRequestProposalProofUsesBaseOnlyWhenZKVMDisabled(t *testing.T) {
	base := &recordingProofProducer{proofType: proofProducer.ProofTypeSgx}
	submitter := &ProofSubmitter{
		baseLevelProofProducer:        base,
		maxRisc0ProofProposalDistance: big.NewInt(30),
	}

	resp, err := submitter.requestProposalProof(
		context.Background(),
		&proofProducer.ProposalProofRequestOptions{ProposalID: big.NewInt(41)},
		big.NewInt(41),
		metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{Id: big.NewInt(41)}, 0),
		time.Now(),
		big.NewInt(10),
	)

	require.NoError(t, err)
	require.Equal(t, proofProducer.ProofTypeSgx, resp.ProofType)
	require.Equal(t, 1, base.requests)
}

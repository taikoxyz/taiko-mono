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
	proofType      proofProducer.ProofType
	requests       int
	requestedTypes []proofProducer.ProofType
}

func (p *recordingProofProducer) RequestProof(
	_ context.Context,
	opts proofProducer.ProofRequestOptions,
	batchID *big.Int,
	meta metadata.TaikoProposalMetaData,
	_ time.Time,
) (*proofProducer.ProofResponse, error) {
	p.requests++
	requestedType := opts.ProposalOptions().ProofType
	if requestedType == "" {
		requestedType = p.proofType
	}
	p.requestedTypes = append(p.requestedTypes, requestedType)
	return &proofProducer.ProofResponse{
		BatchID:   batchID,
		Meta:      meta,
		Opts:      opts,
		ProofType: requestedType,
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
	submitter := &ProofSubmitter{
		baseLevelProofProducer:        base,
		zkvmProofProducer:             risc0,
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
	require.Equal(t, []proofProducer.ProofType{proofProducer.ProofTypeZKR0}, risc0.requestedTypes)
	require.Zero(t, base.requests)
}

func TestRequestProposalProofUsesSameZKVMProducerForSP1Fallback(t *testing.T) {
	base := &recordingProofProducer{proofType: proofProducer.ProofTypeSgx}
	risc0 := &recordingProofProducer{proofType: proofProducer.ProofTypeZKR0}
	submitter := &ProofSubmitter{
		baseLevelProofProducer:        base,
		zkvmProofProducer:             risc0,
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
	require.Equal(t, 1, risc0.requests)
	require.Equal(t, []proofProducer.ProofType{proofProducer.ProofTypeZKSP1}, risc0.requestedTypes)
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

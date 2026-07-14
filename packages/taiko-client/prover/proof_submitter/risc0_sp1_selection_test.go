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
	nilResponse    bool
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
	if p.nilResponse {
		return nil, nil
	}
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
	risc0 := &recordingProofProducer{proofType: proofProducer.ProofTypeZKR0}
	submitter := &ProofSubmitter{
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
}

func TestRequestProposalProofUsesSameZKVMProducerForSP1Fallback(t *testing.T) {
	risc0 := &recordingProofProducer{proofType: proofProducer.ProofTypeZKR0}
	submitter := &ProofSubmitter{
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
}

func TestRequestProposalProofForceSP1UsesSP1WithinRisc0Distance(t *testing.T) {
	risc0 := &recordingProofProducer{proofType: proofProducer.ProofTypeZKR0}
	submitter := &ProofSubmitter{
		zkvmProofProducer:             risc0,
		maxRisc0ProofProposalDistance: big.NewInt(30),
		forceSP1Proof:                 true,
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
	require.Equal(t, proofProducer.ProofTypeZKSP1, resp.ProofType)
	require.Equal(t, 1, risc0.requests)
	require.Equal(t, []proofProducer.ProofType{proofProducer.ProofTypeZKSP1}, risc0.requestedTypes)
}

func TestRequestProposalProofErrorsOnNilZKVMResponse(t *testing.T) {
	risc0 := &recordingProofProducer{proofType: proofProducer.ProofTypeZKR0, nilResponse: true}
	submitter := &ProofSubmitter{
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

	require.ErrorContains(t, err, "nil proof response")
	require.Nil(t, resp)
	require.Equal(t, 1, risc0.requests)
}

func TestRequestProposalProofRejectsMissingZKVMProducer(t *testing.T) {
	submitter := &ProofSubmitter{
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

	require.ErrorContains(t, err, "requires a ZKVM proof producer")
	require.Nil(t, resp)
}

func TestAggregateProofsByTypeRejectsNonZKProofType(t *testing.T) {
	submitter := &ProofSubmitter{
		zkvmProofProducer: &recordingProofProducer{proofType: proofProducer.ProofTypeZKR0},
		proofBuffers: map[proofProducer.ProofType]*proofProducer.ProofBuffer{
			proofProducer.ProofTypeSgx: proofProducer.NewProofBuffer(1),
		},
	}

	err := submitter.AggregateProofsByType(context.Background(), proofProducer.ProofTypeSgx)

	require.ErrorContains(t, err, "unknown proof type: sgx")
}

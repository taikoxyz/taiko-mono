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
	requestedType          proofProducer.ProofType
	requestedCompanionType proofProducer.ProofType
	nilResponse            bool
}

func (p *recordingProofProducer) RequestProof(
	_ context.Context,
	opts proofProducer.ProofRequestOptions,
	proposalID *big.Int,
	meta metadata.TaikoProposalMetaData,
	_ time.Time,
) (*proofProducer.ProofResponse, error) {
	p.requestedType = opts.GetProofType()
	p.requestedCompanionType = opts.GetCompanionProofType()
	if p.nilResponse {
		return nil, nil
	}
	return &proofProducer.ProofResponse{
		BatchID:   proposalID,
		Meta:      meta,
		Opts:      opts,
		ProofType: p.requestedType,
	}, nil
}

func (p *recordingProofProducer) Aggregate(
	_ context.Context,
	items []*proofProducer.ProofResponse,
	_ time.Time,
) (*proofProducer.BatchProofs, error) {
	return &proofProducer.BatchProofs{ProofResponses: items}, nil
}

func TestRequestProposalProofSelectsSP1WithSGXCompanion(t *testing.T) {
	for _, tc := range []struct {
		name          string
		proposalID    int64
		sgxCompanion  bool
		wantCompanion proofProducer.ProofType
	}{
		{name: "near finalized", proposalID: 40, wantCompanion: proofProducer.ProofTypeSgxGeth},
		{name: "far ahead", proposalID: 400, wantCompanion: proofProducer.ProofTypeSgxGeth},
		{name: "SGX_RETH companion", proposalID: 40, sgxCompanion: true, wantCompanion: proofProducer.ProofTypeSgx},
	} {
		t.Run(tc.name, func(t *testing.T) {
			producer := &recordingProofProducer{}
			submitter := &ProofSubmitter{zkvmProofProducer: producer, sgxRethCompanionProof: tc.sgxCompanion}
			proposalID := big.NewInt(tc.proposalID)
			resp, err := submitter.requestProposalProof(
				context.Background(),
				&proofProducer.ProposalProofRequestOptions{ProposalID: proposalID},
				proposalID,
				metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{Id: proposalID}, 0),
				time.Now(),
			)
			require.NoError(t, err)
			require.Equal(t, proofProducer.ProofTypeZKSP1, resp.ProofType)
			require.Equal(t, proofProducer.ProofTypeZKSP1, producer.requestedType)
			require.Equal(t, tc.wantCompanion, producer.requestedCompanionType)
		})
	}
}

func TestRequestProposalProofForceSGX(t *testing.T) {
	producer := &recordingProofProducer{}
	submitter := &ProofSubmitter{zkvmProofProducer: producer, forceSGXProof: true}
	proposalID := big.NewInt(40)
	resp, err := submitter.requestProposalProof(
		context.Background(),
		&proofProducer.ProposalProofRequestOptions{ProposalID: proposalID},
		proposalID,
		metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{Id: proposalID}, 0),
		time.Now(),
	)
	require.NoError(t, err)
	require.Equal(t, proofProducer.ProofTypeSgx, resp.ProofType)
	require.Equal(t, proofProducer.ProofTypeSgxGeth, producer.requestedCompanionType)
}

func TestRequestProposalProofRejectsNilProducerResponse(t *testing.T) {
	producer := &recordingProofProducer{nilResponse: true}
	submitter := &ProofSubmitter{zkvmProofProducer: producer}
	proposalID := big.NewInt(40)
	resp, err := submitter.requestProposalProof(
		context.Background(),
		&proofProducer.ProposalProofRequestOptions{ProposalID: proposalID},
		proposalID,
		metadata.NewTaikoProposalMetadataShasta(&shastaBindings.ShastaInboxClientProposed{Id: proposalID}, 0),
		time.Now(),
	)
	require.ErrorContains(t, err, "nil proof response")
	require.Nil(t, resp)
}

func TestNewProofSubmitterRequiresZKVMProducer(t *testing.T) {
	_, err := NewProofSubmitter(
		context.Background(), nil, nil, nil, nil, &SenderOptions{}, nil,
		0, nil, 0, nil, nil, nil, false, false,
	)
	require.ErrorContains(t, err, "proof submitter requires a ZKVM proof producer")
}

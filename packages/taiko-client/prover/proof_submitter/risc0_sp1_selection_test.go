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
	proofType               proofProducer.ProofType
	requests                int
	requestedTypes          []proofProducer.ProofType
	requestedCompanionTypes []proofProducer.ProofType
	nilResponse             bool
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
	p.requestedCompanionTypes = append(p.requestedCompanionTypes, opts.GetCompanionProofType())
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
	require.Equal(
		t,
		[]proofProducer.ProofType{proofProducer.ProofTypeSgxGeth},
		risc0.requestedCompanionTypes,
	)
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

func TestRequestProposalProofSP1ShareUsesSP1ForFirstProposalsOfEachCycle(t *testing.T) {
	for _, tc := range []struct {
		sp1ProofPercentage uint64
		proposalID         int64
		expected           proofProducer.ProofType
	}{
		{sp1ProofPercentage: 30, proposalID: 100, expected: proofProducer.ProofTypeZKSP1},
		{sp1ProofPercentage: 30, proposalID: 129, expected: proofProducer.ProofTypeZKSP1},
		{sp1ProofPercentage: 30, proposalID: 130, expected: proofProducer.ProofTypeZKR0},
		{sp1ProofPercentage: 30, proposalID: 199, expected: proofProducer.ProofTypeZKR0},
		{sp1ProofPercentage: 30, proposalID: 200, expected: proofProducer.ProofTypeZKSP1},
		{sp1ProofPercentage: 0, proposalID: 100, expected: proofProducer.ProofTypeZKR0},
		{sp1ProofPercentage: 100, proposalID: 199, expected: proofProducer.ProofTypeZKSP1},
	} {
		producer := &recordingProofProducer{proofType: proofProducer.ProofTypeZKR0}
		submitter := &ProofSubmitter{
			zkvmProofProducer: producer,
			// Every RISC0-share proposal below stays within 99 + 1000, so only the share decides.
			maxRisc0ProofProposalDistance: big.NewInt(1000),
			sp1ProofPercentage:            tc.sp1ProofPercentage,
		}

		resp, err := submitter.requestProposalProof(
			context.Background(),
			&proofProducer.ProposalProofRequestOptions{ProposalID: big.NewInt(tc.proposalID)},
			big.NewInt(tc.proposalID),
			metadata.NewTaikoProposalMetadataShasta(
				&shastaBindings.ShastaInboxClientProposed{Id: big.NewInt(tc.proposalID)},
				0,
			),
			time.Now(),
			big.NewInt(99),
		)

		require.NoError(t, err)
		require.Equal(t, tc.expected, resp.ProofType, "percentage %d, proposal %d", tc.sp1ProofPercentage, tc.proposalID)
	}
}

func TestRequestProposalProofForceSGXUsesSGXReth(t *testing.T) {
	producer := &recordingProofProducer{proofType: proofProducer.ProofTypeZKR0}
	submitter := &ProofSubmitter{
		zkvmProofProducer:             producer,
		maxRisc0ProofProposalDistance: big.NewInt(30),
		forceSP1Proof:                 true,
		forceSGXProof:                 true,
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
	require.Equal(t, proofProducer.ProofTypeSgx, resp.ProofType)
	require.Equal(t, []proofProducer.ProofType{proofProducer.ProofTypeSgx}, producer.requestedTypes)
	require.Equal(
		t,
		[]proofProducer.ProofType{proofProducer.ProofTypeSgxGeth},
		producer.requestedCompanionTypes,
	)
}

func TestRequestProposalProofSGXRethCompanion(t *testing.T) {
	for _, tc := range []struct {
		name               string
		sp1ProofPercentage uint64
		forceSP1Proof      bool
		zkOnlyProofs       bool
		proposalID         int64
		expectedPrimary    proofProducer.ProofType
		expectedCompanion  proofProducer.ProofType
	}{
		{
			name:              "RISC0 within distance",
			proposalID:        140,
			expectedPrimary:   proofProducer.ProofTypeZKR0,
			expectedCompanion: proofProducer.ProofTypeSgx,
		},
		{
			name:               "SP1 share",
			sp1ProofPercentage: 10,
			proposalID:         105,
			expectedPrimary:    proofProducer.ProofTypeZKSP1,
			expectedCompanion:  proofProducer.ProofTypeSgx,
		},
		{
			name:              "force SP1",
			forceSP1Proof:     true,
			proposalID:        140,
			expectedPrimary:   proofProducer.ProofTypeZKSP1,
			expectedCompanion: proofProducer.ProofTypeSgx,
		},
		{
			name:              "ZK-only ignores it",
			zkOnlyProofs:      true,
			proposalID:        140,
			expectedPrimary:   proofProducer.ProofTypeZKSP1,
			expectedCompanion: proofProducer.ProofTypeZKR0,
		},
	} {
		t.Run(tc.name, func(t *testing.T) {
			producer := &recordingProofProducer{proofType: proofProducer.ProofTypeZKR0}
			submitter := &ProofSubmitter{
				zkvmProofProducer:             producer,
				maxRisc0ProofProposalDistance: big.NewInt(30),
				sp1ProofPercentage:            tc.sp1ProofPercentage,
				forceSP1Proof:                 tc.forceSP1Proof,
				zkOnlyProofs:                  tc.zkOnlyProofs,
				sgxRethCompanionProof:         true,
			}

			opts := &proofProducer.ProposalProofRequestOptions{ProposalID: big.NewInt(tc.proposalID)}
			resp, err := submitter.requestProposalProof(
				context.Background(),
				opts,
				big.NewInt(tc.proposalID),
				metadata.NewTaikoProposalMetadataShasta(
					&shastaBindings.ShastaInboxClientProposed{Id: big.NewInt(tc.proposalID)},
					0,
				),
				time.Now(),
				big.NewInt(120),
			)

			require.NoError(t, err)
			require.Equal(t, tc.expectedPrimary, resp.ProofType)
			require.Equal(t, []proofProducer.ProofType{tc.expectedCompanion}, producer.requestedCompanionTypes)
			require.Equal(t, tc.expectedCompanion, opts.CompanionProofType)
		})
	}
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

func TestAggregateProofsByTypeSupportsSGXProofType(t *testing.T) {
	submitter := &ProofSubmitter{
		zkvmProofProducer: &recordingProofProducer{proofType: proofProducer.ProofTypeZKR0},
		proofBuffers: map[proofProducer.ProofType]*proofProducer.ProofBuffer{
			proofProducer.ProofTypeSgx: proofProducer.NewProofBuffer(1),
		},
	}

	err := submitter.AggregateProofsByType(context.Background(), proofProducer.ProofTypeSgx)

	require.NoError(t, err)
}

package submitter

import (
	"context"
	"errors"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	pacayaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/pacaya"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

// mockProofProducer is a mock implementation of ProofProducer for testing
type mockProofProducer struct {
	proofProducer.ProofProducer
	requestCount      int
	requestDelay      time.Duration
	shouldReturnErr   error
	shouldTimeout     bool
	timeoutCheckCount int
	callHistory       []time.Time
}

func (m *mockProofProducer) RequestProof(
	_ context.Context,
	opts proofProducer.ProofRequestOptions,
	batchID *big.Int,
	meta metadata.TaikoProposalMetaData,
	startAt time.Time,
) (*proofProducer.ProofResponse, error) {
	m.requestCount++
	m.callHistory = append(m.callHistory, time.Now())

	// Simulate processing delay
	if m.requestDelay > 0 {
		time.Sleep(m.requestDelay)
	}

	// Check if we should simulate timeout
	if m.shouldTimeout {
		elapsed := time.Since(startAt)
		if elapsed > maxProofRequestTimeout {
			m.timeoutCheckCount++
			// After timeout, if it's zkvm producer returning ErrProofInProgress,
			// the submitter should switch to SGX
			if errors.Is(m.shouldReturnErr, proofProducer.ErrProofInProgress) ||
				errors.Is(m.shouldReturnErr, proofProducer.ErrRetry) {
				// Return error to trigger fallback
				return nil, m.shouldReturnErr
			}
		}
	}

	if m.shouldReturnErr != nil {
		return nil, m.shouldReturnErr
	}

	pacayaOpts, ok := opts.(*proofProducer.ProofRequestOptionsPacaya)
	if !ok {
		return nil, errors.New("invalid options type")
	}

	return &proofProducer.ProofResponse{
		BatchID:   batchID,
		Meta:      meta,
		Proof:     testutils.RandomBytes(100),
		ProofType: proofProducer.ProofTypeOp,
		Opts:      pacayaOpts,
	}, nil
}

func (m *mockProofProducer) Aggregate(
	_ context.Context,
	items []*proofProducer.ProofResponse,
	_ time.Time,
) (*proofProducer.BatchProofs, error) {
	return &proofProducer.BatchProofs{
		ProofResponses: items,
	}, nil
}

func TestProofRequestWithMockProducer(t *testing.T) {
	// Create a mock proof producer
	mockProducer := &mockProofProducer{
		shouldReturnErr: nil,
	}

	// Test basic proof request
	ctx := context.Background()
	opts := &proofProducer.ProofRequestOptionsPacaya{
		BatchID: big.NewInt(1),
		Headers: []*types.Header{
			{
				Number: big.NewInt(100),
			},
		},
	}

	meta := metadata.NewTaikoDataBlockMetadataPacaya(&pacayaBindings.TaikoInboxClientBatchProposed{
		Meta: pacayaBindings.ITaikoInboxBatchMetadata{
			BatchId: 1,
		},
	})

	startTime := time.Now()
	resp, err := mockProducer.RequestProof(ctx, opts, big.NewInt(1), meta, startTime)

	require.Nil(t, err)
	require.NotNil(t, resp)
	require.Equal(t, 1, mockProducer.requestCount)
}

func TestProofRequestWithTimeout(t *testing.T) {
	// Create a mock proof producer that simulates timeout
	mockProducer := &mockProofProducer{
		shouldReturnErr: proofProducer.ErrProofInProgress,
		shouldTimeout:   true,
	}

	ctx := context.Background()
	opts := &proofProducer.ProofRequestOptionsPacaya{
		BatchID: big.NewInt(2),
		Headers: []*types.Header{
			{
				Number: big.NewInt(200),
			},
		},
	}

	meta := metadata.NewTaikoDataBlockMetadataPacaya(&pacayaBindings.TaikoInboxClientBatchProposed{
		Meta: pacayaBindings.ITaikoInboxBatchMetadata{
			BatchId: 2,
		},
	})

	// Simulate that the request started more than maxProofRequestTimeout ago
	startTime := time.Now().Add(-maxProofRequestTimeout - 1*time.Second)
	resp, err := mockProducer.RequestProof(ctx, opts, big.NewInt(2), meta, startTime)

	// When timeout occurs with ErrProofInProgress, it should return error
	require.NotNil(t, err)
	require.Nil(t, resp)
	require.True(t, errors.Is(err, proofProducer.ErrProofInProgress))
	require.Equal(t, 1, mockProducer.requestCount)
}

func TestProofRequestWithRetryTimeout(t *testing.T) {
	// Create a mock proof producer that simulates retry timeout
	mockProducer := &mockProofProducer{
		shouldReturnErr: proofProducer.ErrRetry,
		shouldTimeout:   true,
	}

	ctx := context.Background()
	opts := &proofProducer.ProofRequestOptionsPacaya{
		BatchID: big.NewInt(3),
		Headers: []*types.Header{
			{
				Number: big.NewInt(300),
			},
		},
	}

	meta := metadata.NewTaikoDataBlockMetadataPacaya(&pacayaBindings.TaikoInboxClientBatchProposed{
		Meta: pacayaBindings.ITaikoInboxBatchMetadata{
			BatchId: 3,
		},
	})

	// Simulate that the request started more than maxProofRequestTimeout ago
	startTime := time.Now().Add(-maxProofRequestTimeout - 1*time.Second)
	resp, err := mockProducer.RequestProof(ctx, opts, big.NewInt(3), meta, startTime)

	// When timeout occurs with ErrRetry, it should return error
	require.NotNil(t, err)
	require.Nil(t, resp)
	require.True(t, errors.Is(err, proofProducer.ErrRetry))
	require.Equal(t, 1, mockProducer.requestCount)
}

func TestProofRequestNoTimeoutWithinThreshold(t *testing.T) {
	// Create a mock proof producer without timeout
	mockProducer := &mockProofProducer{
		shouldReturnErr: proofProducer.ErrProofInProgress,
		shouldTimeout:   false,
	}

	ctx := context.Background()
	opts := &proofProducer.ProofRequestOptionsPacaya{
		BatchID: big.NewInt(4),
		Headers: []*types.Header{
			{
				Number: big.NewInt(400),
			},
		},
	}

	meta := metadata.NewTaikoDataBlockMetadataPacaya(&pacayaBindings.TaikoInboxClientBatchProposed{
		Meta: pacayaBindings.ITaikoInboxBatchMetadata{
			BatchId: 4,
		},
	})

	// Recent start time, no timeout
	startTime := time.Now()
	resp, err := mockProducer.RequestProof(ctx, opts, big.NewInt(4), meta, startTime)

	// Should return error without timeout logic triggering
	require.NotNil(t, err)
	require.Nil(t, resp)
	require.True(t, errors.Is(err, proofProducer.ErrProofInProgress))
	require.Equal(t, 1, mockProducer.requestCount)
	require.Equal(t, 0, mockProducer.timeoutCheckCount)
}

func TestProofRequestSuccessful(t *testing.T) {
	// Create a mock proof producer that returns success
	mockProducer := &mockProofProducer{
		shouldReturnErr: nil,
	}

	ctx := context.Background()
	opts := &proofProducer.ProofRequestOptionsPacaya{
		BatchID: big.NewInt(5),
		Headers: []*types.Header{
			{
				Number: big.NewInt(500),
			},
		},
	}

	meta := metadata.NewTaikoDataBlockMetadataPacaya(&pacayaBindings.TaikoInboxClientBatchProposed{
		Meta: pacayaBindings.ITaikoInboxBatchMetadata{
			BatchId: 5,
		},
	})

	startTime := time.Now()
	resp, err := mockProducer.RequestProof(ctx, opts, big.NewInt(5), meta, startTime)

	// Verify successful proof generation
	require.Nil(t, err)
	require.NotNil(t, resp)
	require.Equal(t, big.NewInt(5), resp.BatchID)
	require.Equal(t, proofProducer.ProofTypeOp, resp.ProofType)
	require.Equal(t, 1, mockProducer.requestCount)
}

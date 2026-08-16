package submitter

import (
	"context"
	"errors"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/core/types"
	cmap "github.com/orcaman/concurrent-map/v2"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

// mockProofProducer is a mock implementation of ProofProducer for testing
type mockProofProducer struct {
	proofProducer.ProofProducer
	requestCount    int
	requestDelay    time.Duration
	shouldReturnErr error
	callHistory     []time.Time
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

	if m.shouldReturnErr != nil {
		return nil, m.shouldReturnErr
	}

	proposalOpts, ok := opts.(*proofProducer.ProposalProofRequestOptions)
	if !ok {
		return nil, errors.New("invalid options type")
	}

	return &proofProducer.ProofResponse{
		BatchID:   batchID,
		Meta:      meta,
		Proof:     testutils.RandomBytes(100),
		ProofType: proofProducer.ProofTypeOp,
		Opts:      proposalOpts,
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
	opts := &proofProducer.ProposalProofRequestOptions{
		ProposalID: big.NewInt(1),
		Headers: []*types.Header{
			{
				Number: big.NewInt(100),
			},
		},
	}

	meta := metadata.NewTaikoProposalMetadataShasta(
		&shastaBindings.ShastaInboxClientProposed{Id: big.NewInt(1)},
		0,
	)

	startTime := time.Now()
	resp, err := mockProducer.RequestProof(ctx, opts, big.NewInt(1), meta, startTime)

	require.Nil(t, err)
	require.NotNil(t, resp)
	require.Equal(t, 1, mockProducer.requestCount)
}

func TestProofRequestWithProofInProgressError(t *testing.T) {
	mockProducer := &mockProofProducer{
		shouldReturnErr: proofProducer.ErrProofInProgress,
	}

	ctx := context.Background()
	opts := &proofProducer.ProposalProofRequestOptions{
		ProposalID: big.NewInt(2),
		Headers: []*types.Header{
			{
				Number: big.NewInt(200),
			},
		},
	}

	meta := metadata.NewTaikoProposalMetadataShasta(
		&shastaBindings.ShastaInboxClientProposed{Id: big.NewInt(2)},
		0,
	)

	startTime := time.Now()
	resp, err := mockProducer.RequestProof(ctx, opts, big.NewInt(2), meta, startTime)

	// When timeout occurs with ErrProofInProgress, it should return error
	require.NotNil(t, err)
	require.Nil(t, resp)
	require.True(t, errors.Is(err, proofProducer.ErrProofInProgress))
	require.Equal(t, 1, mockProducer.requestCount)
}

func TestProofRequestWithRetryError(t *testing.T) {
	mockProducer := &mockProofProducer{
		shouldReturnErr: proofProducer.ErrRetry,
	}

	ctx := context.Background()
	opts := &proofProducer.ProposalProofRequestOptions{
		ProposalID: big.NewInt(3),
		Headers: []*types.Header{
			{
				Number: big.NewInt(300),
			},
		},
	}

	meta := metadata.NewTaikoProposalMetadataShasta(
		&shastaBindings.ShastaInboxClientProposed{Id: big.NewInt(3)},
		0,
	)

	startTime := time.Now()
	resp, err := mockProducer.RequestProof(ctx, opts, big.NewInt(3), meta, startTime)

	// When timeout occurs with ErrRetry, it should return error
	require.NotNil(t, err)
	require.Nil(t, resp)
	require.True(t, errors.Is(err, proofProducer.ErrRetry))
	require.Equal(t, 1, mockProducer.requestCount)
}

func TestProofRequestSuccessful(t *testing.T) {
	// Create a mock proof producer that returns success
	mockProducer := &mockProofProducer{
		shouldReturnErr: nil,
	}

	ctx := context.Background()
	opts := &proofProducer.ProposalProofRequestOptions{
		ProposalID: big.NewInt(5),
		Headers: []*types.Header{
			{
				Number: big.NewInt(500),
			},
		},
	}

	meta := metadata.NewTaikoProposalMetadataShasta(
		&shastaBindings.ShastaInboxClientProposed{Id: big.NewInt(5)},
		0,
	)

	startTime := time.Now()
	resp, err := mockProducer.RequestProof(ctx, opts, big.NewInt(5), meta, startTime)

	// Verify successful proof generation
	require.Nil(t, err)
	require.NotNil(t, resp)
	require.Equal(t, big.NewInt(5), resp.BatchID)
	require.Equal(t, proofProducer.ProofTypeOp, resp.ProofType)
	require.Equal(t, 1, mockProducer.requestCount)
}

func TestProofBufferMonitorTriggersAggregate(t *testing.T) {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	buffer := proofProducer.NewProofBuffer(2)
	_, err := buffer.Write(&proofProducer.ProofResponse{BatchID: big.NewInt(1)})
	require.NoError(t, err)

	s := &ProofSubmitter{
		proofBuffers: map[proofProducer.ProofType]*proofProducer.ProofBuffer{
			proofProducer.ProofTypeOp: buffer,
		},
		batchAggregationNotify:    make(chan proofProducer.ProofType, 1),
		forceBatchProvingInterval: 50 * time.Millisecond,
		proofPollingInterval:      10 * time.Millisecond,
	}

	go monitorProofBuffer(ctx, proofProducer.ProofTypeOp, buffer, 50*time.Millisecond, s.TryAggregate)

	select {
	case proofType := <-s.batchAggregationNotify:
		require.Equal(t, proofProducer.ProofTypeOp, proofType)
	case <-time.After(2 * time.Second):
		t.Fatal("expected aggregation signal but timed out")
	}

	require.True(t, buffer.IsAggregating())
}

func TestTryAggregateUsesLastItemInsertTimeForForcedInterval(t *testing.T) {
	buffer := proofProducer.NewProofBuffer(3)
	_, err := buffer.Write(&proofProducer.ProofResponse{BatchID: big.NewInt(1)})
	require.NoError(t, err)

	time.Sleep(60 * time.Millisecond)

	_, err = buffer.Write(&proofProducer.ProofResponse{BatchID: big.NewInt(2)})
	require.NoError(t, err)

	s := &ProofSubmitter{
		batchAggregationNotify:    make(chan proofProducer.ProofType, 1),
		forceBatchProvingInterval: 50 * time.Millisecond,
	}

	require.False(t, s.TryAggregate(buffer, proofProducer.ProofTypeOp))
	require.False(t, buffer.IsAggregating())
	require.Empty(t, s.batchAggregationNotify)
}

func TestCacheAccess(t *testing.T) {
	cacheMap := cmap.New[*proofProducer.ProofResponse]()
	cacheMap.Set("1", &proofProducer.ProofResponse{})
	value, ok := cacheMap.Get("1")
	require.True(t, ok)
	require.NotNil(t, value)
}

func TestDefaultProofBufferMonitorInterval(t *testing.T) {
	require.Equal(t, time.Minute, monitorInterval)
}

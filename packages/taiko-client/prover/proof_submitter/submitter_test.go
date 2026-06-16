package submitter

import (
	"context"
	"math/big"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common"
	cmap "github.com/orcaman/concurrent-map/v2"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	proofProducer "github.com/taikoxyz/taiko-mono/packages/taiko-client/prover/proof_producer"
)

type mockProverAdminProducer struct {
	proofProducer.ProofProducer
	clearCount     int
	statusCount    int
	cleanAfter     int
	failClearCount int
}

func (m *mockProverAdminProducer) ClearProver(_ context.Context) error {
	m.clearCount++
	if m.clearCount <= m.failClearCount {
		return context.Canceled
	}
	return nil
}

func (m *mockProverAdminProducer) ProverStatus(_ context.Context) (*proofProducer.RaikoProverStatusResponse, error) {
	m.statusCount++
	return &proofProducer.RaikoProverStatusResponse{
		Status: "ok",
		Data: proofProducer.RaikoProverStatusData{
			Clean: m.statusCount >= m.cleanAfter,
		},
	}, nil
}

func TestProofDistributionWithOutOfOrderResponses(t *testing.T) {
	buffer := proofProducer.NewProofBuffer(8)
	cacheMap := cmap.New[*proofProducer.ProofResponse]()

	submitter := &ProofSubmitter{
		proofBuffers: map[proofProducer.ProofType]*proofProducer.ProofBuffer{
			proofProducer.ProofTypeOp: buffer,
		},
		proofCacheMaps: map[proofProducer.ProofType]cmap.ConcurrentMap[string, *proofProducer.ProofResponse]{
			proofProducer.ProofTypeOp: cacheMap,
		},
		batchAggregationNotify:    make(chan proofProducer.ProofType, 1),
		flushCacheNotify:          make(chan proofProducer.ProofType, 1),
		forceBatchProvingInterval: time.Hour,
	}

	fromID := big.NewInt(1)

	responses := []*proofProducer.ProofResponse{
		newProofResponse(1),
		newProofResponse(3),
		newProofResponse(2),
	}

	metas := []metadata.TaikoProposalMetaData{
		newShastaMetaForTest(1),
		newShastaMetaForTest(3),
		newShastaMetaForTest(2),
	}

	for i := range responses {
		require.NoError(t, submitter.handleProofResponse(metas[i], fromID, responses[i]))
	}

	bufferItems, err := buffer.ReadAll()
	require.NoError(t, err)
	require.Len(t, bufferItems, 3)
	require.Equal(t, uint64(1), bufferItems[0].BatchID.Uint64())
	require.Equal(t, uint64(2), bufferItems[1].BatchID.Uint64())
	require.Equal(t, uint64(3), bufferItems[2].BatchID.Uint64())

	require.Empty(t, cacheMap.Keys())
}

func TestClearProofItemsByTypeAndResend(t *testing.T) {
	buffer := proofProducer.NewProofBuffer(8)
	cacheMap := cmap.New[*proofProducer.ProofResponse]()
	proofSubmissionCh := make(chan *proofProducer.ProofRequestBody, 4)

	bufferedProof := newProofResponse(1)
	bufferedProof.Meta = newShastaMetaForTest(1)
	cachedProof := newProofResponse(2)
	cachedProof.Meta = newShastaMetaForTest(2)

	_, err := buffer.Write(bufferedProof)
	require.NoError(t, err)
	cacheMap.Set(cachedProof.BatchID.String(), cachedProof)

	submitter := &ProofSubmitter{
		proofBuffers: map[proofProducer.ProofType]*proofProducer.ProofBuffer{
			proofProducer.ProofTypeOp: buffer,
		},
		proofCacheMaps: map[proofProducer.ProofType]cmap.ConcurrentMap[string, *proofProducer.ProofResponse]{
			proofProducer.ProofTypeOp: cacheMap,
		},
		proofSubmissionCh: proofSubmissionCh,
	}

	require.NoError(t, submitter.clearProofItemsByTypeAndResend(proofProducer.ProofTypeOp))

	require.Zero(t, buffer.Len())
	require.Empty(t, cacheMap.Keys())
	require.Len(t, proofSubmissionCh, 2)

	require.Equal(t, big.NewInt(1), (<-proofSubmissionCh).Meta.GetProposalID())
	require.Equal(t, big.NewInt(2), (<-proofSubmissionCh).Meta.GetProposalID())
}

func TestClearProofItemsByTypeAndResendOnceOnlyTriggersOnce(t *testing.T) {
	buffer := proofProducer.NewProofBuffer(8)
	cacheMap := cmap.New[*proofProducer.ProofResponse]()
	proofSubmissionCh := make(chan *proofProducer.ProofRequestBody, 4)
	zkvmProducer := &mockProverAdminProducer{cleanAfter: 1}

	firstProof := newProofResponse(1)
	firstProof.Meta = newShastaMetaForTest(1)
	_, err := buffer.Write(firstProof)
	require.NoError(t, err)

	submitter := &ProofSubmitter{
		proofBuffers: map[proofProducer.ProofType]*proofProducer.ProofBuffer{
			proofProducer.ProofTypeOp: buffer,
		},
		proofCacheMaps: map[proofProducer.ProofType]cmap.ConcurrentMap[string, *proofProducer.ProofResponse]{
			proofProducer.ProofTypeOp: cacheMap,
		},
		proofSubmissionCh: proofSubmissionCh,
		zkvmProofProducer: zkvmProducer,
	}

	require.NoError(t, submitter.clearProofItemsByTypeAndResendOnce(t.Context(), proofProducer.ProofTypeOp))

	secondBufferedProof := newProofResponse(2)
	secondBufferedProof.Meta = newShastaMetaForTest(2)
	secondCachedProof := newProofResponse(3)
	secondCachedProof.Meta = newShastaMetaForTest(3)
	_, err = buffer.Write(secondBufferedProof)
	require.NoError(t, err)
	cacheMap.Set(secondCachedProof.BatchID.String(), secondCachedProof)

	require.NoError(t, submitter.clearProofItemsByTypeAndResendOnce(t.Context(), proofProducer.ProofTypeOp))

	require.Len(t, proofSubmissionCh, 1)
	require.Equal(t, big.NewInt(1), (<-proofSubmissionCh).Meta.GetProposalID())
	require.Equal(t, 1, buffer.Len())
	require.True(t, cacheMap.Has(secondCachedProof.BatchID.String()))
	require.Equal(t, 1, zkvmProducer.clearCount)
	require.Zero(t, zkvmProducer.statusCount)
}

func TestClearZKProofItemsAndResendOnceClearsBothZKProofTypes(t *testing.T) {
	risc0Buffer := proofProducer.NewProofBuffer(8)
	sp1Buffer := proofProducer.NewProofBuffer(8)
	risc0CacheMap := cmap.New[*proofProducer.ProofResponse]()
	sp1CacheMap := cmap.New[*proofProducer.ProofResponse]()
	proofSubmissionCh := make(chan *proofProducer.ProofRequestBody, 4)
	zkvmProducer := &mockProverAdminProducer{cleanAfter: 1}

	risc0BufferedProof := newProofResponse(1)
	risc0BufferedProof.ProofType = proofProducer.ProofTypeZKR0
	risc0BufferedProof.Meta = newShastaMetaForTest(1)
	_, err := risc0Buffer.Write(risc0BufferedProof)
	require.NoError(t, err)

	sp1CachedProof := newProofResponse(2)
	sp1CachedProof.ProofType = proofProducer.ProofTypeZKSP1
	sp1CachedProof.Meta = newShastaMetaForTest(2)
	sp1CacheMap.Set(sp1CachedProof.BatchID.String(), sp1CachedProof)

	submitter := &ProofSubmitter{
		proofBuffers: map[proofProducer.ProofType]*proofProducer.ProofBuffer{
			proofProducer.ProofTypeZKR0:  risc0Buffer,
			proofProducer.ProofTypeZKSP1: sp1Buffer,
		},
		proofCacheMaps: map[proofProducer.ProofType]cmap.ConcurrentMap[string, *proofProducer.ProofResponse]{
			proofProducer.ProofTypeZKR0:  risc0CacheMap,
			proofProducer.ProofTypeZKSP1: sp1CacheMap,
		},
		proofSubmissionCh: proofSubmissionCh,
		zkvmProofProducer: zkvmProducer,
	}

	require.NoError(t, submitter.clearZKProofItemsAndResendOnce(t.Context()))

	require.Zero(t, risc0Buffer.Len())
	require.Zero(t, sp1Buffer.Len())
	require.Empty(t, risc0CacheMap.Keys())
	require.Empty(t, sp1CacheMap.Keys())
	require.Len(t, proofSubmissionCh, 2)
	require.Equal(t, 1, zkvmProducer.clearCount)
	require.True(t, submitter.proofItemsClearResendExecuted.Load())
}

func TestClearZKProofItemsAndResendOnceRetriesAfterClearFailure(t *testing.T) {
	proofSubmissionCh := make(chan *proofProducer.ProofRequestBody, 1)
	zkvmProducer := &mockProverAdminProducer{
		cleanAfter:     1,
		failClearCount: 1,
	}

	submitter := &ProofSubmitter{
		proofBuffers: map[proofProducer.ProofType]*proofProducer.ProofBuffer{
			proofProducer.ProofTypeZKR0:  proofProducer.NewProofBuffer(8),
			proofProducer.ProofTypeZKSP1: proofProducer.NewProofBuffer(8),
		},
		proofCacheMaps: map[proofProducer.ProofType]cmap.ConcurrentMap[string, *proofProducer.ProofResponse]{
			proofProducer.ProofTypeZKR0:  cmap.New[*proofProducer.ProofResponse](),
			proofProducer.ProofTypeZKSP1: cmap.New[*proofProducer.ProofResponse](),
		},
		proofSubmissionCh: proofSubmissionCh,
		zkvmProofProducer: zkvmProducer,
	}

	require.Error(t, submitter.clearZKProofItemsAndResendOnce(t.Context()))
	require.False(t, submitter.proofItemsClearResendExecuted.Load())

	require.NoError(t, submitter.clearZKProofItemsAndResendOnce(t.Context()))
	require.True(t, submitter.proofItemsClearResendExecuted.Load())
	require.Equal(t, 2, zkvmProducer.clearCount)
}

func TestResetProofItemsClearResendAfterZKProofRequest(t *testing.T) {
	submitter := &ProofSubmitter{}

	submitter.resetProofItemsClearResendAfterZKProofRequest(false)
	require.False(t, submitter.proofItemsClearResendExecuted.Load())

	submitter.proofItemsClearResendExecuted.Store(true)
	require.True(t, submitter.proofItemsClearResendExecuted.Load())

	submitter.resetProofItemsClearResendAfterZKProofRequest(false)
	require.True(t, submitter.proofItemsClearResendExecuted.Load())

	submitter.resetProofItemsClearResendAfterZKProofRequest(true)
	require.False(t, submitter.proofItemsClearResendExecuted.Load())
}

func TestIsProposalOutOfRange(t *testing.T) {
	t.Run("nil window size disables range check", func(t *testing.T) {
		submitter := &ProofSubmitter{proposalWindowSize: nil}
		require.False(t, submitter.isProposalOutOfRange(big.NewInt(1000), big.NewInt(1)))
	})

	t.Run("count less than one disables range check", func(t *testing.T) {
		submitter := &ProofSubmitter{proposalWindowSize: big.NewInt(0)}
		require.False(t, submitter.isProposalOutOfRange(big.NewInt(1000), big.NewInt(1)))
	})

	t.Run("count equals one only allows next proposal", func(t *testing.T) {
		submitter := &ProofSubmitter{proposalWindowSize: big.NewInt(1)}
		lastFinalizedProposalID := big.NewInt(10)
		require.False(t, submitter.isProposalOutOfRange(big.NewInt(11), lastFinalizedProposalID))
		require.True(t, submitter.isProposalOutOfRange(big.NewInt(12), lastFinalizedProposalID))
	})

	t.Run("upper bound is inclusive", func(t *testing.T) {
		submitter := &ProofSubmitter{proposalWindowSize: big.NewInt(100)}
		lastFinalizedProposalID := big.NewInt(1000)
		require.False(t, submitter.isProposalOutOfRange(big.NewInt(1100), lastFinalizedProposalID))
		require.True(t, submitter.isProposalOutOfRange(big.NewInt(1101), lastFinalizedProposalID))
	})
}

func TestShouldUseZKProof(t *testing.T) {
	zkvmProducer := &mockProverAdminProducer{cleanAfter: 1}
	submitter := &ProofSubmitter{
		maxZKProofProposalDistance: big.NewInt(30),
		zkvmProofProducer:          zkvmProducer,
	}
	submitter.proofItemsClearResendExecuted.Store(true)

	lastFinalizedProposalID := big.NewInt(10)
	useZK, err := submitter.shouldUseZKProof(t.Context(), big.NewInt(40), lastFinalizedProposalID)
	require.NoError(t, err)
	require.True(t, useZK)

	useZK, err = submitter.shouldUseZKProof(t.Context(), big.NewInt(41), lastFinalizedProposalID)
	require.NoError(t, err)
	require.False(t, useZK)
	require.Equal(t, 1, zkvmProducer.statusCount)
}

func TestShouldUseZKProofUsesConfiguredDistance(t *testing.T) {
	submitter := &ProofSubmitter{
		maxZKProofProposalDistance: big.NewInt(5),
		zkvmProofProducer:          &mockProverAdminProducer{cleanAfter: 1},
	}
	submitter.proofItemsClearResendExecuted.Store(true)

	lastFinalizedProposalID := big.NewInt(10)
	useZK, err := submitter.shouldUseZKProof(t.Context(), big.NewInt(15), lastFinalizedProposalID)
	require.NoError(t, err)
	require.True(t, useZK)

	useZK, err = submitter.shouldUseZKProof(t.Context(), big.NewInt(16), lastFinalizedProposalID)
	require.NoError(t, err)
	require.False(t, useZK)
}

func TestShouldUseZKProofRequiresCleanProver(t *testing.T) {
	submitter := &ProofSubmitter{
		maxZKProofProposalDistance: big.NewInt(30),
		zkvmProofProducer:          &mockProverAdminProducer{cleanAfter: 2},
	}
	submitter.proofItemsClearResendExecuted.Store(true)

	useZK, err := submitter.shouldUseZKProof(t.Context(), big.NewInt(40), big.NewInt(10))
	require.NoError(t, err)
	require.False(t, useZK)
}

func TestShouldUseZKProofAllowsZKBeforeClearResendExecuted(t *testing.T) {
	submitter := &ProofSubmitter{
		maxZKProofProposalDistance: big.NewInt(30),
		zkvmProofProducer:          &mockProverAdminProducer{cleanAfter: 1},
	}

	useZK, err := submitter.shouldUseZKProof(t.Context(), big.NewInt(40), big.NewInt(10))
	require.NoError(t, err)
	require.True(t, useZK)
}

func TestShouldUseZKProofAllowsZKBeforeClearResendExecutedWithoutDistanceLimit(t *testing.T) {
	submitter := &ProofSubmitter{
		maxZKProofProposalDistance: nil,
		zkvmProofProducer:          &mockProverAdminProducer{cleanAfter: 2},
	}

	useZK, err := submitter.shouldUseZKProof(t.Context(), big.NewInt(1000), big.NewInt(10))
	require.NoError(t, err)
	require.True(t, useZK)
}

func TestFlushCacheSkipsEmptyCache(t *testing.T) {
	submitter := &ProofSubmitter{
		proofBuffers: map[proofProducer.ProofType]*proofProducer.ProofBuffer{
			proofProducer.ProofTypeOp: proofProducer.NewProofBuffer(8),
		},
		proofCacheMaps: map[proofProducer.ProofType]cmap.ConcurrentMap[string, *proofProducer.ProofResponse]{
			proofProducer.ProofTypeOp: cmap.New[*proofProducer.ProofResponse](),
		},
	}

	require.NotPanics(t, func() {
		require.NoError(t, submitter.FlushCache(t.Context(), proofProducer.ProofTypeOp))
	})
}

func newShastaMetaForTest(id int64) metadata.TaikoProposalMetaData {
	return metadata.NewTaikoProposalMetadataShasta(
		&shastaBindings.ShastaInboxClientProposed{
			Id:       big.NewInt(id),
			Proposer: common.Address{},
		},
		0,
	)
}

func newProofResponse(id int64) *proofProducer.ProofResponse {
	return &proofProducer.ProofResponse{
		BatchID:   big.NewInt(id),
		ProofType: proofProducer.ProofTypeOp,
	}
}

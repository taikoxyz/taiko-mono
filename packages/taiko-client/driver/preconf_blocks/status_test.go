package preconfblocks

import (
	"context"
	"encoding/json"
	"errors"
	"math/big"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"github.com/ethereum-optimism/optimism/op-service/eth"
	"github.com/ethereum/go-ethereum/core/types"
	gethrpc "github.com/ethereum/go-ethereum/rpc"
	"github.com/labstack/echo/v4"
	dto "github.com/prometheus/client_model/go"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/metrics"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/preconf"
)

type statusTestImporter struct {
	header  *types.Header
	imports int
}

func (i *statusTestImporter) InsertPreconfBlocksFromEnvelopes(
	_ context.Context, envelopes []*preconf.Envelope, _ bool,
) ([]*types.Header, error) {
	i.imports += len(envelopes)
	return []*types.Header{i.header}, nil
}

func TestStatusFallbackTracksP2PImportAfterReplayRewind(t *testing.T) {
	parent := &types.Header{Number: big.NewInt(90), Difficulty: big.NewInt(1)}
	imported := &types.Header{Number: big.NewInt(91), Difficulty: big.NewInt(1), ParentHash: parent.Hash()}
	backend := &proposalHeadRPC{
		head: parent, headers: map[gethrpc.BlockNumber]*types.Header{90: parent},
		started: make(chan struct{}), release: make(chan struct{}),
	}
	importer := &statusTestImporter{header: imported}
	s := &PreconfBlockAPIServer{
		rpc: newProposalHeadClient(t, backend), envelopesCache: newEnvelopeQueue(), chainSyncer: importer,
	}
	s.updateHighestUnsafeL2Payload(100)
	done := make(chan uint64, 1)
	go func() { done <- s.reportedUnsafeHead(context.Background()) }()
	<-backend.started
	cached, err := s.TryImportingPayload(context.Background(), nil, &eth.ExecutionPayloadEnvelope{
		ExecutionPayload: &eth.ExecutionPayload{BlockNumber: 91, BlockHash: imported.Hash(), ParentHash: parent.Hash()},
	}, "")
	close(backend.release)
	require.Equal(t, uint64(90), <-done)
	require.NoError(t, err)
	require.False(t, cached)
	require.Equal(t, 1, importer.imports)
	require.Equal(t, uint64(91), s.highestUnsafeL2PayloadBlockID.Load())
}

func TestStatusDoesNotOverwriteAnInterveningImport(t *testing.T) {
	backend := &proposalHeadRPC{
		head:    &types.Header{Number: big.NewInt(11802683), Difficulty: big.NewInt(1)},
		started: make(chan struct{}), release: make(chan struct{}),
	}
	s := &PreconfBlockAPIServer{rpc: newProposalHeadClient(t, backend)}
	s.updateHighestUnsafeL2Payload(11802680)
	done := make(chan uint64, 1)
	go func() { done <- s.reportedUnsafeHead(context.Background()) }()
	<-backend.started
	s.updateHighestUnsafeL2Payload(11802693)
	close(backend.release)
	require.Equal(t, uint64(11802683), <-done)
	require.Equal(t, uint64(11802693), s.highestUnsafeL2PayloadBlockID.Load())
}

func statusSnapshot(t *testing.T, s *PreconfBlockAPIServer) Status {
	t.Helper()
	recorder := httptest.NewRecorder()
	ctx := echo.New().NewContext(httptest.NewRequest(http.MethodGet, "/status", nil), recorder)
	require.NoError(t, s.GetStatus(ctx))
	var status Status
	require.NoError(t, json.Unmarshal(recorder.Body.Bytes(), &status))
	return status
}

func TestStatusReadsLiveHeadAndFallsBack(t *testing.T) {
	backend := &proposalHeadRPC{head: &types.Header{Number: big.NewInt(11802693), Difficulty: big.NewInt(1)}}
	s := &PreconfBlockAPIServer{rpc: newProposalHeadClient(t, backend), envelopesCache: newEnvelopeQueue()}
	s.updateHighestUnsafeL2Payload(11802683)
	require.Equal(t, uint64(11802693), statusSnapshot(t, s).HighestUnsafeL2PayloadBlockID)
	backend.head.Number = big.NewInt(11802680)
	require.Equal(t, uint64(11802680), statusSnapshot(t, s).HighestUnsafeL2PayloadBlockID)
	backend.err = errors.New("temporary execution RPC failure")
	require.Equal(t, uint64(11802680), statusSnapshot(t, s).HighestUnsafeL2PayloadBlockID)
	s.updateHighestUnsafeL2Payload(11802681)
	require.Equal(t, uint64(11802681), statusSnapshot(t, s).HighestUnsafeL2PayloadBlockID)
}

func TestStatusDoesNotWaitForPreconfirmationLock(t *testing.T) {
	backend := &proposalHeadRPC{head: &types.Header{Number: big.NewInt(11802693), Difficulty: big.NewInt(1)}}
	s := &PreconfBlockAPIServer{rpc: newProposalHeadClient(t, backend), envelopesCache: newEnvelopeQueue()}
	s.mutex.Lock()
	finished := make(chan error, 1)
	go func() {
		recorder := httptest.NewRecorder()
		ctx := echo.New().NewContext(httptest.NewRequest(http.MethodGet, "/status", nil), recorder)
		finished <- s.GetStatus(ctx)
	}()
	select {
	case err := <-finished:
		s.mutex.Unlock()
		require.NoError(t, err)
	case <-time.After(time.Second):
		s.mutex.Unlock()
		<-finished
		t.Fatal("status waited for the preconfirmation import lock")
	}
}

func TestStatusBoundsSlowExecutionRPC(t *testing.T) {
	backend := &proposalHeadRPC{waitForCancellation: true}
	s := &PreconfBlockAPIServer{rpc: newProposalHeadClient(t, backend), envelopesCache: newEnvelopeQueue()}
	s.updateHighestUnsafeL2Payload(11802693)
	started := time.Now()
	require.Equal(t, uint64(11802693), statusSnapshot(t, s).HighestUnsafeL2PayloadBlockID)
	require.Less(t, time.Since(started), time.Second)
}

func TestStatusConcurrentWithImportedHeads(t *testing.T) {
	backend := &proposalHeadRPC{head: &types.Header{Number: big.NewInt(11802693), Difficulty: big.NewInt(1)}}
	s := &PreconfBlockAPIServer{rpc: newProposalHeadClient(t, backend), envelopesCache: newEnvelopeQueue()}
	var imports sync.WaitGroup
	imports.Add(1)
	go func() {
		defer imports.Done()
		for i := uint64(0); i < 100; i++ {
			s.mutex.Lock()
			s.updateHighestUnsafeL2Payload(11802693 + i)
			s.mutex.Unlock()
		}
	}()
	defer imports.Wait()
	for i := 0; i < 10; i++ {
		require.Equal(t, uint64(11802693), statusSnapshot(t, s).HighestUnsafeL2PayloadBlockID)
	}
	imports.Wait()
	var gauge dto.Metric
	require.NoError(t, metrics.DriverHighestPreconfUnsafePayloadGauge.Write(&gauge))
	require.Equal(t, float64(s.highestUnsafeL2PayloadBlockID.Load()), gauge.GetGauge().GetValue())
}

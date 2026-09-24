package preconfblocks

import (
	"context"
	"errors"
	"math/big"
	"net/http/httptest"
	"sync/atomic"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	gethrpc "github.com/ethereum/go-ethereum/rpc"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

type proposalHeadRPC struct {
	head                *types.Header
	headers             map[gethrpc.BlockNumber]*types.Header
	err                 error
	requests            atomic.Uint64
	waitForCancellation bool
	started             chan struct{}
	release             chan struct{}
}

func (r *proposalHeadRPC) ChainId() hexutil.Uint64 { return 167001 }

func (r *proposalHeadRPC) GetBlockByNumber(
	ctx context.Context,
	number gethrpc.BlockNumber,
	_ bool,
) (*types.Header, error) {
	r.requests.Add(1)
	if number != gethrpc.LatestBlockNumber {
		if r.headers != nil {
			return r.headers[number], nil
		}
		return nil, errors.New("expected a current canonical head lookup")
	}
	if r.started != nil {
		close(r.started)
		<-r.release
	}
	if r.waitForCancellation {
		<-ctx.Done()
		return nil, ctx.Err()
	}
	return r.head, r.err
}

func newProposalHeadClient(t *testing.T, backend *proposalHeadRPC) *rpc.Client {
	t.Helper()
	server := gethrpc.NewServer()
	require.NoError(t, server.RegisterName("eth", backend))
	httpServer := httptest.NewServer(server)
	t.Cleanup(httpServer.Close)
	t.Cleanup(server.Stop)
	client, err := rpc.NewEthClient(context.Background(), httpServer.URL, time.Second)
	require.NoError(t, err)
	t.Cleanup(client.Close)
	return &rpc.Client{L2: client}
}

func seenProposal(id int64, lastBlockID uint64, reorged bool) *encoding.LastSeenProposal {
	return &encoding.LastSeenProposal{
		TaikoProposalMetaData: metadata.NewTaikoProposalMetadataShasta(
			&shastaBindings.ShastaInboxClientProposed{Id: big.NewInt(id)}, 0,
		),
		LastBlockID:         lastBlockID,
		PreconfChainReorged: reorged,
	}
}

func TestOutOfOrderProposalNotificationsPreserveLatestProposal(t *testing.T) {
	backend := &proposalHeadRPC{err: errors.New("head RPC must not be called by notifications")}
	s := &PreconfBlockAPIServer{rpc: newProposalHeadClient(t, backend)}
	s.updateHighestUnsafeL2Payload(11802693)
	s.recordLatestSeenProposal(seenProposal(37504, 11802684, false), false)
	s.recordLatestSeenProposal(seenProposal(37503, 11802683, true), false)
	require.Equal(t, int64(37504), s.latestSeenProposal.GetProposalID().Int64())
	require.Equal(t, uint64(11802693), s.highestUnsafeL2PayloadBlockID.Load())
	require.Zero(t, backend.requests.Load())

	// A verified L1 reorg is allowed to reset the cached proposal ID.
	s.recordLatestSeenProposal(seenProposal(37502, 11802682, false), true)
	require.Equal(t, int64(37502), s.latestSeenProposal.GetProposalID().Int64())
}

func TestProposalMonitorDoesNotQueryExecutionHead(t *testing.T) {
	backend := &proposalHeadRPC{err: errors.New("unexpected head lookup")}
	s := &PreconfBlockAPIServer{rpc: newProposalHeadClient(t, backend)}
	s.monitorLatestProposalOnChain(context.Background())
	require.Zero(t, backend.requests.Load())
}

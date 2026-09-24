package preconfblocks

import (
	"context"
	"errors"
	"math/big"
	"net/http/httptest"
	"sync"
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
	startedOnce         sync.Once
}

func (r *proposalHeadRPC) ChainId() hexutil.Uint64 { return 167001 }

func (r *proposalHeadRPC) GetBlockByNumber(
	ctx context.Context,
	number gethrpc.BlockNumber,
	_ bool,
) (*types.Header, error) {
	r.requests.Add(1)
	if number == gethrpc.LatestBlockNumber {
		return nil, errors.New("status must use eth_blockNumber instead of fetching a header")
	}
	return r.headers[number], nil
}

func (r *proposalHeadRPC) BlockNumber(ctx context.Context) (hexutil.Uint64, error) {
	r.requests.Add(1)
	if r.started != nil {
		r.startedOnce.Do(func() { close(r.started) })
		<-r.release
	}
	if r.waitForCancellation {
		<-ctx.Done()
		return 0, ctx.Err()
	}
	if r.err != nil {
		return 0, r.err
	}
	return hexutil.Uint64(r.head.Number.Uint64()), nil
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

func TestProposalNotificationsAcceptRewindsAndSameIDReplacements(t *testing.T) {
	backend := &proposalHeadRPC{err: errors.New("head RPC must not be called by notifications")}
	s := &PreconfBlockAPIServer{rpc: newProposalHeadClient(t, backend)}
	s.updateHighestUnsafeL2Payload(11802693)
	for _, proposal := range []*encoding.LastSeenProposal{
		seenProposal(37504, 11802684, false),
		seenProposal(37503, 11802683, true),
		seenProposal(37503, 11802682, true),
	} {
		s.recordLatestSeenProposal(proposal)
		require.Same(t, proposal, s.latestSeenProposal)
	}
	require.Equal(t, uint64(11802693), s.highestUnsafeL2PayloadBlockID)
	require.Zero(t, backend.requests.Load())
}

func TestProposalMonitorChecksL1WithoutQueryingExecutionHead(t *testing.T) {
	header := &types.Header{Number: big.NewInt(7), Difficulty: big.NewInt(1)}
	l1 := &proposalHeadRPC{headers: map[gethrpc.BlockNumber]*types.Header{7: header}}
	l2 := &proposalHeadRPC{err: errors.New("unexpected head lookup")}
	client := newProposalHeadClient(t, l2)
	client.L1 = newProposalHeadClient(t, l1).L2
	proposal := seenProposal(37504, 11802684, false)
	proposal.Shasta().GetEventData().Raw = types.Log{BlockNumber: 7, BlockHash: header.Hash()}
	s := &PreconfBlockAPIServer{rpc: client, latestSeenProposal: proposal}
	s.monitorLatestProposalOnChain(context.Background())
	require.Equal(t, uint64(1), l1.requests.Load())
	require.Zero(t, l2.requests.Load())
}

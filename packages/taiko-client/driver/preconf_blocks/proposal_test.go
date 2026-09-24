package preconfblocks

import (
	"context"
	"errors"
	"math/big"
	"net/http/httptest"
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
	head *types.Header
	err  error
}

func (r *proposalHeadRPC) ChainId() hexutil.Uint64 { return 167001 }

func (r *proposalHeadRPC) GetBlockByNumber(
	_ context.Context,
	number gethrpc.BlockNumber,
	_ bool,
) (*types.Header, error) {
	if number != gethrpc.LatestBlockNumber {
		return nil, errors.New("expected a current canonical head lookup")
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

func TestProposalNotificationReconcilesUnsafeHead(t *testing.T) {
	for _, tt := range []struct {
		name          string
		unsafe        uint64
		proposalTail  uint64
		executionHead uint64
		reorged       bool
		rpcErr        error
		want          uint64
	}{
		{"same hash replay retains newer preconfirmation", 11802693, 11802683, 11802693, false, nil, 11802693},
		{"delayed reorg retains subsequent preconfirmation", 11802693, 11802683, 11802693, true, nil, 11802693},
		{"real reorg rewinds unsafe head", 11802693, 11802683, 11802683, true, nil, 11802683},
		{"canonical replay repairs stale unsafe marker", 11802683, 11802684, 11802693, false, nil, 11802693},
		{"stale nonreorg notification cannot resurrect removed suffix", 11802683, 11802693, 11802683, false, nil, 11802683},
		{"RPC failure preserves unsafe head", 11802693, 11802683, 0, true, errors.New("execution RPC unavailable"), 11802693},
	} {
		t.Run(tt.name, func(t *testing.T) {
			backend := &proposalHeadRPC{
				head: &types.Header{Number: new(big.Int).SetUint64(tt.executionHead), Difficulty: big.NewInt(1)},
				err:  tt.rpcErr,
			}
			s := &PreconfBlockAPIServer{
				rpc:                           newProposalHeadClient(t, backend),
				highestUnsafeL2PayloadBlockID: tt.unsafe,
			}
			s.recordLatestSeenProposal(context.Background(), seenProposal(37503, tt.proposalTail, tt.reorged))
			require.Equal(t, tt.want, s.highestUnsafeL2PayloadBlockID)
		})
	}
}

func TestOutOfOrderProposalNotificationsPreserveExecutionHead(t *testing.T) {
	backend := &proposalHeadRPC{head: &types.Header{Number: big.NewInt(11802693), Difficulty: big.NewInt(1)}}
	s := &PreconfBlockAPIServer{
		rpc:                           newProposalHeadClient(t, backend),
		highestUnsafeL2PayloadBlockID: 11802693,
	}
	s.recordLatestSeenProposal(context.Background(), seenProposal(37504, 11802684, false))
	s.recordLatestSeenProposal(context.Background(), seenProposal(37503, 11802683, true))
	require.Equal(t, uint64(11802693), s.highestUnsafeL2PayloadBlockID)
}

func TestProposalMonitorRetriesUnsafeHeadWithoutNewBlocks(t *testing.T) {
	backend := &proposalHeadRPC{
		head: &types.Header{Number: big.NewInt(11802683), Difficulty: big.NewInt(1)},
		err:  errors.New("temporary RPC failure"),
	}
	s := &PreconfBlockAPIServer{
		rpc:                           newProposalHeadClient(t, backend),
		highestUnsafeL2PayloadBlockID: 11802693,
	}
	s.monitorLatestProposalOnChain(context.Background())
	require.Equal(t, uint64(11802693), s.highestUnsafeL2PayloadBlockID)
	backend.err = nil
	s.monitorLatestProposalOnChain(context.Background())
	require.Equal(t, uint64(11802683), s.highestUnsafeL2PayloadBlockID)
}

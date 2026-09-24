package blocksinserter

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	gethrpc "github.com/ethereum/go-ethereum/rpc"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/encoding"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/metadata"
	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/pkg/rpc"
)

func TestCanonicalHeadReorged(t *testing.T) {
	previous := &types.Header{Number: big.NewInt(11802693), ParentHash: common.Hash{1}}
	replacement := &types.Header{Number: big.NewInt(11802693), ParentHash: common.Hash{2}}
	rpcErr := errors.New("execution RPC unavailable")
	for _, tt := range []struct {
		name   string
		header *types.Header
		err    error
		want   bool
	}{
		{"old tip remains canonical after replay or extension", previous, nil, false},
		{"old tip replaced at the same height", replacement, nil, true},
		{"rewind removes old tip", nil, ethereum.NotFound, true},
		{"wrapped not found still indicates rewind", nil, fmt.Errorf("header: %w", ethereum.NotFound), true},
		{"RPC failure is not evidence of a reorg", nil, rpcErr, false},
	} {
		t.Run(tt.name, func(t *testing.T) {
			reorged, err := canonicalHeadReorged(context.Background(), previous,
				func(_ context.Context, number *big.Int) (*types.Header, error) {
					require.Equal(t, uint64(11802693), number.Uint64())
					return tt.header, tt.err
				},
			)
			require.Equal(t, tt.want, reorged)
			if errors.Is(tt.err, rpcErr) {
				require.ErrorIs(t, err, rpcErr)
			} else {
				require.NoError(t, err)
			}
		})
	}
}

type replayHeadRPC struct {
	header *types.Header
	err    error
}

func (r *replayHeadRPC) ChainId() hexutil.Uint64 { return 167001 }

func (r *replayHeadRPC) GetBlockByNumber(
	_ context.Context,
	number gethrpc.BlockNumber,
	_ bool,
) (*types.Header, error) {
	if number != 11802693 {
		return nil, fmt.Errorf("unexpected block number: %d", number)
	}
	return r.header, r.err
}

func TestReplayCompletionSurvivesRPCFailure(t *testing.T) {
	backend := &replayHeadRPC{
		header: &types.Header{Number: big.NewInt(11802693), Difficulty: big.NewInt(1), ParentHash: common.Hash{2}},
		err:    errors.New("temporary execution RPC failure"),
	}
	server := gethrpc.NewServer()
	require.NoError(t, server.RegisterName("eth", backend))
	httpServer := httptest.NewServer(server)
	t.Cleanup(httpServer.Close)
	t.Cleanup(server.Stop)
	client, err := rpc.NewEthClient(context.Background(), httpServer.URL, time.Second)
	require.NoError(t, err)
	t.Cleanup(client.Close)
	notifications := make(chan *encoding.LastSeenProposal, 1)
	inserter := &Shasta{
		rpc:                  &rpc.Client{L2: client},
		latestSeenProposalCh: notifications,
		pendingReplay: &replayCompletion{
			previousHead: &types.Header{Number: big.NewInt(11802693), Difficulty: big.NewInt(1), ParentHash: common.Hash{1}},
			proposal: &encoding.LastSeenProposal{
				TaikoProposalMetaData: metadata.NewTaikoProposalMetadataShasta(
					&shastaBindings.ShastaInboxClientProposed{Id: big.NewInt(37503)}, 0,
				),
				LastBlockID: 11802683,
			},
		},
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Second)
	defer cancel()
	// Subsequent preconfirmation imports must resolve the pending comparison
	// before they can mutate the canonical chain and obscure the replay's effect.
	_, err = inserter.InsertPreconfBlocksFromEnvelopes(ctx, nil, false)
	require.Error(t, err)
	require.NotNil(t, inserter.pendingReplay)
	require.Empty(t, notifications)
	backend.err = nil
	_, err = inserter.InsertPreconfBlocksFromEnvelopes(ctx, nil, false)
	require.NoError(t, err)
	select {
	case completion := <-notifications:
		require.True(t, completion.PreconfChainReorged)
		require.Equal(t, uint64(11802683), completion.LastBlockID)
	case <-ctx.Done():
		t.Fatal("reorg completion was lost on retry")
	}
	require.Nil(t, inserter.pendingReplay)
}

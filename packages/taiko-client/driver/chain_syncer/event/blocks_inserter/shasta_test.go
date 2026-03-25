package blocksinserter

import (
	"context"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/require"

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

func TestTryLastFinalizedCheckpointShastaReturnsNilWhenBatchMappingMissing(t *testing.T) {
	var headerRequested bool

	checkpoint, err := tryLastFinalizedCheckpointShasta(
		context.Background(),
		big.NewInt(10),
		func(*bind.CallOpts) (*shastaBindings.IInboxCoreState, error) {
			return &shastaBindings.IInboxCoreState{
				LastFinalizedProposalId: big.NewInt(10),
			}, nil
		},
		func(context.Context, *big.Int) (*hexutil.Big, error) {
			return nil, nil
		},
		func(context.Context, *big.Int) (*types.Header, error) {
			headerRequested = true
			return nil, nil
		},
	)

	require.NoError(t, err)
	require.Nil(t, checkpoint)
	require.False(t, headerRequested)
}

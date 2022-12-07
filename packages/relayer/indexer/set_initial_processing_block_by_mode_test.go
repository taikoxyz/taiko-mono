package indexer

import (
	"context"
	"math/big"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/mock"
)

func Test_SetInitialProcessingBlockByMode(t *testing.T) {
	tests := []struct {
		name       string
		mode       relayer.Mode
		chainID    *big.Int
		wantErr    bool
		wantHeight uint64
	}{
		{
			"resync",
			relayer.ResyncMode,
			mock.MockChainID,
			false,
			0,
		},
		{
			"sync",
			relayer.SyncMode,
			mock.MockChainID,
			false,
			mock.LatestBlock.Height,
		},
		{
			"sync error getting latest block",
			relayer.SyncMode,
			big.NewInt(328938),
			true,
			0,
		},
		{
			"invalidMode",
			relayer.Mode("fake"),
			mock.MockChainID,
			true,
			0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc, _ := newTestService()
			err := svc.setInitialProcessingBlockByMode(
				context.Background(),
				tt.mode,
				tt.chainID,
			)

			assert.Equal(t, tt.wantErr, err != nil)

			assert.Equal(t, tt.wantHeight, svc.processingBlockHeight)
		})
	}
}

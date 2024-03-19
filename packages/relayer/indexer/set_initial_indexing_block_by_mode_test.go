package indexer

import (
	"context"
	"math/big"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

func Test_setInitialIndexingBlockByMode(t *testing.T) {
	tests := []struct {
		name       string
		mode       SyncMode
		chainID    *big.Int
		wantErr    bool
		wantHeight uint64
	}{
		{
			"resync",
			Resync,
			mock.MockChainID,
			false,
			0,
		},
		{
			"sync",
			Sync,
			mock.MockChainID,
			false,
			mock.LatestBlockNumber.Uint64() - 1,
		},
		{
			"sync error getting latest block",
			Sync,
			big.NewInt(328938),
			true,
			0,
		},
		{
			"invalidMode",
			SyncMode("fake"),
			mock.MockChainID,
			true,
			0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc, _ := newTestService(tt.mode, FilterAndSubscribe)
			err := svc.setInitialIndexingBlockByMode(
				context.Background(),
				tt.mode,
				tt.chainID,
			)

			assert.Equal(t, tt.wantErr, err != nil)

			assert.Equal(t, tt.wantHeight, svc.latestIndexedBlockNumber)
		})
	}
}

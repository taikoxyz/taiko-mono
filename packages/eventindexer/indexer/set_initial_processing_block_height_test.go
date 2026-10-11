package indexer

import (
	"context"
	"errors"
	"github.com/stretchr/testify/require"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"testing"
)

type initialNFTCursorRepository struct {
	latest uint64
	err    error
	calls  int
}

func (r *initialNFTCursorRepository) FindLatestBlockID(context.Context, uint64) (uint64, error) {
	r.calls++
	return r.latest, r.err
}
func TestInitialIndexingBlockByMode(t *testing.T) {
	failure := errors.New("cursor failed")
	for _, tt := range []struct {
		name         string
		mode         SyncMode
		latest, want uint64
		err, wantErr error
		calls        int
	}{
		{"resume legacy marker", Sync, 10, 9, nil, nil, 1},
		{"empty marker", Sync, 0, 0, nil, nil, 1},
		{"resync", Resync, 10, 0, nil, nil, 0},
		{"invalid", "invalid", 0, 0, nil, eventindexer.ErrInvalidMode, 0},
		{"cursor failure", Sync, 0, 0, failure, failure, 1},
	} {
		t.Run(tt.name, func(t *testing.T) {
			r := &initialNFTCursorRepository{latest: tt.latest, err: tt.err}
			i := &Indexer{nftCursorRepo: r, srcChainID: 1}
			got, err := i.initialIndexingBlockByMode(context.Background(), tt.mode)
			require.ErrorIs(t, err, tt.wantErr)
			require.Equal(t, tt.want, got)
			require.Equal(t, tt.calls, r.calls)

			if err == nil {
				require.NoError(t, i.setInitialIndexingBlockByMode(context.Background(), tt.mode))
				require.Equal(t, tt.want+1, i.nextFilterStartBlock())
			}
		})
	}
}

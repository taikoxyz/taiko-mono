package indexer

import (
	"context"
	"errors"
	"github.com/stretchr/testify/require"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"testing"
)

type initialNFTCursorRepository struct {
	latest     uint64
	err        error
	calls      int
	checkpoint bool
	saveErr    error
	saved      []uint64
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

func (r *initialNFTCursorRepository) FindCheckpoint(context.Context, uint64) (uint64, bool, error) {
	return r.latest, r.checkpoint, nil
}
func (r *initialNFTCursorRepository) SaveCheckpoint(_ context.Context, _ uint64, height uint64) error {
	if r.saveErr != nil {
		return r.saveErr
	}

	r.saved = append(r.saved, height)
	r.latest = height
	r.checkpoint = true

	return nil
}
func TestInitialNFTCheckpointExact(t *testing.T) {
	r := &initialNFTCursorRepository{latest: 20, checkpoint: true}
	i := &Indexer{nftCursorRepo: r, srcChainID: 1}
	got, err := i.initialIndexingBlockByMode(context.Background(), Sync)
	require.NoError(t, err)
	require.EqualValues(t, 20, got)
}

func TestInitialNFTCheckpointZeroPresent(t *testing.T) {
	r := &initialNFTCursorRepository{checkpoint: true}
	i := &Indexer{nftCursorRepo: r, srcChainID: 1}
	require.NoError(t, i.setInitialIndexingBlockByMode(context.Background(), Sync))
	require.EqualValues(t, 1, i.nextFilterStartBlock())
	require.Zero(t, r.calls)
}

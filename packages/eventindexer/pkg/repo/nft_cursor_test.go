package repo

import (
	"context"
	"testing"

	"github.com/stretchr/testify/require"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/pkg/db"
)

func TestNewNFTCursorRepository(t *testing.T) {
	_, err := NewNFTCursorRepository(nil)
	require.ErrorIs(t, err, db.ErrNoDB)
	_, err = NewNFTCursorRepository(&db.Database{})
	require.NoError(t, err)
}

func TestIntegration_NFTCursorReadsLegacyWatermark(t *testing.T) {
	database, closeFn, err := testMysql(t)
	require.NoError(t, err)

	defer closeFn()

	r, err := NewNFTCursorRepository(database)
	require.NoError(t, err)

	for _, block := range []struct{ chain, height int64 }{{1, 10}, {1, 8}, {2, 20}} {
		require.NoError(t, database.GormDB().Exec(
			`INSERT INTO events (name, event, chain_id, data, emitted_block_id, transacted_at)
			 VALUES ('MessageSent', 'MessageSent', ?, '{}', ?, NOW())`, block.chain, block.height).Error)
	}

	for _, tt := range []struct{ chain, want uint64 }{{1, 10}, {2, 20}, {3, 0}} {
		got, err := r.FindLatestBlockID(context.Background(), tt.chain)
		require.NoError(t, err)
		require.Equal(t, tt.want, got)
	}

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	_, err = r.FindLatestBlockID(ctx, 1)
	require.ErrorIs(t, err, context.Canceled)
}

func TestIntegration_NFTCheckpointMarker(t *testing.T) {
	database, closeFn, err := testMysql(t)
	require.NoError(t, err)

	defer closeFn()

	r, err := NewNFTCursorRepository(database)
	require.NoError(t, err)

	ctx := context.Background()
	for _, height := range []uint64{0, 20, 10, 25} {
		require.NoError(t, r.SaveCheckpoint(ctx, 1, height))
		got, found, err := r.FindCheckpoint(ctx, 1)
		require.NoError(t, err)
		require.True(t, found)

		want := height
		if height == 10 {
			want = 20
		}

		require.Equal(t, want, got)
	}

	require.NoError(t, r.SaveCheckpoint(ctx, 2, 0))
	got, found, err := r.FindCheckpoint(ctx, 2)
	require.NoError(t, err)
	require.True(t, found)
	require.Zero(t, got)

	_, found, err = r.FindCheckpoint(ctx, 3)
	require.NoError(t, err)
	require.False(t, found)

	var count int64

	require.NoError(t, database.GormDB().Table("events").Where("chain_id = ? AND event = ?", 1, NFTCheckpointEvent).Count(&count).Error)
	require.EqualValues(t, 1, count)
	require.NoError(t, database.GormDB().Exec("INSERT INTO events (name, event, chain_id, data, emitted_block_id) "+
		"VALUES ('MessageSent','MessageSent',1,'{}',100)").Error)

	legacy, err := r.FindLatestBlockID(ctx, 1)
	require.NoError(t, err)
	require.EqualValues(t, 100, legacy)

	got, found, err = r.FindCheckpoint(ctx, 1)
	require.NoError(t, err)
	require.True(t, found)
	require.EqualValues(t, 25, got)
}

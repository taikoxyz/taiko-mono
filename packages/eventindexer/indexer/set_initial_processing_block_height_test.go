package indexer

import (
	"context"
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
)

type initialBlockEventRepository struct {
	eventindexer.EventRepository
	latest uint64
	err    error
	calls  int
}

func (r *initialBlockEventRepository) FindLatestBlockID(
	context.Context,
	uint64,
) (uint64, error) {
	r.calls++
	return r.latest, r.err
}

func TestInitialIndexingBlockByMode(t *testing.T) {
	repositoryErr := errors.New("repository failed")
	inboxErr := errors.New("inbox failed")

	tests := []struct {
		name           string
		layer          string
		mode           SyncMode
		latest         uint64
		repositoryErr  error
		firstHeight    uint64
		firstErr       error
		wantHeight     uint64
		wantErr        error
		wantRepoCalls  int
		wantFirstCalls int
	}{
		{
			name:          "l1 sync resumes checkpoint",
			layer:         Layer1,
			mode:          Sync,
			latest:        10,
			wantHeight:    9,
			wantRepoCalls: 1,
		},
		{
			name:          "l2 sync resumes checkpoint",
			layer:         Layer2,
			mode:          Sync,
			latest:        10,
			wantHeight:    9,
			wantRepoCalls: 1,
		},
		{
			name:          "l2 sync empty database",
			layer:         Layer2,
			mode:          Sync,
			wantRepoCalls: 1,
		},
		{
			name:  "l2 resync",
			layer: Layer2,
			mode:  Resync,
		},
		{
			name:           "l1 sync empty database",
			layer:          Layer1,
			mode:           Sync,
			firstHeight:    100,
			wantHeight:     100,
			wantRepoCalls:  1,
			wantFirstCalls: 1,
		},
		{
			name:           "l1 resync",
			layer:          Layer1,
			mode:           Resync,
			firstHeight:    100,
			wantHeight:     100,
			wantFirstCalls: 1,
		},
		{
			name:    "invalid mode",
			layer:   Layer1,
			mode:    SyncMode("invalid"),
			wantErr: eventindexer.ErrInvalidMode,
		},
		{
			name:          "repository error",
			layer:         Layer1,
			mode:          Sync,
			repositoryErr: repositoryErr,
			wantErr:       repositoryErr,
			wantRepoCalls: 1,
		},
		{
			name:           "inbox error",
			layer:          Layer1,
			mode:           Resync,
			firstErr:       inboxErr,
			wantErr:        inboxErr,
			wantFirstCalls: 1,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			repository := &initialBlockEventRepository{
				latest: tt.latest,
				err:    tt.repositoryErr,
			}
			indexer := &Indexer{
				eventRepo:  repository,
				layer:      tt.layer,
				srcChainID: 1,
			}
			firstCalls := 0
			firstShastaBlock := func(context.Context) (uint64, error) {
				firstCalls++
				return tt.firstHeight, tt.firstErr
			}

			got, err := indexer.initialIndexingBlockByMode(
				context.Background(), tt.mode, firstShastaBlock,
			)

			if tt.wantErr == nil {
				assert.NoError(t, err)
			} else {
				assert.ErrorIs(t, err, tt.wantErr)
			}
			assert.Equal(t, tt.wantHeight, got)
			assert.Equal(t, tt.wantRepoCalls, repository.calls)
			assert.Equal(t, tt.wantFirstCalls, firstCalls)
		})
	}
}

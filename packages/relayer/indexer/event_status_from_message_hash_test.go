package indexer

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

func Test_eventStatusFromMsgHash(t *testing.T) {
	tests := []struct {
		name       string
		ctx        context.Context
		signal     [32]byte
		wantErr    error
		wantStatus relayer.EventStatus
	}{
		{
			"eventStatusDone",
			context.Background(),
			[32]byte{},
			nil,
			relayer.EventStatusDone,
		},
		{
			"eventStatusFailed",
			context.Background(),
			mock.FailSignal,
			nil,
			relayer.EventStatusFailed,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc, _ := newTestService(Sync, FilterAndSubscribe)

			status, err := svc.eventStatusFromMsgHash(tt.ctx, tt.signal)
			if tt.wantErr != nil {
				assert.EqualError(t, tt.wantErr, err.Error())
			} else {
				assert.Nil(t, err)
			}

			assert.Equal(t, tt.wantStatus, status)
		})
	}
}

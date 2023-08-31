package indexer

import (
	"context"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/mock"
)

func Test_eventStatusFromMsgHash(t *testing.T) {
	tests := []struct {
		name       string
		ctx        context.Context
		gasLimit   *big.Int
		signal     [32]byte
		wantErr    error
		wantStatus relayer.EventStatus
	}{
		{
			"eventStatusDone",
			context.Background(),
			nil,
			[32]byte{},
			nil,
			relayer.EventStatusDone,
		},
		{
			"eventStatusFailed",
			context.Background(),
			nil,
			mock.FailSignal,
			nil,
			relayer.EventStatusFailed,
		},
		{
			"eventStatusNewOnlyOwner, 0GasLimit",
			context.Background(),
			common.Big0,
			mock.SuccessMsgHash,
			nil,
			relayer.EventStatusNewOnlyOwner,
		},
		{
			"eventStatusNewOnlyOwner, nilGasLimit",
			context.Background(),
			nil,
			mock.SuccessMsgHash,
			nil,
			relayer.EventStatusNewOnlyOwner,
		},
		{
			"eventStatusNewOnlyOwner, non0GasLimit",
			context.Background(),
			big.NewInt(100),
			mock.SuccessMsgHash,
			nil,
			relayer.EventStatusNew,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc, _ := newTestService(Sync, FilterAndSubscribe)

			status, err := svc.eventStatusFromMsgHash(tt.ctx, tt.gasLimit, tt.signal)
			if tt.wantErr != nil {
				assert.EqualError(t, tt.wantErr, err.Error())
			} else {
				assert.Nil(t, err)
			}

			assert.Equal(t, tt.wantStatus, status)
		})
	}
}

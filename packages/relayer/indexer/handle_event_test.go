package indexer

import (
	"context"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
	"github.com/taikochain/taiko-mono/packages/relayer"
)

var (
	relayerAddr = common.HexToAddress("0x71C7656EC7ab88b098defB751B7401B5f6d8976F")
)

func Test_canProcessMessage(t *testing.T) {
	tests := []struct {
		name           string
		eventStatus    relayer.EventStatus
		messageOwner   common.Address
		relayerAddress common.Address
		want           bool
	}{
		{
			"canProcess, eventStatusNew",
			relayer.EventStatusNew,
			relayerAddr,
			relayerAddr,
			true,
		},
		{
			"cantProcess, eventStatusDone",
			relayer.EventStatusDone,
			relayerAddr,
			relayerAddr,
			false,
		},
		{
			"cantProcess, eventStatusRetriable",
			relayer.EventStatusRetriable,
			relayerAddr,
			relayerAddr,
			false,
		},
		{
			"cantProcess, eventStatusNewOnlyOwner and relayer is not owner",
			relayer.EventStatusNewOnlyOwner,
			common.HexToAddress("0x"),
			relayerAddr,
			false,
		},
		{
			"canProcess, eventStatusOnlyOwner and relayer address is owner",
			relayer.EventStatusNewOnlyOwner,
			relayerAddr,
			relayerAddr,
			true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			canProcess := canProcessMessage(
				context.Background(),
				tt.eventStatus,
				tt.messageOwner,
				tt.relayerAddress,
			)

			assert.Equal(t, tt.want, canProcess)
		})
	}
}

func Test_eventStatusFromSignal(t *testing.T) {
	tests := []struct {
		name       string
		ctx        context.Context
		gasLimit   *big.Int
		signal     [32]byte
		wantErr    error
		wantStatus relayer.EventStatus
	}{
		{
			"eventStatusNewOnlyOwner, nilGasLimit",
			context.Background(),
			nil,
			[32]byte{},
			nil,
			relayer.EventStatusNewOnlyOwner,
		},
		{
			"eventStatusNewOnlyOwner, 0GasLimit",
			context.Background(),
			common.Big0,
			[32]byte{},
			nil,
			relayer.EventStatusNewOnlyOwner,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc := newTestService()

			status, err := svc.eventStatusFromSignal(tt.ctx, tt.gasLimit, tt.signal)
			if tt.wantErr != nil {
				assert.EqualError(t, tt.wantErr, err.Error())
			} else {
				assert.Nil(t, err)
			}

			assert.Equal(t, tt.wantStatus, status)
		})
	}
}

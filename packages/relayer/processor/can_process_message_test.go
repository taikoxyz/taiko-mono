package processor

import (
	"context"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
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
			"cantProcess, eventStatusFailed",
			relayer.EventStatusFailed,
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

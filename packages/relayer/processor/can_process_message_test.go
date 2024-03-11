package processor

import (
	"context"
	"math/big"
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
		gasLimit       *big.Int
		want           bool
	}{
		{
			"canProcess, eventStatusNew",
			relayer.EventStatusNew,
			relayerAddr,
			relayerAddr,
			big.NewInt(5),
			true,
		},
		{
			"cantProcess, eventStatusDone",
			relayer.EventStatusDone,
			relayerAddr,
			relayerAddr,
			big.NewInt(5),
			false,
		},
		{
			"cantProcess, eventStatusRetriable",
			relayer.EventStatusRetriable,
			relayerAddr,
			relayerAddr,
			big.NewInt(5),
			false,
		},
		{
			"cantProcess, eventStatusNew , gasLimit 0, and relayer is not owner",
			relayer.EventStatusNew,
			common.HexToAddress("0x"),
			relayerAddr,
			big.NewInt(0),
			false,
		},
		{
			"cantProcess, eventStatusFailed",
			relayer.EventStatusFailed,
			common.HexToAddress("0x"),
			relayerAddr,
			big.NewInt(5),
			false,
		},
		{
			"canProcess, eventStatusNew, gasLimit 0, and relayer address is owner",
			relayer.EventStatusNew,
			relayerAddr,
			relayerAddr,
			big.NewInt(0),
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
				tt.gasLimit,
			)

			assert.Equal(t, tt.want, canProcess)
		})
	}
}

package message

import (
	"context"
	"math/big"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/mock"
)

func Test_isProfitable(t *testing.T) {
	p := newTestProcessor(true)

	tests := []struct {
		name           string
		message        bridge.IBridgeMessage
		cost           *big.Int
		wantProfitable bool
		wantErr        error
	}{
		{
			"zeroProcessingFee",
			bridge.IBridgeMessage{
				ProcessingFee: big.NewInt(0),
			},
			big.NewInt(1),
			false,
			nil,
		},
		{
			"nilProcessingFee",
			bridge.IBridgeMessage{},
			big.NewInt(1),
			false,
			nil,
		},
		{
			"lowProcessingFeeHighCost",
			bridge.IBridgeMessage{
				ProcessingFee: new(big.Int).Sub(mock.ProcessMessageTx.Cost(), big.NewInt(1)),
				DestChainId:   big.NewInt(167001),
			},
			big.NewInt(1000000),
			false,
			nil,
		},
		{
			"profitableProcessingFee",
			bridge.IBridgeMessage{
				ProcessingFee: new(big.Int).Add(mock.ProcessMessageTx.Cost(), big.NewInt(1)),
				DestChainId:   big.NewInt(167001),
			},
			big.NewInt(1),
			true,
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			profitable, err := p.isProfitable(
				context.Background(),
				tt.message,
				tt.cost,
			)

			assert.Equal(t, tt.wantProfitable, profitable)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

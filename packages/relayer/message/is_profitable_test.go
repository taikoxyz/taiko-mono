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
		proof          []byte
		wantProfitable bool
		wantErr        error
	}{
		{
			"zeroProcessingFee",
			bridge.IBridgeMessage{
				ProcessingFee: big.NewInt(0),
			},
			nil,
			false,
			nil,
		},
		{
			"nilProcessingFee",
			bridge.IBridgeMessage{},
			nil,
			false,
			nil,
		},
		{
			"lowProcessingFee",
			bridge.IBridgeMessage{
				ProcessingFee: new(big.Int).Sub(mock.ProcessMessageTx.Cost(), big.NewInt(1)),
				DestChainId:   big.NewInt(167001),
			},
			nil,
			false,
			nil,
		},
		{
			"profitableProcessingFee",
			bridge.IBridgeMessage{
				ProcessingFee: new(big.Int).Add(mock.ProcessMessageTx.Cost(), big.NewInt(1)),
				DestChainId:   big.NewInt(167001),
			},
			nil,
			true,
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			profitable, _, err := p.isProfitable(
				context.Background(),
				tt.message,
				tt.proof,
			)

			assert.Equal(t, tt.wantProfitable, profitable)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

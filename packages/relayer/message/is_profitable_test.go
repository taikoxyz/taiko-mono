package message

import (
	"context"
	"math/big"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts"
	"github.com/taikoxyz/taiko-mono/packages/relayer/mock"
)

func Test_isProfitable(t *testing.T) {
	p := newTestProcessor(true)

	tests := []struct {
		name           string
		message        contracts.IBridgeMessage
		proof          []byte
		wantProfitable bool
		wantErr        error
	}{
		{
			"zeroProcessingFee",
			contracts.IBridgeMessage{
				ProcessingFee: big.NewInt(0),
			},
			nil,
			false,
			nil,
		},
		{
			"nilProcessingFee",
			contracts.IBridgeMessage{},
			nil,
			false,
			nil,
		},
		{
			"lowProcessingFee",
			contracts.IBridgeMessage{
				ProcessingFee: new(big.Int).Sub(mock.ProcessMessageTx.Cost(), big.NewInt(1)),
				DestChainId:   big.NewInt(167001),
			},
			nil,
			false,
			nil,
		},
		{
			"profitableProcessingFee",
			contracts.IBridgeMessage{
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

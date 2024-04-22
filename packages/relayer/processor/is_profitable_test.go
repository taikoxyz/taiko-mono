package processor

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
)

func Test_isProfitable(t *testing.T) {
	p := newTestProcessor(true)

	tests := []struct {
		name           string
		message        bridge.IBridgeMessage
		baseFee        uint64
		gasTipCap      uint64
		wantProfitable bool
		wantErr        error
	}{
		{
			"zeroProcessingFee",
			bridge.IBridgeMessage{
				Fee: 0,
			},
			1,
			1,
			false,
			nil,
		},
		{
			"nilProcessingFee",
			bridge.IBridgeMessage{},
			1,
			1,
			false,
			nil,
		},
		{
			"profitable",
			bridge.IBridgeMessage{
				GasLimit: 600000,
				Fee:      600000000600001,
			},
			1000000000,
			1,
			true,
			nil,
		},
		{
			"unprofitable",
			bridge.IBridgeMessage{
				GasLimit: 600000,
				Fee:      590000000600000,
			},
			1000000000,
			1,
			false,
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			profitable, err := p.isProfitable(
				context.Background(),
				tt.message,
				tt.baseFee,
				tt.gasTipCap,
			)

			assert.Equal(t, tt.wantProfitable, profitable)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

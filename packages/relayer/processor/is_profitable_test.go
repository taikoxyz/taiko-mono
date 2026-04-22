package processor

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
)

func Test_isProfitable(t *testing.T) {
	p := newTestProcessor(true)

	tests := []struct {
		id             int
		name           string
		fee            uint64
		gasLimit       uint64
		baseFee        uint64
		gasTipCap      uint64
		wantProfitable bool
		wantErr        error
	}{
		{
			0,
			"zeroProcessingFee",
			0,
			1,
			1,
			1,
			false,
			errImpossible,
		},
		{
			1,
			"profitable",
			7000000000600001,
			600000,
			1000000000,
			1,
			true,
			nil,
		},
		{
			2,
			"unprofitable",
			590000000600000,
			600000,
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
				tt.id,
				tt.fee,
				tt.gasLimit,
				tt.baseFee,
				tt.gasTipCap,
			)

			assert.Equal(t, tt.wantProfitable, profitable)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

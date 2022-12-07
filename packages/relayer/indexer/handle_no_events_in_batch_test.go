package indexer

import (
	"context"
	"math/big"
	"testing"

	"github.com/stretchr/testify/assert"
)

func Test_handleNoEventsInBatch(t *testing.T) {
	tests := []struct {
		name        string
		chainID     *big.Int
		blockNumber int64
		wantErr     error
	}{
		{
			"success",
			big.NewInt(167001),
			1,
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc, _ := newTestService()

			assert.NotEqual(t, svc.processingBlockHeight, uint64(tt.blockNumber))

			err := svc.handleNoEventsInBatch(context.Background(), tt.chainID, tt.blockNumber)

			assert.Equal(t, tt.wantErr, err)

			assert.Equal(t, svc.processingBlockHeight, uint64(tt.blockNumber))
		})
	}
}

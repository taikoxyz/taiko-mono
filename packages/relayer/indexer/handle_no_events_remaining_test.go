package indexer

import (
	"context"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/assert"
	"github.com/taikochain/taiko-mono/packages/relayer/contracts"
)

func Test_handleNoEventsRemaining(t *testing.T) {
	tests := []struct {
		name    string
		chainID *big.Int
		events  *contracts.BridgeMessageSentIterator
		wantErr error
	}{
		{
			"success",
			big.NewInt(167001),
			&contracts.BridgeMessageSentIterator{
				Event: &contracts.BridgeMessageSent{
					Raw: types.Log{
						BlockNumber: 1,
					},
				},
			},
			nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			svc := newTestService()
			err := svc.handleNoEventsRemaining(context.Background(), tt.chainID, tt.events)
			assert.Equal(t, tt.wantErr, err)
		})
	}
}

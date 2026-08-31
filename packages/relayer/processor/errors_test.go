package processor

import (
	"errors"
	"fmt"
	"testing"

	"github.com/stretchr/testify/assert"
)

func Test_IsMaxPriorityFeePerGasNotFoundError(t *testing.T) {
	tests := []struct {
		name string
		err  error
		want bool
	}{
		{
			name: "the sentinel itself",
			err:  errMaxPriorityFeePerGasNotFound,
			want: true,
		},
		{
			// The check is on the text rather than the error identity, because it arrives from an
			// RPC round trip as a fresh error rather than as our own sentinel.
			name: "an RPC error carrying the same text",
			err:  errors.New("Method eth_maxPriorityFeePerGas not found"),
			want: true,
		},
		{
			name: "wrapped in transport detail",
			err:  fmt.Errorf("rpc call failed: %w", errMaxPriorityFeePerGasNotFound),
			want: true,
		},
		{
			name: "an unrelated error",
			err:  errors.New("execution reverted"),
			want: false,
		},
		{
			// Close but not the same method: matching this would silently swap a real tip cap for
			// the fallback constant.
			name: "a different missing method",
			err:  errors.New("Method eth_feeHistory not found"),
			want: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			assert.Equal(t, tt.want, IsMaxPriorityFeePerGasNotFoundError(tt.err))
		})
	}
}

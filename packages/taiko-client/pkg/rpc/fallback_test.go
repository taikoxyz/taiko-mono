package rpc

import (
	"errors"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestIsMaxPriorityFeePerGasNotFoundError(t *testing.T) {
	require.False(t, IsMaxPriorityFeePerGasNotFoundError(errors.New("test")))
	require.True(t, IsMaxPriorityFeePerGasNotFoundError(errMaxPriorityFeePerGasNotFound))
}

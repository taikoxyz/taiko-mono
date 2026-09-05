package flags

import (
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestETHClientRequestTimeoutDefaultsToFiveMinutes(t *testing.T) {
	require.Equal(t, 5*time.Minute, ETHClientRequestTimeout.Value)
	require.Contains(t, CommonFlags, ETHClientRequestTimeout)
}

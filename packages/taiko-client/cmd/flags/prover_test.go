package flags

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestProverRaikoHostFlagsRequired(t *testing.T) {
	require.True(t, RaikoHostEndpoint.Required)
	require.True(t, RaikoZKVMHostEndpoint.Required)
}

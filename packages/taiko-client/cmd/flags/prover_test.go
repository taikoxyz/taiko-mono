package flags

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestProverFlagsExcludeRaikoEndpoints(t *testing.T) {
	names := flagNames(ProverFlags)

	require.Contains(t, names, RaikoHostEndpoint.Name)
	require.Contains(t, names, RaikoZKVMHostEndpoint.Name)
}

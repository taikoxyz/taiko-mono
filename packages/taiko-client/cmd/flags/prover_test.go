package flags

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestProverRaikoHostFlagRequired(t *testing.T) {
	require.True(t, RaikoHostEndpoint.Required)
}

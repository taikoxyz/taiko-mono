package flags

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestProverRaikoHostFlagRequired(t *testing.T) {
	require.True(t, RaikoHostEndpoint.Required)
}

func TestProverMaxRisc0ProofProposalDistanceDefaultsToSP1Only(t *testing.T) {
	require.Equal(t, uint64(0), MaxRisc0ProofProposalDistance.Value)
	require.Contains(t, MaxRisc0ProofProposalDistance.Usage, "Defaults to 0")
}

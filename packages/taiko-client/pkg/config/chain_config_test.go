package config

import (
	"math/big"
	"testing"

	gethcore "github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/require"
)

func TestRemovedChainUsesUnknownNetworkDescription(t *testing.T) {
	config := &ChainConfig{ChainID: big.NewInt(167_011)}

	description := config.Description()
	require.Contains(t, description, "Chain ID:  167011 (unknown)")
	require.NotContains(t, description, " - Ontake:")
	require.NotContains(t, description, " - Pacaya:")
	require.NotContains(t, description, " - Shasta:")
	require.NotContains(t, description, " - Unzen:")
	require.NotContains(t, description, " - Etna:")
}

func TestMainnetDescriptionListsUnscheduledEtna(t *testing.T) {
	description := (&ChainConfig{ChainID: params.TaikoMainnetNetworkID}).Description()
	require.Contains(t, description, "\n - Etna:                     inactive\n")
}

func TestDevnetDescriptionListsEtnaOverride(t *testing.T) {
	original := gethcore.DevnetEtnaTime
	t.Cleanup(func() { gethcore.DevnetEtnaTime = original })

	gethcore.DevnetEtnaTime = 4242

	description := (&ChainConfig{ChainID: params.TaikoInternalNetworkID}).Description()
	require.Contains(t, description, " - Etna:                     @4242")
}

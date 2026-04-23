package rpc

import (
	"math"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/require"
)

func TestIsUnzen_DevnetActiveFromGenesis(t *testing.T) {
	devnetID := params.TaikoInternalNetworkID

	require.True(t, IsUnzen(devnetID, 0))
	require.True(t, IsUnzen(devnetID, 1))
	require.True(t, IsUnzen(devnetID, math.MaxUint64))
}

func TestIsUnzen_NonDevnetNeverActive(t *testing.T) {
	mainnetID := params.TaikoMainnetNetworkID
	require.False(t, IsUnzen(mainnetID, 0))
	require.False(t, IsUnzen(mainnetID, math.MaxUint64))

	hoodiID := params.TaikoHoodiNetworkID
	require.False(t, IsUnzen(hoodiID, 0))
	require.False(t, IsUnzen(hoodiID, math.MaxUint64))

	masayaID := params.MasayaDevnetNetworkID
	require.False(t, IsUnzen(masayaID, 0))
	require.False(t, IsUnzen(masayaID, math.MaxUint64))
}

func TestIsUnzen_NilOrUnknownChainID(t *testing.T) {
	require.False(t, IsUnzen(nil, 0))
	require.False(t, IsUnzen((*big.Int)(nil), 12345))
	require.False(t, IsUnzen(big.NewInt(999999), 0))
}

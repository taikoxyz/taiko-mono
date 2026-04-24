package rpc

import (
	"math/big"
	"testing"

	gethcore "github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/require"
)

func TestIsUnzen_DevnetHonorsDevnetUnzenTimeOverride(t *testing.T) {
	original := gethcore.DevnetUnzenTime
	t.Cleanup(func() { gethcore.DevnetUnzenTime = original })

	gethcore.DevnetUnzenTime = 100

	devnetID := params.TaikoInternalNetworkID
	require.False(t, IsUnzen(devnetID, 99), "before override timestamp")
	require.True(t, IsUnzen(devnetID, 100), "at override timestamp")
	require.True(t, IsUnzen(devnetID, 101), "after override timestamp")
}

func TestIsUnzen_NonDevnetUnaffectedByOverride(t *testing.T) {
	original := gethcore.DevnetUnzenTime
	t.Cleanup(func() { gethcore.DevnetUnzenTime = original })

	gethcore.DevnetUnzenTime = 100

	mainnetID := params.TaikoMainnetNetworkID
	require.False(t, IsUnzen(mainnetID, 0), "mainnet must remain inactive (MaxUint64)")
	require.False(t, IsUnzen(mainnetID, 100), "mainnet must remain inactive at devnet override timestamp")

	hoodiID := params.TaikoHoodiNetworkID
	require.False(t, IsUnzen(hoodiID, 0))
	require.False(t, IsUnzen(hoodiID, 100))
}

func TestIsUnzen_NilChainID(t *testing.T) {
	require.False(t, IsUnzen(nil, 0))
	require.False(t, IsUnzen((*big.Int)(nil), 12345))
}

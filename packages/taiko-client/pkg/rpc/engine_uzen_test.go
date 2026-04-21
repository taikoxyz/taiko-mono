package rpc

import (
	"math/big"
	"testing"

	gethcore "github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/require"
)

func TestIsUzen_DevnetHonorsInternalUzenTimeOverride(t *testing.T) {
	original := gethcore.InternalUzenTime
	t.Cleanup(func() { gethcore.InternalUzenTime = original })

	gethcore.InternalUzenTime = 100

	devnetID := params.TaikoInternalNetworkID
	require.False(t, IsUzen(devnetID, 99), "before override timestamp")
	require.True(t, IsUzen(devnetID, 100), "at override timestamp")
	require.True(t, IsUzen(devnetID, 101), "after override timestamp")
}

func TestIsUzen_NonDevnetUnaffectedByOverride(t *testing.T) {
	original := gethcore.InternalUzenTime
	t.Cleanup(func() { gethcore.InternalUzenTime = original })

	gethcore.InternalUzenTime = 100

	mainnetID := params.TaikoMainnetNetworkID
	require.False(t, IsUzen(mainnetID, 0), "mainnet must remain inactive (MaxUint64)")
	require.False(t, IsUzen(mainnetID, 100), "mainnet must remain inactive at devnet override timestamp")

	hoodiID := params.TaikoHoodiNetworkID
	require.False(t, IsUzen(hoodiID, 0))
	require.False(t, IsUzen(hoodiID, 100))
}

func TestIsUzen_NilChainID(t *testing.T) {
	require.False(t, IsUzen(nil, 0))
	require.False(t, IsUzen((*big.Int)(nil), 12345))
}

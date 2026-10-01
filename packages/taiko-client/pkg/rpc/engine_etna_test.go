package rpc

import (
	"math"
	"math/big"
	"testing"

	gethcore "github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/require"
)

// pinDevnetForkTimes overrides the devnet Unzen and Etna activation times for one test.
func pinDevnetForkTimes(t *testing.T, unzen, etna uint64) {
	t.Helper()
	originalUnzen, originalEtna := gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime
	t.Cleanup(func() { gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime = originalUnzen, originalEtna })
	gethcore.DevnetUnzenTime, gethcore.DevnetEtnaTime = unzen, etna
}

func TestIsEtna_DevnetHonorsDevnetEtnaTimeOverride(t *testing.T) {
	pinDevnetForkTimes(t, 0, 100)

	devnetID := params.TaikoInternalNetworkID
	require.False(t, IsEtna(devnetID, 99), "before override timestamp")
	require.True(t, IsEtna(devnetID, 100), "at override timestamp")
	require.True(t, IsEtna(devnetID, 101), "after override timestamp")
}

func TestIsEtna_PublicNetworksUnscheduled(t *testing.T) {
	pinDevnetForkTimes(t, 0, 0)

	for _, chainID := range []*big.Int{params.TaikoMainnetNetworkID, params.TaikoHoodiNetworkID} {
		require.False(t, IsEtna(chainID, 0))
		require.False(t, IsEtna(chainID, math.MaxUint64-1))
	}
}

func TestIsEtna_NilAndUnknownChainID(t *testing.T) {
	require.False(t, IsEtna(nil, 0))
	require.False(t, IsEtna(big.NewInt(123456789), 0))
}

func TestForkLabel_OrdersEtnaUnzenShasta(t *testing.T) {
	pinDevnetForkTimes(t, 100, 200)

	devnetID := params.TaikoInternalNetworkID
	require.Equal(t, "Shasta", ForkLabel(devnetID, 99))
	require.Equal(t, "Unzen", ForkLabel(devnetID, 100))
	require.Equal(t, "Unzen", ForkLabel(devnetID, 199))
	require.Equal(t, "Etna", ForkLabel(devnetID, 200))
}

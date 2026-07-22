package manifest

import (
	"math/big"
	"testing"

	gethcore "github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/require"
)

func TestAnchorMaxOffsetByChainID(t *testing.T) {
	require.Equal(t, uint64(128), AnchorMaxOffsetByChainID(params.TaikoHoodiNetworkID))
	require.Equal(t, uint64(512), AnchorMaxOffsetByChainID(params.TaikoMainnetNetworkID))
	require.Equal(t, uint64(128), AnchorMaxOffsetByChainID(nil))
	require.Equal(t, uint64(128), AnchorMaxOffsetByChainID(big.NewInt(12345))) // unknown chain
}

func TestTimestampMaxOffsetByChainID(t *testing.T) {
	require.Equal(t, uint64(12*128), TimestampMaxOffsetByChainID(params.TaikoHoodiNetworkID))
	require.Equal(t, uint64(12*512), TimestampMaxOffsetByChainID(params.TaikoMainnetNetworkID))
	require.Equal(t, uint64(12*128), TimestampMaxOffsetByChainID(nil))
	require.Equal(t, uint64(12*128), TimestampMaxOffsetByChainID(big.NewInt(12345))) // unknown chain
}

func TestShastaForkTimeByChainID(t *testing.T) {
	// The accessor mirrors the taiko-geth fork schedule for every supported chain.
	require.Equal(t, gethcore.MainnetShastaTime, ShastaForkTimeByChainID(params.TaikoMainnetNetworkID))
	require.Equal(t, gethcore.HoodiShastaTime, ShastaForkTimeByChainID(params.TaikoHoodiNetworkID))
	require.Equal(t, gethcore.MasayaShastaTime, ShastaForkTimeByChainID(params.MasayaDevnetNetworkID))
	require.Equal(t, gethcore.InternalShastaTime, ShastaForkTimeByChainID(params.TaikoInternalNetworkID))

	// nil and unknown chains impose no fork-time floor.
	require.Equal(t, uint64(0), ShastaForkTimeByChainID(nil))
	require.Equal(t, uint64(0), ShastaForkTimeByChainID(big.NewInt(12345))) // unknown chain

	// Devnets activate Shasta from genesis (floor == 0); public networks activate at a
	// non-genesis timestamp (floor > 0). This is the invariant the fork-time floor relies on.
	require.Zero(t, ShastaForkTimeByChainID(params.TaikoInternalNetworkID))
	require.Zero(t, ShastaForkTimeByChainID(params.MasayaDevnetNetworkID))
	require.NotZero(t, ShastaForkTimeByChainID(params.TaikoHoodiNetworkID))
	require.NotZero(t, ShastaForkTimeByChainID(params.TaikoMainnetNetworkID))
}

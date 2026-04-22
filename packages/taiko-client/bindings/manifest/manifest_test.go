package manifest

import (
	"math/big"
	"testing"

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

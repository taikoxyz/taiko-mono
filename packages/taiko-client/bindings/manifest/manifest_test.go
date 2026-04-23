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

func TestProposalMaxBlocksByChainIDAndTimestamp(t *testing.T) {
	original := gethcore.InternalUzenTime
	t.Cleanup(func() { gethcore.InternalUzenTime = original })

	gethcore.InternalUzenTime = 100

	require.Equal(t, ProposalMaxBlocks, ProposalMaxBlocksByChainIDAndTimestamp(nil, 0))
	require.Equal(
		t,
		ProposalMaxBlocks,
		ProposalMaxBlocksByChainIDAndTimestamp(params.TaikoInternalNetworkID, 99),
	)
	require.Equal(
		t,
		UzenProposalMaxBlocks,
		ProposalMaxBlocksByChainIDAndTimestamp(params.TaikoInternalNetworkID, 100),
	)
	require.Equal(
		t,
		ProposalMaxBlocks,
		ProposalMaxBlocksByChainIDAndTimestamp(params.TaikoHoodiNetworkID, 100),
	)
}

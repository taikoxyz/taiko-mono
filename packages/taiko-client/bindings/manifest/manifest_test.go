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

func TestProposalMaxBlocksByChainIDAndTimestamp(t *testing.T) {
	// Nil / unknown chains get the pre-Unzen limit.
	require.Equal(t, ProposalMaxBlocks, ProposalMaxBlocksByChainIDAndTimestamp(nil, 0))
	require.Equal(t, ProposalMaxBlocks, ProposalMaxBlocksByChainIDAndTimestamp(big.NewInt(12345), 0))

	// Devnet is always Unzen-active (Unzen activation = genesis).
	require.Equal(
		t,
		UnzenProposalMaxBlocks,
		ProposalMaxBlocksByChainIDAndTimestamp(params.TaikoInternalNetworkID, 0),
	)
	require.Equal(
		t,
		UnzenProposalMaxBlocks,
		ProposalMaxBlocksByChainIDAndTimestamp(params.TaikoInternalNetworkID, 100),
	)

	// Hoodi/Mainnet/Masaya have no Unzen activation scheduled yet: pre-Unzen limit.
	require.Equal(
		t,
		ProposalMaxBlocks,
		ProposalMaxBlocksByChainIDAndTimestamp(params.TaikoHoodiNetworkID, 100),
	)
	require.Equal(
		t,
		ProposalMaxBlocks,
		ProposalMaxBlocksByChainIDAndTimestamp(params.TaikoMainnetNetworkID, 100),
	)
}

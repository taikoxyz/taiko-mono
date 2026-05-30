package encoding

import (
	"math/big"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestDecodeShastaExtraDataProposalID(t *testing.T) {
	for _, proposalID := range []*big.Int{
		big.NewInt(0),
		big.NewInt(1),
		big.NewInt(123456),
		new(big.Int).SetUint64((1 << 48) - 1), // max uint48
	} {
		extra, err := EncodeShastaExtraData(42, proposalID)
		require.NoError(t, err)

		decoded, err := DecodeShastaExtraDataProposalID(extra)
		require.NoError(t, err)
		require.Zero(t, decoded.Cmp(proposalID), "round-trip mismatch for %s", proposalID)
	}

	// Too-short extraData must error rather than panic.
	_, err := DecodeShastaExtraDataProposalID([]byte{0x00, 0x01})
	require.Error(t, err)
}

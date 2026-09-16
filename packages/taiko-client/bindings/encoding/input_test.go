package encoding

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/require"
)

// basefeeSharingPctgRange covers every value the inbox accepts, both ends included:
// `LibInboxSetup.validateConfig` requires `basefeeSharingPctg <= 100`, and taiko-geth
// splits a transaction's basefee as `gasUsed * baseFee * pctg / 100` to the coinbase
// with the remainder to the treasury. At 0 the coinbase is paid nothing, at 100 the
// treasury is.
var basefeeSharingPctgRange = []uint8{0, 1, 25, 75, 99, 100}

// TestEncodeShastaExtraDataBasefeeSharingPctg round-trips the percentage byte through
// the decoder both clients rely on, so a change to either end of the range shows up here
// rather than as a block the drivers re-derive with different extraData.
func TestEncodeShastaExtraDataBasefeeSharingPctg(t *testing.T) {
	for _, pctg := range basefeeSharingPctgRange {
		extraData, err := EncodeShastaExtraData(pctg, big.NewInt(1))
		require.Nil(t, err)
		require.Len(t, extraData, params.ShastaExtraDataLen)
		require.Equal(t, pctg, core.DecodeShastaBasefeeSharingPctg(extraData))
	}
}

// TestEncodeShastaExtraDataIndependentFields asserts the percentage and the proposal ID
// never read each other's bytes, including when one of them is zero.
func TestEncodeShastaExtraDataIndependentFields(t *testing.T) {
	maxProposalID := new(big.Int).Sub(
		new(big.Int).Lsh(big.NewInt(1), uint(params.ShastaExtraDataProposalIDLength*8)),
		big.NewInt(1),
	)

	for _, pctg := range basefeeSharingPctgRange {
		for _, proposalID := range []*big.Int{big.NewInt(0), big.NewInt(1), big.NewInt(1337), maxProposalID} {
			extraData, err := EncodeShastaExtraData(pctg, proposalID)
			require.Nil(t, err)

			require.Equal(t, pctg, core.DecodeShastaBasefeeSharingPctg(extraData))

			decodedID, err := core.DecodeShastaProposalID(extraData)
			require.Nil(t, err)
			require.Zero(t, proposalID.Cmp(decodedID))
		}
	}
}

// TestEncodeShastaExtraDataRejectsInvalidProposalID pins the three cases the encoder
// refuses, so an out-of-range proposal ID never silently truncates into the percentage byte.
func TestEncodeShastaExtraDataRejectsInvalidProposalID(t *testing.T) {
	_, err := EncodeShastaExtraData(100, nil)
	require.ErrorContains(t, err, "proposal ID is nil")

	_, err = EncodeShastaExtraData(100, big.NewInt(-1))
	require.ErrorContains(t, err, "proposal ID is negative")

	tooLarge := new(big.Int).Lsh(big.NewInt(1), uint(params.ShastaExtraDataProposalIDLength*8))
	_, err = EncodeShastaExtraData(100, tooLarge)
	require.ErrorContains(t, err, "proposal ID too large")
}

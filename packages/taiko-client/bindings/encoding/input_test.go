package encoding

import (
	"fmt"
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/core"
	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/require"
)

// basefeeSharingPctgRange returns every value the inbox accepts: `LibInboxSetup.validateConfig`
// requires `basefeeSharingPctg <= 100`. taiko-geth splits a transaction's basefee as
// `gasUsed * baseFee * pctg / 100` to the coinbase and pays the remainder to the treasury, so at 0
// the coinbase is paid nothing and at 100 the treasury is paid nothing. Both ends are reachable
// configurations rather than edge cases, and covering all 101 values costs nothing.
func basefeeSharingPctgRange() []uint8 {
	pctgs := make([]uint8, 0, 101)
	for pctg := 0; pctg <= 100; pctg++ {
		pctgs = append(pctgs, uint8(pctg))
	}
	return pctgs
}

// TestEncodeShastaExtraDataBasefeeSharingPctg round-trips every accepted percentage through the
// decoder both clients rely on, so a change at either end of the range shows up here rather than
// as a block the drivers re-derive with different extraData.
func TestEncodeShastaExtraDataBasefeeSharingPctg(t *testing.T) {
	for _, pctg := range basefeeSharingPctgRange() {
		t.Run(fmt.Sprintf("pctg=%d", pctg), func(t *testing.T) {
			extraData, err := EncodeShastaExtraData(pctg, big.NewInt(1))
			require.Nil(t, err)
			require.Len(t, extraData, params.ShastaExtraDataLen)
			require.Equal(t, pctg, core.DecodeShastaBasefeeSharingPctg(extraData))
		})
	}
}

// TestEncodeShastaExtraDataIndependentFields asserts the percentage and the proposal ID never read
// each other's bytes, including when either is zero and when the ID fills its whole uint48.
func TestEncodeShastaExtraDataIndependentFields(t *testing.T) {
	maxProposalID := new(big.Int).Sub(
		new(big.Int).Lsh(big.NewInt(1), uint(params.ShastaExtraDataProposalIDLength*8)),
		big.NewInt(1),
	)
	proposalIDs := []*big.Int{big.NewInt(0), big.NewInt(1), big.NewInt(1337), maxProposalID}

	for _, pctg := range basefeeSharingPctgRange() {
		for _, proposalID := range proposalIDs {
			t.Run(fmt.Sprintf("pctg=%d/proposalID=%s", pctg, proposalID), func(t *testing.T) {
				extraData, err := EncodeShastaExtraData(pctg, proposalID)
				require.Nil(t, err)

				require.Equal(t, pctg, core.DecodeShastaBasefeeSharingPctg(extraData))

				decodedID, err := core.DecodeShastaProposalID(extraData)
				require.Nil(t, err)
				require.Zero(t, proposalID.Cmp(decodedID))
			})
		}
	}
}

// TestEncodeShastaExtraDataRejectsInvalidProposalID pins the three cases the encoder refuses, so an
// out-of-range proposal ID never silently truncates into the percentage byte.
func TestEncodeShastaExtraDataRejectsInvalidProposalID(t *testing.T) {
	tooLarge := new(big.Int).Lsh(big.NewInt(1), uint(params.ShastaExtraDataProposalIDLength*8))

	for _, tt := range []struct {
		name       string
		proposalID *big.Int
		wantErr    string
	}{
		{"nil", nil, "proposal ID is nil"},
		{"negative", big.NewInt(-1), "proposal ID is negative"},
		{"tooLarge", tooLarge, "proposal ID too large"},
	} {
		t.Run(tt.name, func(t *testing.T) {
			_, err := EncodeShastaExtraData(100, tt.proposalID)
			require.ErrorContains(t, err, tt.wantErr)
		})
	}
}

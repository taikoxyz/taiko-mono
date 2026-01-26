package blocksinserter

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/params"
	"github.com/stretchr/testify/require"
)

func TestEncodeShastaExtraData_EndOfProposalFlag(t *testing.T) {
	const basefeeSharingPctg = uint8(0x2a)
	const endOfProposalDisabled = byte(0x00)
	const endOfProposalEnabled = byte(0x01)

	proposalID := big.NewInt(0x010203040506)
	expectedProposalBytes := []byte{0x01, 0x02, 0x03, 0x04, 0x05, 0x06}

	extra, err := encodeShastaExtraData(basefeeSharingPctg, proposalID, false)
	require.NoError(t, err)
	require.Len(t, extra, params.ShastaExtraDataLen)
	require.Equal(t, byte(basefeeSharingPctg), extra[params.ShastaExtraDataBasefeeSharingPctgIndex])
	require.Equal(t, endOfProposalDisabled, extra[params.ShastaExtraDataEndOfProposalIndex])
	require.Equal(
		t,
		expectedProposalBytes,
		extra[params.ShastaExtraDataProposalIDIndex:params.ShastaExtraDataProposalIDIndex+params.ShastaExtraDataProposalIDLength],
	)

	extraEOP, err := encodeShastaExtraData(basefeeSharingPctg, proposalID, true)
	require.NoError(t, err)
	require.Len(t, extraEOP, params.ShastaExtraDataLen)
	require.Equal(t, byte(basefeeSharingPctg), extraEOP[params.ShastaExtraDataBasefeeSharingPctgIndex])
	require.Equal(t, endOfProposalEnabled, extraEOP[params.ShastaExtraDataEndOfProposalIndex])
	require.Equal(
		t,
		expectedProposalBytes,
		extraEOP[params.ShastaExtraDataProposalIDIndex:params.ShastaExtraDataProposalIDIndex+params.ShastaExtraDataProposalIDLength],
	)

	expectedEOP := append([]byte(nil), extra...)
	expectedEOP[params.ShastaExtraDataEndOfProposalIndex] = endOfProposalEnabled
	require.Equal(t, expectedEOP, extraEOP)
}

func TestEncodeShastaExtraData_LengthAndProposalID(t *testing.T) {
	const basefeeSharingPctg = uint8(0x01)

	proposalID := big.NewInt(1)
	expectedProposalBytes := []byte{0x00, 0x00, 0x00, 0x00, 0x00, 0x01}

	extra, err := encodeShastaExtraData(basefeeSharingPctg, proposalID, true)
	require.NoError(t, err)
	require.Len(t, extra, params.ShastaExtraDataLen)
	require.Equal(
		t,
		expectedProposalBytes,
		extra[params.ShastaExtraDataProposalIDIndex:params.ShastaExtraDataProposalIDIndex+params.ShastaExtraDataProposalIDLength],
	)
}

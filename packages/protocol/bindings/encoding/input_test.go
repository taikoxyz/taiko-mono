package encoding

import (
	"math/big"
	"math/rand"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/require"
	"github.com/taikoxyz/taiko-client/bindings"
	"github.com/taikoxyz/taiko-client/testutils"
)

func TestEncodeEvidence(t *testing.T) {
	evidence := &TaikoL1Evidence{
		Meta:   testMeta,
		Header: *FromGethHeader(testHeader),
		Prover: common.BytesToAddress(testutils.RandomHash().Bytes()),
		Proofs: [][]byte{testutils.RandomHash().Bytes(), testutils.RandomHash().Bytes(), testutils.RandomHash().Bytes()},
	}

	b, err := EncodeEvidence(evidence)

	require.Nil(t, err)
	require.NotEmpty(t, b)
}

func TestEncodeCommitHash(t *testing.T) {
	require.NotEmpty(t, EncodeCommitHash(common.BytesToAddress(testutils.RandomHash().Bytes()), testutils.RandomHash()))
}

func TestEncodeProposeBlockInput(t *testing.T) {
	encoded, err := EncodeProposeBlockInput(&testMeta, testutils.RandomHash().Bytes())

	require.Nil(t, err)
	require.NotNil(t, encoded)
}

func TestEncodeProveBlockInput(t *testing.T) {
	encoded, err := EncodeProveBlockInput(
		&TaikoL1Evidence{
			Meta:   testMeta,
			Header: *FromGethHeader(testHeader),
			Prover: common.BytesToAddress(testutils.RandomHash().Bytes()),
		},
		types.NewTransaction(
			0,
			common.BytesToAddress(testutils.RandomHash().Bytes()),
			common.Big0,
			0,
			common.Big0,
			testutils.RandomHash().Bytes(),
		),
		types.NewReceipt(testutils.RandomHash().Bytes(), false, 1024),
	)

	require.Nil(t, err)
	require.NotNil(t, encoded)
}

func TestEncodeProveBlockInvalidInput(t *testing.T) {
	encoded, err := EncodeProveBlockInvalidInput(
		&TaikoL1Evidence{
			Meta:   testMeta,
			Header: *FromGethHeader(testHeader),
			Prover: common.BytesToAddress(testutils.RandomHash().Bytes()),
		},
		&testMeta,
		types.NewReceipt(testutils.RandomHash().Bytes(), false, 1024),
	)

	require.Nil(t, err)
	require.NotNil(t, encoded)
}

func TestUnpackTxListBytes(t *testing.T) {
	_, err := UnpackTxListBytes(testutils.RandomBytes(1024))
	require.NotNil(t, err)

	_, err = UnpackTxListBytes(
		hexutil.MustDecode(
			"0xa0ca2d080000000000000000000000000000000000000000000000000000000000000" +
				"aa8e2b9725cce28787e99447c383d95a9ba83125fe31a9ffa9cbb2c504da86926ab",
		),
	)
	require.ErrorContains(t, err, "no method with id")
}

func TestDecodeEvidenceHeader(t *testing.T) {
	_, err := UnpackEvidenceHeader(testutils.RandomBytes(1024))
	require.NotNil(t, err)

	_, err = decodeEvidenceHeader(testutils.RandomBytes(1024))
	require.NotNil(t, err)

	b, err := EncodeEvidence(&TaikoL1Evidence{
		Meta: bindings.TaikoDataBlockMetadata{
			Id:           new(big.Int).SetUint64(rand.Uint64()),
			L1Height:     new(big.Int).SetUint64(rand.Uint64()),
			L1Hash:       testutils.RandomHash(),
			Beneficiary:  common.BigToAddress(new(big.Int).SetUint64(rand.Uint64())),
			TxListHash:   testutils.RandomHash(),
			MixHash:      testutils.RandomHash(),
			ExtraData:    testutils.RandomHash().Bytes(),
			GasLimit:     rand.Uint64(),
			Timestamp:    rand.Uint64(),
			CommitHeight: rand.Uint64(),
			CommitSlot:   rand.Uint64(),
		},
		Header: *FromGethHeader(testHeader),
		Prover: common.BigToAddress(new(big.Int).SetUint64(rand.Uint64())),
		Proofs: [][]byte{testutils.RandomBytes(1024)},
	})
	require.Nil(t, err)

	header, err := decodeEvidenceHeader(b)
	require.Nil(t, err)
	require.Equal(t, FromGethHeader(testHeader), header)
}

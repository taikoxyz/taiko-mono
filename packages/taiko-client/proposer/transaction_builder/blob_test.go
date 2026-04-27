package builder

import (
	"math/big"
	"testing"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
)

func TestShastaManifestTestCasesIncludeInvalidBlob(t *testing.T) {
	b := &BlobTransactionBuilder{}
	testCase := findShastaManifestTestCase(t, b.shastaManifestTestCases(), "invalid blob")

	sourceManifest := &manifest.DerivationSourceManifest{}
	testCase.buildManifest(sourceManifest, []types.Transactions{{}}, testL1Head(), 30_000_000)
	payload, err := EncodeSourceManifest(sourceManifest)
	require.NoError(t, err)

	payload = testCase.mutatePayload(payload)

	version := new(big.Int).SetBytes(payload[:32]).Uint64()
	require.NotEqual(t, uint64(manifest.ShastaPayloadVersion), version)
}

func TestShastaManifestTestCasesIncludeInvalidTx(t *testing.T) {
	b := &BlobTransactionBuilder{}
	testCase := findShastaManifestTestCase(t, b.shastaManifestTestCases(), "invalid tx")

	sourceManifest := &manifest.DerivationSourceManifest{}
	testCase.buildManifest(sourceManifest, []types.Transactions{{}}, testL1Head(), 30_000_000)

	require.Len(t, sourceManifest.Blocks, 1)
	require.Len(t, sourceManifest.Blocks[0].Transactions, 1)
	tx := sourceManifest.Blocks[0].Transactions[0]
	require.Equal(t, uint8(types.DynamicFeeTxType), tx.Type())
	require.True(t, tx.GasFeeCap().Cmp(tx.GasTipCap()) < 0)
}

func findShastaManifestTestCase(
	t *testing.T,
	testCases []shastaManifestTestCase,
	name string,
) shastaManifestTestCase {
	t.Helper()
	for _, testCase := range testCases {
		if testCase.name == name {
			return testCase
		}
	}
	require.Failf(t, "missing Shasta manifest test case", "name: %s", name)
	return shastaManifestTestCase{}
}

func testL1Head() *types.Header {
	return &types.Header{
		Number: big.NewInt(1_000),
		Time:   1_000,
	}
}

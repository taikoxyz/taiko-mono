package manifest

import (
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/manifest"
	"github.com/taikoxyz/taiko-mono/packages/taiko-client/internal/testutils"
	builder "github.com/taikoxyz/taiko-mono/packages/taiko-client/proposer/transaction_builder"
)

func TestManifestEncodeDecode(t *testing.T) {
	m := &manifest.ProtocolProposalManifest{
		ProverAuthBytes: testutils.RandomBytes(32),
		Blocks: []*manifest.ProtocolBlockManifest{{
			Timestamp:         testutils.RandomHash().Big().Uint64(),
			Coinbase:          common.BytesToAddress(testutils.RandomBytes(20)),
			AnchorBlockNumber: testutils.RandomHash().Big().Uint64(),
			GasLimit:          testutils.RandomHash().Big().Uint64(),
			Transactions:      types.Transactions{},
		}},
	}
	b, err := builder.EncodeProposalManifestShasta(m)
	require.Nil(t, err)
	require.NotEmpty(t, b)

	decoded, err := new(ShastaManifestFetcher).manifestFromBlobBytes(b, 0)
	require.Nil(t, err)
	require.Equal(t, m.ProverAuthBytes, decoded.ProverAuthBytes)
	require.Equal(t, len(m.Blocks), len(decoded.Blocks))
	require.Equal(t, m.Blocks[0].Timestamp, decoded.Blocks[0].Timestamp)
	require.Equal(t, m.Blocks[0].Coinbase, decoded.Blocks[0].Coinbase)
	require.Equal(t, m.Blocks[0].AnchorBlockNumber, decoded.Blocks[0].AnchorBlockNumber)
	require.Equal(t, m.Blocks[0].GasLimit, decoded.Blocks[0].GasLimit)
	require.Equal(t, len(m.Blocks[0].Transactions), len(decoded.Blocks[0].Transactions))
}

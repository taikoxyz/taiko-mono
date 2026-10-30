package proof

import (
	"context"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/encoding"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

var (
	// nolint: lll
	wantEncoded = "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000028c59000000000000000000000000000000000000000000000000000000000000000a1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
)

func Test_EncodedSignalProof(t *testing.T) {
	p := newTestProver()

	params := SignalProofParams{
		ChainID:              mock.MockChainID,
		SignalServiceAddress: common.Address{},
		Key:                  [32]byte{},
		Blocker:              &mock.EthClient{},
		Caller:               &mock.Caller{},
		BlockNumber:          uint64(mock.BlockNum),
	}

	encoded, err := p.EncodedSignalProof(
		context.Background(),
		params,
	)

	assert.Nil(t, err)

	assert.Equal(t, wantEncoded, hexutil.Encode(encoded))
}

func Test_EncodedSignalProof_BlockIDOverridesTheBlockNumber(t *testing.T) {
	p := newTestProver()

	params := SignalProofParams{
		ChainID:              mock.MockChainID,
		SignalServiceAddress: common.Address{},
		Key:                  [32]byte{},
		Blocker:              &mock.EthClient{},
		Caller:               &mock.Caller{},
		BlockNumber:          uint64(mock.BlockNum),
		BlockID:              1_800_000_000,
		StateRoot:            mock.Header.Root,
	}

	encoded, err := p.EncodedSignalProof(context.Background(), params)
	require.NoError(t, err)

	// The proof is the legacy one except for the blockId: an Etna proof carries the timestamp of
	// the L2 block that recorded the root, while the account and storage proofs still come from
	// the L1 block.
	want, err := encoding.EncodeHopProofs([]encoding.HopProof{{
		BlockID:      1_800_000_000,
		ChainID:      mock.MockChainID.Uint64(),
		RootHash:     mock.Header.Root,
		AccountProof: [][]byte{},
		StorageProof: [][]byte{},
	}})
	require.NoError(t, err)

	assert.Equal(t, hexutil.Encode(want), hexutil.Encode(encoded))
}

func Test_EncodedSignalProof_RejectsAStateRootMismatch(t *testing.T) {
	p := newTestProver()

	params := SignalProofParams{
		ChainID:              mock.MockChainID,
		SignalServiceAddress: common.Address{},
		Key:                  [32]byte{},
		Blocker:              &mock.EthClient{},
		Caller:               &mock.Caller{},
		BlockNumber:          uint64(mock.BlockNum),
		BlockID:              1_800_000_000,
		StateRoot:            common.HexToHash("0x01"),
	}

	encoded, err := p.EncodedSignalProof(context.Background(), params)

	require.ErrorIs(t, err, ErrStateRootMismatch)
	assert.Nil(t, encoded)
}

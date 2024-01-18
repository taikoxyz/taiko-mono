package mock

import (
	"context"
	"errors"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

var (
	Header = &types.Header{
		ParentHash:  common.HexToHash("0x3a537c89809712367218bb171b3b1c46aa95df3dee7200ae9dc78f4052024068"),
		UncleHash:   common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Coinbase:    common.HexToAddress("0x0000000000000000000000000000000000000000"),
		Root:        common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		TxHash:      common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		ReceiptHash: common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Bloom:       types.Bloom{},
		Difficulty:  new(big.Int).SetInt64(2),
		Number:      new(big.Int).SetInt64(1),
		GasLimit:    100000,
		GasUsed:     2000,
		Time:        1234,
		Extra:       []byte{0x7f},
		MixDigest:   common.HexToHash("0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
		Nonce:       types.BlockNonce{0x13},
	}
	EmptyHeader = &types.Header{}
)

type Blocker struct {
}

func (b *Blocker) BlockByHash(ctx context.Context, hash common.Hash) (*types.Block, error) {
	if hash == relayer.ZeroHash {
		return nil, errors.New("cant find block")
	}

	return types.NewBlockWithHeader(Header), nil
}

func (b *Blocker) BlockByNumber(ctx context.Context, number *big.Int) (*types.Block, error) {
	return types.NewBlockWithHeader(Header), nil
}

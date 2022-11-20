package proof

import (
	"context"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/relayer/encoding"
	"github.com/taikoxyz/taiko-mono/packages/relayer/mock"
	"gopkg.in/go-playground/assert.v1"
)

func Test_blockHeader(t *testing.T) {
	p := newTestProver()

	header, err := p.blockHeader(context.Background(), common.HexToHash("0x123"))
	assert.Equal(t, err, nil)
	assert.Equal(t, header, encoding.BlockToBlockHeader(types.NewBlockWithHeader(mock.Header)))
}

func Test_blockHeader_cantFindBlock(t *testing.T) {
	p := newTestProver()

	_, err := p.blockHeader(context.Background(), common.HexToHash("0x"))
	assert.NotEqual(t, err, nil)
}

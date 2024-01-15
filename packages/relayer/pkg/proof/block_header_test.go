package proof

import (
	"context"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/encoding"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
	"gopkg.in/go-playground/assert.v1"
)

func Test_blockHeader(t *testing.T) {
	p := newTestProver()

	header, err := p.blockHeader(context.Background(), p.blocker, common.HexToHash("0x123"))
	assert.Equal(t, err, nil)
	assert.Equal(t, header, encoding.BlockToBlockHeader(types.NewBlockWithHeader(mock.Header)))
}

func Test_blockHeader_noHash(t *testing.T) {
	p := newTestProver()

	_, err := p.blockHeader(context.Background(), p.blocker, common.HexToHash("0x"))
	assert.Equal(t, err, nil)
}

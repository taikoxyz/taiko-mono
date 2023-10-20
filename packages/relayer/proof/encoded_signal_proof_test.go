package proof

import (
	"context"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/mock"
)

var (
	// nolint: lll
	wantEncoded = "0x00000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a00000000000000000000000000000000000000000000000000000000000000001c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
)

func Test_EncodedSignalProof(t *testing.T) {
	p := newTestProver()

	encoded, err := p.EncodedSignalProof(
		context.Background(),
		&mock.Caller{},
		common.Address{},
		"1",
		mock.Header.TxHash,
	)
	assert.Nil(t, err)
	assert.Equal(t, hexutil.Encode(encoded), wantEncoded)
}

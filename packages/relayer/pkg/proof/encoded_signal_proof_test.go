package proof

import (
	"context"
	"testing"

	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

var (
	// nolint: lll
	wantEncoded = "0x0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000028c59000000000000000000000000000000000000000000000000000000000000000a1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
)

func Test_EncodedSignalProof(t *testing.T) {
	p := newTestProver()

	hops := []HopParams{
		{
			ChainID:              mock.MockChainID,
			SignalServiceAddress: common.Address{},
			SignalService:        &mock.SignalService{},
			Key:                  [32]byte{},
			Blocker:              &mock.EthClient{},
			Caller:               &mock.Caller{},
			BlockNumber:          uint64(mock.BlockNum),
		},
	}

	encoded, err := p.EncodedSignalProofWithHops(
		context.Background(),
		hops,
	)

	assert.Nil(t, err)

	assert.Equal(t, wantEncoded, hexutil.Encode(encoded))
}

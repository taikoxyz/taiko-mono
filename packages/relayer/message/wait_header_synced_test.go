package message

import (
	"context"
	"testing"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts/bridge"
)

func Test_waitHeaderSynced(t *testing.T) {
	p := newTestProcessor(true)

	err := p.waitHeaderSynced(context.TODO(), &bridge.BridgeMessageSent{
		Raw: types.Log{
			BlockNumber: 1,
		},
	})
	assert.Nil(t, err)
}

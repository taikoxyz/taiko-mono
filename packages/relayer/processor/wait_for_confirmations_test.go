package processor

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

func Test_waitForConfirmations(t *testing.T) {
	p := newTestProcessor(true)

	err := p.waitForConfirmations(context.TODO(), mock.SucceedTxHash, uint64(mock.BlockNum))
	assert.Nil(t, err)
}

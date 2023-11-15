package processor

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/mock"
)

func Test_waitHeaderSynced(t *testing.T) {
	p := newTestProcessor(true)

	_, err := p.waitHeaderSynced(context.TODO(), &mock.HeaderSyncer{}, &mock.EthClient{}, 1)
	assert.Nil(t, err)
}

package indexer

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/mock"
)

func Test_subscribe(t *testing.T) {
	svc, bridge := newTestService()

	go func() {
		_ = svc.subscribe(context.Background(), mock.MockChainID)
	}()

	<-time.After(6 * time.Second)

	b := bridge.(*mock.Bridge)

	assert.Equal(t, b.MessagesSent, 1)
	assert.Equal(t, b.ErrorsSent, 1)
}

package indexer

import (
	"context"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/taikochain/taiko-mono/packages/relayer"
	"github.com/taikochain/taiko-mono/packages/relayer/mock"
)

func Test_FilterThenSubscribe(t *testing.T) {
	svc, bridge := newTestService()
	b := bridge.(*mock.Bridge)

	go svc.FilterThenSubscribe(
		context.Background(),
		relayer.Mode(relayer.SyncMode),
		relayer.FilterAndSubscribeWatchMode,
	)

	<-time.After(6 * time.Second)

	assert.Equal(t, b.MessagesSent, 1)
	assert.Equal(t, b.ErrorsSent, 1)
}

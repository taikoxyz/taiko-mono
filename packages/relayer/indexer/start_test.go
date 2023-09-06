package indexer

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/mock"
)

func Test_Start(t *testing.T) {
	svc, bridge := newTestService(Sync, FilterAndSubscribe)
	b := bridge.(*mock.Bridge)

	svc.processingBlockHeight = 0

	go func() {
		_ = svc.Start()
	}()

	<-time.After(6 * time.Second)

	assert.Equal(t, b.MessagesSent, 1)
	assert.Equal(t, b.MessageStatusesChanged, 1)
	assert.Equal(t, b.ErrorsSent, 2)
}

func Test_Start_subscribeWatchMode(t *testing.T) {
	svc, bridge := newTestService(Sync, Subscribe)
	b := bridge.(*mock.Bridge)

	go func() {
		_ = svc.Start()
	}()

	<-time.After(6 * time.Second)

	assert.Equal(t, b.MessagesSent, 1)
	assert.Equal(t, b.MessageStatusesChanged, 1)
	assert.Equal(t, b.ErrorsSent, 2)
}

func Test_Start_alreadyCaughtUp(t *testing.T) {
	svc, bridge := newTestService(Sync, FilterAndSubscribe)
	b := bridge.(*mock.Bridge)

	svc.processingBlockHeight = mock.LatestBlockNumber.Uint64()

	go func() {
		_ = svc.Start()
	}()

	<-time.After(6 * time.Second)

	assert.Equal(t, b.MessagesSent, 1)
	assert.Equal(t, b.MessageStatusesChanged, 1)
	assert.Equal(t, b.ErrorsSent, 2)
}

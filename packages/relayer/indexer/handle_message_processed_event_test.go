package indexer

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/mock"
)

func Test_isForgedMessage(t *testing.T) {
	svc, b := newTestService(Sync, FilterAndSubscribe)
	mockBridge := b.(*mock.Bridge)

	// destBridge has no record of sending this message => forged.
	mockBridge.IsMessageSentResult = false
	forged, err := svc.isForgedMessage(bridge.IBridgeMessage{Id: 5})
	assert.Nil(t, err)
	assert.True(t, forged)

	// destBridge did send this message => not forged.
	mockBridge.IsMessageSentResult = true
	forged, err = svc.isForgedMessage(bridge.IBridgeMessage{Id: 5})
	assert.Nil(t, err)
	assert.False(t, forged)
}

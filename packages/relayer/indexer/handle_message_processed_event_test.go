package indexer

import (
	"context"
	"errors"
	"math/big"
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
	forged, err := svc.isForgedMessage(context.Background(), bridge.IBridgeMessage{Id: 5})
	assert.Nil(t, err)
	assert.True(t, forged)

	// destBridge did send this message => not forged.
	mockBridge.IsMessageSentResult = true
	forged, err = svc.isForgedMessage(context.Background(), bridge.IBridgeMessage{Id: 5})
	assert.Nil(t, err)
	assert.False(t, forged)
}

func Test_isForgedMessageUsesBoundedContext(t *testing.T) {
	svc, b := newTestService(Sync, FilterAndSubscribe)
	mockBridge := b.(*mock.Bridge)

	forged, err := svc.isForgedMessage(context.Background(), bridge.IBridgeMessage{Id: 5})
	assert.Nil(t, err)
	assert.True(t, forged)

	if assert.NotNil(t, mockBridge.IsMessageSentOpts) &&
		assert.NotNil(t, mockBridge.IsMessageSentOpts.Context) {
		_, ok := mockBridge.IsMessageSentOpts.Context.Deadline()
		assert.True(t, ok)
	}
}

// A transient origin-chain RPC failure on the forged-message check must not
// drop the processed event: the indexer's filter loop advances the block number
// even when the handler errors, so a propagated error would skip the event
// permanently. The event must be indexed and the handler must not fail.
func Test_handleMessageProcessedEvent_indexesWhenForgedCheckRPCFails(t *testing.T) {
	svc, b := newTestService(Sync, FilterAndSubscribe)

	mockBridge := b.(*mock.Bridge)
	mockBridge.IsMessageSentErr = errors.New("origin-chain rpc down")

	repo := svc.eventRepo.(*mock.EventRepository)

	event := &bridge.BridgeMessageProcessed{
		Message: bridge.IBridgeMessage{
			Id:          5,
			DestChainId: mock.MockChainID.Uint64(),
			Value:       big.NewInt(0),
		},
	}

	err := svc.handleMessageProcessedEvent(context.Background(), mock.MockChainID, event, false)

	// The batch must not fail on the RPC error...
	assert.Nil(t, err)
	// ...and the event must still be indexed.
	assert.Equal(t, 1, repo.SavedCount())
}

package rpc

import (
	"context"
	"testing"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/stretchr/testify/require"
)

func TestSubscribeEvent(t *testing.T) {
	sub := SubscribeEvent("test", func(_ context.Context) (event.Subscription, error) {
		return event.NewSubscription(func(_ <-chan struct{}) error { return nil }), nil
	})
	require.NotNil(t, sub)
	sub.Unsubscribe()
}

func TestSubscribeChainHead(t *testing.T) {
	client := newTestClient(t)
	sub := SubscribeChainHead(client.L1, make(chan *types.Header, 1024))
	require.NotNil(t, sub)
	sub.Unsubscribe()
}

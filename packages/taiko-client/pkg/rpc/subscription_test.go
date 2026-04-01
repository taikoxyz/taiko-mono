package rpc

import (
	"context"
	"os"
	"testing"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/stretchr/testify/require"
)

func TestSubscribeEvent(t *testing.T) {
	require.NotNil(t, SubscribeEvent("test", func(_ context.Context) (event.Subscription, error) {
		return event.NewSubscription(func(_ <-chan struct{}) error { return nil }), nil
	}))
}

func TestSubscribeEventShastaOnly(t *testing.T) {
	contents, err := os.ReadFile("subscription.go")
	require.NoError(t, err)

	require.Contains(t, string(contents), "SubscribeProposedShasta")
	require.Contains(t, string(contents), "SubscribeProvedShasta")
}

func TestSubscribeChainHead(t *testing.T) {
	require.NotNil(t, SubscribeChainHead(
		newTestClient(t).L1,
		make(chan *types.Header, 1024)),
	)
}

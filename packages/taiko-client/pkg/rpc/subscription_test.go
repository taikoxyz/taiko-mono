package rpc

import (
	"context"
	"testing"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/stretchr/testify/require"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
)

func TestSubscribeEvent(t *testing.T) {
	require.NotNil(t, SubscribeEvent("test", func(_ context.Context) (event.Subscription, error) {
		return event.NewSubscription(func(_ <-chan struct{}) error { return nil }), nil
	}))
}

func TestSubscribeBlockVerified(t *testing.T) {
	require.NotNil(t, SubscribeBlockVerified(
		newTestClient(t).TaikoL1,
		make(chan *bindings.TaikoL1ClientBlockVerified, 1024)),
	)
}

func TestSubscribeBlockProposed(t *testing.T) {
	require.NotNil(t, SubscribeBlockProposed(
		newTestClient(t).LibProposing,
		make(chan *bindings.LibProposingBlockProposed, 1024)),
	)
}

func TestSubscribeTransitionProved(t *testing.T) {
	require.NotNil(t, SubscribeTransitionProved(
		newTestClient(t).TaikoL1,
		make(chan *bindings.TaikoL1ClientTransitionProved, 1024)),
	)
}

func TestSubscribeTransitionContested(t *testing.T) {
	require.NotNil(t, SubscribeTransitionContested(
		newTestClient(t).TaikoL1,
		make(chan *bindings.TaikoL1ClientTransitionContested, 1024)),
	)
}

func TestSubscribeChainHead(t *testing.T) {
	require.NotNil(t, SubscribeChainHead(
		newTestClient(t).L1,
		make(chan *types.Header, 1024)),
	)
}

package rpc

import (
	"context"
	"testing"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/stretchr/testify/require"

	v1 "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/v1"
)

func TestSubscribeEvent(t *testing.T) {
	require.NotNil(t, SubscribeEvent("test", func(_ context.Context) (event.Subscription, error) {
		return event.NewSubscription(func(_ <-chan struct{}) error { return nil }), nil
	}))
}

func TestSubscribeBlockVerified(t *testing.T) {
	require.NotNil(t, SubscribeBlockVerified(
		newTestClient(t).V1.TaikoL1,
		make(chan *v1.TaikoL1ClientBlockVerified, 1024)),
	)
}

func TestSubscribeBlockProposed(t *testing.T) {
	require.NotNil(t, SubscribeBlockProposed(
		newTestClient(t).V1.LibProposing,
		make(chan *v1.LibProposingBlockProposed, 1024)),
	)
}

func TestSubscribeTransitionProved(t *testing.T) {
	require.NotNil(t, SubscribeTransitionProved(
		newTestClient(t).V1.TaikoL1,
		make(chan *v1.TaikoL1ClientTransitionProved, 1024)),
	)
}

func TestSubscribeTransitionContested(t *testing.T) {
	require.NotNil(t, SubscribeTransitionContested(
		newTestClient(t).V1.TaikoL1,
		make(chan *v1.TaikoL1ClientTransitionContested, 1024)),
	)
}

func TestSubscribeChainHead(t *testing.T) {
	require.NotNil(t, SubscribeChainHead(
		newTestClient(t).L1,
		make(chan *types.Header, 1024)),
	)
}

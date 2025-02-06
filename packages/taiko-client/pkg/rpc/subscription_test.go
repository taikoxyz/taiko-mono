package rpc

import (
	"context"
	"testing"

	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/stretchr/testify/require"

	ontakeBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/ontake"
)

func TestSubscribeEvent(t *testing.T) {
	require.NotNil(t, SubscribeEvent("test", func(_ context.Context) (event.Subscription, error) {
		return event.NewSubscription(func(_ <-chan struct{}) error { return nil }), nil
	}))
}

func TestSubscribeBlockVerifiedV2(t *testing.T) {
	require.NotNil(t, SubscribeBlockVerifiedV2(
		newTestClient(t).OntakeClients.TaikoL1,
		make(chan *ontakeBindings.TaikoL1ClientBlockVerifiedV2, 1024)),
	)
}

func TestSubscribeBlockProposed(t *testing.T) {
	require.NotNil(t, SubscribeBlockProposedV2(
		newTestClient(t).OntakeClients.TaikoL1,
		make(chan *ontakeBindings.TaikoL1ClientBlockProposedV2, 1024)),
	)
}

func TestSubscribeTransitionProved(t *testing.T) {
	require.NotNil(t, SubscribeTransitionProvedV2(
		newTestClient(t).OntakeClients.TaikoL1,
		make(chan *ontakeBindings.TaikoL1ClientTransitionProvedV2, 1024)),
	)
}

func TestSubscribeTransitionContested(t *testing.T) {
	require.NotNil(t, SubscribeTransitionContestedV2(
		newTestClient(t).OntakeClients.TaikoL1,
		make(chan *ontakeBindings.TaikoL1ClientTransitionContestedV2, 1024)),
	)
}

func TestSubscribeChainHead(t *testing.T) {
	require.NotNil(t, SubscribeChainHead(
		newTestClient(t).L1,
		make(chan *types.Header, 1024)),
	)
}

package rpc

import (
	"context"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/ethereum/go-ethereum/log"

	"github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings"
)

// SubscribeEvent creates a event subscription, will retry if the established subscription failed.
func SubscribeEvent(
	eventName string,
	handler func(ctx context.Context) (event.Subscription, error),
) event.Subscription {
	return event.ResubscribeErr(
		backoff.DefaultMaxInterval,
		func(ctx context.Context, err error) (event.Subscription, error) {
			if err != nil {
				log.Warn("Failed to subscribe protocol event, try resubscribing", "event", eventName, "error", err)
			}

			return handler(ctx)
		},
	)
}

// SubscribeBlockVerified subscribes the protocol's BlockVerified events.
func SubscribeBlockVerified(
	taikoL1 *bindings.TaikoL1Client,
	ch chan *bindings.TaikoL1ClientBlockVerified,
) event.Subscription {
	return SubscribeEvent("BlockVerified", func(ctx context.Context) (event.Subscription, error) {
		sub, err := taikoL1.WatchBlockVerified(nil, ch, nil, nil)
		if err != nil {
			log.Error("Create TaikoL1.BlockVerified subscription error", "error", err)
			return nil, err
		}

		defer sub.Unsubscribe()

		return waitSubErr(ctx, sub)
	})
}

// SubscribeBlockVerifiedV2 subscribes the protocol's BlockVerifiedV2 events.
func SubscribeBlockVerifiedV2(
	taikoL1 *bindings.TaikoL1Client,
	ch chan *bindings.TaikoL1ClientBlockVerifiedV2,
) event.Subscription {
	return SubscribeEvent("BlockVerifiedV2", func(ctx context.Context) (event.Subscription, error) {
		sub, err := taikoL1.WatchBlockVerifiedV2(nil, ch, nil, nil)
		if err != nil {
			log.Error("Create TaikoL1.BlockVerifiedV2 subscription error", "error", err)
			return nil, err
		}

		defer sub.Unsubscribe()

		return waitSubErr(ctx, sub)
	})
}

// SubscribeBlockProposed subscribes the protocol's BlockProposed events.
func SubscribeBlockProposed(
	libProposing *bindings.LibProposing,
	ch chan *bindings.LibProposingBlockProposed,
) event.Subscription {
	return SubscribeEvent("BlockProposed", func(ctx context.Context) (event.Subscription, error) {
		sub, err := libProposing.WatchBlockProposed(nil, ch, nil, nil)
		if err != nil {
			log.Error("Create TaikoL1.BlockProposed subscription error", "error", err)
			return nil, err
		}

		defer sub.Unsubscribe()

		return waitSubErr(ctx, sub)
	})
}

// SubscribeBlockProposedV2 subscribes the protocol's BlockProposedV2 events.
func SubscribeBlockProposedV2(
	libProposing *bindings.LibProposing,
	ch chan *bindings.LibProposingBlockProposedV2,
) event.Subscription {
	return SubscribeEvent("BlockProposedV2", func(ctx context.Context) (event.Subscription, error) {
		sub, err := libProposing.WatchBlockProposedV2(nil, ch, nil)
		if err != nil {
			log.Error("Create TaikoL1.BlockProposedV2 subscription error", "error", err)
			return nil, err
		}

		defer sub.Unsubscribe()

		return waitSubErr(ctx, sub)
	})
}

// SubscribeTransitionProved subscribes the protocol's TransitionProved events.
func SubscribeTransitionProved(
	taikoL1 *bindings.TaikoL1Client,
	ch chan *bindings.TaikoL1ClientTransitionProved,
) event.Subscription {
	return SubscribeEvent("TransitionProved", func(ctx context.Context) (event.Subscription, error) {
		sub, err := taikoL1.WatchTransitionProved(nil, ch, nil)
		if err != nil {
			log.Error("Create TaikoL1.TransitionProved subscription error", "error", err)
			return nil, err
		}

		defer sub.Unsubscribe()

		return waitSubErr(ctx, sub)
	})
}

// SubscribeTransitionProvedV2 subscribes the protocol's TransitionProvedV2 events.
func SubscribeTransitionProvedV2(
	taikoL1 *bindings.TaikoL1Client,
	ch chan *bindings.TaikoL1ClientTransitionProvedV2,
) event.Subscription {
	return SubscribeEvent("TransitionProvedV2", func(ctx context.Context) (event.Subscription, error) {
		sub, err := taikoL1.WatchTransitionProvedV2(nil, ch, nil)
		if err != nil {
			log.Error("Create TaikoL1.TransitionProvedV2 subscription error", "error", err)
			return nil, err
		}

		defer sub.Unsubscribe()

		return waitSubErr(ctx, sub)
	})
}

// SubscribeTransitionContested subscribes the protocol's TransitionContested events.
func SubscribeTransitionContested(
	taikoL1 *bindings.TaikoL1Client,
	ch chan *bindings.TaikoL1ClientTransitionContested,
) event.Subscription {
	return SubscribeEvent("TransitionContested", func(ctx context.Context) (event.Subscription, error) {
		sub, err := taikoL1.WatchTransitionContested(nil, ch, nil)
		if err != nil {
			log.Error("Create TaikoL1.TransitionContested subscription error", "error", err)
			return nil, err
		}

		defer sub.Unsubscribe()

		return waitSubErr(ctx, sub)
	})
}

// SubscribeTransitionContestedV2 subscribes the protocol's TransitionContestedV2 events.
func SubscribeTransitionContestedV2(
	taikoL1 *bindings.TaikoL1Client,
	ch chan *bindings.TaikoL1ClientTransitionContestedV2,
) event.Subscription {
	return SubscribeEvent("TransitionContestedV2", func(ctx context.Context) (event.Subscription, error) {
		sub, err := taikoL1.WatchTransitionContestedV2(nil, ch, nil)
		if err != nil {
			log.Error("Create TaikoL1.TransitionContestedV2 subscription error", "error", err)
			return nil, err
		}

		defer sub.Unsubscribe()

		return waitSubErr(ctx, sub)
	})
}

// SubscribeChainHead subscribes the new chain heads.
func SubscribeChainHead(
	client *EthClient,
	ch chan *types.Header,
) event.Subscription {
	return SubscribeEvent("ChainHead", func(ctx context.Context) (event.Subscription, error) {
		sub, err := client.SubscribeNewHead(ctx, ch)
		if err != nil {
			log.Error("Create chain head subscription error", "error", err)
			return nil, err
		}

		defer sub.Unsubscribe()

		return waitSubErr(ctx, sub)
	})
}

// waitSubErr keeps waiting until the given subscription failed.
func waitSubErr(ctx context.Context, sub event.Subscription) (event.Subscription, error) {
	select {
	case err := <-sub.Err():
		return sub, err
	case <-ctx.Done():
		return sub, ctx.Err()
	}
}

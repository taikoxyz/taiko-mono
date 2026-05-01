package rpc

import (
	"context"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/ethereum/go-ethereum/log"

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

const (
	// l1PollInterval is how often the polling backend asks an HTTP L1 for new heads
	// and Proposed/Proved log ranges. Tuned to roughly half an L1 slot.
	l1PollInterval = 6 * time.Second
	// l2PollInterval is how often the polling backend asks an HTTP L2 for new heads.
	l2PollInterval = 2 * time.Second
	// maxPollRange caps the block range queried per Filter* tick so that long
	// catch-ups don't issue a single oversized eth_getLogs call.
	maxPollRange = uint64(1000)
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

// SubscribeProposed subscribes the protocol's Proposed events.
func SubscribeProposed(
	taikoInbox *shastaBindings.ShastaInboxClient,
	ch chan *shastaBindings.ShastaInboxClientProposed,
) event.Subscription {
	return SubscribeEvent("Proposed", func(ctx context.Context) (event.Subscription, error) {
		sub, err := taikoInbox.WatchProposed(nil, ch, nil, nil)
		if err != nil {
			log.Error("Create Inbox.Proposed subscription error", "error", err)
			return nil, err
		}

		defer sub.Unsubscribe()

		return waitSubErr(ctx, sub)
	})
}

// SubscribeProved subscribes the protocol's Proved events.
func SubscribeProved(
	taikoInbox *shastaBindings.ShastaInboxClient,
	ch chan *shastaBindings.ShastaInboxClientProved,
) event.Subscription {
	return SubscribeEvent("Proved", func(ctx context.Context) (event.Subscription, error) {
		sub, err := taikoInbox.WatchProved(nil, ch, nil)
		if err != nil {
			log.Error("Create Inbox.Proved subscription error", "error", err)
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

// pollChainHead returns an event.Subscription that periodically calls
// HeaderByNumber(nil) and forwards every observed advance on ch. Used when
// the underlying client is HTTP-only and cannot use eth_subscribe. Same-number
// reorgs are not delivered (matches the WS path's semantics).
func pollChainHead(
	ctx context.Context,
	client *EthClient,
	ch chan *types.Header,
	interval time.Duration,
) event.Subscription {
	return event.NewSubscription(func(quit <-chan struct{}) error {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()

		var lastNumber uint64
		for {
			select {
			case <-quit:
				return nil
			case <-ctx.Done():
				return nil
			case <-ticker.C:
				h, err := client.HeaderByNumber(ctx, nil)
				if err != nil {
					log.Warn("pollChainHead: HeaderByNumber failed", "err", err)
					continue
				}
				n := h.Number.Uint64()
				if n == lastNumber {
					continue
				}
				select {
				case ch <- h:
				default:
					log.Debug("pollChainHead: receiver channel full, dropping", "number", n)
				}
				lastNumber = n
			}
		}
	})
}

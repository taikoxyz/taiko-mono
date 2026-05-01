package rpc

import (
	"context"
	"time"

	"github.com/cenkalti/backoff/v4"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/event"
	"github.com/ethereum/go-ethereum/log"

	shastaBindings "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

const (
	// l1PollInterval is how often the polling backend asks an HTTP L1 for new heads
	// and Proposed/Proved log ranges. Tuned well below an L1 slot.
	l1PollInterval = 3 * time.Second
	// l2PollInterval is how often the polling backend asks an HTTP L2 for new heads.
	// Set faster than the L2 block time for sub-block tracking latency.
	l2PollInterval = 1 * time.Second
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

// SubscribeProposed subscribes the protocol's Proposed events. Only WS-backed
// callers exist today (the prover); if a future caller needs HTTP polling for
// Proposed, mirror the pollProved approach and reintroduce a polling branch.
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

// SubscribeProved subscribes the protocol's Proved events. If the L1 client
// is HTTP-only, it falls back to polling FilterProved at l1PollInterval.
func SubscribeProved(
	l1 *EthClient,
	taikoInbox *shastaBindings.ShastaInboxClient,
	ch chan *shastaBindings.ShastaInboxClientProved,
) event.Subscription {
	if l1.IsHTTP() {
		return pollProved(context.Background(), l1, taikoInbox, ch, l1PollInterval)
	}
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

// SubscribeChainHead subscribes the new chain heads. WS-backed clients use
// eth_subscribe; HTTP-backed clients fall back to polling HeaderByNumber at
// l1PollInterval. Callers that need a different polling cadence (e.g. the
// driver giving L2 a faster cadence than L1) should use
// SubscribeChainHeadInterval directly.
func SubscribeChainHead(
	client *EthClient,
	ch chan *types.Header,
) event.Subscription {
	return SubscribeChainHeadInterval(client, ch, l1PollInterval)
}

// SubscribeChainHeadInterval is SubscribeChainHead with a caller-chosen
// polling interval for HTTP-backed clients. Ignored when the client is
// WS-backed (eth_subscribe is push-based, no polling needed).
func SubscribeChainHeadInterval(
	client *EthClient,
	ch chan *types.Header,
	pollInterval time.Duration,
) event.Subscription {
	if client.IsHTTP() {
		return pollChainHead(context.Background(), client, ch, pollInterval)
	}
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
// HeaderByNumber(nil) and forwards every observed canonical-head change on
// ch. Used when the underlying client is HTTP-only and cannot use
// eth_subscribe. We track both the last-seen height and hash so same-height
// reorgs (block N replaced by a different block N) are still delivered, matching
// the eth_subscribe("newHeads") posture from the WS path.
func pollChainHead(
	ctx context.Context,
	client *EthClient,
	ch chan *types.Header,
	interval time.Duration,
) event.Subscription {
	return event.NewSubscription(func(quit <-chan struct{}) error {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()

		var (
			lastNumber uint64
			lastHash   common.Hash
		)
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
				hash := h.Hash()
				if n == lastNumber && hash == lastHash {
					continue
				}
				select {
				case ch <- h:
				default:
					log.Debug("pollChainHead: receiver channel full, dropping", "number", n, "hash", hash)
				}
				lastNumber = n
				lastHash = hash
			}
		}
	})
}

// nextFilterRange computes the next [start, end] block range to poll for logs.
// Returns ok=false when there's nothing new to fetch (head <= cursor). The
// range is capped at maxRange blocks so long catch-ups don't produce a single
// oversized eth_getLogs request.
func nextFilterRange(head, cursor, maxRange uint64) (start, end uint64, ok bool) {
	if head <= cursor {
		return 0, 0, false
	}
	start = cursor + 1
	end = head
	if end-cursor > maxRange {
		end = cursor + maxRange
	}
	return start, end, true
}

// pollProved polls FilterProved over the L1 range advanced since the last tick
// and forwards every event on ch. Used when the L1 client is HTTP-only.
func pollProved(
	ctx context.Context,
	l1 *EthClient,
	taikoInbox *shastaBindings.ShastaInboxClient,
	ch chan *shastaBindings.ShastaInboxClientProved,
	interval time.Duration,
) event.Subscription {
	return event.NewSubscription(func(quit <-chan struct{}) error {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()

		var cursor uint64
		bootstrapped := false

		for {
			select {
			case <-quit:
				return nil
			case <-ctx.Done():
				return nil
			case <-ticker.C:
				head, err := l1.BlockNumber(ctx)
				if err != nil {
					log.Warn("pollProved: BlockNumber failed", "err", err)
					continue
				}
				if !bootstrapped {
					cursor = head
					bootstrapped = true
					continue
				}
				start, end, ok := nextFilterRange(head, cursor, maxPollRange)
				if !ok {
					if head < cursor {
						cursor = head
					}
					continue
				}
				iter, err := taikoInbox.FilterProved(&bind.FilterOpts{
					Start:   start,
					End:     &end,
					Context: ctx,
				}, nil)
				if err != nil {
					log.Warn("pollProved: FilterProved failed", "start", start, "end", end, "err", err)
					continue
				}
				for iter.Next() {
					select {
					case ch <- iter.Event:
					default:
						log.Warn(
							"pollProved: receiver channel full, dropping (cursor still advances; downstream may miss this event)",
							"start", start,
							"end", end,
						)
					}
				}
				if iterErr := iter.Error(); iterErr != nil {
					// Don't hold the cursor on a permanent error (e.g. ABI decode
					// of a single bad log) — that would deadlock the polling loop.
					// Log loudly; downstream can still recover the missed event from
					// the chain syncer's canonical re-read on the next L1 head tick.
					log.Warn(
						"pollProved: iterator error, advancing cursor anyway to preserve liveness",
						"start", start,
						"end", end,
						"err", iterErr,
					)
				}
				_ = iter.Close()
				cursor = end
			}
		}
	})
}

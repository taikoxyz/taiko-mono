package indexer

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/event"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts"
	"golang.org/x/sync/errgroup"
)

// subscribe subscribes to latest events
func (svc *Service) subscribe(ctx context.Context, chainID *big.Int) error {
	log.Info("subscribing to new events")

	latestBlock, err := svc.ethClient.HeaderByNumber(ctx, nil)
	if err != nil {
		return errors.Wrap(err, "svc.ethClient.HeaderByNumber")
	}

	svc.processingBlock = &relayer.Block{
		Height: latestBlock.Number.Uint64(),
	}

	sink := make(chan *contracts.BridgeMessageSent)

	sub := event.ResubscribeErr(svc.subscriptionBackoff, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			log.Errorf("svc.bridge.WatchMessageSent: %v", err)
		}

		return svc.bridge.WatchMessageSent(&bind.WatchOpts{
			Context: ctx,
		}, sink, nil)
	})

	defer sub.Unsubscribe()

	group, ctx := errgroup.WithContext(ctx)

	group.SetLimit(svc.numGoroutines)

	for {
		select {
		case err := <-sub.Err():
			return errors.Wrap(err, "sub.Err()")
		case event := <-sink:
			group.Go(func() error {
				err := svc.handleEvent(ctx, chainID, event)
				if err != nil {
					log.Errorf("svc.handleEvent: %v", err)
				}

				return nil
			})
		}
	}
}

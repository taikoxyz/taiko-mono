package indexer

import (
	"context"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/event"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikochain/taiko-mono/packages/relayer/contracts"
	"golang.org/x/sync/errgroup"
)

// subscribe subscribes to latest events
func (svc *Service) subscribe(ctx context.Context, chainID *big.Int) error {
	sink := make(chan *contracts.BridgeMessageSent)

	sub := event.ResubscribeErr(3*time.Second, func(ctx context.Context, err error) (event.Subscription, error) {
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

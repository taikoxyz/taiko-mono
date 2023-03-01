package indexer

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/event"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts/bridge"
)

// subscribe subscribes to latest events
func (svc *Service) subscribe(ctx context.Context, chainID *big.Int) error {
	log.Info("subscribing to new events")

	sink := make(chan *bridge.BridgeMessageSent)

	sub := event.ResubscribeErr(svc.subscriptionBackoff, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			log.Errorf("svc.bridge.WatchMessageSent: %v", err)
		}

		return svc.bridge.WatchMessageSent(&bind.WatchOpts{
			Context: ctx,
		}, sink, nil)
	})

	defer sub.Unsubscribe()

	for {
		select {
		case err := <-sub.Err():
			return errors.Wrap(err, "sub.Err()")
		case event := <-sink:
			go func() {
				err := svc.handleEvent(ctx, chainID, event)
				if err != nil {
					log.Errorf("svc.subscribe, svc.handleEvent: %v", err)
				}

				block, err := svc.blockRepo.GetLatestBlockProcessedForEvent(relayer.EventNameMessageSent, chainID)
				if err != nil {
					log.Errorf("svc.subscribe, blockRepo.GetLatestBlockProcessedForEvent: %v", err)
				}

				if block.Height < event.Raw.BlockNumber {
					err = svc.blockRepo.Save(relayer.SaveBlockOpts{
						Height:    event.Raw.BlockNumber,
						Hash:      event.Raw.BlockHash,
						ChainID:   chainID,
						EventName: relayer.EventNameMessageSent,
					})
					if err != nil {
						log.Errorf("svc.subscribe, svc.blockRepo.Save: %v", err)
					}

					relayer.BlocksProcessed.Inc()
				}
			}()
		}
	}
}

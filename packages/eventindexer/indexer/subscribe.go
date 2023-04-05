package indexer

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/event"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/taikol1"
)

// subscribe subscribes to latest events
func (svc *Service) subscribe(ctx context.Context, chainID *big.Int) error {
	log.Info("subscribing to new events")

	errChan := make(chan error)

	go svc.subscribeBlockProven(ctx, chainID, errChan)

	// nolint: gosimple
	for {
		select {
		case <-ctx.Done():
			log.Info("context finished")
			return nil
		case err := <-errChan:
			eventindexer.ErrorsEncounteredDuringSubscription.Inc()

			return errors.Wrap(err, "errChan")
		}
	}
}

func (svc *Service) subscribeBlockProven(ctx context.Context, chainID *big.Int, errChan chan error) {
	sink := make(chan *taikol1.TaikoL1BlockProven)

	sub := event.ResubscribeErr(svc.subscriptionBackoff, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			log.Errorf("svc.taikoL1.WatchBlockProven: %v", err)
		}
		log.Info("resubscribing to BlockProven events")

		return svc.taikol1.WatchBlockProven(&bind.WatchOpts{
			Context: ctx,
		}, sink, nil)
	})

	defer sub.Unsubscribe()

	for {
		select {
		case <-ctx.Done():
			log.Info("context finished")
			return
		case err := <-sub.Err():
			errChan <- errors.Wrap(err, "sub.Err()")
		case event := <-sink:
			log.Infof("blockProvenEvent from subscription for prover %v", event.Prover.Hex())

			if err := svc.saveBlockProvenEvent(ctx, chainID, event); err != nil {
				log.Errorf("svc.subscribe, svc.saveBlockProvenEvent: %v", err)
			}

			block, err := svc.blockRepo.GetLatestBlockProcessed(chainID)
			if err != nil {
				log.Errorf("svc.subscribe, blockRepo.GetLatestBlockProcessed: %v", err)
				continue
			}

			if block.Height < event.Raw.BlockNumber {
				err = svc.blockRepo.Save(eventindexer.SaveBlockOpts{
					Height:  event.Raw.BlockNumber,
					Hash:    event.Raw.BlockHash,
					ChainID: chainID,
				})
				if err != nil {
					log.Errorf("svc.subscribe, svc.blockRepo.Save: %v", err)
				}

				eventindexer.BlocksProcessed.Inc()
			}
		}
	}
}

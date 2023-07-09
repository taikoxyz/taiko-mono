package indexer

import (
	"context"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/event"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/bridge"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/swap"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/taikol1"
)

// subscribe subscribes to latest events
func (svc *Service) subscribe(ctx context.Context, chainID *big.Int) error {
	log.Info("subscribing to new events")

	errChan := make(chan error)

	if svc.taikol1 != nil {
		go svc.subscribeBlockProven(ctx, chainID, errChan)
		go svc.subscribeBlockProposed(ctx, chainID, errChan)
		go svc.subscribeBlockVerified(ctx, chainID, errChan)
	}

	if svc.bridge != nil {
		go svc.subscribeMessageSent(ctx, chainID, errChan)
	}

	if svc.swaps != nil {
		for _, swap := range svc.swaps {
			go svc.subscribeSwap(ctx, swap, chainID, errChan)
		}
	}

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
			log.Errorf("sub.Err(): %v", err)
			errChan <- errors.Wrap(err, "sub.Err()")
		case event := <-sink:
			go func() {
				log.Infof("blockProvenEvent from subscription for prover %v", event.Prover.Hex())

				if err := svc.saveBlockProvenEvent(ctx, chainID, event); err != nil {
					eventindexer.BlockProvenEventsProcessedError.Inc()

					log.Errorf("svc.subscribe, svc.saveBlockProvenEvent: %v", err)

					return
				}

				block, err := svc.blockRepo.GetLatestBlockProcessed(chainID)
				if err != nil {
					log.Errorf("svc.subscribe, blockRepo.GetLatestBlockProcessed: %v", err)
					return
				}

				if block.Height < event.Raw.BlockNumber {
					err = svc.blockRepo.Save(eventindexer.SaveBlockOpts{
						Height:  event.Raw.BlockNumber,
						Hash:    event.Raw.BlockHash,
						ChainID: chainID,
					})
					if err != nil {
						log.Errorf("svc.subscribe, svc.blockRepo.Save: %v", err)
						return
					}

					eventindexer.BlocksProcessed.Inc()
				}
			}()
		}
	}
}

func (svc *Service) subscribeBlockProposed(ctx context.Context, chainID *big.Int, errChan chan error) {
	sink := make(chan *taikol1.TaikoL1BlockProposed)

	sub := event.ResubscribeErr(svc.subscriptionBackoff, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			log.Errorf("svc.taikoL1.WatchBlockProposed: %v", err)
		}
		log.Info("resubscribing to BlockProposed events")

		return svc.taikol1.WatchBlockProposed(&bind.WatchOpts{
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
			log.Errorf("sub.Err(): %v", err)
			errChan <- errors.Wrap(err, "sub.Err()")
		case event := <-sink:
			go func() {
				log.Infof("blockProposedEvent from subscription")

				tx, _, err := svc.ethClient.TransactionByHash(ctx, event.Raw.TxHash)
				if err != nil {
					log.Errorf("svc.ethClient.TransactionByHash: %v", err)

					return
				}

				sender, err := svc.ethClient.TransactionSender(ctx, tx, event.Raw.BlockHash, event.Raw.TxIndex)
				if err != nil {
					log.Errorf("svc.ethClient.TransactionSender: %v", err)

					return
				}

				log.Infof("blockProposed by: %v", sender.Hex())

				if err := svc.saveBlockProposedEvent(ctx, chainID, event, sender); err != nil {
					eventindexer.BlockProposedEventsProcessedError.Inc()

					log.Errorf("svc.subscribe, svc.saveBlockProposedEvent: %v", err)

					return
				}

				block, err := svc.blockRepo.GetLatestBlockProcessed(chainID)
				if err != nil {
					log.Errorf("svc.subscribe, blockRepo.GetLatestBlockProcessed: %v", err)

					return
				}

				if block.Height < event.Raw.BlockNumber {
					err = svc.blockRepo.Save(eventindexer.SaveBlockOpts{
						Height:  event.Raw.BlockNumber,
						Hash:    event.Raw.BlockHash,
						ChainID: chainID,
					})
					if err != nil {
						log.Errorf("svc.subscribe, svc.blockRepo.Save: %v", err)

						return
					}

					eventindexer.BlocksProcessed.Inc()
				}
			}()
		}
	}
}

func (svc *Service) subscribeBlockVerified(ctx context.Context, chainID *big.Int, errChan chan error) {
	sink := make(chan *taikol1.TaikoL1BlockVerified)

	sub := event.ResubscribeErr(svc.subscriptionBackoff, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			log.Errorf("svc.taikoL1.WatchBlockVerified: %v", err)
		}

		log.Info("resubscribing to BlockVerified events")

		return svc.taikol1.WatchBlockVerified(&bind.WatchOpts{
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
			log.Errorf("sub.Err(): %v", err)
			errChan <- errors.Wrap(err, "sub.Err()")
		case event := <-sink:
			go func() {
				log.Infof("blockVerifiedEvent from subscription")

				if err := svc.saveBlockVerifiedEvent(ctx, chainID, event); err != nil {
					eventindexer.BlockVerifiedEventsProcessedError.Inc()
					log.Errorf("svc.subscribe, svc.saveBlockVerifiedEvent: %v", err)

					return
				}

				block, err := svc.blockRepo.GetLatestBlockProcessed(chainID)
				if err != nil {
					log.Errorf("svc.subscribe, blockRepo.GetLatestBlockProcessed: %v", err)
					return
				}

				if block.Height < event.Raw.BlockNumber {
					err = svc.blockRepo.Save(eventindexer.SaveBlockOpts{
						Height:  event.Raw.BlockNumber,
						Hash:    event.Raw.BlockHash,
						ChainID: chainID,
					})
					if err != nil {
						log.Errorf("svc.subscribe, svc.blockRepo.Save: %v", err)
						return
					}

					eventindexer.BlocksProcessed.Inc()
				}
			}()
		}
	}
}

func (svc *Service) subscribeMessageSent(ctx context.Context, chainID *big.Int, errChan chan error) {
	sink := make(chan *bridge.BridgeMessageSent)

	sub := event.ResubscribeErr(svc.subscriptionBackoff, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			log.Errorf("svc.taikoL1.WatchMessageSent: %v", err)
		}
		log.Info("resubscribing to MessageSent events")

		return svc.bridge.WatchMessageSent(&bind.WatchOpts{
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
			log.Errorf("sub.Err(): %v", err)
			errChan <- errors.Wrap(err, "sub.Err()")
		case event := <-sink:
			go func() {
				log.Infof("messageSentEvent for owner: %v", event.Message.Owner.Hex())

				if err := svc.saveMessageSentEvent(ctx, chainID, event); err != nil {
					eventindexer.MessageSentEventsProcessedError.Inc()

					log.Errorf("svc.subscribe, svc.saveMessageSentEvent: %v", err)

					return
				}

				block, err := svc.blockRepo.GetLatestBlockProcessed(chainID)
				if err != nil {
					log.Errorf("svc.subscribe, blockRepo.GetLatestBlockProcessed: %v", err)
					return
				}

				if block.Height < event.Raw.BlockNumber {
					err = svc.blockRepo.Save(eventindexer.SaveBlockOpts{
						Height:  event.Raw.BlockNumber,
						Hash:    event.Raw.BlockHash,
						ChainID: chainID,
					})
					if err != nil {
						log.Errorf("svc.subscribe, svc.blockRepo.Save: %v", err)
						return
					}

					eventindexer.BlocksProcessed.Inc()
				}
			}()
		}
	}
}

func (svc *Service) subscribeSwap(ctx context.Context, s *swap.Swap, chainID *big.Int, errChan chan error) {
	sink := make(chan *swap.SwapSwap)

	sub := event.ResubscribeErr(svc.subscriptionBackoff, func(ctx context.Context, err error) (event.Subscription, error) {
		if err != nil {
			log.Errorf("s.WatchSwap: %v", err)
		}
		log.Info("resubscribing to Swap events")

		return s.WatchSwap(&bind.WatchOpts{
			Context: ctx,
		}, sink, nil, nil)
	})

	defer sub.Unsubscribe()

	for {
		select {
		case <-ctx.Done():
			log.Info("context finished")
			return
		case err := <-sub.Err():
			log.Errorf("sub.Err(): %v", err)
			errChan <- errors.Wrap(err, "sub.Err()")
		case event := <-sink:
			go func() {
				if err := svc.saveSwapEvent(ctx, chainID, event); err != nil {
					eventindexer.SwapEventsProcessedError.Inc()

					log.Errorf("svc.subscribe, svc.saveSwapEvent: %v", err)

					return
				}

				block, err := svc.blockRepo.GetLatestBlockProcessed(chainID)
				if err != nil {
					log.Errorf("svc.subscribe, blockRepo.GetLatestBlockProcessed: %v", err)
					return
				}

				if block.Height < event.Raw.BlockNumber {
					err = svc.blockRepo.Save(eventindexer.SaveBlockOpts{
						Height:  event.Raw.BlockNumber,
						Hash:    event.Raw.BlockHash,
						ChainID: chainID,
					})
					if err != nil {
						log.Errorf("svc.subscribe, svc.blockRepo.Save: %v", err)
						return
					}

					eventindexer.BlocksProcessed.Inc()
				}
			}()
		}
	}
}

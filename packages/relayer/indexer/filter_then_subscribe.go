package indexer

import (
	"context"
	"sync"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikochain/taiko-mono/packages/relayer"
)

var (
	eventName = relayer.EventNameMessageSent
)

// FilterThenSubscribe gets the most recent block height that has been indexed, and works it's way
// up to the latest block. As it goes, it tries to process messages.
// When it catches up, it then starts to Subscribe to latest events as they come in.
func (svc *Service) FilterThenSubscribe(ctx context.Context) error {
	go svc.watchErrors()

	chainID, err := svc.ethClient.ChainID(ctx)
	if err != nil {
		return errors.Wrap(err, "s.ethClient.ChainID()")
	}

	// get most recently processed block height from the DB
	latestProcessedBlock, err := svc.blockRepo.GetLatestBlockProcessedForEvent(
		eventName,
		chainID,
	)
	if err != nil {
		return errors.Wrap(err, "s.blockRepo.GetLatestBlock()")
	}

	header, err := svc.ethClient.HeaderByNumber(ctx, nil)
	if err != nil {
		return errors.Wrap(err, "s.ethClient.HeaderByNumber")
	}

	// if we have already done the latest block, subscribe to new changes
	if latestProcessedBlock.Height == header.Number.Uint64() {
		return svc.subscribe(ctx, chainID)
	}

	svc.processingBlock = latestProcessedBlock

	log.Infof("getting events between %v and %v in batches of %v",
		svc.processingBlock.Height,
		header.Number.Int64(),
		svc.blockBatchSize,
	)

	for i := latestProcessedBlock.Height; i < header.Number.Uint64(); i += svc.blockBatchSize {
		var end uint64 = svc.processingBlock.Height + svc.blockBatchSize
		// if the end of the batch is greater than the latest block number, set end
		// to the latest block number
		if end > header.Number.Uint64() {
			end = header.Number.Uint64()
		}

		log.Infof("batch from %v to %v", i, end)

		events, err := svc.bridge.FilterMessageSent(&bind.FilterOpts{
			Start:   latestProcessedBlock.Height + uint64(1),
			End:     &end,
			Context: ctx,
		}, nil)
		if err != nil {
			return errors.Wrap(err, "bridge.FilterMessageSent")
		}

		if !events.Next() || events.Event == nil {
			if err := svc.handleNoEventsInBatch(ctx, chainID, int64(end)); err != nil {
				return errors.Wrap(err, "s.handleNoEventsInBatch")
			}

			continue
		}

		log.Info("found events")

		wg := &sync.WaitGroup{}

		for {
			go svc.handleEvent(ctx, wg, svc.errChan, chainID, events.Event)

			if !events.Next() {
				wg.Wait()

				if err := svc.handleNoEventsRemaining(ctx, chainID, events); err != nil {
					return errors.Wrap(err, "svc.handleNoEventsRemaining")
				}

				break
			}
		}
	}

	log.Info("indexer fully caught up, checking latest block number to see if it's advanced")

	latestBlock, err := svc.ethClient.HeaderByNumber(ctx, nil)
	if err != nil {
		return errors.Wrap(err, "svc.ethclient.HeaderByNumber")
	}

	if svc.processingBlock.Height < latestBlock.Number.Uint64() {
		return svc.FilterThenSubscribe(ctx)
	}

	return svc.subscribe(ctx, chainID)
}

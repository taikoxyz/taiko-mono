package indexer

import (
	"context"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"golang.org/x/sync/errgroup"
)

var (
	eventName = relayer.EventNameMessageSent
)

// FilterThenSubscribe gets the most recent block height that has been indexed, and works it's way
// up to the latest block. As it goes, it tries to process messages.
// When it catches up, it then starts to Subscribe to latest events as they come in.
func (svc *Service) FilterThenSubscribe(
	ctx context.Context,
	mode relayer.Mode,
	watchMode relayer.WatchMode,
) error {
	chainID, err := svc.ethClient.ChainID(ctx)
	if err != nil {
		return errors.Wrap(err, "svc.ethClient.ChainID()")
	}

	// if subscribing to new events, skip filtering and subscribe
	if watchMode == relayer.SubscribeWatchMode {
		return svc.subscribe(ctx, chainID)
	}

	if err := svc.setInitialProcessingBlockByMode(ctx, mode, chainID); err != nil {
		return errors.Wrap(err, "svc.setInitialProcessingBlockByMode")
	}

	header, err := svc.ethClient.HeaderByNumber(ctx, nil)
	if err != nil {
		return errors.Wrap(err, "svc.ethClient.HeaderByNumber")
	}

	if svc.processingBlockHeight == header.Number.Uint64() {
		log.Infof("chain ID %v caught up, subscribing to new incoming events", chainID.Uint64())
		return svc.subscribe(ctx, chainID)
	}

	log.Infof("chain ID %v getting events between %v and %v in batches of %v",
		chainID.Uint64(),
		svc.processingBlockHeight,
		header.Number.Int64(),
		svc.blockBatchSize,
	)

	for i := svc.processingBlockHeight; i < header.Number.Uint64(); i += svc.blockBatchSize {
		end := svc.processingBlockHeight + svc.blockBatchSize
		// if the end of the batch is greater than the latest block number, set end
		// to the latest block number
		if end > header.Number.Uint64() {
			end = header.Number.Uint64()
		}

		events, err := svc.bridge.FilterMessageSent(&bind.FilterOpts{
			Start:   svc.processingBlockHeight,
			End:     &end,
			Context: ctx,
		}, nil)
		if err != nil {
			return errors.Wrap(err, "bridge.FilterMessageSent")
		}

		if !events.Next() || events.Event == nil {
			if err := svc.handleNoEventsInBatch(ctx, chainID, int64(end)); err != nil {
				return errors.Wrap(err, "svc.handleNoEventsInBatch")
			}

			continue
		}

		group, groupCtx := errgroup.WithContext(ctx)

		group.SetLimit(svc.numGoroutines)

		for {
			event := events.Event

			group.Go(func() error {
				err := svc.handleEvent(groupCtx, chainID, event)
				if err != nil {
					// log error but always return nil to keep other goroutines active
					log.Error(err.Error())
				}

				return nil
			})

			// if there are no more events
			if !events.Next() {
				// wait for the last of the goroutines to finish
				if err := group.Wait(); err != nil {
					return errors.Wrap(err, "group.Wait")
				}
				// handle no events remaining, saving the processing block and restarting the for
				// loop
				if err := svc.handleNoEventsInBatch(ctx, chainID, int64(end)); err != nil {
					return errors.Wrap(err, "svc.handleNoEventsInBatch")
				}

				break
			}
		}
	}

	log.Infof(
		"chain id %v indexer fully caught up, checking latest block number to see if it's advanced",
		chainID.Uint64(),
	)

	latestBlock, err := svc.ethClient.HeaderByNumber(ctx, nil)
	if err != nil {
		return errors.Wrap(err, "svc.ethclient.HeaderByNumber")
	}

	if svc.processingBlockHeight < latestBlock.Number.Uint64() {
		return svc.FilterThenSubscribe(ctx, relayer.SyncMode, watchMode)
	}

	// we are caught up and specified not to subscribe, we can return now
	if watchMode == relayer.FilterWatchMode {
		return nil
	}

	return svc.subscribe(ctx, chainID)
}

package indexer

import (
	"context"
	"encoding/json"
	"math/big"
	"time"

	"log/slog"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/pacaya/taikoinbox"
	"golang.org/x/sync/errgroup"
)

func (i *Indexer) saveBatchesProvedEvents(
	ctx context.Context,
	chainID *big.Int,
	events *taikoinbox.TaikoInboxBatchesProvedIterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no batchesProved events")
		return nil
	}

	wg, ctx := errgroup.WithContext(ctx)

	for {
		event := events.Event

		wg.Go(func() error {
			if err := i.saveBatchesProvedEvent(ctx, chainID, event); err != nil {
				eventindexer.BatchesProvenEventsProcessedError.Inc()

				return errors.Wrap(err, "i.saveBatchesProvedEvent")
			}

			return nil
		})

		if !events.Next() {
			break
		}
	}

	if err := wg.Wait(); err != nil {
		return err
	}

	return nil
}

func (i *Indexer) saveBatchesProvedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *taikoinbox.TaikoInboxBatchesProved,
) error {
	slog.Info("batchesProved event found",
		"batchIds", event.BatchIds,
		"verifier", event.Verifier.Hex())

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	block, err := i.ethClient.BlockByNumber(ctx, new(big.Int).SetUint64(event.Raw.BlockNumber))
	if err != nil {
		return errors.Wrap(err, "i.ethClient.BlockByNumber")
	}

	for _, batchID := range event.BatchIds {
		bID := int64(batchID)

		_, err = i.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
			Name:           eventindexer.EventNameBatchesProven,
			Data:           string(marshaled),
			ChainID:        chainID,
			Event:          eventindexer.EventNameBatchesProven,
			Address:        event.Verifier.Hex(),
			TransactedAt:   time.Unix(int64(block.Time()), 0),
			EmittedBlockID: event.Raw.BlockNumber,
			BatchID:        &bID,
		})
		if err != nil {
			return errors.Wrap(err, "i.eventRepo.Save")
		}
	}

	eventindexer.BatchesProvedEventsProcessed.Inc()

	return nil
}

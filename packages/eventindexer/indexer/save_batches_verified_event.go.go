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

func (i *Indexer) saveBatchesVerifiedEvents(
	ctx context.Context,
	chainID *big.Int,
	events *taikoinbox.TaikoInboxBatchesVerifiedIterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no BatchesVerified events")
		return nil
	}

	wg, ctx := errgroup.WithContext(ctx)

	for {
		event := events.Event

		wg.Go(func() error {
			if err := i.saveBatchesVerifiedEvent(ctx, chainID, event); err != nil {
				eventindexer.BatchesVerifiedEventsProcessedError.Inc()

				return errors.Wrap(err, "i.saveBatchesVerifiedEvent")
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

func (i *Indexer) saveBatchesVerifiedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *taikoinbox.TaikoInboxBatchesVerified,
) error {
	slog.Info("new BatchesVerified event", "batchId", event.BatchId)

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	batchID := int64(event.BatchId)

	block, err := i.ethClient.BlockByNumber(ctx, new(big.Int).SetUint64(event.Raw.BlockNumber))
	if err != nil {
		return errors.Wrap(err, "i.ethClient.BlockByNumber")
	}

	_, err = i.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:           eventindexer.EventNameBatchesVerified,
		Data:           string(marshaled),
		ChainID:        chainID,
		Event:          eventindexer.EventNameBatchesVerified,
		Address:        "",
		BatchID:        &batchID,
		TransactedAt:   time.Unix(int64(block.Time()), 0),
		EmittedBlockID: event.Raw.BlockNumber,
	})
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.Save")
	}

	eventindexer.BatchesVerifiedEventsProcessed.Inc()

	return nil
}

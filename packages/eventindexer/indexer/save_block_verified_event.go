package indexer

import (
	"context"
	"encoding/json"
	"math/big"
	"time"

	"log/slog"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/taikol1"
)

func (i *Indexer) saveBlockVerifiedEvents(
	ctx context.Context,
	chainID *big.Int,
	events *taikol1.TaikoL1BlockVerifiedIterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no BlockVerified events")
		return nil
	}

	for {
		event := events.Event

		if err := i.saveBlockVerifiedEvent(ctx, chainID, event); err != nil {
			eventindexer.BlockVerifiedEventsProcessedError.Inc()

			return errors.Wrap(err, "i.saveBlockVerifiedEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (i *Indexer) saveBlockVerifiedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *taikol1.TaikoL1BlockVerified,
) error {
	slog.Info("new blockVerified event", "blockID", event.BlockId.Int64())

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	blockID := event.BlockId.Int64()

	block, err := i.ethClient.BlockByNumber(ctx, new(big.Int).SetUint64(event.Raw.BlockNumber))
	if err != nil {
		return errors.Wrap(err, "i.ethClient.BlockByNumber")
	}

	_, err = i.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:           eventindexer.EventNameBlockVerified,
		Data:           string(marshaled),
		ChainID:        chainID,
		Event:          eventindexer.EventNameBlockVerified,
		Address:        "",
		BlockID:        &blockID,
		TransactedAt:   time.Unix(int64(block.Time()), 0),
		EmittedBlockID: event.Raw.BlockNumber,
	})
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.Save")
	}

	eventindexer.BlockVerifiedEventsProcessed.Inc()

	return nil
}

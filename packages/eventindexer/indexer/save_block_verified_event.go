package indexer

import (
	"context"
	"encoding/json"
	"math/big"

	"log/slog"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/taikol1"
)

func (svc *Service) saveBlockVerifiedEvents(
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

		if err := svc.detectAndHandleReorg(ctx, eventindexer.EventNameBlockVerified, event.BlockId.Int64()); err != nil {
			return errors.Wrap(err, "svc.detectAndHandleReorg")
		}

		if err := svc.saveBlockVerifiedEvent(ctx, chainID, event); err != nil {
			eventindexer.BlockVerifiedEventsProcessedError.Inc()

			return errors.Wrap(err, "svc.saveBlockVerifiedEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (svc *Service) saveBlockVerifiedEvent(
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

	_, err = svc.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:    eventindexer.EventNameBlockVerified,
		Data:    string(marshaled),
		ChainID: chainID,
		Event:   eventindexer.EventNameBlockVerified,
		Address: "",
		BlockID: &blockID,
	})
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.Save")
	}

	eventindexer.BlockVerifiedEventsProcessed.Inc()

	return nil
}

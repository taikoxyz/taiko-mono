package indexer

import (
	"context"
	"encoding/json"
	"math/big"
	"strconv"

	"log/slog"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/proverpool"
)

func (svc *Service) saveSlashedEvents(
	ctx context.Context,
	chainID *big.Int,
	events *proverpool.ProverPoolSlashedIterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no Slashed events")
		return nil
	}

	for {
		event := events.Event

		slog.Info("new slashed event",
			"address", event.Addr.Hex(),
			"amount", strconv.FormatUint(event.Amount, 10),
		)

		if err := svc.saveSlashedEvent(ctx, chainID, event); err != nil {
			eventindexer.SlashedEventsProcessedError.Inc()

			return errors.Wrap(err, "svc.saveSlashedEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (svc *Service) saveSlashedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *proverpool.ProverPoolSlashed,
) error {
	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	_, err = svc.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:    eventindexer.EventNameSlashed,
		Data:    string(marshaled),
		ChainID: chainID,
		Event:   eventindexer.EventNameSlashed,
		Address: event.Addr.Hex(),
		Amount:  new(big.Int).SetUint64(event.Amount),
	})
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.Save")
	}

	eventindexer.SlashedEventsProcessed.Inc()

	return nil
}

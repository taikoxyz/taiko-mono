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

func (svc *Service) saveExitedEvents(
	ctx context.Context,
	chainID *big.Int,
	events *proverpool.ProverPoolExitedIterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no Exited events")
		return nil
	}

	for {
		event := events.Event

		slog.Info("new Exited event",
			"address",
			event.Addr.Hex(),
			"amount",
			strconv.FormatUint(event.Amount, 10),
		)

		if err := svc.saveExitedEvent(ctx, chainID, event); err != nil {
			eventindexer.ExitedEventsProcessedError.Inc()

			return errors.Wrap(err, "svc.saveExitedEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (svc *Service) saveExitedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *proverpool.ProverPoolExited,
) error {
	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	_, err = svc.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:    eventindexer.EventNameExited,
		Data:    string(marshaled),
		ChainID: chainID,
		Event:   eventindexer.EventNameExited,
		Address: event.Addr.Hex(),
		Amount:  new(big.Int).SetUint64(event.Amount),
	})
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.Save")
	}

	eventindexer.ExitedEventsProcessed.Inc()

	return nil
}

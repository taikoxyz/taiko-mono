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

func (svc *Service) saveStakedEvents(
	ctx context.Context,
	chainID *big.Int,
	events *proverpool.ProverPoolStakedIterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no Staked events")
		return nil
	}

	for {
		event := events.Event

		slog.Info("new Staked event",
			"address", event.Addr.Hex(),
			"amount", strconv.FormatUint(event.Amount, 10),
		)

		if err := svc.saveStakedEvent(ctx, chainID, event); err != nil {
			eventindexer.StakedEventsProcessedError.Inc()

			return errors.Wrap(err, "svc.saveStakedEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (svc *Service) saveStakedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *proverpool.ProverPoolStaked,
) error {
	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	_, err = svc.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:    eventindexer.EventNameStaked,
		Data:    string(marshaled),
		ChainID: chainID,
		Event:   eventindexer.EventNameStaked,
		Address: event.Addr.Hex(),
		Amount:  new(big.Int).SetUint64(event.Amount),
	})
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.Save")
	}

	eventindexer.StakedEventsProcessed.Inc()

	return nil
}

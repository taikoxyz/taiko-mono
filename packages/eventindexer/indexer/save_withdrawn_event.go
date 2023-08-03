package indexer

import (
	"context"
	"encoding/json"
	"math/big"

	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/proverpool"
)

func (svc *Service) saveWithdrawnEvents(
	ctx context.Context,
	chainID *big.Int,
	events *proverpool.ProverPoolWithdrawnIterator,
) error {
	if !events.Next() || events.Event == nil {
		log.Infof("no Withdrawn events")
		return nil
	}

	for {
		event := events.Event

		log.Infof("new Withdrawn event, addr: %v, amt: %v", event.Addr.Hex(), event.Amount)

		if err := svc.saveWithdrawnEvent(ctx, chainID, event); err != nil {
			eventindexer.WithdrawnEventsProcessedError.Inc()

			return errors.Wrap(err, "svc.saveWithdrawnEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (svc *Service) saveWithdrawnEvent(
	ctx context.Context,
	chainID *big.Int,
	event *proverpool.ProverPoolWithdrawn,
) error {
	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	_, err = svc.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:    eventindexer.EventNameWithdrawn,
		Data:    string(marshaled),
		ChainID: chainID,
		Event:   eventindexer.EventNameWithdrawn,
		Address: event.Addr.Hex(),
		Amount:  new(big.Int).SetUint64(event.Amount),
	})
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.Save")
	}

	eventindexer.WithdrawnEventsProcessed.Inc()

	return nil
}

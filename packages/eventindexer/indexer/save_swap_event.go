package indexer

import (
	"context"
	"encoding/json"
	"math/big"

	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/swap"
)

func (svc *Service) saveSwapEvents(
	ctx context.Context,
	chainID *big.Int,
	events *swap.SwapSwapIterator,
) error {
	if !events.Next() || events.Event == nil {
		log.Infof("no Swap events")
		return nil
	}

	for {
		event := events.Event

		log.Infof("new Swap event for sender: %v", event.Sender.Hex())

		if err := svc.saveSwapEvent(ctx, chainID, event); err != nil {
			eventindexer.SwapEventsProcessedError.Inc()

			return errors.Wrap(err, "svc.saveSwapEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (svc *Service) saveSwapEvent(
	ctx context.Context,
	chainID *big.Int,
	event *swap.SwapSwap,
) error {
	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	_, err = svc.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:    eventindexer.EventNameSwap,
		Data:    string(marshaled),
		ChainID: chainID,
		Event:   eventindexer.EventNameSwap,
		Address: event.Sender.Hex(),
	})
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.Save")
	}

	eventindexer.SwapEventsProcessed.Inc()

	return nil
}

package indexer

import (
	"context"
	"encoding/json"
	"math/big"

	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/taikol1"
)

func (svc *Service) saveBlockProvenEvents(
	ctx context.Context,
	chainID *big.Int,
	events *taikol1.TaikoL1BlockProvenIterator,
) error {
	if !events.Next() || events.Event == nil {
		log.Infof("no blockProven events")
		return nil
	}

	for {
		event := events.Event

		if event.Raw.Removed {
			continue
		}

		log.Infof("blockProven by: %v", event.Prover.Hex())

		if err := svc.saveBlockProvenEvent(ctx, chainID, event); err != nil {
			eventindexer.BlockProvenEventsProcessedError.Inc()

			return errors.Wrap(err, "svc.saveBlockProvenEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (svc *Service) saveBlockProvenEvent(
	ctx context.Context,
	chainID *big.Int,
	event *taikol1.TaikoL1BlockProven,
) error {
	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	_, err = svc.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:    eventindexer.EventNameBlockProven,
		Data:    string(marshaled),
		ChainID: chainID,
		Event:   eventindexer.EventNameBlockProven,
		Address: event.Prover.Hex(),
	})
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.Save")
	}

	eventindexer.BlockProvenEventsProcessed.Inc()

	return nil
}

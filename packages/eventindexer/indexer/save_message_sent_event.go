package indexer

import (
	"context"
	"encoding/json"
	"math/big"

	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/bridge"
)

func (svc *Service) saveMessageSentEvents(
	ctx context.Context,
	chainID *big.Int,
	events *bridge.BridgeMessageSentIterator,
) error {
	if !events.Next() || events.Event == nil {
		log.Infof("no MessageSent events")
		return nil
	}

	for {
		event := events.Event

		log.Infof("new messageSent event for owner: %v", event.Message.Owner.Hex())

		if err := svc.saveMessageSentEvent(ctx, chainID, event); err != nil {
			eventindexer.MessageSentEventsProcessedError.Inc()

			return errors.Wrap(err, "svc.saveMessageSentEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (svc *Service) saveMessageSentEvent(
	ctx context.Context,
	chainID *big.Int,
	event *bridge.BridgeMessageSent,
) error {
	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	_, err = svc.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:    eventindexer.EventNameMessageSent,
		Data:    string(marshaled),
		ChainID: chainID,
		Event:   eventindexer.EventNameMessageSent,
		Address: event.Message.Owner.Hex(),
	})
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.Save")
	}

	eventindexer.MessageSentEventsProcessed.Inc()

	return nil
}

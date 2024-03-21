package indexer

import (
	"context"
	"encoding/json"
	"math/big"
	"time"

	"log/slog"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/bridge"
)

func (i *Indexer) saveMessageSentEvents(
	ctx context.Context,
	chainID *big.Int,
	events *bridge.BridgeMessageSentIterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no MessageSent events")
		return nil
	}

	for {
		event := events.Event

		slog.Info("new messageSent event", "owner", event.Message.From.Hex())

		if err := i.saveMessageSentEvent(ctx, chainID, event); err != nil {
			eventindexer.MessageSentEventsProcessedError.Inc()

			return errors.Wrap(err, "i.saveMessageSentEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (i *Indexer) saveMessageSentEvent(
	ctx context.Context,
	chainID *big.Int,
	event *bridge.BridgeMessageSent,
) error {
	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	block, err := i.ethClient.BlockByNumber(ctx, new(big.Int).SetUint64(event.Raw.BlockNumber))
	if err != nil {
		return errors.Wrap(err, "i.ethClient.BlockByNumber")
	}

	_, err = i.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:           eventindexer.EventNameMessageSent,
		Data:           string(marshaled),
		ChainID:        chainID,
		Event:          eventindexer.EventNameMessageSent,
		Address:        event.Message.From.Hex(),
		TransactedAt:   time.Unix(int64(block.Time()), 0),
		EmittedBlockID: event.Raw.BlockNumber,
	})
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.Save")
	}

	eventindexer.MessageSentEventsProcessed.Inc()

	return nil
}

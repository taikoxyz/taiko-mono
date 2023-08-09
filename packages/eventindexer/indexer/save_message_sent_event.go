package indexer

import (
	"context"
	"encoding/json"
	"math/big"

	"log/slog"

	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/bridge"
)

var (
	minEthAmount = new(big.Int).SetUint64(150000000000000000)
	zeroHash     = common.HexToHash("0x0000000000000000000000000000000000000000000000000000000000000000")
)

func (svc *Service) saveMessageSentEvents(
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

		slog.Info("new messageSent event", "owner", event.Message.Owner.Hex())

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
	// only save eth transfers
	if event.Message.Data != nil && common.BytesToHash(event.Message.Data) != zeroHash {
		slog.Info("skipping message sent event, is not eth transfer")
		return nil
	}

	// amount must be >= 0.15 eth
	if event.Message.DepositValue.Cmp(minEthAmount) < 0 {
		slog.Info("skipping message sent event",
			"value",
			event.Message.DepositValue.String(),
			"requiredValue",
			minEthAmount.String(),
		)

		return nil
	}

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

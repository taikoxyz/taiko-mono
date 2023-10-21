package indexer

import (
	"context"
	"encoding/json"
	"math/big"

	"log/slog"

	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
)

func (i *Indexer) saveMessageStatusChangedEvents(
	ctx context.Context,
	chainID *big.Int,
	events *bridge.BridgeMessageStatusChangedIterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no messageStatusChanged events")
		return nil
	}

	for {
		event := events.Event

		slog.Info("messageStatusChanged", "msgHash", common.Hash(event.MsgHash).Hex())

		if err := i.detectAndHandleReorg(
			ctx,
			relayer.EventNameMessageStatusChanged,
			common.Hash(event.MsgHash).Hex(),
		); err != nil {
			return errors.Wrap(err, "i.detectAndHandleReorg")
		}

		if err := i.saveMessageStatusChangedEvent(ctx, chainID, event); err != nil {
			return errors.Wrap(err, "i.saveMessageStatusChangedEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (i *Indexer) saveMessageStatusChangedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *bridge.BridgeMessageStatusChanged,
) error {
	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	// get the previous MessageSent event or other message status changed events,
	// so we can find out the previous owner of this msg hash,
	// to save to the db.
	e, err := i.eventRepo.FirstByMsgHash(ctx, common.Hash(event.MsgHash).Hex())
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.FirstByMsgHash")
	}

	if e == nil || e.MsgHash == "" {
		return nil
	}

	_, err = i.eventRepo.Save(ctx, relayer.SaveEventOpts{
		Name:         relayer.EventNameMessageStatusChanged,
		Data:         string(marshaled),
		ChainID:      chainID,
		Status:       relayer.EventStatus(event.Status),
		MessageOwner: e.MessageOwner,
		MsgHash:      common.Hash(event.MsgHash).Hex(),
		Event:        relayer.EventNameMessageStatusChanged,
	})
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.Save")
	}

	return nil
}

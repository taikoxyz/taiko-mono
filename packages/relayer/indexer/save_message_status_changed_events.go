package indexer

import (
	"context"
	"encoding/json"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	log "github.com/sirupsen/logrus"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/contracts/bridge"
)

func (svc *Service) saveMessageStatusChangedEvents(
	ctx context.Context,
	chainID *big.Int,
	events *bridge.BridgeMessageStatusChangedIterator,
) error {
	if !events.Next() || events.Event == nil {
		log.Infof("no messageStatusChanged events")
		return nil
	}

	for {
		event := events.Event

		log.Infof("messageStatusChanged: %v", common.Hash(event.MsgHash).Hex())

		if err := svc.detectAndHandleReorg(
			ctx,
			relayer.EventNameMessageStatusChanged,
			common.Hash(event.MsgHash).Hex(),
		); err != nil {
			return errors.Wrap(err, "svc.detectAndHandleReorg")
		}

		if err := svc.saveMessageStatusChangedEvent(ctx, chainID, event); err != nil {
			return errors.Wrap(err, "svc.saveMessageStatusChangedEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (svc *Service) saveMessageStatusChangedEvent(
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
	e, err := svc.eventRepo.FirstByMsgHash(ctx, common.Hash(event.MsgHash).Hex())
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.FirstByMsgHash")
	}

	if e == nil || e.MsgHash == "" {
		return nil
	}

	_, err = svc.eventRepo.Save(ctx, relayer.SaveEventOpts{
		Name:         relayer.EventNameMessageStatusChanged,
		Data:         string(marshaled),
		ChainID:      chainID,
		Status:       relayer.EventStatus(event.Status),
		MessageOwner: e.MessageOwner,
		MsgHash:      common.Hash(event.MsgHash).Hex(),
		Event:        relayer.EventNameMessageStatusChanged,
	})
	if err != nil {
		return errors.Wrap(err, "svc.eventRepo.Save")
	}

	return nil
}

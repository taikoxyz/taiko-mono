package indexer

import (
	"context"
	"encoding/json"
	"math/big"

	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
)

func (i *Indexer) handleMessageStatusChangedEvent(
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
		Name:           relayer.EventNameMessageStatusChanged,
		Data:           string(marshaled),
		ChainID:        chainID,
		DestChainID:    i.destChainId,
		Status:         relayer.EventStatus(event.Status),
		MessageOwner:   e.MessageOwner,
		MsgHash:        common.Hash(event.MsgHash).Hex(),
		Event:          relayer.EventNameMessageStatusChanged,
		EmittedBlockID: event.Raw.BlockNumber,
	})
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.Save")
	}

	relayer.MessageStatusChangedEventsIndexed.Inc()

	return nil
}

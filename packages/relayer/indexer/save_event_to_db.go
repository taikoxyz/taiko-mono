package indexer

import (
	"context"
	"math/big"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

func (i *Indexer) saveEventToDB(
	ctx context.Context,
	marshalledEvent []byte,
	msgHash string,
	chainID *big.Int,
	eventStatus relayer.EventStatus,
	msgOwner string,
	eventData []byte,
	eventValue *big.Int,
) (int, error) {
	eventType, canonicalToken, amount, err := relayer.DecodeMessageData(eventData, eventValue)
	if err != nil {
		return 0, errors.Wrap(err, "eventTypeAmountAndCanonicalTokenFromEvent(event)")
	}

	// check if we have an existing event already. this is mostly likely only true
	// in the case of us crawling past blocks.
	existingEvent, err := i.eventRepo.FirstByEventAndMsgHash(
		ctx,
		i.eventName,
		msgHash,
	)
	if err != nil {
		return 0, errors.Wrap(err, "i.eventRepo.FirstByEventAndMsgHash")
	}

	var id int

	// if we dont have an existing event, we want to create a database entry
	// for the processor to be able to fetch it.
	if existingEvent == nil {
		opts := relayer.SaveEventOpts{
			Name:         i.eventName,
			Data:         string(marshalledEvent),
			ChainID:      chainID,
			Status:       eventStatus,
			EventType:    eventType,
			Amount:       amount.String(),
			MsgHash:      msgHash,
			MessageOwner: msgOwner,
			Event:        i.eventName,
		}

		if canonicalToken != nil {
			opts.CanonicalTokenAddress = canonicalToken.Address().Hex()
			opts.CanonicalTokenSymbol = canonicalToken.ContractSymbol()
			opts.CanonicalTokenName = canonicalToken.ContractName()
			opts.CanonicalTokenDecimals = canonicalToken.TokenDecimals()
		}

		e, err := i.eventRepo.Save(ctx, opts)
		if err != nil {
			return 0, errors.Wrap(err, "svc.eventRepo.Save")
		}

		id = e.ID
	} else {
		// otherwise, we can use the existing event ID for the body.
		id = existingEvent.ID
	}

	return id, nil
}

package indexer

import (
	"context"
	"fmt"
	"math/big"
	"unicode/utf8"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
)

// saveEventToDB is used to save any type of event to the database
func (i *Indexer) saveEventToDB(
	ctx context.Context,
	marshalledEvent []byte,
	msgHash string,
	chainID *big.Int,
	eventStatus relayer.EventStatus,
	msgOwner string,
	eventData []byte,
	eventValue *big.Int,
	emittedBlockNumber uint64,
) (int, error) {
	eventType, canonicalToken, amount, err := relayer.DecodeMessageData(eventData, eventValue)
	if err != nil {
		return 0, errors.Wrap(err, "relayer.DecodeMessageData")
	}

	if eventType == relayer.EventTypeSendETH {
		canonicalToken = nil
		amount = eventValue
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
			Name:           i.eventName,
			Data:           string(marshalledEvent),
			ChainID:        chainID,
			DestChainID:    i.destChainId,
			Status:         eventStatus,
			EventType:      eventType,
			Amount:         amount.String(),
			MsgHash:        msgHash,
			MessageOwner:   msgOwner,
			Event:          i.eventName,
			EmittedBlockID: emittedBlockNumber,
		}

		if canonicalToken != nil {
			opts.CanonicalTokenAddress = canonicalToken.Address().Hex()
			opts.CanonicalTokenSymbol = sanitizeString(canonicalToken.ContractSymbol())
			opts.CanonicalTokenName = sanitizeString(canonicalToken.ContractName())
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

		// if indexing message sent event, we want to check if we need to
		// update status.
		if i.eventName == relayer.EventNameMessageSent {
			if i.watchMode == CrawlPastBlocks && eventStatus == existingEvent.Status {
				// If the status from contract matches the existing event status,
				// we can return early as this message has been processed as expected.
				return id, nil
			}

			// If the status from contract is done, update the database
			if i.watchMode == CrawlPastBlocks && eventStatus == relayer.EventStatusDone {
				if err := i.eventRepo.UpdateStatus(ctx, id, relayer.EventStatusDone); err != nil {
					return 0, errors.Wrap(err, fmt.Sprintf("i.eventRepo.UpdateStatus, id: %v", id))
				}

				return id, nil
			}
		}
	}

	return id, nil
}

const maxLength = 255

// sanitizeString ensures that the input string is
// valid UTF-8 and does not exceed the maximum allowed length.
// If the input string contains invalid UTF-8 characters
// or exceeds the maximum length, it returns an empty string.
func sanitizeString(input string) string {
	if !utf8.ValidString(input) || len(input) > maxLength {
		return ""
	}

	return input
}

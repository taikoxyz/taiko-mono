package indexer

import (
	"context"
	"encoding/json"
	"fmt"
	"math/big"
	"time"

	"log/slog"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
)

var (
	defaultCtxTimeout    = 3 * time.Minute
	defaultConfirmations = 5
)

// handleEvent handles an individual MessageSent event
func (i *Indexer) handleEvent(
	ctx context.Context,
	chainID *big.Int,
	event *bridge.BridgeMessageSent,
) error {
	slog.Info("event found for msgHash", "msgHash", common.Hash(event.MsgHash).Hex(), "txHash", event.Raw.TxHash.Hex())

	// if the destinatio chain doesnt match, we dont process it in this indexer.
	if new(big.Int).SetUint64(event.Message.DestChainId).Cmp(i.destChainId) != 0 {
		slog.Info("skipping event, wrong chainID",
			"messageDestChainID",
			event.Message.DestChainId,
			"indexerDestChainID",
			i.destChainId.Uint64(),
		)

		return nil
	}

	if event.Raw.Removed {
		slog.Info("event is removed")
		return nil
	}

	// we should never see an empty msgHash, but if we do, we dont process.
	if event.MsgHash == relayer.ZeroHash {
		slog.Warn("Zero msgHash found. This is unexpected. Returning early")
		return nil
	}

	// only wait for confirmations when not crawling past blocks.
	// these are guaranteed to be confirmed since the blocks are old.
	if i.watchMode != CrawlPastBlocks {
		// check if we have seen this event and msgHash before - if we have, it is being reorged.
		if err := i.detectAndHandleReorg(ctx, relayer.EventNameMessageSent, common.Hash(event.MsgHash).Hex()); err != nil {
			return errors.Wrap(err, "svc.detectAndHandleReorg")
		}

		// we need to wait for confirmations to confirm this event is not being reverted,
		// removed, or reorged now.
		confCtx, confCtxCancel := context.WithTimeout(ctx, defaultCtxTimeout)

		defer confCtxCancel()

		if err := relayer.WaitConfirmations(
			confCtx,
			i.srcEthClient,
			uint64(defaultConfirmations),
			event.Raw.TxHash,
		); err != nil {
			return err
		}
	}

	// get event status from msgHash on chain
	eventStatus, err := i.eventStatusFromMsgHash(ctx, event.Message.GasLimit, event.MsgHash)
	if err != nil {
		return errors.Wrap(err, "svc.eventStatusFromMsgHash")
	}

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	eventType, canonicalToken, amount, err := relayer.DecodeMessageSentData(event)
	if err != nil {
		return errors.Wrap(err, "eventTypeAmountAndCanonicalTokenFromEvent(event)")
	}

	// TODO(xiaodino): Change to batch query

	// check if we have an existing event already. this is mostly likely only true
	// in the case of us crawling past blocks.
	existingEvent, err := i.eventRepo.FirstByEventAndMsgHash(
		ctx,
		relayer.EventNameMessageSent,
		common.Hash(event.MsgHash).Hex(),
	)
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.FirstByEventAndMsgHash")
	}

	var id int

	// if we dont have an existing event, we want to create a database entry
	// for the processor to be able to fetch it.
	if existingEvent == nil {
		opts := relayer.SaveEventOpts{
			Name:         relayer.EventNameMessageSent,
			Data:         string(marshaled),
			ChainID:      chainID,
			Status:       eventStatus,
			EventType:    eventType,
			Amount:       amount.String(),
			MsgHash:      common.Hash(event.MsgHash).Hex(),
			MessageOwner: event.Message.Owner.Hex(),
			Event:        relayer.EventNameMessageSent,
		}

		if canonicalToken != nil {
			opts.CanonicalTokenAddress = canonicalToken.Address().Hex()
			opts.CanonicalTokenSymbol = canonicalToken.ContractSymbol()
			opts.CanonicalTokenName = canonicalToken.ContractName()
			opts.CanonicalTokenDecimals = canonicalToken.TokenDecimals()
		}

		e, err := i.eventRepo.Save(ctx, opts)
		if err != nil {
			return errors.Wrap(err, "svc.eventRepo.Save")
		}

		id = e.ID
	} else {
		// otherwise, we can use the existing event ID for the body.
		id = existingEvent.ID

		if i.watchMode == CrawlPastBlocks && eventStatus == existingEvent.Status {
			// If the status from contract matches the existing event status,
			// we can return early as this message has been processed as expected.
			// slog.Info("crawler returning early", "eventStatus", eventStatus, "existingEvent.Status", existingEvent.Status)
			return nil
		}

		// If the status from contract is done, update the database
		if i.watchMode == CrawlPastBlocks && eventStatus == relayer.EventStatusDone {
			slog.Info("updating status for msgHash", "msgHash", common.Hash(event.MsgHash).Hex())

			if err := i.eventRepo.UpdateStatus(ctx, id, relayer.EventStatusDone); err != nil {
				return errors.Wrap(err, fmt.Sprintf("i.eventRepo.UpdateStatus, id: %v", id))
			}

			return nil
		}
	}

	msg := queue.QueueMessageBody{
		ID:    id,
		Event: event,
	}

	marshalledMsg, err := json.Marshal(msg)
	if err != nil {
		return errors.Wrap(err, "json.Marshal")
	}

	// we add it to the queue, so the processor can pick up and attempt to process
	// the message onchain.
	if err := i.queue.Publish(ctx, marshalledMsg); err != nil {
		return errors.Wrap(err, "i.queue.Publish")
	}

	return nil
}

func (i *Indexer) eventStatusFromMsgHash(
	ctx context.Context,
	gasLimit *big.Int,
	signal [32]byte,
) (relayer.EventStatus, error) {
	var eventStatus relayer.EventStatus

	ctx, cancel := context.WithTimeout(ctx, i.ethClientTimeout)

	defer cancel()

	messageStatus, err := i.destBridge.MessageStatus(&bind.CallOpts{
		Context: ctx,
	}, signal)
	if err != nil {
		return 0, errors.Wrap(err, "svc.destBridge.GetMessageStatus")
	}

	eventStatus = relayer.EventStatus(messageStatus)
	if eventStatus == relayer.EventStatusNew {
		if gasLimit == nil || gasLimit.Cmp(common.Big0) == 0 {
			// if gasLimit is 0, relayer can not process this.
			eventStatus = relayer.EventStatusNewOnlyOwner
		}
	}

	return eventStatus, nil
}

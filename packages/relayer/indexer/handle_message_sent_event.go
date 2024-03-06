package indexer

import (
	"context"
	"encoding/json"
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

// handleMessageSentEvent handles an individual MessageSent event
func (i *Indexer) handleMessageSentEvent(
	ctx context.Context,
	chainID *big.Int,
	event *bridge.BridgeMessageSent,
	waitForConfirmations bool,
) error {
	slog.Info("MessageSent event found for msgHash",
		"msgHash",
		common.Hash(event.MsgHash).Hex(),
		"txHash",
		event.Raw.TxHash.Hex(),
	)

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

	// check if we have seen this event and msgHash before - if we have, it is being reorged.
	if err := i.detectAndHandleReorg(ctx, i.eventName, common.Hash(event.MsgHash).Hex()); err != nil {
		return errors.Wrap(err, "svc.detectAndHandleReorg")
	}

	// we should never see an empty msgHash, but if we do, we dont process.
	if event.MsgHash == relayer.ZeroHash {
		slog.Warn("Zero msgHash found. This is unexpected. Returning early")
		return nil
	}

	if waitForConfirmations {
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

	id, err := i.saveEventToDB(
		ctx,
		marshaled,
		common.Hash(event.MsgHash).Hex(),
		chainID,
		eventStatus,
		event.Message.SrcOwner.Hex(),
		event.Message.Data,
		event.Message.Value,
	)
	if err != nil {
		return errors.Wrap(err, "i.saveEventToDB")
	}

	msg := queue.QueueMessageSentBody{
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

	relayer.MessageSentEventsIndexed.Inc()

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

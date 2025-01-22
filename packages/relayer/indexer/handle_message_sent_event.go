package indexer

import (
	"context"
	"encoding/json"
	"math/big"

	"log/slog"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
)

// handleMessageSentEvent handles an individual MessageSent event
func (i *Indexer) handleMessageSentEvent(
	ctx context.Context,
	chainID *big.Int,
	event *bridge.BridgeMessageSent,
	waitForConfirmations bool,
) error {
	// if the destinatio chain doesnt match, we dont process it in this indexer.
	if new(big.Int).SetUint64(event.Message.DestChainId).Cmp(i.destChainId) != 0 {
		return nil
	}

	slog.Info("MessageSent event found for msgHash",
		"msgHash",
		common.Hash(event.MsgHash).Hex(),
		"txHash",
		event.Raw.TxHash.Hex(),
		"srcChainId", event.Message.SrcChainId,
		"destChainId", event.Message.DestChainId,
	)

	if event.Raw.Removed {
		slog.Info("event is removed")
		return nil
	}

	// we should never see an empty msgHash, but if we do, we dont process.
	if event.MsgHash == relayer.ZeroHash {
		slog.Warn("Zero msgHash found. This is unexpected. Returning early")
		return nil
	}

	if waitForConfirmations {
		// we need to wait for confirmations to confirm this event is not being reverted,
		// removed, or reorged now.
		confCtx, confCtxCancel := context.WithTimeout(ctx, i.cfg.ConfirmationTimeout)

		defer confCtxCancel()

		if err := relayer.WaitConfirmations(
			confCtx,
			i.srcEthClient,
			i.confirmations,
			event.Raw.TxHash,
		); err != nil {
			return err
		}
	}

	// get event status from msgHash on chain
	eventStatus, err := i.eventStatusFromMsgHash(ctx, event.MsgHash)
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
		event.Raw.BlockNumber,
	)
	if err != nil {
		return errors.Wrap(err, "i.saveEventToDB")
	}

	// only add messages with new status to queue
	if eventStatus != relayer.EventStatusNew {
		return nil
	}

	// we shouldnt add messages to the queue that will be determined
	// unprocessable.
	if event.Message.GasLimit == 0 {
		slog.Warn("Zero gaslimit message found, will be unprocessable")
		return nil
	}

	if i.minFeeToIndex != 0 && event.Message.Fee < i.minFeeToIndex {
		slog.Warn("Fee is less than minFeeToIndex, not adding to queue",
			"fee", event.Message.Fee,
			"minFeeToIndex", i.minFeeToIndex,
		)
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
	if err := i.queue.Publish(ctx, i.queueName(), marshalledMsg, nil, nil); err != nil {
		return errors.Wrap(err, "i.queue.Publish")
	}

	relayer.MessageSentEventsIndexed.Inc()

	return nil
}

func (i *Indexer) eventStatusFromMsgHash(
	ctx context.Context,
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

	return eventStatus, nil
}

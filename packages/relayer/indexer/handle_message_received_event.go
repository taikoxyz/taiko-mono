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
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
)

// handleMessageReceivedEvent handles an individual MessageSent event
func (i *Indexer) handleMessageReceivedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *bridge.BridgeMessageReceived,
) error {
	slog.Info("msg received event found for msgHash",
		"msgHash", common.Hash(event.MsgHash).Hex(),
		"txHash", event.Raw.TxHash.Hex(),
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

	// get event status from msgHash on chain
	eventStatus, err := i.eventStatusFromMsgHash(ctx, event.Message.GasLimit, event.MsgHash)
	if err != nil {
		return errors.Wrap(err, "svc.eventStatusFromMsgHash")
	}

	// if the message is not status new, and we are iterating crawling past blocks,
	// we also dont want to handle this event. it has already been handled.
	if i.watchMode == CrawlPastBlocks && eventStatus != relayer.EventStatusNew {
		// we can return early, this message has been processed as expected.
		return nil
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
		event.Message.Owner.Hex(),
		event.Message.Data,
		event.Message.Value,
	)
	if err != nil {
		return errors.Wrap(err, "i.saveEventToDB")
	}

	msg := queue.QueueMessageReceivedBody{
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

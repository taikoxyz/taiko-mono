package indexer

import (
	"context"
	"encoding/json"
	"log/slog"
	"math/big"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/bindings/bridge"
)

// handleMessageProcessedEvent handles an individual MessageProcessed event
func (i *Indexer) handleMessageProcessedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *bridge.BridgeMessageProcessed,
	waitForConfirmations bool,
) error {
	slog.Info("msg received event found",
		"txHash", event.Raw.TxHash.Hex(),
	)

	message := event.Message

	// if the destination doesn't match our source chain, we dont want to handle this event.
	if new(big.Int).SetUint64(message.DestChainId).Cmp(i.srcChainId) != 0 {
		slog.Info("skipping event, wrong chainID",
			"messageDestChainID",
			message.DestChainId,
			"indexerSrcChainID",
			i.srcChainId.Uint64(),
		)

		return nil
	}

	if _, ignored := i.ignoredMsgHashes[event.MsgHash]; ignored {
		slog.Warn("skipping ignored MessageProcessed msgHash", "msgHash", event.MsgHash)
		return nil
	}

	if event.Raw.Removed {
		slog.Info("event is removed")
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

	// if the message is not status new, and we are iterating crawling past blocks,
	// we also dont want to handle this event. it has already been handled.
	if i.watchMode == CrawlPastBlocks {
		// we can return early, this message has been processed as expected.
		return nil
	}

	// Forged-message detection (relocated from the removed watchdog): if the
	// bridge that should have originated this message has no record of sending
	// it, alert. Runs before saveEventToDB so an RPC failure leaves no
	// half-saved state and the event is cleanly re-indexed on retry.
	forged, err := i.isForgedMessage(message)
	if err != nil {
		return errors.Wrap(err, "i.isForgedMessage")
	}

	if forged {
		slog.Warn("dest bridge did not send this message", "msgId", message.Id)

		relayer.BridgeMessageNotSent.Inc()
	}

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	if _, err := i.saveEventToDB(
		ctx,
		marshaled,
		"0x",
		chainID,
		1,
		message.SrcOwner.Hex(),
		message.Data,
		message.Value,
		event.Raw.BlockNumber,
	); err != nil {
		return errors.Wrap(err, "i.saveEventToDB")
	}

	return nil
}

// isForgedMessage reports whether the bridge that should have originated this
// message (destBridge) has no record of having sent it — the signature of a
// forged message. Relocated from the removed watchdog.
func (i *Indexer) isForgedMessage(message bridge.IBridgeMessage) (bool, error) {
	sent, err := i.destBridge.IsMessageSent(nil, message)
	if err != nil {
		return false, errors.Wrap(err, "i.destBridge.IsMessageSent")
	}

	return !sent, nil
}

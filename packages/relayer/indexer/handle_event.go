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
	"github.com/taikoxyz/taiko-mono/packages/relayer/queue"
)

// handleEvent handles an individual MessageSent event
func (i *Indexer) handleEvent(
	ctx context.Context,
	chainID *big.Int,
	event *bridge.BridgeMessageSent,
) error {
	slog.Info("event found for msgHash", "msgHash", common.Hash(event.MsgHash).Hex(), "txHash", event.Raw.TxHash.Hex())

	if event.Message.DestChainId.Cmp(i.destChainId) != 0 {
		slog.Info("skipping event, wrong chainID",
			"messageDestChainID",
			event.Message.DestChainId.Uint64(),
			"indexerDestChainID",
			i.destChainId.Uint64(),
		)

		return nil
	}

	if err := i.detectAndHandleReorg(ctx, relayer.EventNameMessageSent, common.Hash(event.MsgHash).Hex()); err != nil {
		return errors.Wrap(err, "svc.detectAndHandleReorg")
	}

	if event.MsgHash == relayer.ZeroHash {
		slog.Warn("Zero msgHash found. This is unexpected. Returning early")
		return nil
	}

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

	opts := relayer.SaveEventOpts{
		Name:         relayer.EventNameMessageSent,
		Data:         string(marshaled),
		ChainID:      chainID,
		Status:       eventStatus,
		EventType:    eventType,
		Amount:       amount.String(),
		MsgHash:      common.Hash(event.MsgHash).Hex(),
		MessageOwner: event.Message.User.Hex(),
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

	msg := queue.QueueMessageBody{
		ID:    e.ID,
		Event: event,
	}

	marshalledMsg, err := json.Marshal(msg)
	if err != nil {
		return errors.Wrap(err, "json.Marshal")
	}

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

	messageStatus, err := i.destBridge.GetMessageStatus(&bind.CallOpts{
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

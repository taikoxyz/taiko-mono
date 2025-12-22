package indexer

import (
	"context"
	"encoding/json"
	"log/slog"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"github.com/taikoxyz/taiko-mono/packages/relayer/pkg/queue"
	shasta "github.com/taikoxyz/taiko-mono/packages/taiko-client/bindings/shasta"
)

func (i *Indexer) handleBondInstructionCreatedEvent(
	ctx context.Context,
	event *shasta.ShastaInboxClientBondInstructionCreated,
	waitForConfirmations bool,
) error {
	slog.Info("bond instruction created event found",
		"proposalId", event.ProposalId,
		"payer", event.BondInstruction.Payer.Hex(),
		"payee", event.BondInstruction.Payee.Hex(),
		"txHash", event.Raw.TxHash.Hex(),
	)

	if event.Raw.Removed {
		slog.Info("event is removed")
		return nil
	}

	if waitForConfirmations {
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

	if i.shastaInbox == nil {
		return errors.New("shasta inbox not configured")
	}

	signal, err := i.shastaInbox.HashBondInstruction(&bind.CallOpts{
		Context: ctx,
	}, event.BondInstruction)
	if err != nil {
		return errors.Wrapf(
			err,
			"i.shastaInbox.HashBondInstruction proposalId=%s payer=%s payee=%s txHash=%s",
			event.ProposalId.String(),
			event.BondInstruction.Payer.Hex(),
			event.BondInstruction.Payee.Hex(),
			event.Raw.TxHash.Hex(),
		)
	}

	signalHex := common.Hash(signal).Hex()

	existingEvent, err := i.eventRepo.FirstByEventAndMsgHash(
		ctx,
		relayer.EventNameBondInstructionCreated,
		signalHex,
	)
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.FirstByEventAndMsgHash")
	}

	if existingEvent != nil {
		return nil
	}

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	e, err := i.eventRepo.Save(ctx, &relayer.SaveEventOpts{
		Name:           relayer.EventNameBondInstructionCreated,
		Data:           string(marshaled),
		ChainID:        i.srcChainId,
		DestChainID:    i.destChainId,
		Status:         relayer.EventStatusNew,
		EventType:      relayer.EventTypeBondInstruction,
		Amount:         "0",
		MsgHash:        signalHex,
		MessageOwner:   event.BondInstruction.Payer.Hex(),
		Event:          relayer.EventNameBondInstructionCreated,
		EmittedBlockID: event.Raw.BlockNumber,
	})
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.Save")
	}

	msg := queue.QueueBondInstructionCreatedBody{
		ID:     e.ID,
		Event:  event,
		Signal: signalHex,
	}

	marshalledMsg, err := json.Marshal(msg)
	if err != nil {
		return errors.Wrap(err, "json.Marshal")
	}

	if err := i.queue.Publish(ctx, i.queueName(), marshalledMsg, nil, nil); err != nil {
		return errors.Wrap(err, "i.queue.Publish")
	}

	return nil
}

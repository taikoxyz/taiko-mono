package indexer

import (
	"context"
	"encoding/json"
	"math/big"
	"time"

	"log/slog"

	"github.com/ethereum/go-ethereum/common"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/sgxverifier"
)

func (i *Indexer) saveInstanceAddedEvents(
	ctx context.Context,
	chainID *big.Int,
	events *sgxverifier.SgxVerifierInstanceAddedIterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no InstanceAdded events")
		return nil
	}

	for {
		event := events.Event

		slog.Info("new instanceAdded event")

		// Getting the transaction
		tx, _, err := i.ethClient.TransactionByHash(context.Background(), event.Raw.TxHash)
		if err != nil {
			return err
		}

		receipt, err := i.ethClient.TransactionReceipt(ctx, tx.Hash())

		if err != nil {
			return err
		}

		sender, err := i.ethClient.TransactionSender(ctx, tx, event.Raw.BlockHash, receipt.TransactionIndex)
		if err != nil {
			return err
		}

		if err := i.saveInstanceAddedEvent(ctx, chainID, event, sender); err != nil {
			return errors.Wrap(err, "i.saveInstanceAddedEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (i *Indexer) saveInstanceAddedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *sgxverifier.SgxVerifierInstanceAdded,
	sender common.Address,
) error {
	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	block, err := i.ethClient.BlockByNumber(ctx, new(big.Int).SetUint64(event.Raw.BlockNumber))
	if err != nil {
		return errors.Wrap(err, "i.ethClient.BlockByNumber")
	}

	_, err = i.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:           eventindexer.EventNameInstanceAdded,
		Data:           string(marshaled),
		ChainID:        chainID,
		Event:          eventindexer.EventNameInstanceAdded,
		Address:        sender.Hex(),
		TransactedAt:   time.Unix(int64(block.Time()), 0),
		EmittedBlockID: event.Raw.BlockNumber,
	})
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.Save")
	}

	return nil
}

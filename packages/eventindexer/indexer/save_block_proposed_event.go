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
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/taikol1"
)

func (i *Indexer) saveBlockProposedEvents(
	ctx context.Context,
	chainID *big.Int,
	events *taikol1.TaikoL1BlockProposedIterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no blockProposed events")
		return nil
	}

	for {
		event := events.Event

		tx, _, err := i.ethClient.TransactionByHash(ctx, event.Raw.TxHash)
		if err != nil {
			return errors.Wrap(err, "i.ethClient.TransactionByHash")
		}

		sender, err := i.ethClient.TransactionSender(ctx, tx, event.Raw.BlockHash, event.Raw.TxIndex)
		if err != nil {
			return errors.Wrap(err, "i.ethClient.TransactionSender")
		}

		if err := i.saveBlockProposedEvent(ctx, chainID, event, sender); err != nil {
			eventindexer.BlockProposedEventsProcessedError.Inc()

			return errors.Wrap(err, "i.saveBlockProposedEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (i *Indexer) saveBlockProposedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *taikol1.TaikoL1BlockProposed,
	sender common.Address,
) error {
	slog.Info("blockProposed", "proposer", sender.Hex())

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	blockID := event.BlockId.Int64()

	assignedProver := event.AssignedProver.Hex()

	block, err := i.ethClient.BlockByNumber(ctx, new(big.Int).SetUint64(event.Raw.BlockNumber))
	if err != nil {
		return errors.Wrap(err, "i.ethClient.BlockByNumber")
	}

	_, err = i.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:           eventindexer.EventNameBlockProposed,
		Data:           string(marshaled),
		ChainID:        chainID,
		Event:          eventindexer.EventNameBlockProposed,
		Address:        sender.Hex(),
		BlockID:        &blockID,
		AssignedProver: &assignedProver,
		TransactedAt:   time.Unix(int64(block.Time()), 0).UTC(),
		EmittedBlockID: event.Raw.BlockNumber,
	})
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.Save")
	}

	eventindexer.BlockProposedEventsProcessed.Inc()

	return nil
}

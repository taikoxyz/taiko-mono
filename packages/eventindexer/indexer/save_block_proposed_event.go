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

func (indxr *Indexer) saveBlockProposedEvents(
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

		if err := indxr.detectAndHandleReorg(ctx, eventindexer.EventNameBlockProposed, event.BlockId.Int64()); err != nil {
			return errors.Wrap(err, "indxr.detectAndHandleReorg")
		}

		tx, _, err := indxr.ethClient.TransactionByHash(ctx, event.Raw.TxHash)
		if err != nil {
			return errors.Wrap(err, "indxr.ethClient.TransactionByHash")
		}

		sender, err := indxr.ethClient.TransactionSender(ctx, tx, event.Raw.BlockHash, event.Raw.TxIndex)
		if err != nil {
			return errors.Wrap(err, "indxr.ethClient.TransactionSender")
		}

		if err := indxr.saveBlockProposedEvent(ctx, chainID, event, sender); err != nil {
			eventindexer.BlockProposedEventsProcessedError.Inc()

			return errors.Wrap(err, "indxr.saveBlockProposedEvent")
		}

		if !events.Next() {
			return nil
		}
	}
}

func (indxr *Indexer) saveBlockProposedEvent(
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

	block, err := indxr.ethClient.BlockByNumber(ctx, new(big.Int).SetUint64(event.Raw.BlockNumber))
	if err != nil {
		return errors.Wrap(err, "indxr.ethClient.BlockByNumber")
	}

	_, err = indxr.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:           eventindexer.EventNameBlockProposed,
		Data:           string(marshaled),
		ChainID:        chainID,
		Event:          eventindexer.EventNameBlockProposed,
		Address:        sender.Hex(),
		BlockID:        &blockID,
		AssignedProver: &assignedProver,
		TransactedAt:   time.Unix(int64(block.Time()), 0).UTC(),
	})
	if err != nil {
		return errors.Wrap(err, "indxr.eventRepo.Save")
	}

	eventindexer.BlockProposedEventsProcessed.Inc()

	return nil
}

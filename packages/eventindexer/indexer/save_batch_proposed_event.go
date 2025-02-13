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
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/pacaya/taikoinbox"
	"golang.org/x/sync/errgroup"
)

func (i *Indexer) saveBatchProposedEvents(
	ctx context.Context,
	chainID *big.Int,
	events *taikoinbox.TaikoInboxBatchProposedIterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no batchProposed events")
		return nil
	}

	wg, ctx := errgroup.WithContext(ctx)

	for {
		event := events.Event

		wg.Go(func() error {
			tx, _, err := i.ethClient.TransactionByHash(ctx, event.Raw.TxHash)
			if err != nil {
				return errors.Wrap(err, "i.ethClient.TransactionByHash")
			}

			sender, err := i.ethClient.TransactionSender(ctx, tx, event.Raw.BlockHash, event.Raw.TxIndex)
			if err != nil {
				return errors.Wrap(err, "i.ethClient.TransactionSender")
			}

			if err := i.saveBatchProposedEvent(ctx, chainID, event, sender); err != nil {
				eventindexer.BatchProposedEventsProcessedError.Inc()

				return errors.Wrap(err, "i.saveBatchProposedEvent")
			}

			return nil
		})

		if !events.Next() {
			break
		}
	}

	if err := wg.Wait(); err != nil {
		return err
	}

	return nil
}

func (i *Indexer) saveBatchProposedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *taikoinbox.TaikoInboxBatchProposed,
	sender common.Address,
) error {
	slog.Info("batchProposed", "proposer", sender.Hex())

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	lastBlockId := int64(event.Info.LastBlockId)

	numBlocks := int64(len(event.Info.Blocks))

	batchId := int64(event.Meta.BatchId)
	assignedProver := sender.Hex()

	block, err := i.ethClient.BlockByNumber(ctx, new(big.Int).SetUint64(event.Raw.BlockNumber))
	if err != nil {
		return errors.Wrap(err, "i.ethClient.BlockByNumber")
	}

	_, err = i.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:           eventindexer.EventNameBatchProposed,
		Data:           string(marshaled),
		ChainID:        chainID,
		Event:          eventindexer.EventNameBatchProposed,
		BlockID:        &lastBlockId,
		Address:        sender.Hex(),
		AssignedProver: &assignedProver,
		TransactedAt:   time.Unix(int64(block.Time()), 0).UTC(),
		EmittedBlockID: event.Raw.BlockNumber,
		NumBlocks:      &numBlocks,
		BatchID:        &batchId,
	})
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.Save")
	}

	eventindexer.BatchProposedEventsProcessed.Inc()

	return nil
}

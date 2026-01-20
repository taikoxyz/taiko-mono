package indexer

import (
	"context"
	"encoding/json"
	"math/big"
	"time"

	"log/slog"

	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer"
	"github.com/taikoxyz/taiko-mono/packages/eventindexer/contracts/shasta/inbox"
	"golang.org/x/sync/errgroup"
)

func (i *Indexer) saveProposedEvents(
	ctx context.Context,
	chainID *big.Int,
	events *inbox.InboxProposedIterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no Proposed events")
		return nil
	}

	wg, ctx := errgroup.WithContext(ctx)

	for {
		currentEvent := events.Event
		wg.Go(func() error {
			if err := i.saveProposedEvent(ctx, chainID, currentEvent); err != nil {
				eventindexer.ProposedEventsProcessedError.Inc()

				return errors.Wrap(err, "i.saveProposedEvent")
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

func (i *Indexer) saveProposedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *inbox.InboxProposed,
) error {
	slog.Info("Proposed", "proposer", event.Proposer.Hex())

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}
	// reuse batchId for proposal ID for compatibility
	proposalId := event.Id.Int64()
	proposer := event.Proposer.Hex()

	block, err := i.ethClient.BlockByNumber(ctx, new(big.Int).SetUint64(event.Raw.BlockNumber))
	if err != nil {
		return errors.Wrap(err, "i.ethClient.BlockByNumber")
	}

	_, err = i.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
		Name:    eventindexer.EventNameProposed,
		Data:    string(marshaled),
		ChainID: chainID,
		Event:   eventindexer.EventNameProposed,
		// Address = proposer
		Address:      proposer,
		TransactedAt: time.Unix(int64(block.Time()), 0).UTC(),
		// EmittedBlockID = L1 Block ID
		EmittedBlockID: event.Raw.BlockNumber,
		BatchID:        &proposalId,
	})
	if err != nil {
		return errors.Wrap(err, "i.eventRepo.Save")
	}

	eventindexer.ProposedEventsProcessed.Inc()

	return nil
}

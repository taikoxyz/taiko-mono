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

func (i *Indexer) saveProvedEvents(
	ctx context.Context,
	chainID *big.Int,
	events *inbox.InboxProvedIterator,
) error {
	if !events.Next() || events.Event == nil {
		slog.Info("no Proved events")
		return nil
	}

	wg, ctx := errgroup.WithContext(ctx)

	for {
		event := events.Event

		wg.Go(func() error {
			if err := i.saveProvedEvent(ctx, chainID, event); err != nil {
				eventindexer.ProvedEventsProcessedError.Inc()

				return errors.Wrap(err, "i.saveProvedEvent")
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

func (i *Indexer) saveProvedEvent(
	ctx context.Context,
	chainID *big.Int,
	event *inbox.InboxProved,
) error {
	slog.Info("Proved event found",
		"FirstProposalId", event.FirstProposalId.Int64(),
		"FirstNewProposalId", event.FirstNewProposalId.Int64(),
		"LastProposalId", event.LastProposalId.Int64(),
		"prover", event.ActualProver.Hex())

	marshaled, err := json.Marshal(event)
	if err != nil {
		return errors.Wrap(err, "json.Marshal(event)")
	}

	block, err := i.ethClient.BlockByNumber(ctx, new(big.Int).SetUint64(event.Raw.BlockNumber))
	if err != nil {
		return errors.Wrap(err, "i.ethClient.BlockByNumber")
	}

	// iterate through the range of new proposals that were Proved per event
	for proposalID := event.FirstNewProposalId.Int64(); proposalID <= event.LastProposalId.Int64(); proposalID++ {
		pID := int64(proposalID)

		_, err = i.eventRepo.Save(ctx, eventindexer.SaveEventOpts{
			Name:    eventindexer.EventNameProved,
			Data:    string(marshaled),
			ChainID: chainID,
			Event:   eventindexer.EventNameProved,
			// let Address = actualProver
			Address:        event.ActualProver.Hex(),
			TransactedAt:   time.Unix(int64(block.Time()), 0),
			EmittedBlockID: event.Raw.BlockNumber,
			// let BatchID = proposalID
			BatchID: &pID,
		})
		if err != nil {
			return errors.Wrap(err, "i.eventRepo.Save")
		}
	}

	eventindexer.ProvedEventsProcessed.Inc()

	return nil
}

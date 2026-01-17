package indexer

import (
	"context"
	"log/slog"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/pkg/errors"
	"golang.org/x/sync/errgroup"
)

// nolint
func filterFuncShasta(
	ctx context.Context,
	chainID *big.Int,
	i *Indexer,
	filterOpts *bind.FilterOpts,
) error {
	wg, ctx := errgroup.WithContext(ctx)

	if i.shastaInbox != nil {
		wg.Go(func() error {
			provedEvents, err := i.shastaInbox.FilterProved(filterOpts, nil)
			if err != nil {
				return errors.Wrap(err, "i.shastaInbox.FilterProved")
			}

			err = i.saveProvedEvents(ctx, chainID, provedEvents)
			if err != nil {
				return errors.Wrap(err, "i.saveProvedEvents")
			}

			return nil
		})

		// dont run in goroutines, as the batchProposed events need to be processed in order and
		// saved to the DB in order, as we need the previous one's "lastBlockId" to calculate
		// the blockIds of the next batchProposed event, since they are no longer
		// emitted in the event themself.
		proposedEvent, err := i.shastaInbox.FilterProposed(filterOpts, nil, nil)
		if err != nil {
			return errors.Wrap(err, "i.shastaInbox.FilterProposed")
		}

		err = i.saveProposedEvents(ctx, chainID, proposedEvent)
		if err != nil {
			return errors.Wrap(err, "i.saveProposedEvent")
		}
	}

	if i.bridge != nil {
		wg.Go(func() error {
			messagesSent, err := i.bridge.FilterMessageSent(filterOpts, nil)
			if err != nil {
				return errors.Wrap(err, "i.bridge.FilterMessageSent")
			}

			err = i.saveMessageSentEvents(ctx, chainID, messagesSent)
			if err != nil {
				return errors.Wrap(err, "i.saveMessageSentEvents")
			}

			return nil
		})
	}

	wg.Go(func() error {
		if err := i.indexRawBlockData(ctx, chainID, filterOpts.Start, *filterOpts.End); err != nil {
			return errors.Wrap(err, "i.indexRawBlockData")
		}

		return nil
	})

	err := wg.Wait()

	if err != nil {
		if errors.Is(err, context.Canceled) {
			slog.Error("filter context cancelled")
			return err
		}

		return err
	}

	return nil
}

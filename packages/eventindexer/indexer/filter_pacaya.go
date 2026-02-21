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
func filterFuncPacaya(
	ctx context.Context,
	chainID *big.Int,
	i *Indexer,
	filterOpts *bind.FilterOpts,
) error {
	wg, ctx := errgroup.WithContext(ctx)

	if i.taikoInbox != nil {
		wg.Go(func() error {
			batchesProvedEvents, err := i.taikoInbox.FilterBatchesProved(filterOpts)
			if err != nil {
				return errors.Wrap(err, "i.taikoInbox.FilterBatchesProved")
			}

			err = i.saveBatchesProvedEvents(ctx, chainID, batchesProvedEvents)
			if err != nil {
				return errors.Wrap(err, "i.saveBatchesProvedEvents")
			}

			return nil
		})

		wg.Go(func() error {
			batchesVerifiedEvents, err := i.taikoInbox.FilterBatchesVerified(filterOpts)
			if err != nil {
				return errors.Wrap(err, "i.taikoInbox.FilterBatchesVerified")
			}

			err = i.saveBatchesVerifiedEvents(ctx, chainID, batchesVerifiedEvents)
			if err != nil {
				return errors.Wrap(err, "i.saveBatchesVerifiedEvents")
			}

			return nil
		})

		// dont run in goroutines, as the batchProposed events need to be processed in order and
		// saved to the DB in order, as we need the previous one's "lastBlockId" to calculate
		// the blockIds of the next batchProposed event, since they are no longer
		// emitted in the event themself.
		batchProposedEvent, err := i.taikoInbox.FilterBatchProposed(filterOpts)
		if err != nil {
			return errors.Wrap(err, "i.taikoInbox.FilterBatchProposed")
		}

		err = i.saveBatchProposedEvents(ctx, chainID, batchProposedEvent)
		if err != nil {
			return errors.Wrap(err, "i.saveBatchProposedEvents")
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

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
		wg.Go(func() error {
			proposedEvents, err := i.shastaInbox.FilterProposed(filterOpts, nil, nil)
			if err != nil {
				return errors.Wrap(err, "i.shastaInbox.FilterProposed")
			}

			err = i.saveProposedEvents(ctx, chainID, proposedEvents)
			if err != nil {
				return errors.Wrap(err, "i.saveProposedEvent")
			}

			return nil
		})
	}

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

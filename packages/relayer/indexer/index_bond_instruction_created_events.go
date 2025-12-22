package indexer

import (
	"context"
	"log/slog"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/pkg/errors"
	"github.com/taikoxyz/taiko-mono/packages/relayer"
	"golang.org/x/sync/errgroup"
)

func (i *Indexer) indexBondInstructionCreatedEvents(
	ctx context.Context,
	filterOpts *bind.FilterOpts,
) error {
	if i.shastaInbox == nil {
		return errors.New("shasta inbox not configured")
	}

	slog.Info("indexing bondInstructionCreated events")

	events, err := i.shastaInbox.FilterBondInstructionCreated(filterOpts, nil)
	if err != nil {
		return errors.Wrap(err, "shastaInbox.FilterBondInstructionCreated")
	}

	group, _ := errgroup.WithContext(ctx)
	group.SetLimit(i.numGoroutines)

	first := true

	for events.Next() {
		event := events.Event

		if i.watchMode != CrawlPastBlocks && first {
			first = false

			if err := i.checkReorg(ctx, event.Raw.BlockNumber); err != nil {
				return err
			}
		}

		group.Go(func() error {
			err := i.handleBondInstructionCreatedEvent(ctx, event, true)
			if err != nil {
				relayer.ErrorEvents.Inc()
				slog.Error("error handling bond instruction created", "err", err.Error())

				return err
			}

			return nil
		})
	}

	if err := group.Wait(); err != nil {
		return errors.Wrap(err, "group.Wait")
	}

	return nil
}

package indexer

import (
	"context"
	"math/big"

	"log/slog"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/pkg/errors"
	"golang.org/x/sync/errgroup"
)

type FilterFunc func(
	ctx context.Context,
	chainID *big.Int,
	i *Indexer,
	filterOpts *bind.FilterOpts,
) error

func filterFunc(
	ctx context.Context,
	chainID *big.Int,
	i *Indexer,
	filterOpts *bind.FilterOpts,
) error {
	wg, ctx := errgroup.WithContext(ctx)

	if i.bridge != nil {
		wg.Go(func() error {
			messagesSent, err := i.bridge.FilterMessageSent(filterOpts, nil)
			if err != nil {
				return errors.Wrap(err, "i.bridge.FilterMessageSent")
			}
			defer messagesSent.Close()

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

func (i *Indexer) filter(
	ctx context.Context,
) error {
	endBlockID, err := i.ethClient.BlockNumber(ctx)
	if err != nil {
		return errors.Wrap(err, "i.ethClient.BlockNumber")
	}

	slog.Info("getting batch of events",
		"startBlock", i.latestIndexedBlockNumber,
		"endBlock", endBlockID,
		"batchSize", i.blockBatchSize,
	)

	for j := i.latestIndexedBlockNumber + 1; j <= endBlockID; j += i.blockBatchSize {
		end := min(j+i.blockBatchSize-1, endBlockID)

		slog.Info("block batch", "start", j, "end", end)

		filterOpts := &bind.FilterOpts{
			Start:   j,
			End:     &end,
			Context: ctx,
		}

		wg, ctx := errgroup.WithContext(ctx)

		wg.Go(func() error {
			if err := filterFunc(ctx, new(big.Int).SetUint64(i.srcChainID), i, filterOpts); err != nil {
				return errors.Wrap(err, "filter")
			}

			return nil
		})

		if i.inbox != nil {
			wg.Go(func() error {
				if err := filterFuncShasta(ctx, new(big.Int).SetUint64(i.srcChainID), i, filterOpts); err != nil {
					return errors.Wrap(err, "filterFuncShasta")
				}

				return nil
			})
		}

		if err := wg.Wait(); err != nil {
			return err
		}

		i.latestIndexedBlockNumber = end
	}

	return nil
}

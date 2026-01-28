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

	if i.taikol1 != nil {
		wg.Go(func() error {
			transitionProvedEvents, err := i.taikol1.FilterTransitionProved(filterOpts, nil)
			if err != nil {
				return errors.Wrap(err, "i.taikol1.FilterTransitionProved")
			}

			err = i.saveTransitionProvedEvents(ctx, chainID, transitionProvedEvents)
			if err != nil {
				return errors.Wrap(err, "i.saveTransitionProvedEvents")
			}

			return nil
		})

		wg.Go(func() error {
			transitionContestedEvents, err := i.taikol1.FilterTransitionContested(filterOpts, nil)
			if err != nil {
				return errors.Wrap(err, "i.taikol1.FilterTransitionContested")
			}

			err = i.saveTransitionContestedEvents(ctx, chainID, transitionContestedEvents)
			if err != nil {
				return errors.Wrap(err, "i.saveTransitionContestedEvents")
			}

			return nil
		})

		wg.Go(func() error {
			blockProposedEvents, err := i.taikol1.FilterBlockProposed(filterOpts, nil, nil)
			if err != nil {
				return errors.Wrap(err, "i.taikol1.FilterBlockProposed")
			}

			err = i.saveBlockProposedEvents(ctx, chainID, blockProposedEvents)
			if err != nil {
				return errors.Wrap(err, "i.saveBlockProposedEvents")
			}

			return nil
		})

		wg.Go(func() error {
			blockVerifiedEvents, err := i.taikol1.FilterBlockVerified(filterOpts, nil, nil)
			if err != nil {
				return errors.Wrap(err, "i.taikol1.FilterBlockVerified")
			}

			err = i.saveBlockVerifiedEvents(ctx, chainID, blockVerifiedEvents)
			if err != nil {
				return errors.Wrap(err, "i.saveBlockVerifiedEvents")
			}

			return nil
		})
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

	if i.latestIndexedBlockNumber >= i.ontakeForkHeight {
		slog.Info("ontake fork height reached", "forkHeight", i.ontakeForkHeight)
		i.isPostOntakeForkHeightReached = true
	}

	if i.latestIndexedBlockNumber >= i.pacayaForkHeight {
		slog.Info("pacaya fork height reached", "forkHeight", i.pacayaForkHeight)
		i.isPostPacayaForkHeightReached = true
	}

	for j := i.latestIndexedBlockNumber + 1; j <= endBlockID; j += i.blockBatchSize {
		end := min(j+i.blockBatchSize-1, endBlockID)

		if !i.isPostPacayaForkHeightReached && i.taikol1 != nil && i.pacayaForkHeight > i.latestIndexedBlockNumber && i.pacayaForkHeight <= end {
			slog.Info("pacaya fork height reached", "height", i.pacayaForkHeight)

			i.isPostPacayaForkHeightReached = true

			end = i.pacayaForkHeight - 1

			slog.Info("setting end block ID to pacayaForkheight - 1",
				"latestIndexedBlockNumber",
				i.latestIndexedBlockNumber,
				"pacayaForkHeight", i.pacayaForkHeight,
				"endBlockID", end,
				"isPostPacayaForkHeightReached", i.isPostPacayaForkHeightReached,
			)
		} else if !i.isPostOntakeForkHeightReached && i.taikol1 != nil && i.ontakeForkHeight > i.latestIndexedBlockNumber && i.ontakeForkHeight <= end {
			slog.Info("ontake fork height reached", "height", i.ontakeForkHeight)

			i.isPostOntakeForkHeightReached = true

			end = i.ontakeForkHeight - 1

			slog.Info("setting end block ID to ontakeForkHeight - 1",
				"latestIndexedBlockNumber",
				i.latestIndexedBlockNumber,
				"ontakeForkHeight", i.ontakeForkHeight,
				"endBlockID", end,
				"isPostOntakeForkHeightReached", i.isPostOntakeForkHeightReached,
			)
		}

		slog.Info("block batch", "start", j, "end", end)

		filterOpts := &bind.FilterOpts{
			Start:   j,
			End:     &end,
			Context: ctx,
		}

		var filter FilterFunc

		switch {
		case i.isPostPacayaForkHeightReached:
			filter = filterFuncPacaya
		case i.isPostOntakeForkHeightReached:
			filter = filterFuncOntake
		default:
			filter = filterFunc
		}

		wg, ctx := errgroup.WithContext(ctx)

		wg.Go(func() error {
			if err := filter(ctx, new(big.Int).SetUint64(i.srcChainID), i, filterOpts); err != nil {
				return errors.Wrap(err, "filter")
			}

			return nil
		})
		// runs shasta filter concurrently with pacaya filter which will result in more RPC requests, but allows for
		// graceful transition without the forkHeight set.
		if i.shastaInbox != nil {
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

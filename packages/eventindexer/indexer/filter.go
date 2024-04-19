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

// nolint
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
				return errors.Wrap(err, "i.saveBlockProvenEvents")
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

	if i.assignmentHook != nil {
		wg.Go(func() error {
			blocksAssigned, err := i.assignmentHook.FilterBlockAssigned(filterOpts, nil)
			if err != nil {
				return errors.Wrap(err, "i.assignmentHook.FilterBlockAssigned")
			}

			err = i.saveBlockAssignedEvents(ctx, chainID, blocksAssigned)
			if err != nil {
				return errors.Wrap(err, "i.saveBlockAssignedEvents")
			}

			return nil
		})
	}

	if i.swaps != nil {
		for _, s := range i.swaps {
			swap := s

			wg.Go(func() error {
				swaps, err := swap.FilterSwap(filterOpts, nil, nil)
				if err != nil {
					return errors.Wrap(err, "i.bridge.FilterSwap")
				}

				// only save ones above 0.01 ETH, this is only for Galaxe
				// and we dont care about the rest
				err = i.saveSwapEvents(ctx, chainID, swaps)
				if err != nil {
					return errors.Wrap(err, "i.saveSwapEvents")
				}

				return nil
			})

			wg.Go(func() error {
				liquidityAdded, err := swap.FilterMint(filterOpts, nil)

				if err != nil {
					return errors.Wrap(err, "i.bridge.FilterMint")
				}

				// only save ones above 0.1 ETH, this is only for Galaxe
				// and we dont care about the rest
				err = i.saveLiquidityAddedEvents(ctx, chainID, liquidityAdded)
				if err != nil {
					return errors.Wrap(err, "i.saveLiquidityAddedEvents")
				}

				return nil
			})
		}
	}

	if i.sgxVerifier != nil {
		wg.Go(func() error {
			instancesAdded, err := i.sgxVerifier.FilterInstanceAdded(filterOpts, nil, nil)
			if err != nil {
				return errors.Wrap(err, "i.sgxVerifier.FilterInstanceAdded")
			}

			err = i.saveInstanceAddedEvents(ctx, chainID, instancesAdded)
			if err != nil {
				return errors.Wrap(err, "i.saveInstanceAddedEvents")
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
	filter FilterFunc,
) error {
	header, err := i.ethClient.HeaderByNumber(ctx, nil)
	if err != nil {
		return errors.Wrap(err, "i.ethClient.HeaderByNumber")
	}

	// the end block is the latest header.
	endBlockID := header.Number.Uint64()

	slog.Info("getting batch of events",
		"startBlock", i.latestIndexedBlockNumber,
		"endBlock", header.Number.Int64(),
		"batchSize", i.blockBatchSize,
	)

	for j := i.latestIndexedBlockNumber + 1; j <= endBlockID; j += i.blockBatchSize {
		end := i.latestIndexedBlockNumber + i.blockBatchSize
		// if the end of the batch is greater than the latest block number, set end
		// to the latest block number
		if end > endBlockID {
			end = endBlockID
		}

		slog.Info("block batch", "start", j, "end", end)

		filterOpts := &bind.FilterOpts{
			Start:   j,
			End:     &end,
			Context: ctx,
		}

		if err := filter(ctx, new(big.Int).SetUint64(i.srcChainID), i, filterOpts); err != nil {
			return errors.Wrap(err, "filter")
		}

		i.latestIndexedBlockNumber = end
	}

	return nil
}

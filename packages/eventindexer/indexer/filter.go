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
			blockVerifiedEvents, err := i.taikol1.FilterBlockVerified(filterOpts, nil, nil, nil)
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
